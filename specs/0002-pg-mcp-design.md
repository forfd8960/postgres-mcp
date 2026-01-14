# Postgres MCP Server 技术设计文档

**文档版本**: v1.1
**创建日期**: 2026-01-11
**更新日期**: 2026-01-14
**文档编号**: 0002-pg-mcp-design
**基于 PRD**: 0001-pg-mcp-prd.md

---

## 1. 技术架构概述

### 1.1 技术栈

| 组件 | 技术选型 | 版本要求 | 用途 |
|------|----------|----------|------|
| MCP 框架 | FastMCP | latest | MCP 协议服务器实现 |
| 数据库驱动 | asyncpg | latest | 异步 PostgreSQL 连接 |
| SQL 解析 | SQLGlot | latest | SQL 解析与验证 |
| 数据验证 | Pydantic | latest | 数据模型与类型验证 |
| AI 集成 | OpenAI SDK | latest | LLM API 调用 |
| 异步运行时 | asyncio | Python 3.10+ | 异步任务调度 |
| 配置管理 | pydantic-settings | latest | 环境变量配置 |
| 可观测性 | OpenTelemetry | latest | 指标与追踪 |

### 1.2 系统架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        MCP Client (Claude)                       │
└───────────────────────────────┬─────────────────────────────────┘
                                │ MCP Protocol (STDIO/SSE)
┌───────────────────────────────▼─────────────────────────────────┐
│                      pg-mcp Server (FastMCP)                     │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    MCP Tool Interface                        │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │ │
│  │  │ query()     │  │ explain()   │  │ refresh_schema()   │  │ │
│  │  └──────┬──────┘  └──────┬──────┘  └─────────────────────┘  │ │
│  └─────────┼────────────────┼───────────────────────────────────┘ │
│            │                │                                       │
│  ┌─────────▼────────────────▼───────────────────────────────────┐ │
│  │                     Service Layer                             │ │
│  │  ┌───────────────┐  ┌───────────────┐  ┌─────────────────┐   │ │
│  │  │ NLQ Service   │  │ SQL Service   │  │ Schema Service  │   │ │
│  │  │ (OpenAI)      │  │ (SQLGlot)     │  │ (asyncpg)       │   │ │
│  │  └───────┬───────┘  └───────┬───────┘  └─────────────────┘   │ │
│  └───────────┼─────────────────┼───────────────────────────────────┘ │
│              │                 │                                     │
│  ┌───────────▼────────────────▼───────────────────────────────────┐ │
│  │                    Security Layer                              │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌───────────────┐   │ │
│  │  │ SQL Validator   │  │ Result Guard    │  │ Query Limiter │   │ │
│  │  └─────────────────┘  └─────────────────┘  └───────────────┘   │ │
│  └───────────────────────────┬─────────────────────────────────────┘ │
│                              │                                      │
│  ┌───────────────────────────▼────────────────────────────────────┐ │
│  │                    Data Layer                                  │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌────────────────┐  │ │
│  │  │ Schema Cache    │  │ DB Connection   │  │ Result Cache   │  │ │
│  │  │ (LRU Cache)     │  │ Pool (asyncpg)  │  │ (Optional)     │  │ │
│  │  └─────────────────┘  └─────────────────┘  └────────────────┘  │ │
│  └───────────────────────────┬─────────────────────────────────────┘ │
└──────────────────────────────┼──────────────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    │   PostgreSQL DB     │
                    └─────────────────────┘
```

### 1.3 项目目录结构

```
postgres-mcp/
├── src/
│   ├── __init__.py
│   ├── main.py                    # FastMCP 应用入口
│   ├── config.py                  # 配置管理
│   ├── models/
│   │   ├── __init__.py
│   │   ├── database.py            # 数据库模型
│   │   ├── query.py               # 查询请求/响应模型
│   │   └── schema.py              # Schema 模型
│   ├── services/
│   │   ├── __init__.py
│   │   ├── database.py            # 数据库连接服务
│   │   ├── schema.py              # Schema 收集服务
│   │   ├── nlq.py                 # 自然语言查询服务
│   │   ├── sql_validator.py       # SQL 安全验证
│   │   └── ai_client.py           # OpenAI 客户端
│   ├── tools/
│   │   ├── __init__.py
│   │   ├── query.py               # query 工具
│   │   ├── explain.py             # explain 工具
│   │   └── schema.py              # schema 工具
│   └── utils/
│       ├── __init__.py
│       ├── formatting.py          # 结果格式化
│       └── constants.py           # 常量定义
├── tests/
│   ├── __init__.py
│   ├── test_sql_validator.py
│   ├── test_services.py
│   └── test_tools.py
├── specs/
│   ├── 0001-pg-mcp-prd.md
│   └── 0002-pg-mcp-design.md      # 本文档
├── pyproject.toml
└── README.md
```

---

## 2. 配置设计

### 2.1 环境变量配置

```python
# src/config.py
from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """应用配置类"""

    # PostgreSQL 连接配置
    postgres_dsn: str = "postgresql://localhost:5432/postgres"
    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_database: str = "postgres"
    postgres_user: str = "postgres"
    postgres_password: str = ""
    postgres_ssl: bool = False

    # OpenAI 配置
    openai_api_key: str
    openai_model: str = "gpt-4o-mini"
    openai_base_url: Optional[str] = None
    openai_timeout: int = 30

    # 查询配置
    max_result_rows: int = 1000
    query_timeout: int = 30
    schema_cache_ttl: int = 3600

    # 安全配置
    allowed_statements: list[str] = ["SELECT"]
    enable_result_validation: bool = True

    # MCP 配置
    mcp_host: str = "0.0.0.0"
    mcp_port: int = 8080

    class Config:
        env_prefix = "PG_MCP_"

    def get_dsn(self) -> str:
        """获取数据库连接字符串"""
        if self.postgres_dsn:
            return self.postgres_dsn
        return (
            f"postgresql://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_database}"
        )
```

### 2.2 配置示例

```bash
# .env 示例
export PG_MCP_POSTGRES_DSN="postgresql://user:pass@localhost:5432/mydb"
export PG_MCP_OPENAI_API_KEY="sk-xxxxx"
export PG_MCP_OPENAI_MODEL="gpt-4o-mini"
export PG_MCP_MAX_RESULT_ROWS=100
export PG_MCP_QUERY_TIMEOUT=30
```

---

## 3. 数据模型设计

### 3.1 查询相关模型

```python
# src/models/query.py
from enum import Enum
from pydantic import BaseModel, Field
from typing import Optional, Any, Literal
from datetime import datetime


class ReturnMode(str, Enum):
    """返回模式"""
    SQL = "sql"
    RESULT = "result"


class QueryRequest(BaseModel):
    """查询请求模型"""
    query: str = Field(..., description="自然语言查询描述")
    database: Optional[str] = Field(None, description="数据库名称")
    return_mode: ReturnMode = Field(
        default=ReturnMode.SQL,
        description="返回模式：sql 或 result"
    )
    parameters: Optional[dict[str, Any]] = Field(
        None,
        description="查询参数"
    )


class QueryResponse(BaseModel):
    """查询响应基类"""
    status: Literal["success", "error"]


class SqlModeResponse(QueryResponse):
    """SQL 模式响应"""
    mode: Literal["sql"] = "sql"
    sql: str
    explanation: Optional[str] = None
    error: Optional[str] = None


class ResultModeResponse(QueryResponse):
    """结果模式响应"""
    mode: Literal["result"] = "result"
    sql: str
    rows: list[dict[str, Any]] = []
    row_count: int = 0
    execution_time_ms: float = 0.0
    validation: Optional[dict[str, Any]] = None
    error: Optional[str] = None


class ErrorDetails(BaseModel):
    """错误详情"""
    code: str
    message: str
    details: Optional[dict[str, Any]] = None
```

### 3.2 Schema 相关模型

```python
# src/models/schema.py
from pydantic import BaseModel
from typing import Optional, list
from enum import Enum


class DataType(str, Enum):
    """数据类型枚举"""
    INTEGER = "INTEGER"
    BIGINT = "BIGINT"
    SMALLINT = "SMALLINT"
    DECIMAL = "DECIMAL"
    NUMERIC = "NUMERIC"
    REAL = "REAL"
    DOUBLE_PRECISION = "DOUBLE_PRECISION"
    VARCHAR = "VARCHAR"
    CHAR = "CHAR"
    TEXT = "TEXT"
    BOOLEAN = "BOOLEAN"
    DATE = "DATE"
    TIME = "TIME"
    TIMESTAMP = "TIMESTAMP"
    TIMESTAMPTZ = "TIMESTAMPTZ"
    JSON = "JSON"
    JSONB = "JSONB"
    UUID = "UUID"
    ARRAY = "ARRAY"
    OTHER = "OTHER"


class ColumnInfo(BaseModel):
    """列信息"""
    name: str
    data_type: str
    is_nullable: bool = False
    is_primary_key: bool = False
    default_value: Optional[str] = None
    max_length: Optional[int] = None


class TableInfo(BaseModel):
    """表信息"""
    name: str
    schema: str
    columns: list[ColumnInfo]
    comment: Optional[str] = None


class IndexInfo(BaseModel):
    """索引信息"""
    name: str
    table_name: str
    columns: list[str]
    is_unique: bool = False
    definition: str


class ForeignKeyInfo(BaseModel):
    """外键信息"""
    name: str
    columns: list[str]
    ref_table: str
    ref_columns: list[str]


class SchemaInfo(BaseModel):
    """Schema 信息"""
    database: str
    schema: str
    tables: list[TableInfo]
    views: list[str] = []
    indexes: list[IndexInfo] = []
    foreign_keys: list[ForeignKeyInfo] = []
    enums: list[str] = []
```

### 3.3 数据库模型

```python
# src/models/database.py
from pydantic import BaseModel
from typing import Optional


class DatabaseConfig(BaseModel):
    """数据库配置"""
    name: str
    dsn: str
    ssl: bool = False


class ConnectionStatus(BaseModel):
    """连接状态"""
    database: str
    connected: bool
    latency_ms: Optional[float] = None
    error: Optional[str] = None
```

---

## 4. 服务层设计

### 4.1 AI 客户端服务

```python
# src/services/ai_client.py
from openai import AsyncOpenAI
from typing import Optional
import json


class AIClient:
    """OpenAI 客户端封装"""

    def __init__(self, api_key: str, model: str, base_url: Optional[str] = None):
        self.client = AsyncOpenAI(
            api_key=api_key,
            base_url=base_url
        )
        self.model = model

    async def generate_sql(
        self,
        schema_info: str,
        user_query: str,
        system_prompt: Optional[str] = None
    ) -> str:
        """生成 SQL 语句"""
        if system_prompt is None:
            system_prompt = """你是一个 PostgreSQL 专家。用户想要查询数据库。
请根据可用的 Schema 信息生成对应的 PostgreSQL SELECT 语句。
只返回 SQL 代码，不要其他解释。
如果无法生成有效的查询，返回 "ERROR: {原因}""""

        response = await self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"Schema 信息:\n{schema_info}\n\n用户查询: {user_query}"}
            ],
            temperature=0.1
        )

        return response.choices[0].message.content.strip()

    async def validate_result(
        self,
        user_query: str,
        sql: str,
        result_preview: str
    ) -> tuple[bool, str]:
        """验证查询结果是否符合用户需求"""
        system_prompt = """你是一个数据库查询验证专家。
请判断给定的查询结果是否符合用户的原始查询需求。
只回答 "YES" 或 "NO"，以及简短的原因。"""

        response = await self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"用户原始查询: {user_query}\n生成的 SQL: {sql}\n查询结果预览: {result_preview}"}
            ],
            temperature=0.0
        )

        result = response.choices[0].message.content.strip()
        is_valid = result.upper().startswith("YES")
        reason = result[4:].strip() if not is_valid else ""

        return is_valid, reason
```

### 4.2 Schema 服务

```python
# src/services/schema.py
from typing import Optional
from datetime import datetime
import asyncpg
from src.models.schema import SchemaInfo, TableInfo, ColumnInfo


class SchemaService:
    """Schema 信息服务"""

    def __init__(self, pool: asyncpg.Pool):
        self.pool = pool
        self._cache: dict[str, SchemaInfo] = {}
        self._cache_time: Optional[datetime] = None

    async def get_schema_info(self, force_refresh: bool = False) -> SchemaInfo:
        """获取数据库 Schema 信息"""
        # 检查缓存
        if not force_refresh and self._is_cache_valid():
            return self._cache["default"]

        # 从数据库加载
        async with self.pool.acquire() as conn:
            tables = await self._get_tables(conn)
            indexes = await self._get_indexes(conn)
            foreign_keys = await self._get_foreign_keys(conn)

        schema_info = SchemaInfo(
            database="default",
            schema="public",
            tables=tables,
            indexes=indexes,
            foreign_keys=foreign_keys
        )

        # 更新缓存
        self._cache["default"] = schema_info
        self._cache_time = datetime.utcnow()

        return schema_info

    def format_schema_for_ai(self, schema_info: SchemaInfo) -> str:
        """格式化 Schema 信息供 AI 使用"""
        lines = []

        for table in schema_info.tables:
            columns = []
            for col in table.columns:
                col_desc = f"  - {col.name}: {col.data_type}"
                if col.is_nullable:
                    col_desc += " (nullable)"
                if col.is_primary_key:
                    col_desc += " (primary key)"
                columns.append(col_desc)

            lines.append(f"表 {table.name}:")
            lines.extend(columns)
            lines.append("")

        return "\n".join(lines)

    async def _get_tables(self, conn) -> list[TableInfo]:
        """获取所有表信息"""
        rows = await conn.fetch("""
            SELECT
                t.table_name,
                t.table_schema,
                obj_description(
                    (t.table_schema || '.' || t.table_name)::regclass,
                    'pg_class'
                ) as comment
            FROM information_schema.tables t
            WHERE t.table_schema NOT IN ('pg_catalog', 'information_schema')
            ORDER BY t.table_name
        """)

        tables = []
        for row in rows:
            table_name = row["table_name"]
            columns = await self._get_columns(conn, table_name, row["table_schema"])
            tables.append(TableInfo(
                name=table_name,
                schema=row["table_schema"],
                columns=columns,
                comment=row["comment"]
            ))

        return tables

    async def _get_columns(
        self, conn, table_name: str, schema: str
    ) -> list[ColumnInfo]:
        """获取表列信息"""
        rows = await conn.fetch("""
            SELECT
                column_name,
                data_type,
                is_nullable,
                column_default,
                character_maximum_length,
                pg_get_serial_sequence($1, column_name) IS NOT NULL as is_serial
            FROM information_schema.columns
            WHERE table_schema = $2 AND table_name = $1
            ORDER BY ordinal_position
        """, table_name, schema)

        columns = []
        for row in rows:
            is_pk = await self._is_primary_key(conn, table_name, schema, row["column_name"])
            columns.append(ColumnInfo(
                name=row["column_name"],
                data_type=row["data_type"],
                is_nullable=row["is_nullable"] == "YES",
                is_primary_key=is_pk,
                default_value=row["column_default"],
                max_length=row["character_maximum_length"]
            ))

        return columns

    async def _is_primary_key(
        self, conn, table_name: str, schema: str, column_name: str
    ) -> bool:
        """检查列是否为主键"""
        row = await conn.fetchval("""
            SELECT 1 FROM information_schema.table_constraints tc
            JOIN information_schema.constraint_column_usage ccu
                ON tc.constraint_name = ccu.constraint_name
            WHERE tc.table_schema = $1
                AND tc.table_name = $2
                AND tc.constraint_type = 'PRIMARY KEY'
                AND ccu.column_name = $3
        """, schema, table_name, column_name)

        return row is not None

    async def _get_indexes(self, conn) -> list:
        """获取索引信息"""
        rows = await conn.fetch("""
            SELECT indexname, indexdef, tablename
            FROM pg_indexes
            WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
        """)
        return [{"name": r["indexname"], "definition": r["indexdef"]} for r in rows]

    async def _get_foreign_keys(self, conn) -> list:
        """获取外键信息"""
        rows = await conn.fetch("""
            SELECT
                conname,
                pg_get_constraintdef(oid) as condef
            FROM pg_constraint
            WHERE contype = 'f'
        """)
        return [{"name": r["conname"], "definition": r["condef"]} for r in rows]

    def _is_cache_valid(self) -> bool:
        """检查缓存是否有效"""
        if self._cache_time is None:
            return False
        from datetime import timedelta
        return datetime.utcnow() - self._cache_time < timedelta(seconds=3600)
```

### 4.3 SQL 验证服务

```python
# src/services/sql_validator.py
import sqlglot
from sqlglot.errors import ParseError
from typing import Optional
import re


class SQLValidator:
    """SQL 安全验证器"""

    # 允许的语句类型
    ALLOWED_STATEMENTS = {"SELECT"}

    # 禁止的关键词模式
    FORBIDDEN_PATTERNS = [
        r"\bINSERT\b",
        r"\bUPDATE\b",
        r"\bDELETE\b",
        r"\bDROP\b",
        r"\bTRUNCATE\b",
        r"\bALTER\b",
        r"\bCREATE\b",
        r"\bGRANT\b",
        r"\bREVOKE\b",
        r"\bEXECUTE\b",
        r"\bWITH\s+.*\bDROP\b",  # WITH xx DROP 注入
    ]

    def __init__(self, allowed_statements: Optional[set[str]] = None):
        self.allowed_statements = allowed_statements or self.ALLOWED_STATEMENTS
        self._compiled_patterns = [
            re.compile(p, re.IGNORECASE) for p in self.FORBIDDEN_PATTERNS
        ]

    def validate(self, sql: str) -> tuple[bool, Optional[str]]:
        """
        验证 SQL 语句

        Returns:
            (is_valid, error_message)
        """
        # 1. 基本语法检查
        try:
            parsed = sqlglot.parse_one(sql, read="postgres")
        except ParseError as e:
            return False, f"SQL 语法错误: {str(e)}"

        # 2. 语句类型检查
        statement_type = type(parsed).__name__.upper()
        if statement_type not in self.allowed_statements:
            return False, f"不允许的语句类型: {statement_type}"

        # 3. 模式检查（防止注入）
        for pattern in self._compiled_patterns:
            if pattern.search(sql):
                return False, f"检测到禁止的关键词或模式"

        # 4. 检查是否有子句包含危险操作
        if self._contains_forbidden_clauses(sql):
            return False, "检测到禁止的子句组合"

        return True, None

    def extract_tables(self, sql: str) -> list[str]:
        """提取 SQL 中的表名"""
        try:
            parsed = sqlglot.parse_one(sql, read="postgres")
            tables = []

            # 遍历所有表引用
            for node in parsed.walk():
                if isinstance(node, sqlglot.exp.Table):
                    tables.append(node.name)

            return list(set(tables))
        except ParseError:
            return []

    def _contains_forbidden_clauses(self, sql: str) -> bool:
        """检查是否包含禁止的子句组合"""
        sql_upper = sql.upper()

        # 检查 WITH 后是否包含危险操作
        with_match = re.search(r"WITH\s+(\w+)\s+AS\s*\([^)]+([^\)]+)\)", sql_upper)
        if with_match:
            cte_body = with_match.group(2)
            dangerous_keywords = ["DROP", "DELETE", "INSERT", "UPDATE", "ALTER"]
            for kw in dangerous_keywords:
                if kw in cte_body:
                    return True

        return False

    def validate_explain(self, sql: str) -> tuple[bool, Optional[str]]:
        """
        使用 EXPLAIN 验证 SQL 可执行性
        """
        explain_sql = f"EXPLAIN {sql}"
        return self.validate(explain_sql)
```

---

## 5. 工具层设计 (MCP Tools)

### 5.1 Query Tool

```python
# src/tools/query.py
from mcp.server.fastmcp import FastMCP
from src.services.schema import SchemaService
from src.services.ai_client import AIClient
from src.services.sql_validator import SQLValidator
from src.models.query import QueryRequest, SqlModeResponse, ResultModeResponse
from src.models.schema import SchemaInfo
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
):
    """注册 query 工具"""

    @mcp.tool()
    async def query(
        query: str,
        return_mode: str = "sql",
        database: Optional[str] = None,
        parameters: Optional[dict] = None
    ) -> dict:
        """
        使用自然语言查询 PostgreSQL 数据库。

        Args:
            query: 自然语言查询描述（中文或英文）
            return_mode: 返回模式，"sql" 返回 SQL 语句，"result" 返回查询结果
            database: 目标数据库名称（可选，默认使用主数据库）
            parameters: 查询参数（用于参数化查询）

        Returns:
            返回 SQL 语句或查询结果
        """
        start_time = datetime.utcnow()

        try:
            # 1. 获取 Schema 信息
            schema_info = await schema_service.get_schema_info()
            schema_text = schema_service.format_schema_for_ai(schema_info)

            # 2. 使用 AI 生成 SQL
            sql = await ai_client.generate_sql(schema_text, query)

            # 3. 检查 AI 是否返回错误
            if sql.startswith("ERROR:"):
                return SqlModeResponse(
                    status="error",
                    mode="sql",
                    sql="",
                    error=sql[6:].strip()
                ).model_dump()

            # 4. 验证 SQL 安全性
            is_valid, error_msg = validator.validate(sql)
            if not is_valid:
                return SqlModeResponse(
                    status="error",
                    mode="sql",
                    sql=sql,
                    error=error_msg
                ).model_dump()

            # 5. 返回模式处理
            if return_mode == "sql":
                return SqlModeResponse(
                    status="success",
                    mode="sql",
                    sql=sql,
                    explanation="生成的 SQL 语句已通过安全验证"
                ).model_dump()

            # 6. 执行查询并返回结果
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
    """执行查询并验证结果"""
    try:
        async with pool.acquire() as conn:
            # 设置超时
            await conn.execute(f"SET statement_timeout = '{timeout}s'")

            # 执行查询
            rows = await conn.fetch(sql)

            execution_time = (datetime.utcnow() - start_time).total_seconds() * 1000

            # 限制结果数量
            rows = rows[:max_rows]

            # 构建结果预览
            result_preview = str([dict(row) for row in rows[:5]])

            # AI 验证结果
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
```

### 5.2 Explain Tool

```python
# src/tools/explain.py
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
):
    """注册 explain 工具"""

    @mcp.tool()
    async def explain(
        query: str,
        database: Optional[str] = None
    ) -> dict:
        """
        解释自然语言查询并展示生成的 SQL 语句。

        Args:
            query: 自然语言查询描述
            database: 目标数据库名称（可选）

        Returns:
            包含 SQL 语句、解释和分析结果的字典
        """
        try:
            # 获取 Schema 信息
            schema_info = await schema_service.get_schema_info()
            schema_text = schema_service.format_schema_for_ai(schema_info)

            # 生成 SQL
            sql = await ai_client.generate_sql(schema_text, query)

            # 检查 AI 错误
            if sql.startswith("ERROR:"):
                return {
                    "status": "error",
                    "error": sql[6:].strip()
                }

            # 验证 SQL
            is_valid, error_msg = validator.validate(sql)

            # 提取涉及的表
            tables = validator.extract_tables(sql)

            # 构建响应
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
```

### 5.3 Schema Tool

```python
# src/tools/schema.py
from mcp.server.fastmcp import FastMCP
from src.services.schema import SchemaService
from typing import Optional


def register_schema_tool(
    mcp: FastMCP,
    schema_service: SchemaService
):
    """注册 schema 工具"""

    @mcp.tool()
    async def get_schema(
        refresh: bool = False,
        format: str = "summary"
    ) -> dict:
        """
        获取当前连接的 PostgreSQL 数据库 Schema 信息。

        Args:
            refresh: 是否强制刷新缓存
            format: 输出格式，"summary" 简略，"full" 完整详情

        Returns:
            数据库 Schema 信息
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

            # 简化输出
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
```

---

## 6. 主应用入口

```python
# src/main.py
import asyncpg
from mcp.server.fastmcp import FastMCP
from contextlib import asynccontextmanager

from src.config import Settings
from src.services.database import create_pool
from src.services.schema import SchemaService
from src.services.ai_client import AIClient
from src.services.sql_validator import SQLValidator
from src.tools.query import register_query_tool
from src.tools.explain import register_explain_tool
from src.tools.schema import register_schema_tool


@asynccontextmanager
async def app_lifespan(settings: Settings):
    """应用生命周期管理"""
    # 启动时创建连接池
    pool = await create_pool(
        dsn=settings.get_dsn(),
        ssl=settings.postgres_ssl
    )

    # 初始化服务
    schema_service = SchemaService(pool)
    ai_client = AIClient(
        api_key=settings.openai_api_key,
        model=settings.openai_model,
        base_url=settings.openai_base_url
    )
    validator = SQLValidator(
        allowed_statements=settings.allowed_statements
    )

    yield {
        "pool": pool,
        "schema_service": schema_service,
        "ai_client": ai_client,
        "validator": validator,
        "settings": settings
    }

    # 关闭时清理
    await pool.close()


def create_mcp_app(settings: Settings) -> FastMCP:
    """创建 MCP 应用"""
    mcp = FastMCP("pg-mcp")

    # 注册工具
    mcp.context_lifespan_factory = app_lifespan

    # 注意：FastMCP 的工具注册需要在 lifespan 外部进行
    # 这里使用装饰器模式，实际工具逻辑在工具函数内部访问 context

    return mcp


def main():
    """主入口"""
    import argparse

    parser = argparse.ArgumentParser(description="PostgreSQL MCP Server")
    parser.add_argument("--dsn", type=str, help="Database DSN")
    parser.add_argument("--api-key", type=str, help="OpenAI API Key")
    parser.add_argument("--model", type=str, default="gpt-4o-mini", help="OpenAI Model")

    args = parser.parse_args()

    # 加载配置
    settings = Settings()
    if args.dsn:
        settings.postgres_dsn = args.dsn
    if args.api_key:
        settings.openai_api_key = args.api_key
    if args.model:
        settings.openai_model = args.model

    # 创建并运行 MCP 服务器
    mcp = create_mcp_app(settings)

    # 注册工具
    @mcp.tool()
    async def query(
        query: str,
        return_mode: str = "sql",
        database: str = None,
        parameters: dict = None
    ):
        from src.tools.query import query as query_impl
        context = mcp.context
        # ... 实现逻辑

    mcp.run()


if __name__ == "__main__":
    main()
```

---

## 7. 安全设计

### 7.1 SQL 注入防护

```python
# 安全策略实现

class SecurityPolicy:
    """安全策略"""

    # 允许的 SQL 关键字
    ALLOWED_KEYWORDS = {
        "SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "IN", "BETWEEN",
        "LIKE", "ILIKE", "IS", "NULL", "TRUE", "FALSE", "AS", "DISTINCT",
        "GROUP", "BY", "HAVING", "ORDER", "ASC", "DESC", "LIMIT", "OFFSET",
        "JOIN", "INNER", "LEFT", "RIGHT", "FULL", "OUTER", "ON", "USING",
        "UNION", "INTERSECT", "EXCEPT", "EXISTS", "ANY", "ALL",
        "COUNT", "SUM", "AVG", "MIN", "MAX", "CASE", "WHEN", "THEN", "ELSE",
        "END", "CAST", "COALESCE", "NULLIF", "GREATEST", "LEAST",
        "WITH", "AS", "RECURSIVE", "OVER", "PARTITION", "ROW_NUMBER",
        "RANK", "DENSE_RANK", "LEAD", "LAG", "FIRST_VALUE", "LAST_VALUE",
        "CURRENT_TIMESTAMP", "CURRENT_DATE", "NOW", "INTERVAL"
    }

    # 禁止的操作
    FORBIDDEN_OPERATIONS = {
        "INSERT", "UPDATE", "DELETE", "DROP", "TRUNCATE", "ALTER",
        "CREATE", "GRANT", "REVOKE", "EXECUTE", "CALL", "LOAD"
    }

    @classmethod
    def analyze_sql(cls, sql: str) -> tuple[bool, list[str]]:
        """
        分析 SQL 是否安全

        Returns:
            (is_safe, violations)
        """
        violations = []

        # 检查语句类型
        normalized = sql.strip().upper()
        first_word = normalized.split()[0] if normalized else ""

        if first_word not in cls.ALLOWED_KEYWORDS and first_word in cls.FORBIDDEN_OPERATIONS:
            violations.append(f"禁止的语句类型: {first_word}")

        # 检查 WITH 子句注入
        if "WITH" in normalized:
            with_clause_match = re.search(r"WITH\s+(\w+)\s+AS\s*\(", normalized)
            if with_clause_match:
                cte_content = normalized[with_clause_match.end():]
                for op in cls.FORBIDDEN_OPERATIONS:
                    if op in cte_content:
                        violations.append(f"WITH 子句中包含禁止操作: {op}")

        # 检查多语句
        if ";" in sql.strip(";") and ";" in sql:
            violations.append("检测到多语句执行")

        return len(violations) == 0, violations
```

### 7.2 查询限流

```python
# src/services/rate_limiter.py
from typing import Dict
from datetime import datetime, timedelta
from collections import deque


class RateLimiter:
    """查询限流器"""

    def __init__(self, max_requests: int = 100, window_seconds: int = 60):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.requests: Dict[str, deque] = {}

    def is_allowed(self, client_id: str) -> bool:
        """检查是否允许请求"""
        now = datetime.utcnow()
        window_start = now - timedelta(seconds=self.window_seconds)

        if client_id not in self.requests:
            self.requests[client_id] = deque()

        # 清理过期请求
        client_requests = self.requests[client_id]
        while client_requests and client_requests[0] < window_start:
            client_requests.popleft()

        # 检查限制
        if len(client_requests) >= self.max_requests:
            return False

        # 记录请求
        client_requests.append(now)
        return True

    def get_remaining(self, client_id: str) -> int:
        """获取剩余请求数"""
        now = datetime.utcnow()
        window_start = now - timedelta(seconds=self.window_seconds)

        if client_id not in self.requests:
            return self.max_requests

        client_requests = self.requests[client_id]
        while client_requests and client_requests[0] < window_start:
            client_requests.popleft()

        return max(0, self.max_requests - len(client_requests))
```

---

## 8. 错误处理设计

### 8.1 错误码定义

```python
# src/utils/constants.py
from enum import Enum


class ErrorCode(str, Enum):
    """错误码枚举"""
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


ERROR_MESSAGES = {
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
```

### 8.2 统一错误响应

```python
# src/utils/exceptions.py
from src.utils.constants import ErrorCode, ERROR_MESSAGES


class PgMCPError(Exception):
    """基础异常类"""

    def __init__(
        self,
        code: ErrorCode,
        message: str = None,
        details: dict = None
    ):
        self.code = code
        self.message = message or ERROR_MESSAGES.get(code, "未知错误")
        self.details = details or {}
        super().__init__(self.message)

    def to_dict(self) -> dict:
        """转换为字典格式"""
        return {
            "status": "error",
            "error": {
                "code": self.code.value,
                "message": self.message,
                "details": self.details
            }
        }


class DatabaseConnectionError(PgMCPError):
    """数据库连接错误"""

    def __init__(self, message: str):
        super().__init__(
            code=ErrorCode.DB_CONNECTION_FAILED,
            message=message
        )


class SQLSecurityError(PgMCPError):
    """SQL 安全检查错误"""

    def __init__(self, sql: str, reason: str):
        super().__init__(
            code=ErrorCode.SQL_SECURITY_CHECK_FAILED,
            message=f"SQL 安全检查失败: {reason}",
            details={"sql": sql}
        )
```

---

## 9. 依赖管理

### 9.1 pyproject.toml

```toml
[project]
name = "postgres-mcp"
version = "0.1.0"
description = "PostgreSQL MCP Server - Natural Language Query Interface"
readme = "README.md"
requires-python = ">=3.10"
license = {text = "MIT"}
authors = [
    {name = "pg-mcp Contributors"}
]
dependencies = [
    "fastmcp>=0.2.0",
    "asyncpg>=0.29.0",
    "sqlglot>=25.0.0",
    "pydantic>=2.5.0",
    "pydantic-settings>=2.1.0",
    "openai>=1.0.0",
    "python-dotenv>=1.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.4.0",
    "pytest-asyncio>=0.21.0",
    "pytest-cov>=4.1.0",
    "black>=23.0.0",
    "ruff>=0.1.0",
    "mypy>=1.7.0",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]

[tool.black]
line-length = 100
target-version = ['py310']

[tool.ruff]
line-length = 100
target-version = "py310"
```

---

## 10. 部署说明

### 10.1 Docker 部署

```dockerfile
# Dockerfile
FROM python:3.11-slim

WORKDIR /app

# 安装依赖
COPY pyproject.toml .
RUN pip install --no-cache-dir -e .

# 复制代码
COPY src/ ./src/

# 设置环境变量
ENV PG_MCP_OPENAI_MODEL="gpt-4o-mini"
ENV PG_MCP_MAX_RESULT_ROWS=1000

# 运行
CMD ["python", "-m", "src.main"]
```

### 10.2 使用方式

```bash
# 方式一：直接运行
python -m src.main --dsn "postgresql://..." --api-key "sk-..."

# 方式二：使用 MCP 客户端
# 配置到 Claude Desktop 或其他 MCP 客户端

# 方式三：Docker
docker run -e PG_MCP_POSTGRES_DSN="postgresql://..." \
           -e PG_MCP_OPENAI_API_KEY="sk-..." \
           postgres-mcp
```

---

## 11. 测试策略

### 11.1 测试覆盖

| 测试类型 | 覆盖范围 |
|----------|----------|
| 单元测试 | SQL 验证器、模型验证、服务逻辑 |
| 集成测试 | 数据库连接、Schema 收集、查询执行 |
| E2E 测试 | 完整查询流程（自然语言 → SQL → 结果） |
| 安全测试 | SQL 注入防护、边界条件测试 |

### 11.2 测试示例

```python
# tests/test_sql_validator.py
import pytest
from src.services.sql_validator import SQLValidator


class TestSQLValidator:
    def setup_method(self):
        self.validator = SQLValidator()

    def test_valid_select(self):
        sql = "SELECT id, name FROM users WHERE id = 1"
        is_valid, error = self.validator.validate(sql)
        assert is_valid is True
        assert error is None

    def test_reject_insert(self):
        sql = "INSERT INTO users (name) VALUES ('test')"
        is_valid, error = self.validator.validate(sql)
        assert is_valid is False
        assert "INSERT" in error

    def test_reject_with_drop_injection(self):
        sql = "WITH x AS (SELECT * FROM users) DROP TABLE users"
        is_valid, error = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_multiple_statements(self):
        sql = "SELECT * FROM users; DROP TABLE users;"
        is_valid, error = self.validator.validate(sql)
        assert is_valid is False
```

---

**文档结束**
