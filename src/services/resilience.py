"""Resilience patterns: retry, circuit breaker, and timeouts."""

import asyncio
import functools
import logging
import random
import time
from typing import Type, Callable, Any, Optional, TypeVar, Union
from dataclasses import dataclass
from enum import Enum

logger = logging.getLogger("resilience")

T = TypeVar('T')
ExcType = TypeVar('ExcType', bound=BaseException)


class CircuitState(Enum):
    """Circuit breaker states."""
    CLOSED = "closed"      # Normal operation
    OPEN = "open"          # Failing, reject all requests
    HALF_OPEN = "half_open"  # Testing recovery


@dataclass
class CircuitBreakerConfig:
    """Configuration for circuit breaker."""
    failure_threshold: int = 5          # Failures before opening
    success_threshold: int = 3          # Successes in half-open to close
    timeout_seconds: float = 60.0       # Time in open state before half-open
    sampling_window: int = 10           # Number of recent calls to consider
    volume_threshold: int = 5           # Min calls in window to trigger state change


class CircuitBreaker:
    """Circuit breaker implementation for preventing cascade failures.

    Implements a state machine with three states:
    - CLOSED: Normal operation, requests pass through
    - OPEN: Failures exceeded threshold, requests rejected immediately
    - HALF_OPEN: Testing recovery, limited requests allowed
    """

    def __init__(self, name: str, config: Optional[CircuitBreakerConfig] = None):
        """Initialize the circuit breaker.

        Args:
            name: Unique identifier for the circuit breaker.
            config: Configuration options.
        """
        self.name = name
        self.config = config or CircuitBreakerConfig()
        self._state = CircuitState.CLOSED
        self._failure_count = 0
        self._success_count = 0
        self._last_failure_time: Optional[float] = None
        self._recent_results: list[bool] = []  # True = success, False = failure
        self._lock = __import__('threading').Lock()

    @property
    def state(self) -> CircuitState:
        """Get current state, checking for state transitions."""
        current_time = time.time()

        with self._lock:
            # Check if we should transition from OPEN to HALF_OPEN
            if self._state == CircuitState.OPEN:
                if self._last_failure_time is None:
                    self._state = CircuitState.HALF_OPEN
                    logger.info("Circuit %s: OPEN -> HALF_OPEN (timeout)", self.name)
                elif current_time - self._last_failure_time >= self.config.timeout_seconds:
                    self._state = CircuitState.HALF_OPEN
                    logger.info("Circuit %s: OPEN -> HALF_OPEN (timeout expired)", self.name)

            return self._state

    def __call__(self, func: Callable[..., T]) -> Callable[..., T]:
        """Decorator to wrap a function with circuit breaker."""
        @functools.wraps(func)
        async def async_wrapper(*args: Any, **kwargs: Any) -> T:
            return await self._execute_async(func, *args, **kwargs)

        @functools.wraps(func)
        def sync_wrapper(*args: Any, **kwargs: Any) -> T:
            return self._execute_sync(func, *args, **kwargs)

        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        return sync_wrapper

    async def _execute_async(self, func: Callable[..., T], *args: Any, **kwargs: Any) -> T:
        """Execute async function with circuit breaker protection."""
        if self.state == CircuitState.OPEN:
            raise CircuitOpenError(f"Circuit {self.name} is open")

        try:
            result = await func(*args, **kwargs)
            self._on_success()
            return result
        except Exception as e:
            self._on_failure()
            raise

    def _execute_sync(self, func: Callable[..., T], *args: Any, **kwargs: Any) -> T:
        """Execute sync function with circuit breaker protection."""
        if self.state == CircuitState.OPEN:
            raise CircuitOpenError(f"Circuit {self.name} is open")

        try:
            result = func(*args, **kwargs)
            self._on_success()
            return result
        except Exception as e:
            self._on_failure()
            raise

    def _on_success(self) -> None:
        """Handle successful execution."""
        with self._lock:
            self._recent_results.append(True)
            self._trim_recent_results()

            if self._state == CircuitState.HALF_OPEN:
                self._success_count += 1
                if self._success_count >= self.config.success_threshold:
                    self._state = CircuitState.CLOSED
                    self._failure_count = 0
                    self._success_count = 0
                    self._recent_results.clear()
                    logger.info("Circuit %s: HALF_OPEN -> CLOSED", self.name)

    def _on_failure(self) -> None:
        """Handle failed execution."""
        with self._lock:
            self._recent_results.append(False)
            self._trim_recent_results()
            self._failure_count += 1
            self._last_failure_time = time.time()

            if self._state == CircuitState.HALF_OPEN:
                self._state = CircuitState.OPEN
                self._success_count = 0
                logger.warning("Circuit %s: HALF_OPEN -> OPEN (failure)", self.name)
            elif self._should_open():
                self._state = CircuitState.OPEN
                logger.warning("Circuit %s: CLOSED -> OPEN (failure threshold reached)", self.name)

    def _should_open(self) -> bool:
        """Determine if circuit should open based on recent failures."""
        if len(self._recent_results) < self.config.volume_threshold:
            return False

        recent_failures = sum(1 for r in self._recent_results if not r)
        return recent_failures >= self.config.failure_threshold

    def _trim_recent_results(self) -> None:
        """Trim results to the sampling window size."""
        while len(self._recent_results) > self.config.sampling_window:
            self._recent_results.pop(0)

    def reset(self) -> None:
        """Reset the circuit breaker to closed state."""
        with self._lock:
            self._state = CircuitState.CLOSED
            self._failure_count = 0
            self._success_count = 0
            self._last_failure_time = None
            self._recent_results.clear()
            logger.info("Circuit %s: reset to CLOSED", self.name)

    def get_stats(self) -> dict:
        """Get circuit breaker statistics."""
        with self._lock:
            recent_failures = sum(1 for r in self._recent_results if not r)
            return {
                "name": self.name,
                "state": self._state.value,
                "failure_count": self._failure_count,
                "success_count": self._success_count,
                "recent_total": len(self._recent_results),
                "recent_failures": recent_failures,
                "recent_failure_rate": recent_failures / max(1, len(self._recent_results))
            }


class CircuitOpenError(Exception):
    """Raised when circuit breaker is open."""
    pass


def with_retry(
    max_attempts: int = 3,
    base_delay: float = 1.0,
    max_delay: float = 60.0,
    multiplier: float = 2.0,
    exponential_base: float = 2.0,
    jitter: bool = True,
    retry_on: Union[Type[Exception], tuple] = (Exception,)
) -> Callable:
    """Decorator to add retry logic with exponential backoff.

    Args:
        max_attempts: Maximum number of attempts.
        base_delay: Initial delay between retries.
        max_delay: Maximum delay between retries.
        multiplier: Delay multiplier for consecutive failures.
        exponential_base: Base for exponential backoff (set to 1 for linear).
        jitter: Whether to add random jitter to delays.
        retry_on: Exception types to retry on.

    Returns:
        Decorated function with retry logic.
    """
    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        @functools.wraps(func)
        async def async_wrapper(*args: Any, **kwargs: Any) -> T:
            last_exception = None
            for attempt in range(max_attempts):
                try:
                    return await func(*args, **kwargs)
                except retry_on as e:
                    last_exception = e
                    if attempt == max_attempts - 1:
                        raise

                    # Calculate delay
                    if exponential_base > 1:
                        delay = base_delay * (exponential_base ** attempt)
                    else:
                        delay = base_delay * (multiplier ** attempt)

                    delay = min(delay, max_delay)

                    if jitter:
                        delay = delay * (0.5 + random.random())

                    logger.warning(
                        "Attempt %d/%d failed: %s. Retrying in %.2fs...",
                        attempt + 1, max_attempts, str(e), delay
                    )
                    await asyncio.sleep(delay)

            raise last_exception

        @functools.wraps(func)
        def sync_wrapper(*args: Any, **kwargs: Any) -> T:
            last_exception = None
            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                except retry_on as e:
                    last_exception = e
                    if attempt == max_attempts - 1:
                        raise

                    # Calculate delay
                    if exponential_base > 1:
                        delay = base_delay * (exponential_base ** attempt)
                    else:
                        delay = base_delay * (multiplier ** attempt)

                    delay = min(delay, max_delay)

                    if jitter:
                        delay = delay * (0.5 + random.random())

                    logger.warning(
                        "Attempt %d/%d failed: %s. Retrying in %.2fs...",
                        attempt + 1, max_attempts, str(e), delay
                    )
                    time.sleep(delay)

            raise last_exception

        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        return sync_wrapper

    return decorator


def with_timeout(seconds: float) -> Callable:
    """Decorator to add timeout to a function.

    Args:
        seconds: Timeout in seconds.

    Returns:
        Decorated function with timeout.
    """
    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        @functools.wraps(func)
        async def async_wrapper(*args: Any, **kwargs: Any) -> T:
            try:
                return await asyncio.wait_for(
                    func(*args, **kwargs),
                    timeout=seconds
                )
            except asyncio.TimeoutError:
                raise TimeoutError(f"Function timed out after {seconds}s")

        @functools.wraps(func)
        def sync_wrapper(*args: Any, **kwargs: Any) -> T:
            import signal

            def handler(signum, frame):
                raise TimeoutError(f"Function timed out after {seconds}s")

            # Set signal handler (Unix only)
            old_handler = signal.signal(signal.SIGALRM, handler)
            signal.alarm(int(seconds))
            try:
                result = func(*args, **kwargs)
            finally:
                signal.alarm(0)
                signal.signal(signal.SIGALRM, old_handler)
            return result

        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        return sync_wrapper

    return decorator
