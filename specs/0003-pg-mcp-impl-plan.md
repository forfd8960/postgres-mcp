# Postgres MCP Server 实现计划

**文档版本**: v1.1
**创建日期**: 2026-01-11
**更新日期**: 2026-01-14
**文档编号**: 0003-pg-mcp-impl-plan
**基于设计文档**: 0002-pg-mcp-design.md

---

## 1. 执行摘要

本文档详细描述了 pg-mcp 项目的分阶段实现计划，基于技术设计文档构建。项目采用分层架构设计，核心依赖链为：`配置/模型 → 数据库连接 → Schema 服务 → SQL 验证 → AI 客户端 → MCP 工具 → 主应用`。

**总体实施策略**: 渐进式交付，每个阶段产出可运行的增量功能

| 阶段 | 核心产出 | 预计复杂度 |
|------|----------|------------|
| Phase 0 | 项目脚手架与依赖 | 低 |
| Phase 1 | 配置层与数据模型 | 低 |
| Phase 2 | 核心服务层 | 中 |
| Phase 3 | MCP 工具层 | 中 |
| Phase 4 | 应用集成 | 低 |
| Phase 5 | 测试与质量保障 | 中 |

---

## 2. 依赖关系分析

### 2.1 组件依赖图

```
                    ┌─────────────────┐
                    │   pyproject.toml │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────────┐
│   config.py   │   │   constants.py│   │   exceptions.py   │
└───────┬───────┘   └───────┬───────┘   └─────────┬─────────┘
        │                   │                     │
        │           ┌───────┴───────┐             │
        │           │               │             │
        ▼           ▼               ▼             ▼
┌─────────────────────────────────────────────────────────┐
│                      models/                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                 │
│  │ query.py │ │ schema.py│ │database.py               │
│  └────┬─────┘ └────┬─────┘ └────┬────┘                 │
└───────┼───────────┼───────────┼────────────────────────┘
        │           │           │
        │     ┌─────┴─────┐     │
        │     │           │     │
        ▼     ▼           ▼     ▼
┌─────────────────────────────────────────────────────────┐
│                    services/                             │
│  ┌────────────┐ ┌────────────┐ ┌─────────────────────┐ │
│  │ database.py│ │ sql_validator│ │ ai_client.py       │ │
│  └─────┬──────┘ └─────┬──────┘ └──────────┬──────────┘ │
│        │              │                   │            │
│        │              │                   │            │
│        ▼              │                   │            │
│  ┌──────────────┐     │                   │            │
│  │ schema.py    │◄────┘                   │            │
│  └──────┬───────┘                         │            │
└─────────┼─────────────────────────────────┼────────────┘
          │                                 │
    ┌─────┴─────┐                           │
    │           │                           │
    ▼           ▼                           ▼
┌─────────────────────────────────────────────────────────┐
│                     tools/                               │
│  ┌────────────┐ ┌────────────┐ ┌─────────────────────┐ │
│  │ schema.py  │ │ explain.py │ │ query.py            │ │
│  └────────────┘ └────────────┘ └─────────────────────┘ │
└─────────────────────────┬───────────────────────────────┘
                          │
                          ▼
                ┌─────────────────┐
                │   main.py       │
                └─────────────────┘
```

### 2.2 关键依赖链

| 组件 | 被依赖数量 | 关键前置依赖 |
|------|-----------|-------------|
| pyproject.toml | 5 | 无 |
| config.py | 4 | pyproject.toml |
| models/* | 3 | config.py |
| services/database.py | 2 | config.py |
| services/schema.py | 2 | services/database.py, models/schema.py |
| services/sql_validator.py | 1 | 无 |
| services/ai_client.py | 2 | config.py |
| tools/* | 0 | 对应服务 |
| main.py | 0 | 所有组件 |

**关键路径**: `pyproject.toml → config.py → models/ → services/database.py → services/schema.py → tools/query.py → main.py`

---

## 3. Phase 0: 项目脚手架与依赖管理

### 3.1 目标
建立项目基础结构，配置开发环境和依赖管理。

### 3.2 任务清单

#### Task-001: 初始化项目结构
**优先级**: P0 | **预估工时**: 30min

```
检查项:
  [ ] 创建 src/ 目录结构
  [ ] 创建 tests/ 目录结构
  [ ] 创建 src/__init__.py
  [ ] 创建 tests/__init__.py
  [ ] 初始化 git 仓库 (如未完成)
```

#### Task-002: 配置 pyproject.toml
**优先级**: P0 | **预估工时**: 30min

```toml
# pyproject.toml 核心配置
[project]
name = "postgres-mcp"
version = "0.1.0"
description = "PostgreSQL MCP Server - Natural Language Query Interface"
requires-python = ">=3.10"

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

[tool.pytest.ini_options]
asyncio_mode = "auto"

[tool.ruff]
line-length = 100
target-version = "py310"
```

#### Task-003: 配置开发工具
**优先级**: P1 | **预估工时**: 15min

```
文件:
  [ ] .gitignore (Python 模板)
  [ ] .env.example (环境变量示例)
  [ ] Makefile (常用命令)
  [ ] .python-version (Python 版本)
```

#### Task-004: 创建虚拟环境并安装依赖
**优先级**: P0 | **预估工时**: 10min

```bash
# 创建虚拟环境
python -m venv venv
source venv/bin/activate

# 安装依赖
pip install -e ".[dev]"

# 验证安装
python -c "import fastmcp; import asyncpg; import sqlglot; import pydantic; import openai"
```

### 3.3 验收标准
- [ ] `pip list` 显示所有依赖正确安装
- `python -m pytest --version` 正常执行
- 项目结构符合设计文档

---

## 4. Phase 1: 配置层与数据模型

### 4.1 目标
实现配置管理和核心数据模型，为上层服务提供基础。

### 4.2 任务清单

#### Task-005: 实现配置管理 (src/config.py)
**优先级**: P0 | **预估工时**: 1h

**实现要点**:
```python
# 设计决策点
1. 使用 pydantic_settings.BaseSettings 实现环境变量绑定
2. 支持 DSN 和分离配置两种方式
3. 提供 get_dsn() 方法统一获取连接字符串

# 关键配置项
- postgres_dsn: str (支持 env: PG_MCP_POSTGRES_DSN)
- postgres_host/port/database/user/password: 分离配置
- openai_api_key: 必填
- openai_model: 默认 "gpt-4o-mini"
- max_result_rows: 默认 1000
- query_timeout: 默认 30
- schema_cache_ttl: 默认 3600
```

**测试策略**:
- 环境变量加载测试
- DSN 拼接测试
- 默认值测试

#### Task-006: 实现常量定义 (src/utils/constants.py)
**优先级**: P0 | **预估工时**: 30min

```python
# 定义内容
class ErrorCode(str, Enum):
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

ERROR_MESSAGES: dict[ErrorCode, str] = {...}
```

#### Task-007: 实现异常类 (src/utils/exceptions.py)
**优先级**: P0 | **预估工时**: 30min

```python
# 异常体系
class PgMCPError(Exception):
    """基础异常类"""

class DatabaseConnectionError(PgMCPError): ...
class SQLSecurityError(PgMCPError): ...
class AIServiceError(PgMCPError): ...
class SchemaLoadError(PgMCPError): ...
class QueryExecutionError(PgMCPError): ...
```

#### Task-008: 实现查询模型 (src/models/query.py)
**优先级**: P0 | **预估工时**: 1h

**数据模型**:
```python
class ReturnMode(str, Enum):
    SQL = "sql"
    RESULT = "result"

class QueryRequest(BaseModel):
    query: str
    database: Optional[str] = None
    return_mode: ReturnMode = ReturnMode.SQL
    parameters: Optional[dict[str, Any]] = None

class SqlModeResponse(BaseModel):
    status: Literal["success", "error"]
    mode: Literal["sql"] = "sql"
    sql: str
    explanation: Optional[str] = None
    error: Optional[str] = None

class ResultModeResponse(BaseModel):
    status: Literal["success", "error"]
    mode: Literal["result"] = "result"
    sql: str
    rows: list[dict[str, Any]] = []
    row_count: int = 0
    execution_time_ms: float = 0.0
    validation: Optional[dict[str, Any]] = None
    error: Optional[str] = None
```

**测试策略**:
- Pydantic 验证测试
- 序列化/反序列化测试
- 默认值测试

#### Task-009: 实现 Schema 模型 (src/models/schema.py)
**优先级**: P0 | **预估工时**: 1.5h

**数据模型**:
```python
class DataType(str, Enum):  # 核心数据类型
    INTEGER = "INTEGER"
    BIGINT = "BIGINT"
    VARCHAR = "VARCHAR"
    TEXT = "TEXT"
    BOOLEAN = "BOOLEAN"
    DATE = "DATE"
    TIMESTAMP = "TIMESTAMP"
    JSON = "JSON"
    # ... 其他类型

class ColumnInfo(BaseModel):
    name: str
    data_type: str
    is_nullable: bool = False
    is_primary_key: bool = False
    default_value: Optional[str] = None
    max_length: Optional[int] = None

class TableInfo(BaseModel):
    name: str
    schema: str
    columns: list[ColumnInfo]
    comment: Optional[str] = None

class IndexInfo(BaseModel): ...
class ForeignKeyInfo(BaseModel): ...
class SchemaInfo(BaseModel): ...
```

#### Task-010: 实现数据库模型 (src/models/database.py)
**优先级**: P1 | **预估工时**: 30min

```python
class DatabaseConfig(BaseModel):
    name: str
    dsn: str
    ssl: bool = False

class ConnectionStatus(BaseModel):
    database: str
    connected: bool
    latency_ms: Optional[float] = None
    error: Optional[str] = None
```

### 4.3 验收标准
- [ ] 所有配置项可正确加载环境变量
- [ ] Pydantic 模型验证通过
- [ ] 异常类正确继承和格式化
- [ ] 单元测试覆盖率达到 80%+

---

## 5. Phase 2: 核心服务层

### 5.1 目标
实现业务逻辑核心服务，包括数据库连接、Schema 收集、SQL 验证和 AI 客户端。

### 5.2 任务清单

#### Task-011: 实现数据库连接服务 (src/services/database.py)
**优先级**: P0 | **预估工时**: 1h

**实现要点**:
```python
async def create_pool(
    dsn: str,
    min_size: int = 1,
    max_size: int = 10,
    ssl: bool = False
) -> asyncpg.Pool:
    """创建数据库连接池"""

async def test_connection(pool: asyncpg.Pool) -> bool:
    """测试连接可用性"""
```

**关键设计决策**:
1. 连接池大小: min=1, max=10 (可配置)
2. 连接超时: 30 秒
3. SSL: 根据配置启用

**测试策略**:
- Mock 测试: 验证池创建逻辑
- 集成测试: 使用 testcontainers 或本地 PostgreSQL

#### Task-012: 实现 SQL 验证服务 (src/services/sql_validator.py)
**优先级**: P0 | **预估工时**: 2h

**这是最关键的安全组件，需要详细设计**:

```python
class SQLValidator:
    ALLOWED_STATEMENTS = {"SELECT"}
    SYSTEM_SCHEMA_PREFIXES = ("pg_", "information_schema")
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
        r"\bWITH\s+.*\bDROP\b",  # CTE 注入防护
    ]

    def __init__(self) -> None:
        self._compiled_patterns = [re.compile(p, re.IGNORECASE) for p in self.FORBIDDEN_PATTERNS]

    def validate(self, sql: str) -> tuple[bool, Optional[str]]:
        """验证 SQL 安全性"""
        # 1. 预处理: 清理注释、统一大小写
        # 2. 语句拆解: 使用 sqlglot.parse 确保单语句
        # 3. 语句类型检查: 仅允许 SELECT
        # 4. 危险关键词正则匹配
        # 5. 系统 Schema / 系统表访问拦截
        # 6. CTE 注入检测

    def extract_tables(self, sql: str) -> list[str]:
        """提取表名用于日志"""
```

**安全边界测试用例**:
| 输入 | 预期结果 | 原因 |
|------|----------|------|
| `SELECT * FROM users` | ✓ 通过 | 合法 SELECT |
| `select id, name from users where id = 1` | ✓ 通过 | 大小写不敏感 |
| `INSERT INTO users...` | ✗ 拒绝 | 非 SELECT |
| `WITH x AS (SELECT * FROM users) DROP TABLE users` | ✗ 拒绝 | CTE 注入 |
| `SELECT * FROM users; DROP TABLE users;` | ✗ 拒绝 | 多语句 |
| `SELECT * FROM users WHERE name = 'x'; DELETE FROM users;` | ✗ 拒绝 | 隐式多语句 |
| `/* comment */ DROP TABLE users` | ✗ 拒绝 | 注释隐藏危险操作 |
| `SeLeCt * FrOm users` | ✓ 通过 | 大小写混淆 |
| `SELECT * FROM pg_password` | ✗ 拒绝 | 系统表访问 |
| `SELECT * FROM users WHERE id = 1; -- DROP TABLE users` | ✗ 拒绝 | 注释后多语句 |

**实现细节**:
```python
def validate(self, sql: str) -> tuple[bool, Optional[str]]:
    # 清理 SQL: 移除注释
    cleaned_sql = self._remove_comments(sql)

    # 基础语法检查 + 单语句约束
    try:
        statements = sqlglot.parse(cleaned_sql, read="postgres")
    except ParseError as e:
        return False, f"SQL 语法错误: {str(e)}"

    if len(statements) != 1:
        return False, "仅允许单条 SELECT 语句"

    parsed = statements[0]

    # 检查语句类型
    statement_type = type(parsed).__name__.upper()
    if statement_type not in self.ALLOWED_STATEMENTS:
        return False, f"不允许的语句类型: {statement_type}"

    # 正则模式检查
    for pattern in self._compiled_patterns:
        if pattern.search(cleaned_sql):
            return False, "检测到禁止的关键词"

    # 系统表 / 系统 Schema 拦截
    tables = {t.name for t in parsed.find_all(sqlglot.expressions.Table)}
    if any(str(tbl).lower().startswith(self.SYSTEM_SCHEMA_PREFIXES) for tbl in tables):
        return False, "禁止访问系统表或 information_schema"

    # CTE 注入检测
    if self._contains_forbidden_cte(cleaned_sql):
        return False, "CTE 子句包含危险操作"

    return True, None
```

#### Task-013: 实现 AI 客户端服务 (src/services/ai_client.py)
**优先级**: P0 | **预估工时**: 1.5h

**实现要点**:
```python
class AIClient:
    def __init__(self, api_key: str, model: str, base_url: Optional[str] = None):
        self.client = AsyncOpenAI(api_key=api_key, base_url=base_url)
        self.model = model

    async def generate_sql(
        self,
        schema_info: str,
        user_query: str,
        system_prompt: Optional[str] = None
    ) -> str:
        """生成 SQL"""

    async def validate_result(
        self,
        user_query: str,
        sql: str,
        result_preview: str
    ) -> tuple[bool, str]:
        """验证结果"""
```

**系统提示词设计**:

```python
# SQL 生成提示词
SQL_GENERATION_PROMPT = """你是一个 PostgreSQL 专家。用户想要查询数据库。

可用的数据库 Schema 信息:
{schema_info}

用户的查询需求: {user_query}

请生成对应的 PostgreSQL SELECT 语句。只返回 SQL 代码，不要其他解释。
如果无法生成有效的查询，返回 "ERROR: {原因}"。

约束:
- 只使用 SELECT 语句
- 使用正确的 PostgreSQL 语法
- 列名使用双引号处理保留字
- 字符串使用单引号
"""

# 结果验证提示词
RESULT_VALIDATION_PROMPT = """你是一个数据库查询验证专家。
请判断给定的查询结果是否符合用户的原始查询需求。

用户原始查询: {user_query}
生成的 SQL: {sql}
查询结果预览: {result_preview}

只回答 "YES" 或 "NO"，以及简短的原因。
"""
```

**测试策略**:
- Mock OpenAI API 响应
- 测试错误处理 (API 错误、超时)
- 测试提示词注入防护

#### Task-014: 实现 Schema 服务 (src/services/schema.py)
**优先级**: P0 | **预估工时**: 2h

**实现要点**:
```python
class SchemaService:
    def __init__(self, pool: asyncpg.Pool):
        self.pool = pool
        self._cache: dict[str, SchemaInfo] = {}
        self._cache_time: Optional[datetime] = None

    async def get_schema_info(self, force_refresh: bool = False) -> SchemaInfo:
        """获取 Schema 信息 (带缓存)"""

    def format_schema_for_ai(self, schema_info: SchemaInfo) -> str:
        """格式化供 AI 使用的 Schema 描述"""
```

**Schema 查询 SQL 模板**:
```sql
-- 获取所有表
SELECT table_name, table_schema
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog', 'information_schema');

-- 获取表结构
SELECT
    c.column_name,
    c.data_type,
    c.is_nullable,
    c.column_default,
    c.character_maximum_length
FROM information_schema.columns c
WHERE c.table_schema = $1 AND c.table_name = $2
ORDER BY c.ordinal_position;

-- 获取主键
SELECT k.column_name
FROM information_schema.table_constraints t
JOIN information_schema.constraint_column_usage k
    ON t.constraint_name = k.constraint_name
WHERE t.table_schema = $1
    AND t.table_name = $2
    AND t.constraint_type = 'PRIMARY KEY';

-- 获取索引
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = $1 AND tablename = $2;

-- 获取外键
SELECT conname, pg_get_constraintdef(oid) as condef
FROM pg_constraint
WHERE contype = 'f'
AND connamespace = (SELECT oid FROM pg_namespace WHERE nspname = $1);
```

**缓存策略**:
- TTL: 默认 3600 秒 (可配置)
- 强制刷新: 支持 `force_refresh=True`
- 缓存键: `"default"` (单数据库) 或数据库名称 (多数据库)

**性能考虑**:
- Schema 加载是启动时的阻塞操作
- 大型数据库可能有数百表，需要分批查询
- 考虑添加进度回调

### 5.3 验收标准
- [ ] 数据库连接池正确管理
- [ ] SQL 验证覆盖所有安全测试用例
- [ ] AI 客户端正确处理 API 错误
- [ ] Schema 缓存正常工作
- [ ] 集成测试通过

---

## 6. Phase 3: MCP 工具层

### 6.1 目标
实现 MCP 协议工具，将服务层功能暴露为 MCP 工具。

### 6.2 任务清单

#### Task-015: 实现 Schema 工具 (src/tools/schema.py)
**优先级**: P1 | **预估工时**: 1h

**MCP 工具定义**:
```python
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
```

**实现逻辑**:
1. 调用 `schema_service.get_schema_info(force_refresh=refresh)`
2. 根据 format 参数返回相应格式
3. 错误处理并返回结构化响应

#### Task-016: 实现 Explain 工具 (src/tools/explain.py)
**优先级**: P1 | **预估工时**: 1h

**MCP 工具定义**:
```python
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
```

**实现逻辑**:
1. 获取 Schema 信息
2. 调用 AI 生成 SQL
3. 验证 SQL 安全性
4. 提取涉及的表
5. 返回完整分析结果

#### Task-017: 实现 Query 工具 (src/tools/query.py)
**优先级**: P0 | **预估工时**: 2h

**MCP 工具定义**:
```python
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
```

**完整流程实现**:
```
1. 获取 Schema 信息 (缓存)
2. 调用 AI 生成 SQL
3. 检查 AI 错误响应
4. 验证 SQL 安全性
5. 如果 return_mode == "sql": 返回 SQL
6. 如果 return_mode == "result":
   6.1 设置查询超时
    6.2 使用 asyncpg 参数化执行 (避免字符串拼接)
    6.3 限制结果数量 (row_count / LIMIT)
    6.4 调用 AI 验证结果
    6.5 返回结果
```

**关键实现细节**:
```python
async def query(...) -> dict:
    start_time = datetime.utcnow()

    # 1. 获取 Schema
    schema_info = await schema_service.get_schema_info()
    schema_text = schema_service.format_schema_for_ai(schema_info)

    # 2. 生成 SQL
    sql = await ai_client.generate_sql(schema_text, query)

    # 3. 检查 AI 错误
    if sql.startswith("ERROR:"):
        return SqlModeResponse(
            status="error",
            mode="sql",
            sql="",
            error=sql[6:].strip()
        ).model_dump()

    # 4. 验证安全性
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
            sql=sql
        ).model_dump()

    # 6. 执行查询
    return await _execute_and_validate(...)
```

```python
# _execute_and_validate 关键要点
async def _execute_and_validate(sql: str, return_mode: str, parameters: Optional[dict] = None):
    async with pool.acquire() as conn:
        await conn.execute("SET LOCAL statement_timeout = $1", settings.query_timeout * 1000)
        rows = await conn.fetch(sql, *(parameters or {}).values())  # 参数化执行
    rows = rows[: settings.max_result_rows]
    # 可选: AI 结果验证逻辑
    return ResultModeResponse(
        status="success",
        mode="result",
        sql=sql,
        rows=[dict(r) for r in rows],
        row_count=len(rows),
    ).model_dump()
```

### 6.3 验收标准
- [ ] 工具函数正确注册到 MCP 服务器
- [ ] 参数验证正常工作
- [ ] 错误响应符合规范
- [ ] 工具文档字符串准确

---

## 7. Phase 4: 应用集成

### 7.1 目标
组装所有组件，创建可运行的 MCP 服务器。

### 7.2 任务清单

#### Task-018: 实现主入口 (src/main.py)
**优先级**: P0 | **预估工时**: 1.5h

**实现要点**:
```python
import asyncio
from mcp.server.fastmcp import FastMCP

async def create_mcp_app() -> FastMCP:
    """创建并配置 MCP 应用"""
    mcp = FastMCP("pg-mcp")

    # 从环境变量加载配置
    settings = Settings()

    # 初始化服务
    pool = await create_pool(settings.get_dsn())
    schema_service = SchemaService(pool)
    ai_client = AIClient(settings.openai_api_key, settings.openai_model)
    validator = SQLValidator()

    # 注册工具
    @mcp.tool()
    async def query(...):
        # 使用闭包捕获服务实例
        ...

    @mcp.tool()
    async def explain(...):
        ...

    @mcp.tool()
    async def get_schema(...):
        ...

    return mcp

async def main() -> None:
    mcp = await create_mcp_app()
    await mcp.run()

if __name__ == "__main__":
    asyncio.run(main())
```

**FastMCP 最佳实践**:
```python
# 使用 context 传递服务实例 (推荐方式)
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("pg-mcp")

@mcp.tool()
async def query(query: str, return_mode: str = "sql"):
    # 从 context 获取服务
    context = mcp.context
    pool = context.pool
    schema_service = context.schema_service
    # ...
```

#### Task-019: 创建 __main__.py
**优先级**: P1 | **预估工时**: 15min

```python
# src/__main__.py
from src.main import main

if __name__ == "__main__":
    main()
```

#### Task-020: 更新 README.md
**优先级**: P1 | **预估工时**: 30min

**文档内容**:
- 项目介绍
- 安装指南
- 配置说明
- 使用示例
- 环境变量参考

### 7.3 验收标准
- [ ] 服务器正常启动
- [ ] 工具正确注册
- [ ] 可以通过 MCP 客户端连接

---

## 8. Phase 5: 测试与质量保障

### 8.1 目标
建立完整的测试体系，确保代码质量。

### 8.2 任务清单

#### Task-021: 编写 SQL 验证器单元测试
**优先级**: P0 | **预估工时**: 2h

**测试文件**: `tests/test_sql_validator.py`

```python
import pytest
from src.services.sql_validator import SQLValidator

class TestSQLValidator:
    """SQL 验证器测试套件"""

    def setup_method(self):
        self.validator = SQLValidator()

    # === 通过测试 ===
    def test_valid_select(self):
        sql = "SELECT id, name FROM users WHERE id = 1"
        is_valid, error = self.validator.validate(sql)
        assert is_valid is True
        assert error is None

    def test_select_with_join(self):
        sql = "SELECT u.name, o.total FROM users u JOIN orders o ON u.id = o.user_id"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_subquery(self):
        sql = "SELECT * FROM users WHERE id IN (SELECT user_id FROM orders)"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_cte(self):
        sql = "WITH active_users AS (SELECT * FROM users WHERE active = true) SELECT * FROM active_users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    # === 拒绝测试 ===
    def test_reject_insert(self):
        sql = "INSERT INTO users (name) VALUES ('test')"
        is_valid, error = self.validator.validate(sql)
        assert is_valid is False
        assert "INSERT" in error

    def test_reject_update(self):
        sql = "UPDATE users SET name = 'hacked' WHERE id = 1"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_delete(self):
        sql = "DELETE FROM users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_drop(self):
        sql = "DROP TABLE users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_cte_injection(self):
        sql = "WITH x AS (SELECT * FROM users) DROP TABLE users"
        is_valid, error = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_multiple_statements(self):
        sql = "SELECT * FROM users; DROP TABLE users;"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_hidden_drop_in_comment(self):
        sql = "SELECT * FROM users /* ; DROP TABLE users; */"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_system_table(self):
        sql = "SELECT * FROM pg_password"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_case_insensitive(self):
        sql = "SeLeCt * FrOm users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True
```

#### Task-022: 编写模型单元测试
**优先级**: P1 | **预估工时**: 1h

**测试文件**: `tests/test_models.py`

```python
import pytest
from src.models.query import QueryRequest, SqlModeResponse, ResultModeResponse
from src.models.schema import ColumnInfo, TableInfo, SchemaInfo

class TestQueryModels:
    """查询模型测试"""

    def test_query_request_defaults(self):
        req = QueryRequest(query="test query")
        assert req.return_mode.value == "sql"
        assert req.database is None

    def test_sql_mode_response(self):
        resp = SqlModeResponse(
            status="success",
            sql="SELECT * FROM users"
        )
        assert resp.mode == "sql"
        assert resp.error is None

    def test_result_mode_response(self):
        resp = ResultModeResponse(
            status="success",
            sql="SELECT * FROM users",
            rows=[{"id": 1, "name": "test"}],
            row_count=1
        )
        assert resp.mode == "result"

class TestSchemaModels:
    """Schema 模型测试"""

    def test_column_info(self):
        col = ColumnInfo(name="id", data_type="INTEGER")
        assert col.is_nullable is False
        assert col.is_primary_key is False

    def test_table_info(self):
        col = ColumnInfo(name="id", data_type="INTEGER", is_primary_key=True)
        table = TableInfo(
            name="users",
            schema="public",
            columns=[col]
        )
        assert len(table.columns) == 1
        assert table.columns[0].is_primary_key is True
```

#### Task-023: 编写配置测试
**优先级**: P1 | **预估工时**: 1h

**测试文件**: `tests/test_config.py`

```python
import pytest
from src.config import Settings
from pydantic import ValidationError

class TestSettings:
    """配置测试"""

    def test_default_values(self):
        # 需要 mock 环境变量
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://localhost:5432/test"
        )
        assert settings.openai_model == "gpt-4o-mini"
        assert settings.max_result_rows == 1000

    def test_dsn_from_parts(self):
        settings = Settings(
            openai_api_key="test-key",
            postgres_host="localhost",
            postgres_port=5432,
            postgres_database="testdb",
            postgres_user="user",
            postgres_password="pass"
        )
        dsn = settings.get_dsn()
        assert dsn == "postgresql://user:pass@localhost:5432/testdb"

    def test_explicit_dsn_takes_precedence(self):
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://explicit:5432/explicit",
            postgres_host="ignored",
            postgres_port=9999
        )
        dsn = settings.get_dsn()
        assert "explicit" in dsn
```

#### Task-024: 编写集成测试
**优先级**: P2 | **预估工时**: 2h

**测试文件**: `tests/test_integration.py`

```python
import pytest
import asyncio
from src.services.database import create_pool
from src.services.schema import SchemaService
from src.services.sql_validator import SQLValidator

# 需要使用 testcontainers 或本地 PostgreSQL
@pytest.fixture
async def pool():
    pool = await create_pool("postgresql://postgres@localhost:5432/testdb")
    yield pool
    await pool.close()

@pytest.mark.asyncio
async def test_database_connection(pool):
    async with pool.acquire() as conn:
        result = await conn.fetchval("SELECT 1")
        assert result == 1

@pytest.mark.asyncio
async def test_schema_loading(pool):
    schema_service = SchemaService(pool)
    schema_info = await schema_service.get_schema_info()
    assert schema_info is not None
    assert len(schema_info.tables) >= 0
```

#### Task-025: 配置 CI/CD
**优先级**: P1 | **预估工时**: 1h

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: testdb
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - name: Install dependencies
        run: |
          pip install -e ".[dev]"
      - name: Run linters
        run: |
          ruff check src/ tests/
          black --check src/ tests/
          mypy src/
      - name: Run tests
        env:
          PG_MCP_POSTGRES_DSN: postgresql://postgres:postgres@localhost:5432/testdb
          PG_MCP_OPENAI_API_KEY: sk-test
        run: |
          pytest --cov=src --cov-report=xml
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.xml
```

### 8.3 验收标准
- [ ] 单元测试覆盖率 >= 80%
- [ ] 所有安全测试用例通过
- [ ] CI pipeline 通过
- [ ] 代码通过 lint 检查

---

## 9. 风险分析与缓解

### 9.1 技术风险

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|--------|------|----------|
| FastMCP API 变化 | 中 | 高 | 固定版本号，隔离工具注册逻辑 |
| AI API 成本超预期 | 高 | 中 | 添加使用监控，实现预算告警 |
| SQL 验证绕过 | 低 | 极高 | 多层验证，定期审计测试用例 |
| 数据库连接池耗尽 | 中 | 中 | 实现连接超时和回收机制 |
| 大型 Schema 加载超时 | 中 | 低 | 异步加载，增加超时配置 |

### 9.2 安全风险

| 风险 | 缓解措施 |
|------|----------|
| SQL 注入 | SQLValidator 多层验证 + 只读用户 |
| AI Prompt 注入 | 输入清理 + 输出验证 |
| API Key 泄露 | 使用环境变量 + .gitignore |
| 查询超时 | 设置 statement_timeout |

### 9.3 依赖风险

| 依赖 | 风险 | 缓解措施 |
|------|------|----------|
| OpenAI API | 服务不可用 | 实现错误处理和回退机制 |
| PostgreSQL | 版本兼容 | 测试多种版本 (12-17) |
| asyncpg | 性能问题 | 连接池优化 + 监控 |

---

## 10. 详细任务时间线

### 10.1 Phase 0-1 详细计划 (Day 1)

```
Day 1 - 上午 (3h)
├── Task-001: 项目结构 (30min)
├── Task-002: pyproject.toml (30min)
├── Task-003: 开发工具配置 (30min)
├── Task-004: 环境搭建 (30min)
└── 验证: 依赖安装完成 ✓

Day 1 - 下午 (4h)
├── Task-005: config.py (1h)
├── Task-006: constants.py (30min)
├── Task-007: exceptions.py (30min)
└── Task-008: query models (1h)
    └── 验证: 配置和模型测试通过 ✓
```

### 10.2 Phase 2 详细计划 (Day 2-3)

```
Day 2 - 上午 (3h)
├── Task-009: schema models (1.5h)
├── Task-010: database models (30min)
└── Task-011: database service (1h)

Day 2 - 下午 (4h)
└── Task-012: SQL Validator (4h)
    ├── 核心验证逻辑实现
    ├── 安全测试用例编写
    └── 验证: 安全测试全部通过 ✓

Day 3 - 上午 (3h)
├── Task-013: AI Client (1.5h)
└── Task-014: Schema Service (1.5h)
    └── 验证: Schema 加载测试通过 ✓
```

### 10.3 Phase 3-4 详细计划 (Day 4)

```
Day 4 - 上午 (3h)
├── Task-015: Schema Tool (1h)
├── Task-016: Explain Tool (1h)
└── Task-017: Query Tool (1h)

Day 4 - 下午 (3h)
├── Task-018: Main Application (1.5h)
├── Task-019: __main__.py (15min)
└── Task-020: README (30min)
    └── 验证: 服务器启动成功 ✓
```

### 10.4 Phase 5 详细计划 (Day 5)

```
Day 5 - 全天 (8h)
├── Task-021: SQL Validator Tests (2h)
├── Task-022: Model Tests (1h)
├── Task-023: Config Tests (1h)
├── Task-024: Integration Tests (2h)
└── Task-025: CI/CD Setup (2h)
    └── 验证: 所有测试通过 ✓
```

---

## 11. 验收清单

### 11.1 功能验收

- [ ] 服务器能够正常启动并加载配置
- [ ] 根据自然语言查询能够生成有效的 PostgreSQL SELECT 语句
- [ ] 生成的 SQL 能够通过安全性检查
- [ ] 执行的 SQL 能够返回正确的结果
- [ ] AI 能够验证返回结果的合理性
- [ ] 能够根据用户请求返回 SQL 或查询结果

### 11.2 安全验收

- [ ] 无法执行任何非 SELECT 语句
- [ ] SQL 注入尝试被正确拦截
- [ ] 系统 Schema / 系统表访问被拒绝 (pg_catalog, information_schema)
- [ ] WITH DROP 注入被正确拦截
- [ ] 多语句执行被正确拦截
- [ ] 查询结果限制生效 (默认 1000 条)

### 11.3 性能验收

- [ ] 启动时间 < 5 秒
- [ ] SQL 生成时间 < 3 秒
- [ ] 验证通过后执行时间 < 10 秒

### 11.4 质量验收

- [ ] 单元测试覆盖率 >= 80%
- [ ] 代码通过 ruff/black/mypy 检查
- [ ] CI pipeline 通过
- [ ] 文档完整

---

## 12. 增强功能实现 (v1.1 更新)

### 12.1 多数据库支持

**新增服务**: `src/services/multi_db.py`

```python
class MultiDatabaseManager:
    """多数据库连接池管理器"""

    def configure_default(self, dsn: str, ssl: bool = False):
        """配置默认数据库"""

    def add_database(self, config: DatabaseConfig):
        """添加数据库配置"""

    async def get_pool(self, database: Optional[str] = None) -> asyncpg.Pool:
        """获取指定数据库的连接池"""

    async def test_connection(self, database: Optional[str] = None) -> Dict[str, Any]:
        """测试数据库连接"""

    async def close(self, database: Optional[str] = None):
        """关闭连接池"""
```

**配置示例**:
```bash
export PG_MCP_DATABASES='[
  {"name": "default", "dsn": "postgresql://localhost:5432/maindb"},
  {"name": "analytics", "dsn": "postgresql://localhost:5432/analytics", "pool_max": 20}
]'
```

### 12.2 访问控制

**增强**: `src/services/sql_validator.py`

```python
class SQLValidator:
    def __init__(
        self,
        allowed_statements: Optional[Set[str]] = None,
        blocked_tables: Optional[Set[str]] = None,
        blocked_columns: Optional[Dict[str, Set[str]]] = None,
        allowed_tables: Optional[Set[str]] = None,
        allowed_columns: Optional[Dict[str, Set[str]]] = None
    ):
        """支持表级和列级访问控制"""

    def validate(self, sql: str) -> tuple[bool, Optional[str], Optional[dict]]:
        """返回 (是否通过, 错误信息, 详细信息)"""

    def set_blocked_tables(self, tables: Set[str]):
        """运行时更新阻塞表"""

    def set_allowed_columns(self, columns: Dict[str, Set[str]]):
        """运行时更新允许列"""
```

**配置示例**:
```bash
export PG_MCP_ENABLE_ACCESS_CONTROL=true
export PG_MCP_BLOCKED_TABLES='["users", "passwords", "credentials"]'
export PG_MCP_BLOCKED_COLUMNS='{"users": ["password", "ssn", "credit_card"]}'
```

### 12.3 限流服务

**新增服务**: `src/services/rate_limiter.py`

```python
class SlidingWindowRateLimiter:
    """滑动窗口限流器"""

    def __init__(self, max_requests: int = 100, window_seconds: int = 60):
        ...

    def is_allowed(self, client_id: str) -> RateLimitResult:
        ...

    def get_stats(self, client_id: str) -> Dict[str, Any]:
        ...

class TokenBucketRateLimiter:
    """令牌桶限流器 (支持突发流量)"""

    def __init__(self, rate_per_second: float = 10.0, max_burst: int = 100):
        ...
```

**配置示例**:
```bash
export PG_MCP_RATE_LIMIT_ENABLED=true
export PG_MCP_RATE_LIMIT_REQUESTS=100
export PG_MCP_RATE_LIMIT_WINDOW=60
```

### 12.4 弹性机制

**新增服务**: `src/services/resilience.py`

```python
class CircuitBreaker:
    """熔断器 - 防止级联故障"""

    def __init__(self, name: str, config: Optional[CircuitBreakerConfig] = None):
        ...

    @property
    def state(self) -> CircuitState:
        """CLOSED | OPEN | HALF_OPEN"""

@with_retry(
    max_attempts=3,
    base_delay=1.0,
    max_delay=60.0,
    multiplier=2.0,
    jitter=True
)
async def unreliable_operation():
    """带重试的函数"""
    ...

@with_timeout(seconds=30)
async def timed_operation():
    """带超时的函数"""
    ...
```

### 12.5 可观测性

**新增服务**: `src/services/metrics.py`

```python
class MetricsCollector:
    """指标收集器"""

    def record_request(
        self,
        operation: str,
        success: bool,
        duration_ms: float,
        error_type: Optional[str] = None
    ):
        ...

    def get_operation_summary(self, operation: str) -> Optional[MetricSummary]:
        ...

    def get_global_summary(self) -> MetricSummary:
        ...

    def export_json(self) -> str:
        ...

class TracingService:
    """追踪服务"""

    @contextmanager
    def trace_operation(self, operation: str, **context):
        """追踪操作上下文管理器"""
        ...

# 使用示例
with trace_operation("query", database="default") as trace_id:
    result = await execute_query(...)
    # 自动记录指标和追踪
```

**配置示例**:
```bash
export PG_MCP_METRICS_ENABLED=true
export PG_MCP_TRACING_ENABLED=false
```

---

## 13. 附录: 开发环境快速启动

```bash
# 1. 克隆并进入项目
git clone <repo-url>
cd postgres-mcp

# 2. 创建虚拟环境
python -m venv venv
source venv/bin/activate  # 或 venv\Scripts\activate (Windows)

# 3. 安装依赖
pip install -e ".[dev]"

# 4. 配置环境变量
cp .env.example .env
# 编辑 .env 文件填入实际配置

# 5. 运行测试
pytest

# 6. 启动服务器
python -m src.main

# 7. 开发模式 (热重载)
pip install hupper
python -m hupper -m src.main
```

---

**文档结束**
