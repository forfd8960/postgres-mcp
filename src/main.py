# src/main.py
"""Main entry point for the pg-mcp server."""

import asyncio
import logging
from contextlib import asynccontextmanager
from mcp.server.fastmcp import FastMCP

from src.config import Settings
from src.services.database import create_pool, close_pool
from src.services.schema import SchemaService
from src.services.ai_client import AIClient
from src.services.sql_validator import SQLValidator
from src.tools.schema import register_schema_tool
from src.tools.explain import register_explain_tool
from src.tools.query import register_query_tool


logger = logging.getLogger("pg_mcp")


@asynccontextmanager
async def app_lifespan(settings: Settings):
    """Application lifespan manager for startup and shutdown.

    Args:
        settings: Application settings.

    Yields:
        Dictionary containing initialized services.
    """
    # Create connection pool on startup
    pool = await create_pool(
        dsn=settings.get_dsn(),
        ssl=settings.postgres_ssl
    )

    # Initialize services
    schema_service = SchemaService(
        pool=pool,
        cache_ttl=settings.schema_cache_ttl
    )
    ai_client = AIClient(
        api_key=settings.openai_api_key,
        model=settings.openai_model,
        base_url=settings.openai_base_url,
        timeout=settings.openai_timeout
    )
    validator = SQLValidator(
        allowed_statements=set(settings.allowed_statements)
    )

    yield {
        "pool": pool,
        "schema_service": schema_service,
        "ai_client": ai_client,
        "validator": validator,
        "settings": settings
    }

    # Cleanup on shutdown
    await close_pool(pool)


async def create_mcp_app(settings: Settings) -> FastMCP:
    """Create and configure the MCP application.

    Args:
        settings: Application settings.

    Returns:
        Configured FastMCP instance.
    """
    mcp = FastMCP("pg-mcp")

    # Set up lifespan
    mcp.context_lifespan_factory = lambda: app_lifespan(settings)

    # Note: FastMCP tools need to be defined inside the lifespan context
    # The actual tool implementations will access services through mcp.context

    return mcp


def main() -> None:
    """Main entry point for the server."""
    import argparse

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    )

    parser = argparse.ArgumentParser(description="PostgreSQL MCP Server")
    parser.add_argument(
        "--dsn",
        type=str,
        default="postgresql://postgres:postgres@localhost:5432/db_pg_mcp_small",
        help="Database DSN"
    )
    parser.add_argument(
        "--api-key",
        type=str,
        help="OpenAI API Key"
    )
    parser.add_argument(
        "--base-url",
        type=str,
        default="https://api.minimaxi.com/v1",
        help="OpenAI API Base URL"
    )
    parser.add_argument(
        "--model",
        type=str,
        default="MiniMax-M2.1",
        help="OpenAI Model"
    )

    args = parser.parse_args()

    # Load settings
    settings = Settings()
    if args.dsn:
        settings.postgres_dsn = args.dsn
    if args.api_key:
        settings.openai_api_key = args.api_key
    if args.base_url:
        settings.openai_base_url = args.base_url
    if args.model:
        settings.openai_model = args.model

    logger.info("Starting pg-mcp server initialization")

    # Run the MCP server
    asyncio.run(run_server(settings))


async def run_server(settings: Settings) -> None:
    """Run the MCP server.

    Args:
        settings: Application settings.
    """
    mcp = FastMCP("pg-mcp")

    logger.info("settings: %s", settings.model_dump())

    # Create services
    logger.info("Initializing services (pool, schema, AI client, validator)")
    pool = await create_pool(
        dsn=settings.get_dsn(),
        ssl=settings.postgres_ssl
    )

    schema_service = SchemaService(
        pool=pool,
        cache_ttl=settings.schema_cache_ttl
    )
    ai_client = AIClient(
        api_key=settings.openai_api_key,
        model=settings.openai_model,
        base_url=settings.openai_base_url,
        timeout=settings.openai_timeout
    )
    validator = SQLValidator(
        allowed_statements=set(settings.allowed_statements)
    )

    # Register tools using closure pattern
    # This captures the services by reference
    _register_tools(
        mcp=mcp,
        pool=pool,
        schema_service=schema_service,
        ai_client=ai_client,
        validator=validator,
        settings=settings
    )

    logger.info("pg-mcp server ready; starting event loop")

    # Run the server inside existing event loop
    await mcp.run_sse_async()


def _register_tools(
    mcp: FastMCP,
    pool,
    schema_service,
    ai_client,
    validator,
    settings
) -> None:
    """Register all MCP tools.

    Args:
        mcp: The FastMCP instance.
        pool: Database connection pool.
        schema_service: Schema service.
        ai_client: AI client.
        validator: SQL validator.
        settings: Application settings.
    """
    from src.tools.schema import register_schema_tool
    from src.tools.explain import register_explain_tool
    from src.tools.query import register_query_tool

    # Register schema tool
    register_schema_tool(mcp, schema_service)

    # Register explain tool
    register_explain_tool(mcp, schema_service, ai_client, validator)

    # Register query tool
    register_query_tool(
        mcp,
        pool,
        schema_service,
        ai_client,
        validator,
        max_rows=settings.max_result_rows,
        timeout=settings.query_timeout
    )


if __name__ == "__main__":
    main()
