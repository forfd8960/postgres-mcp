# src/tools/query.py
"""MCP query tool implementation."""

from mcp.server.fastmcp import FastMCP
from src.services.schema import SchemaService
from src.services.ai_client import AIClient
from src.services.sql_validator import SQLValidator
from src.models.query import SqlModeResponse, ResultModeResponse
from typing import Optional
import asyncpg
from datetime import datetime


def register_query_tool(
    mcp: FastMCP,
    pool: asyncpg.Pool,
    schema_service: SchemaService,
    ai_client: AIClient,
    validator: SQLValidator,
    max_rows: int = 1000,
    timeout: int = 30
) -> None:
    """Register the query tool with the MCP server.

    Args:
        mcp: The FastMCP server instance.
        pool: The database connection pool.
        schema_service: The schema service instance.
        ai_client: The AI client instance.
        validator: The SQL validator instance.
        max_rows: Maximum number of rows to return.
        timeout: Query timeout in seconds.
    """

    @mcp.tool()
    async def query(
        query: str,
        return_mode: str = "sql",
        database: Optional[str] = None,
        parameters: Optional[dict] = None
    ) -> dict:
        """
        Query the PostgreSQL database using natural language.

        Args:
            query: Natural language query description (Chinese or English).
            return_mode: Return mode, "sql" returns SQL statement, "result" returns query results.
            database: Target database name (optional, uses main database by default).
            parameters: Query parameters (for parameterized queries).

        Returns:
            SQL statement or query results.
        """
        start_time = datetime.utcnow()

        try:
            # Step 1: Get schema information
            schema_info = await schema_service.get_schema_info()
            schema_text = schema_service.format_schema_for_ai(schema_info)

            # Step 2: Use AI to generate SQL
            sql = await ai_client.generate_sql(schema_text, query)

            # Step 3: Check for AI errors
            if sql.startswith("ERROR:"):
                return SqlModeResponse(
                    status="error",
                    mode="sql",
                    sql="",
                    error=sql[6:].strip()
                ).model_dump()

            # Step 4: Validate SQL security
            is_valid, error_msg = validator.validate(sql)
            if not is_valid:
                return SqlModeResponse(
                    status="error",
                    mode="sql",
                    sql=sql,
                    error=error_msg
                ).model_dump()

            # Step 5: Return mode handling
            if return_mode == "sql":
                return SqlModeResponse(
                    status="success",
                    mode="sql",
                    sql=sql,
                    explanation="生成的 SQL 语句已通过安全验证"
                ).model_dump()

            # Step 6: Execute query and return results
            return await _execute_and_validate(
                pool=pool,
                sql=sql,
                ai_client=ai_client,
                user_query=query,
                max_rows=max_rows,
                timeout=timeout,
                start_time=start_time
            )

        except Exception as e:
            return ResultModeResponse(
                status="error",
                mode="result",
                sql="",
                error=f"查询处理失败: {str(e)}"
            ).model_dump()


async def _execute_and_validate(
    pool: asyncpg.Pool,
    sql: str,
    ai_client: AIClient,
    user_query: str,
    max_rows: int,
    timeout: int,
    start_time: datetime
) -> dict:
    """Execute query and validate results.

    Args:
        pool: The database connection pool.
        sql: The SQL statement to execute.
        ai_client: The AI client for result validation.
        user_query: The original user query.
        max_rows: Maximum number of rows to return.
        timeout: Query timeout in seconds.
        start_time: Query start time.

    Returns:
        Query result response.
    """
    try:
        async with pool.acquire() as conn:
            # Set timeout
            await conn.execute(
                f"SET LOCAL statement_timeout = '{timeout}s'"
            )

            # Execute query
            rows = await conn.fetch(sql)

            execution_time = (
                datetime.utcnow() - start_time
            ).total_seconds() * 1000

            # Limit results
            rows = rows[:max_rows]

            # Build result preview
            result_preview = str([dict(row) for row in rows[:5]])

            # AI validate results
            is_valid, reason = await ai_client.validate_result(
                user_query, sql, result_preview
            )

            return ResultModeResponse(
                status="success",
                mode="result",
                sql=sql,
                rows=[dict(row) for row in rows],
                row_count=len(rows),
                execution_time_ms=execution_time,
                validation={"is_valid": is_valid, "reason": reason}
            ).model_dump()

    except asyncpg.QueryCanceledError:
        return ResultModeResponse(
            status="error",
            mode="result",
            sql=sql,
            error="查询超时"
        ).model_dump()
    except Exception as e:
        return ResultModeResponse(
            status="error",
            mode="result",
            sql=sql,
            error=f"执行失败: {str(e)}"
        ).model_dump()
