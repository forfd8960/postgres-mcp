# src/utils/constants.py
"""Constants for pg-mcp."""

from enum import Enum


class ErrorCode(str, Enum):
    """Error code enumeration."""

    DB_CONNECTION_FAILED = "ERR_001"
    SCHEMA_LOAD_FAILED = "ERR_002"
    AI_SERVICE_ERROR = "ERR_003"
    SQL_GENERATION_FAILED = "ERR_004"
    SQL_SECURITY_CHECK_FAILED = "ERR_005"
    SQL_EXECUTION_FAILED = "ERR_006"
    RESULT_VALIDATION_FAILED = "ERR_007"
    INVALID_REQUEST = "ERR_008"
    RATE_LIMIT_EXCEEDED = "ERR_009"
    QUERY_TIMEOUT = "ERR_010"


ERROR_MESSAGES: dict[ErrorCode, str] = {
    ErrorCode.DB_CONNECTION_FAILED: "无法连接到配置的数据库",
    ErrorCode.SCHEMA_LOAD_FAILED: "无法加载数据库 Schema 信息",
    ErrorCode.AI_SERVICE_ERROR: "AI 服务调用失败",
    ErrorCode.SQL_GENERATION_FAILED: "无法根据用户输入生成 SQL",
    ErrorCode.SQL_SECURITY_CHECK_FAILED: "生成的 SQL 包含不允许的操作",
    ErrorCode.SQL_EXECUTION_FAILED: "SQL 执行失败",
    ErrorCode.RESULT_VALIDATION_FAILED: "AI 认为结果不符合用户需求",
    ErrorCode.INVALID_REQUEST: "输入参数不完整或格式错误",
    ErrorCode.RATE_LIMIT_EXCEEDED: "请求频率超限",
    ErrorCode.QUERY_TIMEOUT: "查询超时",
}
