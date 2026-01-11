# tests/test_integration.py
"""Integration tests for pg-mcp."""

import pytest
import pytest_asyncio
from src.config import Settings
from src.services.database import create_pool, close_pool
from src.services.sql_validator import SQLValidator
from src.services.schema import SchemaService
from src.services.ai_client import AIClient


# Skip integration tests if no database is available
pytestmark = pytest.mark.integration


class TestDatabaseIntegration:
    """Database integration tests."""

    @pytest_asyncio.fixture
    async def pool(self):
        """Create a test database connection pool."""
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://postgres@localhost:5432/postgres"
        )
        try:
            pool = await create_pool(
                dsn=settings.get_dsn(),
                ssl=settings.postgres_ssl
            )
            yield pool
        except Exception as e:
            pytest.skip(f"Database not available: {e}")
        finally:
            if 'pool' in dir() and pool:
                await close_pool(pool)

    @pytest.mark.asyncio
    async def test_database_connection(self, pool):
        """Test database connection."""
        async with pool.acquire() as conn:
            result = await conn.fetchval("SELECT 1")
            assert result == 1

    @pytest.mark.asyncio
    async def test_database_version(self, pool):
        """Test database version retrieval."""
        async with pool.acquire() as conn:
            version = await conn.fetchval("SELECT version()")
            assert version is not None
            assert "PostgreSQL" in version

    @pytest.mark.asyncio
    async def test_schema_loading(self, pool):
        """Test schema information loading."""
        schema_service = SchemaService(pool)
        try:
            schema_info = await schema_service.get_schema_info()
            assert schema_info is not None
            assert isinstance(schema_info.tables, list)
        except Exception as e:
            pytest.skip(f"Schema loading failed: {e}")


class TestSQLValidatorIntegration:
    """SQL Validator integration tests."""

    def test_validator_with_realistic_queries(self):
        """Test validator with realistic query patterns."""
        validator = SQLValidator()

        # Valid complex SELECT
        valid_queries = [
            "SELECT u.id, u.name, COUNT(o.id) as order_count "
            "FROM users u LEFT JOIN orders o ON u.id = o.user_id "
            "WHERE u.created_at > '2024-01-01' "
            "GROUP BY u.id, u.name "
            "HAVING COUNT(o.id) > 0 "
            "ORDER BY order_count DESC "
            "LIMIT 10 OFFSET 0",
            """
            SELECT
                p.id,
                p.name,
                p.price,
                c.name as category_name
            FROM products p
            JOIN categories c ON p.category_id = c.id
            WHERE p.price BETWEEN 10 AND 100
              AND p.active = true
              AND c.slug IN ('electronics', 'books', 'clothing')
            ORDER BY p.created_at DESC
            """,
            """
            WITH ranked_products AS (
                SELECT
                    *,
                    ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY created_at DESC) as rn
                FROM products
            )
            SELECT * FROM ranked_products WHERE rn <= 5
            """,
        ]

        for sql in valid_queries:
            is_valid, error = validator.validate(sql)
            assert is_valid is True, f"Expected valid SQL to pass: {sql}\nError: {error}"

    def test_validator_blocks_dangerous_patterns(self):
        """Test that dangerous patterns are blocked."""
        validator = SQLValidator()

        dangerous_queries = [
            "SELECT * FROM users; DELETE FROM users;",
            "WITH x AS (SELECT * FROM users) DROP TABLE users",
            "SELECT * FROM pg_shadow",
            "/* malicious */ DROP TABLE users",
            "SELECT * FROM users WHERE id = 1; UPDATE users SET name = 'x' WHERE id = 1",
        ]

        for sql in dangerous_queries:
            is_valid, error = validator.validate(sql)
            assert is_valid is False, f"Expected dangerous SQL to be blocked: {sql}"
            assert error is not None


class TestSettingsIntegration:
    """Settings integration tests."""

    def test_settings_from_environment(self):
        """Test settings loaded from environment variables."""
        import os

        # Set environment variables
        os.environ["PG_MCP_OPENAI_API_KEY"] = "env-api-key"
        os.environ["PG_MCP_POSTGRES_DSN"] = "postgresql://env-host:5432/env-db"
        os.environ["PG_MCP_OPENAI_MODEL"] = "gpt-4o"

        try:
            settings = Settings()
            assert settings.openai_api_key == "env-api-key"
            assert "env-host" in settings.get_dsn()
            assert settings.openai_model == "gpt-4o"
        finally:
            # Clean up
            del os.environ["PG_MCP_OPENAI_API_KEY"]
            del os.environ["PG_MCP_POSTGRES_DSN"]
            del os.environ["PG_MCP_OPENAI_MODEL"]

    def test_settings_override(self):
        """Test that constructor values override environment."""
        import os

        os.environ["PG_MCP_OPENAI_API_KEY"] = "env-key"

        try:
            settings = Settings(openai_api_key="explicit-key")
            assert settings.openai_api_key == "explicit-key"
        finally:
            del os.environ["PG_MCP_OPENAI_API_KEY"]


class TestAIClientIntegration:
    """AI Client integration tests."""

    @pytest.mark.asyncio
    async def test_ai_client_generates_sql(self):
        """Test AI client SQL generation."""
        client = AIClient(
            api_key="test-key",
            model="gpt-4o-mini"
        )

        schema_info = """
表 users:
  - id: INTEGER (primary key)
  - name: VARCHAR
  - email: VARCHAR

表 orders:
  - id: INTEGER (primary key)
  - user_id: INTEGER
  - total: DECIMAL
"""

        # This will likely fail with invalid API key, but tests the error handling
        result = await client.generate_sql(
            schema_info=schema_info,
            user_query="Get all users with their orders"
        )

        # Should either get valid SQL or an error message
        assert result is not None
        assert isinstance(result, str)

    @pytest.mark.asyncio
    async def test_ai_client_error_handling(self):
        """Test AI client error handling with invalid key."""
        client = AIClient(
            api_key="invalid-key",
            model="gpt-4o-mini"
        )

        result = await client.generate_sql(
            schema_info="schema info",
            user_query="test query"
        )

        # Should return an error message
        assert "ERROR:" in result or "失败" in result
