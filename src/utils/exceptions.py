# src/utils/exceptions.py
"""Exception classes for pg-mcp."""

from src.utils.constants import ErrorCode, ERROR_MESSAGES


class PgMCPError(Exception):
    """Base exception class for pg-mcp."""

    def __init__(
        self,
        code: ErrorCode,
        message: str | None = None,
        details: dict | None = None
    ):
        self.code = code
        self.message = message or ERROR_MESSAGES.get(code, "未知错误")
        self.details = details or {}
        super().__init__(self.message)

    def to_dict(self) -> dict:
        """Convert the exception to a dictionary format.

        Returns:
            A dictionary representation of the error.
        """
        return {
            "status": "error",
            "error": {
                "code": self.code.value,
                "message": self.message,
                "details": self.details
            }
        }


class DatabaseConnectionError(PgMCPError):
    """Database connection error."""

    def __init__(self, message: str):
        super().__init__(
            code=ErrorCode.DB_CONNECTION_FAILED,
            message=message
        )


class SQLSecurityError(PgMCPError):
    """SQL security check error."""

    def __init__(self, sql: str, reason: str):
        super().__init__(
            code=ErrorCode.SQL_SECURITY_CHECK_FAILED,
            message=f"SQL 安全检查失败: {reason}",
            details={"sql": sql}
        )


class AIServiceError(PgMCPError):
    """AI service error."""

    def __init__(self, message: str):
        super().__init__(
            code=ErrorCode.AI_SERVICE_ERROR,
            message=message
        )


class SchemaLoadError(PgMCPError):
    """Schema load error."""

    def __init__(self, message: str):
        super().__init__(
            code=ErrorCode.SCHEMA_LOAD_FAILED,
            message=message
        )


class QueryExecutionError(PgMCPError):
    """Query execution error."""

    def __init__(self, message: str):
        super().__init__(
            code=ErrorCode.SQL_EXECUTION_FAILED,
            message=message
        )
