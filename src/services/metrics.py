"""Metrics and observability service for monitoring and tracing."""

import time
import logging
import threading
from typing import Optional, Dict, Any, List
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from collections import defaultdict, deque
from contextlib import contextmanager
import json

logger = logging.getLogger("metrics")


@dataclass
class RequestMetrics:
    """Metrics for a single request."""
    operation: str
    success: bool
    duration_ms: float
    timestamp: float
    error_type: Optional[str] = None
    details: Optional[Dict[str, Any]] = None


@dataclass
class MetricSummary:
    """Summary of metrics over a time window."""
    operation: str
    count: int
    success_count: int
    failure_count: int
    avg_duration_ms: float
    min_duration_ms: float
    max_duration_ms: float
    p50_duration_ms: float
    p95_duration_ms: float
    p99_duration_ms: float
    success_rate: float
    errors: Dict[str, int] = field(default_factory=dict)


class MetricsCollector:
    """Collect and aggregate metrics for the application.

    Features:
    - Request timing and success/failure tracking
    - Rolling window aggregation
    - Error type counting
    - JSON export for external monitoring
    """

    def __init__(
        self,
        window_seconds: int = 60,
        max_window_count: int = 1000
    ):
        """Initialize the metrics collector.

        Args:
            window_seconds: Rolling window size in seconds.
            max_window_count: Maximum requests to keep in window.
        """
        self.window_seconds = window_seconds
        self.max_window_count = max_window_count

        # Thread-safe storage
        self._lock = threading.Lock()
        self._requests: deque[RequestMetrics] = deque()
        self._error_counts: Dict[str, Dict[str, int]] = defaultdict(lambda: defaultdict(int))
        self._operation_counts: Dict[str, Dict[str, int]] = defaultdict(lambda: {"success": 0, "failure": 0})
        self._durations: Dict[str, List[float]] = defaultdict(list)
        self._start_time = time.time()

    def record_request(
        self,
        operation: str,
        success: bool,
        duration_ms: float,
        error_type: Optional[str] = None,
        details: Optional[Dict[str, Any]] = None
    ) -> None:
        """Record a request for metrics.

        Args:
            operation: Type of operation (e.g., "query", "explain").
            success: Whether the operation succeeded.
            duration_ms: Duration in milliseconds.
            error_type: Type of error if failed.
            details: Additional details to record.
        """
        with self._lock:
            now = time.time()

            # Remove old requests outside the window
            window_start = now - self.window_seconds
            while self._requests and self._requests[0].timestamp < window_start:
                self._requests.popleft()

            # Record request
            metric = RequestMetrics(
                operation=operation,
                success=success,
                duration_ms=duration_ms,
                timestamp=now,
                error_type=error_type,
                details=details
            )
            self._requests.append(metric)

            # Update counts
            status = "success" if success else "failure"
            self._operation_counts[operation][status] += 1
            self._durations[operation].append(duration_ms)

            # Track errors
            if error_type:
                self._error_counts[operation][error_type] += 1

            # Trim durations to prevent memory bloat
            if len(self._durations[operation]) > self.max_window_count:
                self._durations[operation] = self._durations[operation][-self.max_window_count:]

    def get_operation_summary(self, operation: str) -> Optional[MetricSummary]:
        """Get metrics summary for a specific operation.

        Args:
            operation: The operation to get metrics for.

        Returns:
            MetricSummary or None if no data.
        """
        with self._lock:
            now = time.time()
            window_start = now - self.window_seconds

            # Filter requests for this operation in the window
            relevant = [r for r in self._requests if r.operation == operation and r.timestamp >= window_start]

            if not relevant:
                return None

            durations = sorted([r.duration_ms for r in relevant])
            success_count = sum(1 for r in relevant if r.success)
            failure_count = len(relevant) - success_count

            return MetricSummary(
                operation=operation,
                count=len(relevant),
                success_count=success_count,
                failure_count=failure_count,
                avg_duration_ms=sum(durations) / len(durations),
                min_duration_ms=min(durations),
                max_duration_ms=max(durations),
                p50_duration_ms=self._percentile(durations, 50),
                p95_duration_ms=self._percentile(durations, 95),
                p99_duration_ms=self._percentile(durations, 99),
                success_rate=success_count / len(relevant) * 100,
                errors=dict(self._error_counts.get(operation, {}))
            )

    def get_all_summaries(self) -> Dict[str, MetricSummary]:
        """Get metrics summaries for all operations.

        Returns:
            Dictionary of operation -> MetricSummary.
        """
        with self._lock:
            operations = set(r.operation for r in self._requests)
            return {
                op: summary
                for op in operations
                if (summary := self.get_operation_summary(op)) is not None
            }

    def get_global_summary(self) -> MetricSummary:
        """Get global metrics summary across all operations.

        Returns:
            MetricSummary for all operations combined.
        """
        with self._lock:
            now = time.time()
            window_start = now - self.window_seconds

            relevant = [r for r in self._requests if r.timestamp >= window_start]

            if not relevant:
                return MetricSummary(
                    operation="all",
                    count=0,
                    success_count=0,
                    failure_count=0,
                    avg_duration_ms=0,
                    min_duration_ms=0,
                    max_duration_ms=0,
                    p50_duration_ms=0,
                    p95_duration_ms=0,
                    p99_duration_ms=0,
                    success_rate=0
                )

            durations = sorted([r.duration_ms for r in relevant])
            success_count = sum(1 for r in relevant if r.success)
            failure_count = len(relevant) - success_count

            # Aggregate errors
            all_errors: Dict[str, int] = defaultdict(int)
            for op, errors in self._error_counts.items():
                for err_type, count in errors.items():
                    all_errors[err_type] += count

            return MetricSummary(
                operation="all",
                count=len(relevant),
                success_count=success_count,
                failure_count=failure_count,
                avg_duration_ms=sum(durations) / len(durations),
                min_duration_ms=min(durations),
                max_duration_ms=max(durations),
                p50_duration_ms=self._percentile(durations, 50),
                p95_duration_ms=self._percentile(durations, 95),
                p99_duration_ms=self._percentile(durations, 99),
                success_rate=success_count / len(relevant) * 100,
                errors=dict(all_errors)
            )

    def get_stats(self) -> Dict[str, Any]:
        """Get overall statistics.

        Returns:
            Dictionary with overall stats.
        """
        with self._lock:
            return {
                "uptime_seconds": time.time() - self._start_time,
                "total_requests": len(self._requests),
                "window_seconds": self.window_seconds,
                "operations_tracked": list(self._operation_counts.keys()),
                "global_summary": {
                    "count": sum(
                        self._operation_counts[op]["success"] +
                        self._operation_counts[op]["failure"]
                        for op in self._operation_counts
                    )
                }
            }

    def reset(self) -> None:
        """Reset all metrics."""
        with self._lock:
            self._requests.clear()
            self._error_counts.clear()
            self._operation_counts.clear()
            self._durations.clear()
            self._start_time = time.time()

    def _percentile(self, sorted_list: List[float], percentile: float) -> float:
        """Calculate percentile of a sorted list.

        Args:
            sorted_list: Sorted list of values.
            percentile: Percentile to calculate (0-100).

        Returns:
            Percentile value.
        """
        if not sorted_list:
            return 0
        idx = int(len(sorted_list) * percentile / 100)
        return sorted_list[min(idx, len(sorted_list) - 1)]

    def export_json(self) -> str:
        """Export metrics as JSON.

        Returns:
            JSON string representation of metrics.
        """
        summaries = self.get_all_summaries()
        data = {
            "timestamp": datetime.utcnow().isoformat(),
            "uptime_seconds": time.time() - self._start_time,
            "operations": {
                name: {
                    "count": summary.count,
                    "success_count": summary.success_count,
                    "failure_count": summary.failure_count,
                    "avg_duration_ms": summary.avg_duration_ms,
                    "p95_duration_ms": summary.p95_duration_ms,
                    "success_rate": summary.success_rate,
                    "errors": summary.errors
                }
                for name, summary in summaries.items()
            },
            "global": {
                "total_count": sum(s.count for s in summaries.values()),
                "total_success_rate": self.get_global_summary().success_rate
            }
        }
        return json.dumps(data, indent=2)


class TracingService:
    """Simple tracing service for request tracking.

    Provides basic request tracing without external dependencies.
    """

    def __init__(self, enabled: bool = True):
        """Initialize the tracing service.

        Args:
            enabled: Whether tracing is enabled.
        """
        self.enabled = enabled
        self._traces: List[Dict[str, Any]] = []
        self._lock = threading.Lock()
        self._max_traces = 100

    def start_trace(self, operation: str, **kwargs) -> str:
        """Start a new trace.

        Args:
            operation: Type of operation.
            **kwargs: Additional context.

        Returns:
            Trace ID string.
        """
        trace_id = f"{datetime.utcnow().strftime('%Y%m%d%H%M%S%f')}_{id(self)}"
        return trace_id

    def end_trace(
        self,
        trace_id: str,
        operation: str,
        success: bool,
        duration_ms: float,
        details: Optional[Dict[str, Any]] = None,
        error: Optional[str] = None
    ) -> None:
        """End a trace.

        Args:
            trace_id: Trace ID from start_trace.
            operation: Type of operation.
            success: Whether successful.
            duration_ms: Duration in milliseconds.
            details: Additional details.
            error: Error message if failed.
        """
        if not self.enabled:
            return

        with self._lock:
            self._traces.append({
                "trace_id": trace_id,
                "operation": operation,
                "success": success,
                "duration_ms": duration_ms,
                "details": details or {},
                "error": error,
                "timestamp": datetime.utcnow().isoformat()
            })

            # Trim old traces
            if len(self._traces) > self._max_traces:
                self._traces = self._traces[-self._max_traces:]

    def get_recent_traces(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Get recent traces.

        Args:
            limit: Maximum number of traces to return.

        Returns:
            List of recent trace records.
        """
        with self._lock:
            return list(self._traces[-limit:])

    def get_failed_traces(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Get recent failed traces.

        Args:
            limit: Maximum number of traces to return.

        Returns:
            List of failed trace records.
        """
        with self._lock:
            failed = [t for t in self._traces if not t["success"]]
            return failed[-limit:]


# Default instances
_metrics_collector: Optional[MetricsCollector] = None
_tracing_service: Optional[TracingService] = None


def get_metrics_collector() -> MetricsCollector:
    """Get or create the default metrics collector."""
    global _metrics_collector
    if _metrics_collector is None:
        _metrics_collector = MetricsCollector()
    return _metrics_collector


def get_tracing_service() -> TracingService:
    """Get or create the default tracing service."""
    global _tracing_service
    if _tracing_service is None:
        _tracing_service = TracingService()
    return _tracing_service


@contextmanager
def trace_operation(
    operation: str,
    metrics: Optional[MetricsCollector] = None,
    tracing: Optional[TracingService] = None,
    **context
):
    """Context manager for tracing an operation.

    Usage:
        with trace_operation("query", user_id="123") as trace_id:
            # do work
            pass  # Exception will be captured

    Args:
        operation: Type of operation.
        metrics: Metrics collector to use.
        tracing: Tracing service to use.
        **context: Additional context for the trace.

    Yields:
        Trace ID.
    """
    metrics = metrics or get_metrics_collector()
    tracing = tracing or get_tracing_service()

    trace_id = tracing.start_trace(operation, **context)
    start_time = time.time()

    try:
        yield trace_id
        success = True
        error = None
    except Exception as e:
        success = False
        error = str(e)
        raise
    finally:
        duration_ms = (time.time() - start_time) * 1000
        tracing.end_trace(
            trace_id=trace_id,
            operation=operation,
            success=success,
            duration_ms=duration_ms,
            details=context,
            error=error
        )
        metrics.record_request(
            operation=operation,
            success=success,
            duration_ms=duration_ms,
            error_type=type(error).__name__ if error else None,
            details=context if context else None
        )
