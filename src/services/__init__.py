# src/services/__init__.py
"""Service modules for pg-mcp."""

from src.services.database import (
    create_pool,
    test_connection,
    close_pool,
)
from src.services.sql_validator import SQLValidator
from src.services.ai_client import AIClient, SQL_GENERATION_PROMPT, RESULT_VALIDATION_PROMPT
from src.services.schema import SchemaService
from src.services.multi_db import MultiDatabaseManager
from src.services.rate_limiter import (
    RateLimiterFactory,
    SlidingWindowRateLimiter,
    TokenBucketRateLimiter,
    check_rate_limit,
    get_default_rate_limiter,
)
from src.services.resilience import (
    CircuitBreaker,
    CircuitState,
    CircuitOpenError,
    CircuitBreakerConfig,
    with_retry,
    with_timeout,
)
from src.services.metrics import (
    MetricsCollector,
    TracingService,
    RequestMetrics,
    MetricSummary,
    get_metrics_collector,
    get_tracing_service,
    trace_operation,
)

__all__ = [
    # Database
    "create_pool",
    "test_connection",
    "close_pool",
    "MultiDatabaseManager",
    # SQL
    "SQLValidator",
    # AI
    "AIClient",
    "SQL_GENERATION_PROMPT",
    "RESULT_VALIDATION_PROMPT",
    # Schema
    "SchemaService",
    # Rate Limiting
    "RateLimiterFactory",
    "SlidingWindowRateLimiter",
    "TokenBucketRateLimiter",
    "check_rate_limit",
    "get_default_rate_limiter",
    # Resilience
    "CircuitBreaker",
    "CircuitState",
    "CircuitOpenError",
    "CircuitBreakerConfig",
    "with_retry",
    "with_timeout",
    # Metrics
    "MetricsCollector",
    "TracingService",
    "RequestMetrics",
    "MetricSummary",
    "get_metrics_collector",
    "get_tracing_service",
    "trace_operation",
]
