# src/tools/__init__.py
"""MCP tools for pg-mcp."""

from src.tools.schema import register_schema_tool
from src.tools.explain import register_explain_tool
from src.tools.query import register_query_tool

__all__ = [
    "register_schema_tool",
    "register_explain_tool",
    "register_query_tool",
]
