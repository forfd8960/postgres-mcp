"""Tests for metrics and observability service."""

import pytest
import time

from src.services.metrics import (
    MetricsCollector,
    TracingService,
    trace_operation,
    get_metrics_collector,
    get_tracing_service,
)


class TestMetricsCollector:
    """Tests for MetricsCollector."""

    def setup_method(self):
        """Set up test fixtures."""
        self.collector = MetricsCollector(window_seconds=60, max_window_count=100)

    def test_records_request_success(self):
        """Test recording a successful request."""
        self.collector.record_request(
            operation="query",
            success=True,
            duration_ms=100.0
        )

        summary = self.collector.get_operation_summary("query")
        assert summary is not None
        assert summary.count == 1
        assert summary.success_count == 1
        assert summary.failure_count == 0
        assert summary.avg_duration_ms == 100.0

    def test_records_request_failure(self):
        """Test recording a failed request."""
        self.collector.record_request(
            operation="query",
            success=False,
            duration_ms=50.0,
            error_type="ValueError"
        )

        summary = self.collector.get_operation_summary("query")
        assert summary is not None
        assert summary.count == 1
        assert summary.success_count == 0
        assert summary.failure_count == 1
        assert "ValueError" in summary.errors

    def test_tracks_multiple_operations(self):
        """Test tracking multiple operation types."""
        self.collector.record_request("query", True, 100.0)
        self.collector.record_request("query", True, 200.0)
        self.collector.record_request("explain", True, 50.0)

        query_summary = self.collector.get_operation_summary("query")
        explain_summary = self.collector.get_operation_summary("explain")

        assert query_summary.count == 2
        assert explain_summary.count == 1

    def test_calculates_percentiles(self):
        """Test percentile calculations."""
        durations = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]
        for d in durations:
            self.collector.record_request("query", True, d)

        summary = self.collector.get_operation_summary("query")
        assert summary.min_duration_ms == 10.0
        assert summary.max_duration_ms == 100.0
        # P50 should be around 55
        assert summary.p50_duration_ms > 40 and summary.p50_duration_ms < 70
        # P95 should be around 95
        assert summary.p95_duration_ms > 85 and summary.p95_duration_ms < 100

    def test_calculates_success_rate(self):
        """Test success rate calculation."""
        self.collector.record_request("query", True, 100.0)
        self.collector.record_request("query", True, 100.0)
        self.collector.record_request("query", False, 100.0, "Error")

        summary = self.collector.get_operation_summary("query")
        assert summary.success_rate == pytest.approx(66.67, abs=1.0)

    def test_get_global_summary(self):
        """Test getting global summary across all operations."""
        self.collector.record_request("query", True, 100.0)
        self.collector.record_request("explain", True, 50.0)
        self.collector.record_request("query", False, 30.0, "Error")

        summary = self.collector.get_global_summary()
        assert summary.count == 3
        assert summary.success_count == 2
        assert summary.failure_count == 1

    def test_get_all_summaries(self):
        """Test getting summaries for all operations."""
        self.collector.record_request("query", True, 100.0)
        self.collector.record_request("explain", True, 50.0)

        summaries = self.collector.get_all_summaries()
        assert "query" in summaries
        assert "explain" in summaries

    def test_resets_metrics(self):
        """Test resetting all metrics."""
        self.collector.record_request("query", True, 100.0)
        self.collector.reset()

        summary = self.collector.get_operation_summary("query")
        assert summary is None

    def test_get_stats(self):
        """Test getting overall statistics."""
        self.collector.record_request("query", True, 100.0)
        stats = self.collector.get_stats()

        assert "uptime_seconds" in stats
        assert "total_requests" in stats
        assert stats["total_requests"] == 1
        assert "operations_tracked" in stats

    def test_export_json(self):
        """Test exporting metrics as JSON."""
        self.collector.record_request("query", True, 100.0)
        json_str = self.collector.export_json()

        import json
        data = json.loads(json_str)
        assert "timestamp" in data
        assert "operations" in data
        assert "query" in data["operations"]

    def test_returns_none_for_no_data(self):
        """Test that None is returned when no data for operation."""
        summary = self.collector.get_operation_summary("nonexistent")
        assert summary is None


class TestTracingService:
    """Tests for TracingService."""

    def setup_method(self):
        """Set up test fixtures."""
        self.tracing = TracingService(enabled=True)

    def test_starts_trace(self):
        """Test starting a trace."""
        trace_id = self.tracing.start_trace("query", user_id="123")
        assert trace_id is not None
        assert len(trace_id) > 0

    def test_ends_trace_success(self):
        """Test ending a trace with success."""
        trace_id = self.tracing.start_trace("query")
        self.tracing.end_trace(
            trace_id=trace_id,
            operation="query",
            success=True,
            duration_ms=100.0
        )

        traces = self.tracing.get_recent_traces(limit=10)
        assert len(traces) == 1
        assert traces[0]["success"] is True
        assert traces[0]["duration_ms"] == 100.0

    def test_ends_trace_failure(self):
        """Test ending a trace with failure."""
        trace_id = self.tracing.start_trace("query")
        self.tracing.end_trace(
            trace_id=trace_id,
            operation="query",
            success=False,
            duration_ms=50.0,
            error="ValueError: invalid input"
        )

        traces = self.tracing.get_recent_traces(limit=10)
        assert len(traces) == 1
        assert traces[0]["success"] is False
        assert traces[0]["error"] == "ValueError: invalid input"

    def test_get_failed_traces(self):
        """Test getting only failed traces."""
        # Create successful trace
        t1 = self.tracing.start_trace("query")
        self.tracing.end_trace(t1, "query", True, 100.0)

        # Create failed trace
        t2 = self.tracing.start_trace("query")
        self.tracing.end_trace(t2, "query", False, 50.0, "Error")

        failed = self.tracing.get_failed_traces(limit=10)
        assert len(failed) == 1
        assert failed[0]["success"] is False

    def test_disabled_tracing(self):
        """Test that tracing can be disabled."""
        disabled_tracing = TracingService(enabled=False)
        trace_id = disabled_tracing.start_trace("query")
        disabled_tracing.end_trace(trace_id, "query", True, 100.0)

        # No traces should be recorded
        traces = disabled_tracing.get_recent_traces()
        assert len(traces) == 0


class TestTraceOperationContextManager:
    """Tests for trace_operation context manager."""

    def test_traces_successful_operation(self):
        """Test tracing a successful operation."""
        collector = get_metrics_collector()
        collector.reset()

        with trace_operation("test_op", value="test") as trace_id:
            result = "success"

        assert result == "success"

        # Check metrics were recorded
        summary = collector.get_operation_summary("test_op")
        assert summary is not None
        assert summary.success_count == 1
        assert summary.failure_count == 0

    def test_traces_failed_operation(self):
        """Test tracing a failed operation."""
        collector = get_metrics_collector()
        collector.reset()

        with pytest.raises(ValueError):
            with trace_operation("test_op") as trace_id:
                raise ValueError("Test error")

        # Check metrics were recorded
        summary = collector.get_operation_summary("test_op")
        assert summary is not None
        assert summary.success_count == 0
        assert summary.failure_count == 1


class TestMetricsSingleton:
    """Tests for metrics singleton behavior."""

    def test_get_metrics_collector_singleton(self):
        """Test that get_metrics_collector returns singleton."""
        collector1 = get_metrics_collector()
        collector2 = get_metrics_collector()
        assert collector1 is collector2

    def test_get_tracing_service_singleton(self):
        """Test that get_tracing_service returns singleton."""
        tracing1 = get_tracing_service()
        tracing2 = get_tracing_service()
        assert tracing1 is tracing2
