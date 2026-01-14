# src/config.py
"""Configuration management for pg-mcp."""

from pydantic_settings import BaseSettings
from pydantic import Field
from typing import Optional, List, Dict
import json


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

    # Multi-database configuration (JSON array)
    databases: str = Field(
        default="[]",
        description="JSON array of database configurations"
    )

    # OpenAI configuration
    openai_api_key: str = ""
    openai_model: str = "gpt-4o-mini"
    openai_base_url: Optional[str] = None
    openai_timeout: int = 30

    # Retry configuration
    retry_max_attempts: int = 3
    retry_base_delay: float = 1.0
    retry_max_delay: float = 60.0
    retry_multiplier: float = 2.0

    # Query configuration
    max_result_rows: int = 1000
    query_timeout: int = 30
    schema_cache_ttl: int = 3600

    # Security configuration
    allowed_statements: list[str] = ["SELECT"]
    enable_result_validation: bool = True
    enable_access_control: bool = False
    blocked_tables: str = Field(default="[]", description="JSON array of blocked table names")
    blocked_columns: str = Field(default="{}", description="JSON dict of table -> blocked columns")

    # Rate limiting configuration
    rate_limit_enabled: bool = True
    rate_limit_requests: int = 100
    rate_limit_window: int = 60
    rate_limit_block_duration: int = 0

    # Observability configuration
    metrics_enabled: bool = True
    tracing_enabled: bool = False
    log_requests: bool = True

    # MCP configuration
    mcp_host: str = "0.0.0.0"
    mcp_port: int = 8989

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

    def get_blocked_tables(self) -> List[str]:
        """Parse blocked tables from JSON.

        Returns:
            List of blocked table names.
        """
        try:
            return json.loads(self.blocked_tables)
        except json.JSONDecodeError:
            return []

    def get_blocked_columns(self) -> Dict[str, List[str]]:
        """Parse blocked columns from JSON.

        Returns:
            Dict mapping table names to blocked column lists.
        """
        try:
            return json.loads(self.blocked_columns)
        except json.JSONDecodeError:
            return {}

    def get_databases(self) -> List[Dict]:
        """Parse databases config from JSON.

        Returns:
            List of database configurations.
        """
        try:
            return json.loads(self.databases)
        except json.JSONDecodeError:
            return []
