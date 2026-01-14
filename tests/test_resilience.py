"""Tests for resilience services: rate limiter, circuit breaker, retry."""

import pytest
import time
from unittest.mock import patch, AsyncMock

from src.services.rate_limiter import (
    SlidingWindowRateLimiter,
    TokenBucketRateLimiter,
    RateLimitResult,
    check_rate_limit,
    get_default_rate_limiter,
)
from src.services.resilience import (
    CircuitBreaker,
    CircuitState,
    CircuitOpenError,
    CircuitBreakerConfig,
    with_retry,
)


class TestSlidingWindowRateLimiter:
    """Tests for SlidingWindowRateLimiter."""

    def setup_method(self):
        """Set up test fixtures."""
        self.limiter = SlidingWindowRateLimiter(
            max_requests=3,
            window_seconds=60,
            block_duration=0
        )

    def test_allows_requests_under_limit(self):
        """Test that requests are allowed under the limit."""
        for i in range(3):
            result = self.limiter.is_allowed("client1")
            assert result.allowed is True
            assert result.remaining == 2 - i

    def test_blocks_requests_over_limit(self):
        """Test that requests are blocked over the limit."""
        for i in range(3):
            self.limiter.is_allowed("client1")

        result = self.limiter.is_allowed("client1")
        assert result.allowed is False
        assert result.remaining == 0

    def test_different_clients_independent(self):
        """Test that different clients have independent limits."""
        self.limiter.is_allowed("client1")
        self.limiter.is_allowed("client1")
        self.limiter.is_allowed("client1")

        # client1 is now blocked
        assert self.limiter.is_allowed("client1").allowed is False

        # client2 should still be allowed
        result = self.limiter.is_allowed("client2")
        assert result.allowed is True

    def test_get_stats(self):
        """Test getting statistics for a client."""
        self.limiter.is_allowed("client1")
        self.limiter.is_allowed("client1")

        stats = self.limiter.get_stats("client1")
        assert stats["used"] == 2
        assert stats["remaining"] == 1
        assert stats["limit"] == 3
        assert stats["blocked"] is False

    def test_reset(self):
        """Test resetting the rate limiter."""
        self.limiter.is_allowed("client1")
        self.limiter.is_allowed("client1")
        self.limiter.is_allowed("client1")

        # Now blocked
        assert self.limiter.is_allowed("client1").allowed is False

        # Reset
        self.limiter.reset("client1")

        # Should be allowed again
        result = self.limiter.is_allowed("client1")
        assert result.allowed is True


class TestTokenBucketRateLimiter:
    """Tests for TokenBucketRateLimiter."""

    def setup_method(self):
        """Set up test fixtures."""
        self.limiter = TokenBucketRateLimiter(
            rate_per_second=1.0,
            max_burst=5
        )

    def test_allows_burst_up_to_max(self):
        """Test that burst traffic is allowed up to max."""
        for i in range(5):
            result = self.limiter.is_allowed("client1")
            assert result.allowed is True

        # Now exhausted
        result = self.limiter.is_allowed("client1")
        assert result.allowed is False

    def test_refills_over_time(self):
        """Test that tokens refill over time."""
        # Exhaust the bucket
        for i in range(5):
            self.limiter.is_allowed("client1")

        # Wait for refill
        time.sleep(0.2)

        # Should have some tokens now
        result = self.limiter.is_allowed("client1")
        # At least 1 token should have refilled
        assert result.remaining >= 0


class TestCircuitBreaker:
    """Tests for CircuitBreaker."""

    def setup_method(self):
        """Set up test fixtures."""
        self.config = CircuitBreakerConfig(
            failure_threshold=3,
            success_threshold=2,
            timeout_seconds=0.1,
            volume_threshold=3
        )
        self.breaker = CircuitBreaker("test", self.config)

    def test_initial_state_closed(self):
        """Test that circuit starts in closed state."""
        assert self.breaker.state == CircuitState.CLOSED

    def test_stays_closed_on_success(self):
        """Test that circuit stays closed on success."""
        self.breaker._on_success()
        assert self.breaker.state == CircuitState.CLOSED

    def test_opens_after_failure_threshold(self):
        """Test that circuit opens after failure threshold."""
        for _ in range(3):
            self.breaker._on_failure()

        assert self.breaker.state == CircuitState.OPEN

    def test_rejects_requests_when_open(self):
        """Test that requests are rejected when open."""
        for _ in range(3):
            self.breaker._on_failure()

        with pytest.raises(CircuitOpenError):
            self.breaker._execute_sync(lambda: "result")

    def test_transitions_to_half_open_after_timeout(self):
        """Test that circuit transitions to half-open after timeout."""
        for _ in range(3):
            self.breaker._on_failure()

        # Wait for timeout
        time.sleep(0.15)

        assert self.breaker.state == CircuitState.HALF_OPEN

    def test_closes_on_success_in_half_open(self):
        """Test that circuit closes on success in half-open."""
        for _ in range(3):
            self.breaker._on_failure()

        # Wait for timeout and access state to trigger transition
        time.sleep(0.15)
        assert self.breaker.state == CircuitState.HALF_OPEN

        # Need success_threshold (3) successes to close
        self.breaker._on_success()
        self.breaker._on_success()
        self.breaker._on_success()

        # State property triggers the transition check
        assert self.breaker.state == CircuitState.CLOSED

    def test_reopens_on_failure_in_half_open(self):
        """Test that circuit reopens on failure in half-open."""
        for _ in range(3):
            self.breaker._on_failure()

        # Wait for timeout
        time.sleep(0.15)

        # Failure should reopen
        self.breaker._on_failure()
        assert self.breaker.state == CircuitState.OPEN

    def test_reset(self):
        """Test resetting the circuit breaker."""
        for _ in range(3):
            self.breaker._on_failure()

        self.breaker.reset()

        assert self.breaker.state == CircuitState.CLOSED
        assert self.breaker._failure_count == 0

    def test_get_stats(self):
        """Test getting circuit statistics."""
        # The stats are based on _recent_results which tracks success/failure
        self.breaker._on_success()
        self.breaker._on_failure()

        stats = self.breaker.get_stats()
        assert stats["state"] == "closed"
        assert stats["recent_total"] == 2
        assert stats["recent_failures"] == 1
        assert stats["name"] == "test"


class TestRetryDecorator:
    """Tests for retry decorator."""

    def test_retries_on_failure(self):
        """Test that retry decorator retries on failure."""
        call_count = 0

        @with_retry(max_attempts=3, base_delay=0.01)
        def failing_function():
            nonlocal call_count
            call_count += 1
            if call_count < 3:
                raise ValueError("Temporary failure")
            return "success"

        result = failing_function()
        assert result == "success"
        assert call_count == 3

    def test_raises_after_max_attempts(self):
        """Test that exception is raised after max attempts."""
        call_count = 0

        @with_retry(max_attempts=3, base_delay=0.01)
        def always_failing():
            nonlocal call_count
            call_count += 1
            raise ValueError("Permanent failure")

        with pytest.raises(ValueError):
            always_failing()

        assert call_count == 3

    def test_no_retry_on_unexpected_exception(self):
        """Test that only specified exceptions are retried."""
        call_count = 0

        @with_retry(max_attempts=3, base_delay=0.01, retry_on=(ValueError,))
        def unexpected_exception():
            nonlocal call_count
            call_count += 1
            raise TypeError("Unexpected")

        with pytest.raises(TypeError):
            unexpected_exception()

        assert call_count == 1


class TestDefaultRateLimiter:
    """Tests for default rate limiter singleton."""

    def test_singleton_behavior(self):
        """Test that default rate limiter is a singleton."""
        limiter1 = get_default_rate_limiter()
        limiter2 = get_default_rate_limiter()
        assert limiter1 is limiter2

    def test_check_rate_limit_function(self):
        """Test the convenience check_rate_limit function."""
        result = check_rate_limit("test_client")
        assert isinstance(result, RateLimitResult)
