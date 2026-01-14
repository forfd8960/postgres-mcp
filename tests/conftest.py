"""Pytest configuration and fixtures for pg-mcp tests."""

import pytest


# Markers for test categorization
def pytest_configure(config):
    """Configure pytest with custom markers."""
    config.addinivalue_line(
        "markers", "integration: marks tests as integration tests (deselect with '-m \"not integration\"')"
    )
    config.addinivalue_line(
        "markers", "slow: marks tests as slow running tests"
    )


# Pytest.ini style options (additional configuration)
@pytest.fixture(scope="session")
def anyio_backend():
    """Set the async backend for anyio."""
    return "asyncio"


# Disable warnings for cleaner test output
def pytest_collection_modifyitems(config, items):
    """Modify test items after collection."""
    # Optionally sort tests by marker for better organization
    items.sort(key=lambda item: (item.get_closest_marker("integration") is not None, item.name))
