# tests/test_config.py
"""Tests for configuration management."""

import os
import pytest
from src.config import Settings


class TestSettings:
    """Settings test suite."""

    def test_default_values(self):
        """Test default configuration values."""
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://localhost:5432/test"
        )
        assert settings.openai_model == "gpt-4o-mini"
        assert settings.max_result_rows == 1000
        assert settings.query_timeout == 30
        assert settings.schema_cache_ttl == 3600

    def test_dsn_from_parts(self):
        """Test DSN construction from separate parts."""
        settings = Settings(
            openai_api_key="test-key",
            postgres_host="localhost",
            postgres_port=5432,
            postgres_database="testdb",
            postgres_user="user",
            postgres_password="pass"
        )
        dsn = settings.get_dsn()
        assert dsn == "postgresql://user:pass@localhost:5432/testdb"

    def test_explicit_dsn_takes_precedence(self):
        """Test that explicit DSN takes precedence."""
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://explicit:5432/explicit",
            postgres_host="ignored",
            postgres_port=9999
        )
        dsn = settings.get_dsn()
        assert "explicit" in dsn

    def test_ssl_setting(self):
        """Test SSL setting."""
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://localhost:5432/test",
            postgres_ssl=True
        )
        assert settings.postgres_ssl is True

    def test_openai_timeout(self):
        """Test OpenAI timeout setting."""
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://localhost:5432/test",
            openai_timeout=60
        )
        assert settings.openai_timeout == 60

    def test_allowed_statements(self):
        """Test allowed statements configuration."""
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://localhost:5432/test",
            allowed_statements=["SELECT", "INSERT"]
        )
        assert "SELECT" in settings.allowed_statements
        assert "INSERT" in settings.allowed_statements

    def test_max_result_rows(self):
        """Test max result rows setting."""
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://localhost:5432/test",
            max_result_rows=500
        )
        assert settings.max_result_rows == 500

    def test_query_timeout(self):
        """Test query timeout setting."""
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://localhost:5432/test",
            query_timeout=60
        )
        assert settings.query_timeout == 60

    def test_schema_cache_ttl(self):
        """Test schema cache TTL setting."""
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://localhost:5432/test",
            schema_cache_ttl=7200
        )
        assert settings.schema_cache_ttl == 7200

    def test_mcp_settings(self):
        """Test MCP server settings."""
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://localhost:5432/test",
            mcp_host="127.0.0.1",
            mcp_port=9000
        )
        assert settings.mcp_host == "127.0.0.1"
        assert settings.mcp_port == 9000

    def test_enable_result_validation(self):
        """Test result validation setting."""
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://localhost:5432/test",
            enable_result_validation=False
        )
        assert settings.enable_result_validation is False

    def test_empty_password(self):
        """Test empty password handling."""
        settings = Settings(
            openai_api_key="test-key",
            postgres_host="localhost",
            postgres_database="test",
            postgres_user="user",
            postgres_password=""
        )
        dsn = settings.get_dsn()
        assert "localhost" in dsn
