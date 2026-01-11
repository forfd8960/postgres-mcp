# src/models/query.py
"""Query-related data models."""

from enum import Enum
from pydantic import BaseModel, Field
from typing import Optional, Any, Literal
from datetime import datetime


class ReturnMode(str, Enum):
    """Return mode enumeration."""

    SQL = "sql"
    RESULT = "result"


class QueryRequest(BaseModel):
    """Query request model."""

    query: str = Field(..., description="Natural language query description")
    database: Optional[str] = Field(None, description="Database name")
    return_mode: ReturnMode = Field(
        default=ReturnMode.SQL,
        description="Return mode: sql or result"
    )
    parameters: Optional[dict[str, Any]] = Field(
        None,
        description="Query parameters"
    )


class QueryResponse(BaseModel):
    """Base query response model."""

    status: Literal["success", "error"]


class SqlModeResponse(QueryResponse):
    """SQL mode response."""

    mode: Literal["sql"] = "sql"
    sql: str
    explanation: Optional[str] = None
    error: Optional[str] = None


class ResultModeResponse(QueryResponse):
    """Result mode response."""

    mode: Literal["result"] = "result"
    sql: str
    rows: list[dict[str, Any]] = []
    row_count: int = 0
    execution_time_ms: float = 0.0
    validation: Optional[dict[str, Any]] = None
    error: Optional[str] = None


class ErrorDetails(BaseModel):
    """Error details model."""

    code: str
    message: str
    details: Optional[dict[str, Any]] = None
