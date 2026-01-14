# src/tools/explain.py
"""MCP explain tool implementation."""

from mcp.server.fastmcp import FastMCP
from src.services.schema import SchemaService
from src.services.ai_client import AIClient
from src.services.sql_validator import SQLValidator
from typing import Optional


def register_explain_tool(
    mcp: FastMCP,
    schema_service: SchemaService,
    ai_client: AIClient,
    validator: SQLValidator
) -> None:
    """Register the explain tool with the MCP server.

    Args:
        mcp: The FastMCP server instance.
        schema_service: The schema service instance.
        ai_client: The AI client instance.
        validator: The SQL validator instance.
    """

    @mcp.tool()
    async def explain(
        query: str,
        database: Optional[str] = None
    ) -> dict:
        """
        Explain a natural language query and show the generated SQL.

        Args:
            query: Natural language query description.
            database: Target database name (optional).

        Returns:
            Dictionary containing the SQL statement, explanation, and analysis.
        """
        try:
            # Use provided database or default
            db = database or "default"
            # Get schema information
            schema_info = await schema_service.get_schema_info(database=db)
            schema_text = schema_service.format_schema_for_ai(schema_info)

            # Generate SQL
            sql = await ai_client.generate_sql(schema_text, query)

            # Check for AI errors
            if sql.startswith("ERROR:"):
                return {
                    "status": "error",
                    "error": sql[6:].strip()
                }

            # Validate SQL
            is_valid, error_msg, _ = validator.validate(sql)

            # Extract involved tables
            tables = validator.extract_tables(sql)

            # Build response
            response = {
                "status": "success" if is_valid else "warning",
                "original_query": query,
                "generated_sql": sql,
                "tables_involved": tables,
                "security_check": {
                    "is_valid": is_valid,
                    "message": error_msg or "SQL 语句通过安全检查"
                }
            }

            return response

        except Exception as e:
            return {
                "status": "error",
                "error": f"解释失败: {str(e)}"
            }
