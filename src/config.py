# src/config.py
"""Configuration management for pg-mcp."""

from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # PostgreSQL connection configuration
    postgres_dsn: str = "postgresql://localhost:5432/postgres"
    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_database: str = "postgres"
    postgres_user: str = "postgres"
    postgres_password: str = ""
    postgres_ssl: bool = False

    # OpenAI configuration
    openai_api_key: str = ""
    openai_model: str = "gpt-4o-mini"
    openai_base_url: Optional[str] = None
    openai_timeout: int = 30

    # Query configuration
    max_result_rows: int = 1000
    query_timeout: int = 30
    schema_cache_ttl: int = 3600

    # Security configuration
    allowed_statements: list[str] = ["SELECT"]
    enable_result_validation: bool = True

    # MCP configuration
    mcp_host: str = "0.0.0.0"
    mcp_port: int = 8080

    class Config:
        env_prefix = "PG_MCP_"

    def get_dsn(self) -> str:
        """Get the database connection string.

        Returns:
            The DSN string for connecting to PostgreSQL.
        """
        if self.postgres_dsn and not self.postgres_dsn.startswith("${"):
            return self.postgres_dsn
        return (
            f"postgresql://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_database}"
        )
