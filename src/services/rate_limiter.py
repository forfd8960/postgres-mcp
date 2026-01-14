"""Rate limiting service for request throttling."""

import time
import logging
from typing import Optional, Dict, Tuple
from dataclasses import dataclass, field
from collections import defaultdict, deque

logger = logging.getLogger("rate-limiter")


@dataclass
class RateLimitResult:
    """Result of a rate limit check."""
    allowed: bool
    remaining: int
    reset_time: float
    retry_after: Optional[float] = None
    limit: int = 0
    window: int = 0


class SlidingWindowRateLimiter:
    """Sliding window rate limiter using atomic operations.

    This implementation uses a sliding window algorithm which provides
    more accurate rate limiting than fixed windows.
    """

    def __init__(
        self,
        max_requests: int = 100,
        window_seconds: int = 60,
        block_duration: int = 0
    ):
        """Initialize the rate limiter.

        Args:
            max_requests: Maximum requests allowed per window.
            window_seconds: Time window in seconds.
            block_duration: Duration to block after exceeding limit (0 = no block).
        """
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.block_duration = block_duration

        # Sliding window state: {client_id: deque of timestamps}
        self._requests: defaultdict[str, deque] = defaultdict(deque)
        # Blocked clients: {client_id: unblock_timestamp}
        self._blocked: Dict[str, float] = {}
        # Lock for thread safety
        self._lock = __import__('threading').Lock()

    def is_allowed(self, client_id: str) -> RateLimitResult:
        """Check if a request is allowed.

        Args:
            client_id: Unique identifier for the client.

        Returns:
            RateLimitResult with decision and metadata.
        """
        current_time = time.time()
        window_start = current_time - self.window_seconds

        with self._lock:
            # Check if client is blocked
            if client_id in self._blocked:
                unblock_time = self._blocked[client_id]
                if current_time < unblock_time:
                    retry_after = unblock_time - current_time
                    return RateLimitResult(
                        allowed=False,
                        remaining=0,
                        reset_time=unblock_time,
                        retry_after=retry_after,
                        limit=self.max_requests,
                        window=self.window_seconds
                    )
                else:
                    # Block expired, remove it
                    del self._blocked[client_id]

            # Clean up old requests outside window
            client_requests = self._requests[client_id]
            while client_requests and client_requests[0] < window_start:
                client_requests.popleft()

            # Check if under limit
            current_count = len(client_requests)
            if current_count < self.max_requests:
                # Record this request
                client_requests.append(current_time)
                remaining = self.max_requests - current_count - 1
                return RateLimitResult(
                    allowed=True,
                    remaining=remaining,
                    reset_time=current_time + self.window_seconds,
                    limit=self.max_requests,
                    window=self.window_seconds
                )
            else:
                # Limit exceeded
                if self.block_duration > 0:
                    self._blocked[client_id] = current_time + self.block_duration
                return RateLimitResult(
                    allowed=False,
                    remaining=0,
                    reset_time=current_time + self.window_seconds,
                    retry_after=float(self.block_duration) if self.block_duration > 0 else None,
                    limit=self.max_requests,
                    window=self.window_seconds
                )

    def get_remaining(self, client_id: str) -> int:
        """Get remaining requests for a client.

        Args:
            client_id: Unique identifier for the client.

        Returns:
            Number of remaining requests.
        """
        current_time = time.time()
        window_start = current_time - self.window_seconds

        with self._lock:
            # Check if blocked
            if client_id in self._blocked:
                return 0

            # Clean up old requests
            client_requests = self._requests[client_id]
            while client_requests and client_requests[0] < window_start:
                client_requests.popleft()

            return max(0, self.max_requests - len(client_requests))

    def get_stats(self, client_id: str) -> Dict[str, any]:
        """Get rate limit statistics for a client.

        Args:
            client_id: Unique identifier for the client.

        Returns:
            Dictionary with rate limit statistics.
        """
        current_time = time.time()
        window_start = current_time - self.window_seconds

        with self._lock:
            # Check if blocked
            if client_id in self._blocked:
                return {
                    "client_id": client_id,
                    "blocked": True,
                    "unblock_time": self._blocked[client_id],
                    "remaining": 0,
                    "used": self.max_requests,
                    "limit": self.max_requests,
                    "window": self.window_seconds
                }

            # Clean up old requests
            client_requests = self._requests[client_id]
            while client_requests and client_requests[0] < window_start:
                client_requests.popleft()

            used = len(client_requests)
            return {
                "client_id": client_id,
                "blocked": False,
                "remaining": self.max_requests - used,
                "used": used,
                "limit": self.max_requests,
                "window": self.window_seconds,
                "reset_in_seconds": max(0, self.window_seconds - (current_time - window_start))
            }

    def reset(self, client_id: Optional[str] = None) -> None:
        """Reset rate limit for a client or all clients.

        Args:
            client_id: Client to reset. If None, resets all.
        """
        with self._lock:
            if client_id:
                self._requests[client_id].clear()
                if client_id in self._blocked:
                    del self._blocked[client_id]
            else:
                self._requests.clear()
                self._blocked.clear()


class TokenBucketRateLimiter:
    """Token bucket rate limiter for more flexible rate limiting.

    This implementation allows burst traffic up to a maximum burst size
    while maintaining an average rate limit.
    """

    def __init__(
        self,
        rate_per_second: float = 10.0,
        max_burst: int = 100
    ):
        """Initialize the token bucket.

        Args:
            rate_per_second: Rate at which tokens are added.
            max_burst: Maximum burst size (initial tokens).
        """
        self.rate_per_second = rate_per_second
        self.max_burst = max_burst

        # Token buckets: {client_id: (tokens, last_update_time)}
        self._buckets: Dict[str, Tuple[float, float]] = {}
        self._lock = __import__('threading').Lock()

    def is_allowed(self, client_id: str, tokens_requested: int = 1) -> RateLimitResult:
        """Check if request is allowed based on token availability.

        Args:
            client_id: Unique identifier for the client.
            tokens_requested: Number of tokens needed (default 1).

        Returns:
            RateLimitResult with decision and metadata.
        """
        current_time = time.time()

        with self._lock:
            if client_id not in self._buckets:
                # New client, start with full bucket
                tokens, _ = self.max_burst, current_time
                self._buckets[client_id] = (self.max_burst, current_time)
            else:
                tokens, last_update = self._buckets[client_id]

                # Add tokens based on elapsed time
                elapsed = current_time - last_update
                tokens = min(self.max_burst, tokens + elapsed * self.rate_per_second)
                self._buckets[client_id] = (tokens, current_time)

            # Check if we have enough tokens
            if tokens >= tokens_requested:
                # Consume tokens
                new_tokens = tokens - tokens_requested
                self._buckets[client_id] = (new_tokens, current_time)
                tokens_in_bucket = self.max_burst - new_tokens
                return RateLimitResult(
                    allowed=True,
                    remaining=int(tokens_in_bucket / tokens_requested) if tokens_requested > 0 else 0,
                    reset_time=current_time + (tokens_requested / self.rate_per_second),
                    limit=self.max_burst,
                    window=int(self.max_burst / self.rate_per_second)
                )
            else:
                # Not enough tokens
                time_until_next = (tokens_requested - tokens) / self.rate_per_second
                return RateLimitResult(
                    allowed=False,
                    remaining=0,
                    reset_time=current_time + time_until_next,
                    retry_after=time_until_next,
                    limit=self.max_burst,
                    window=int(self.max_burst / self.rate_per_second)
                )


class RateLimiterFactory:
    """Factory for creating rate limiters with different strategies."""

    @staticmethod
    def create_sliding_window(
        max_requests: int = 100,
        window_seconds: int = 60,
        block_duration: int = 0
    ) -> SlidingWindowRateLimiter:
        """Create a sliding window rate limiter."""
        return SlidingWindowRateLimiter(
            max_requests=max_requests,
            window_seconds=window_seconds,
            block_duration=block_duration
        )

    @staticmethod
    def create_token_bucket(
        rate_per_second: float = 10.0,
        max_burst: int = 100
    ) -> TokenBucketRateLimiter:
        """Create a token bucket rate limiter."""
        return TokenBucketRateLimiter(
            rate_per_second=rate_per_second,
            max_burst=max_burst
        )


# Default rate limiter instance
_default_rate_limiter: Optional[SlidingWindowRateLimiter] = None


def get_default_rate_limiter() -> SlidingWindowRateLimiter:
    """Get or create the default rate limiter."""
    global _default_rate_limiter
    if _default_rate_limiter is None:
        _default_rate_limiter = SlidingWindowRateLimiter(
            max_requests=100,
            window_seconds=60
        )
    return _default_rate_limiter


def check_rate_limit(client_id: str) -> RateLimitResult:
    """Convenience function to check rate limit using default limiter."""
    return get_default_rate_limiter().is_allowed(client_id)
