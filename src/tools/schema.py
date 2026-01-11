# src/tools/schema.py
"""MCP schema tool implementation."""

from mcp.server.fastmcp import FastMCP
from src.services.schema import SchemaService
from typing import Optional


def register_schema_tool(
    mcp: FastMCP,
    schema_service: SchemaService
) -> None:
    """Register the schema tool with the MCP server.

    Args:
        mcp: The FastMCP server instance.
        schema_service: The schema service instance.
    """

    @mcp.tool()
    async def get_schema(
        refresh: bool = False,
        format: str = "summary"
    ) -> dict:
        """
        Get the PostgreSQL database schema information.

        Args:
            refresh: Force refresh the cached schema.
            format: Output format, "summary" for brief or "full" for complete details.

        Returns:
            Database schema information.
        """
        try:
            schema_info = await schema_service.get_schema_info(
                force_refresh=refresh
            )

            if format == "full":
                return {
                    "status": "success",
                    "cached": schema_service._cache_time is not None,
                    "data": schema_info.model_dump()
                }

            # Simplified output
            tables_summary = []
            for table in schema_info.tables:
                tables_summary.append({
                    "name": table.name,
                    "columns_count": len(table.columns),
                    "comment": table.comment
                })

            return {
                "status": "success",
                "cached": schema_service._cache_time is not None,
                "database": schema_info.database,
                "schema": schema_info.schema,
                "tables": tables_summary,
                "tables_count": len(tables_summary)
            }

        except Exception as e:
            return {
                "status": "error",
                "error": f"获取 Schema 失败: {str(e)}"
            }
