# Postgres MCP Server 测试计划

**文档版本**: v1.0
**创建日期**: 2026-01-12
**文档编号**: 0005-pg-mcp-test-plan
**基于设计文档**: 0002-pg-mcp-design.md, 0003-pg-mcp-impl-plan.md

---

## 1. 测试策略概述

### 1.1 测试目标

pg-mcp 作为连接 LLM 与 PostgreSQL 数据库的 MCP 服务器，其测试策略需要确保以下核心目标：

| 目标 | 描述 | 验证方式 |
|------|------|----------|
| **功能正确性** | 自然语言转 SQL 的准确性 | 单元测试 + E2E 测试 |
| **安全性** | SQL 注入防护、只读限制 | 安全测试用例 |
| **健壮性** | 异常处理、边界条件 | 异常测试 |
| **性能** | 查询响应时间、资源使用 | 性能测试 |
| **可靠性** | 长时间运行稳定性 | 稳定性测试 |

### 1.2 测试金字塔

```
                    ┌─────────────┐
                    │   E2E 测试   │      5%  (核心场景验证)
           ┌────────┴─────────────┴────────┐
           │        集成测试                │     25% (服务间交互)
    ┌──────┴────────────────────────────────┴──────┐
    │              单元测试                         │  70% (各组件独立验证)
    └────────────────────────────────────────────────┘
```

**各层测试比例与目的**：

| 层级 | 比例 | 目的 | 工具 |
|------|------|------|------|
| 单元测试 | 70% | 验证各组件逻辑正确性 | pytest + unittest.mock |
| 集成测试 | 25% | 验证组件间协作 | pytest + testcontainers |
| E2E 测试 | 5% | 验证完整用户场景 | MCP Client 模拟 |

### 1.3 测试优先级矩阵

```
优先级定义：
P0 - 必须通过，阻塞发布
P1 - 应该通过，严重缺陷
P2 - 最好通过，一般缺陷
P3 - 可选通过，小优化
```

---

## 2. 测试环境规划

### 2.1 环境矩阵

| 环境 | 用途 | 数据库版本 | AI 模拟 |
|------|------|------------|---------|
| **Unit** | 单元测试 | Mock | Mock |
| **Integration** | 集成测试 | PostgreSQL 16 (Docker) | Mock / Fake |
| **E2E** | 端到端测试 | PostgreSQL 16 (Docker) | Real API |
| **Staging** | 预发布验证 | PostgreSQL 14/15/16 | Real API |

### 2.2 测试数据库 Schema

```sql
-- tests/fixtures/schema.sql
-- 测试数据库使用的标准 Schema

-- 用户表
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- 订单表
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    total DECIMAL(10, 2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 产品表
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    stock INTEGER DEFAULT 0,
    category VARCHAR(50)
);

-- 订单明细表
CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id),
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER NOT NULL,
    price DECIMAL(10, 2) NOT NULL
);

-- 插入测试数据
INSERT INTO users (username, email) VALUES
    ('alice', 'alice@example.com'),
    ('bob', 'bob@example.com'),
    ('charlie', 'charlie@example.com');

INSERT INTO products (name, price, stock, category) VALUES
    ('Widget A', 19.99, 100, 'Electronics'),
    ('Widget B', 29.99, 50, 'Electronics'),
    ('Gadget X', 49.99, 25, 'Gadgets');

INSERT INTO orders (user_id, total, status) VALUES
    (1, 59.97, 'completed'),
    (1, 29.99, 'pending'),
    (2, 99.98, 'completed');
```

### 2.3 pytest 配置

```python
# pytest.ini 或 pyproject.toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
addopts = """
    -v --tb=short
    --strict-markers
    --disable-warnings
    -p no:cacheprovider
"""
filterwarnings = [
    "ignore::DeprecationWarning",
    "ignore::pytest.PytestUnraisableExceptionWarning",
]
```

### 2.4 conftest.py 配置

```python
# tests/conftest.py
import asyncio
import pytest
import pytest_asyncio
from unittest.mock import AsyncMock, MagicMock
from src.config import Settings
from src.services.sql_validator import SQLValidator


@pytest.fixture(scope="session")
def event_loop():
    """创建事件循环 fixture"""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
def test_settings():
    """测试配置 fixture"""
    return Settings(
        openai_api_key="test-api-key",
        postgres_dsn="postgresql://test@localhost:5432/testdb",
        max_result_rows=100,
        query_timeout=30,
    )


@pytest.fixture
def sql_validator():
    """SQL 验证器 fixture"""
    return SQLValidator()


@pytest.fixture
def mock_ai_client():
    """Mock AI 客户端 fixture"""
    client = AsyncMock()
    client.generate_sql = AsyncMock(return_value="SELECT * FROM users")
    client.validate_result = AsyncMock(return_value=(True, ""))
    return client


@pytest.fixture
def mock_schema_info():
    """Mock Schema 信息 fixture"""
    return {
        "tables": [
            {
                "name": "users",
                "columns": [
                    {"name": "id", "type": "INTEGER", "pk": True},
                    {"name": "username", "type": "VARCHAR"},
                    {"name": "email", "type": "VARCHAR"},
                ],
            }
        ]
    }
```

---

## 3. 单元测试详细设计

### 3.1 配置模块测试 (test_config.py)

**测试文件**: `tests/test_config.py`

```python
import pytest
from unittest.mock import patch
from src.config import Settings
from pydantic import ValidationError


class TestSettings:
    """配置类测试套件"""

    def test_default_values(self):
        """测试默认值配置"""
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://localhost:5432/test"
        )
        assert settings.openai_model == "gpt-4o-mini"
        assert settings.max_result_rows == 1000
        assert settings.query_timeout == 30
        assert settings.schema_cache_ttl == 3600
        assert settings.openai_timeout == 30

    def test_dsn_from_parts(self):
        """测试从分离配置构建 DSN"""
        settings = Settings(
            openai_api_key="test-key",
            postgres_host="db.example.com",
            postgres_port=5433,
            postgres_database="mydb",
            postgres_user="admin",
            postgres_password="secret"
        )
        dsn = settings.get_dsn()
        assert dsn == "postgresql://admin:secret@db.example.com:5433/mydb"

    def test_explicit_dsn_takes_precedence(self):
        """测试显式 DSN 优先于分离配置"""
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://explicit:5432/explicitdb",
            postgres_host="ignored-host",
            postgres_port=9999,
            postgres_database="ignored-db"
        )
        dsn = settings.get_dsn()
        assert "explicit:5432" in dsn
        assert "explicitdb" in dsn

    @patch.dict('os.environ', {
        'PG_MCP_OPENAI_API_KEY': 'env-api-key',
        'PG_MCP_POSTGRES_DSN': 'postgresql://env:5432/envdb',
        'PG_MCP_MAX_RESULT_ROWS': '500'
    })
    def test_env_variable_loading(self):
        """测试环境变量加载"""
        settings = Settings()
        assert settings.openai_api_key == "env-api-key"
        assert "envdb" in settings.postgres_dsn
        assert settings.max_result_rows == 500

    def test_missing_required_api_key(self):
        """测试缺少必填 API Key"""
        with pytest.raises(ValidationError):
            Settings(
                postgres_dsn="postgresql://localhost:5432/test"
            )

    def test_ssl_configuration(self):
        """测试 SSL 配置"""
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://localhost:5432/test",
            postgres_ssl=True
        )
        assert settings.postgres_ssl is True

    def test_openai_base_url_optional(self):
        """测试 OpenAI Base URL 可选"""
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://localhost:5432/test"
        )
        assert settings.openai_base_url is None

    def test_custom_openai_base_url(self):
        """测试自定义 OpenAI Base URL"""
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://localhost:5432/test",
            openai_base_url="https://custom-api.example.com/v1"
        )
        assert settings.openai_base_url == "https://custom-api.example.com/v1"

    def test_allowed_statements_default(self):
        """测试默认允许语句类型"""
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://localhost:5432/test"
        )
        assert settings.allowed_statements == ["SELECT"]

    def test_custom_allowed_statements(self):
        """测试自定义允许语句类型"""
        settings = Settings(
            openai_api_key="test-key",
            postgres_dsn="postgresql://localhost:5432/test",
            allowed_statements=["SELECT", "SHOW"]
        )
        assert "SHOW" in settings.allowed_statements

    def test_get_dsn_with_empty_parts(self):
        """测试空部分配置的 DSN 生成"""
        settings = Settings(
            openai_api_key="test-key",
            postgres_host="localhost",
            postgres_port=5432,
            postgres_database="testdb"
        )
        dsn = settings.get_dsn()
        assert "localhost:5432/testdb" in dsn
```

### 3.2 数据模型测试 (test_models.py)

**测试文件**: `tests/test_models.py`

```python
import pytest
from datetime import datetime
from src.models.query import (
    QueryRequest, SqlModeResponse, ResultModeResponse,
    ReturnMode, ErrorDetails
)
from src.models.schema import (
    DataType, ColumnInfo, TableInfo, IndexInfo,
    ForeignKeyInfo, SchemaInfo
)
from src.models.database import DatabaseConfig, ConnectionStatus


class TestQueryModels:
    """查询模型测试套件"""

    def test_query_request_defaults(self):
        """测试查询请求默认参数"""
        req = QueryRequest(query="查询所有用户")
        assert req.return_mode == ReturnMode.SQL
        assert req.database is None
        assert req.parameters is None

    def test_query_request_full(self):
        """测试完整查询请求"""
        req = QueryRequest(
            query="查询活跃用户",
            database="testdb",
            return_mode=ReturnMode.RESULT,
            parameters={"active": True}
        )
        assert req.database == "testdb"
        assert req.return_mode == ReturnMode.RESULT
        assert req.parameters["active"] is True

    def test_sql_mode_response_success(self):
        """测试 SQL 模式成功响应"""
        resp = SqlModeResponse(
            status="success",
            sql="SELECT * FROM users",
            explanation="生成的 SQL 语句已通过安全验证"
        )
        assert resp.mode == "sql"
        assert resp.status == "success"
        assert resp.error is None

    def test_sql_mode_response_error(self):
        """测试 SQL 模式错误响应"""
        resp = SqlModeResponse(
            status="error",
            sql="SELECT * FROM users",
            error="不允许的语句类型: INSERT"
        )
        assert resp.status == "error"
        assert resp.error is not None

    def test_result_mode_response(self):
        """测试结果模式响应"""
        rows = [{"id": 1, "name": "test"}]
        resp = ResultModeResponse(
            status="success",
            sql="SELECT * FROM users",
            rows=rows,
            row_count=1,
            execution_time_ms=15.5,
            validation={"is_valid": True, "reason": ""}
        )
        assert resp.mode == "result"
        assert len(resp.rows) == 1
        assert resp.row_count == 1
        assert resp.execution_time_ms > 0

    def test_error_details(self):
        """测试错误详情模型"""
        error = ErrorDetails(
            code="ERR_001",
            message="无法连接到数据库",
            details={"host": "localhost", "port": 5432}
        )
        assert error.code == "ERR_001"
        assert "5432" in str(error.details)


class TestSchemaModels:
    """Schema 模型测试套件"""

    def test_data_type_enum(self):
        """测试数据类型枚举"""
        assert DataType.INTEGER.value == "INTEGER"
        assert DataType.VARCHAR.value == "VARCHAR"
        assert DataType.TIMESTAMPTZ.value == "TIMESTAMPTZ"
        assert DataType.JSONB.value == "JSONB"

    def test_column_info_defaults(self):
        """测试列信息默认"""
        col = ColumnInfo(name="id", data_type="INTEGER")
        assert col.is_nullable is False
        assert col.is_primary_key is False
        assert col.default_value is None
        assert col.max_length is None

    def test_column_info_full(self):
        """测试完整列信息"""
        col = ColumnInfo(
            name="username",
            data_type="VARCHAR",
            is_nullable=False,
            is_primary_key=False,
            default_value="'guest'",
            max_length=50
        )
        assert col.max_length == 50
        assert col.default_value == "'guest'"

    def test_table_info(self):
        """测试表信息"""
        columns = [
            ColumnInfo(name="id", data_type="INTEGER", is_primary_key=True),
            ColumnInfo(name="name", data_type="VARCHAR", max_length=100)
        ]
        table = TableInfo(
            name="users",
            schema="public",
            columns=columns,
            comment="用户表"
        )
        assert len(table.columns) == 2
        assert table.columns[0].is_primary_key is True
        assert table.comment == "用户表"

    def test_index_info(self):
        """测试索引信息"""
        idx = IndexInfo(
            name="idx_users_email",
            table_name="users",
            columns=["email"],
            is_unique=True,
            definition="CREATE UNIQUE INDEX idx_users_email ON users(email)"
        )
        assert idx.is_unique is True
        assert len(idx.columns) == 1

    def test_foreign_key_info(self):
        """测试外键信息"""
        fk = ForeignKeyInfo(
            name="fk_orders_user",
            columns=["user_id"],
            ref_table="users",
            ref_columns=["id"]
        )
        assert fk.ref_table == "users"
        assert "user_id" in fk.columns

    def test_schema_info(self):
        """测试 Schema 信息"""
        tables = [
            TableInfo(
                name="users",
                schema="public",
                columns=[
                    ColumnInfo(name="id", data_type="INTEGER")
                ]
            )
        ]
        schema = SchemaInfo(
            database="testdb",
            schema="public",
            tables=tables,
            views=["active_users_view"],
            indexes=[],
            foreign_keys=[],
            enums=["user_status"]
        )
        assert schema.database == "testdb"
        assert len(schema.tables) == 1
        assert "active_users_view" in schema.views


class TestDatabaseModels:
    """数据库模型测试套件"""

    def test_database_config(self):
        """测试数据库配置"""
        config = DatabaseConfig(
            name="testdb",
            dsn="postgresql://localhost:5432/testdb",
            ssl=True
        )
        assert config.name == "testdb"
        assert config.ssl is True

    def test_connection_status_success(self):
        """测试连接成功状态"""
        status = ConnectionStatus(
            database="testdb",
            connected=True,
            latency_ms=5.5
        )
        assert status.connected is True
        assert status.latency_ms == 5.5
        assert status.error is None

    def test_connection_status_failure(self):
        """测试连接失败状态"""
        status = ConnectionStatus(
            database="testdb",
            connected=False,
            error="Connection refused"
        )
        assert status.connected is False
        assert status.error == "Connection refused"
```

### 3.3 SQL 验证器测试 (test_sql_validator.py)

**测试文件**: `tests/test_sql_validator.py`

这是最关键的安全测试模块，需要全面覆盖各种攻击场景。

```python
import pytest
from src.services.sql_validator import SQLValidator


class TestSQLValidatorBasic:
    """SQL 验证器基础测试套件"""

    def setup_method(self):
        self.validator = SQLValidator()

    # === 通过测试 (Allowed Queries) ===

    def test_simple_select(self):
        """测试简单 SELECT 语句"""
        sql = "SELECT id, name FROM users WHERE id = 1"
        is_valid, error = self.validator.validate(sql)
        assert is_valid is True
        assert error is None

    def test_select_with_all_columns(self):
        """测试 SELECT * 语句"""
        sql = "SELECT * FROM users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_where_clause(self):
        """测试带 WHERE 子句的 SELECT"""
        sql = "SELECT * FROM users WHERE is_active = true AND created_at > '2024-01-01'"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_like(self):
        """测试 LIKE 查询"""
        sql = "SELECT * FROM users WHERE email LIKE '%@example.com'"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_in_clause(self):
        """测试 IN 子句"""
        sql = "SELECT * FROM users WHERE id IN (1, 2, 3)"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_between(self):
        """测试 BETWEEN 子句"""
        sql = "SELECT * FROM orders WHERE total BETWEEN 10 AND 100"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_join(self):
        """测试 JOIN 查询"""
        sql = """SELECT u.name, o.total
                 FROM users u
                 JOIN orders o ON u.id = o.user_id
                 WHERE o.status = 'completed'"""
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_left_join(self):
        """测试 LEFT JOIN"""
        sql = """SELECT p.name, COUNT(o.id) as order_count
                 FROM products p
                 LEFT JOIN order_items oi ON p.id = oi.product_id
                 LEFT JOIN orders o ON oi.order_id = o.id
                 GROUP BY p.name"""
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_subquery(self):
        """测试子查询"""
        sql = "SELECT * FROM users WHERE id IN (SELECT user_id FROM orders)"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_cte(self):
        """测试 CTE (Common Table Expression)"""
        sql = """WITH active_users AS (
                     SELECT * FROM users WHERE is_active = true
                 )
                 SELECT * FROM active_users"""
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_aggregate(self):
        """测试聚合函数"""
        sql = """SELECT user_id, COUNT(*) as order_count, SUM(total) as total_amount
                 FROM orders
                 GROUP BY user_id
                 HAVING COUNT(*) > 5"""
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_case(self):
        """测试 CASE 表达式"""
        sql = """SELECT name,
                        CASE WHEN status = 'completed' THEN '完成'
                             ELSE '未完成' END as status_text
                 FROM orders"""
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_order_limit(self):
        """测试 ORDER BY 和 LIMIT"""
        sql = "SELECT * FROM users ORDER BY created_at DESC LIMIT 10"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_offset(self):
        """测试 OFFSET"""
        sql = "SELECT * FROM users ORDER BY id LIMIT 10 OFFSET 20"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_distinct(self):
        """测试 DISTINCT"""
        sql = "SELECT DISTINCT status FROM orders"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_case_insensitive_keywords(self):
        """测试关键字大小写不敏感"""
        sql = "SeLeCt id, NaMe FrOm users WhErE id = 1"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_union(self):
        """测试 UNION"""
        sql = "SELECT name FROM users UNION SELECT name FROM admins"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_exists(self):
        """测试 EXISTS"""
        sql = """SELECT * FROM users u
                 WHERE EXISTS (
                     SELECT 1 FROM orders o WHERE o.user_id = u.id
                 )"""
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True


class TestSQLValidatorRejected:
    """SQL 验证器拒绝测试套件 - 安全边界测试"""

    def setup_method(self):
        self.validator = SQLValidator()

    # === 语句类型拒绝 ===

    def test_reject_insert(self):
        """测试拒绝 INSERT"""
        sql = "INSERT INTO users (name) VALUES ('test')"
        is_valid, error = self.validator.validate(sql)
        assert is_valid is False
        assert "INSERT" in error or "不允许" in error

    def test_reject_update(self):
        """测试拒绝 UPDATE"""
        sql = "UPDATE users SET name = 'hacked' WHERE id = 1"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_delete(self):
        """测试拒绝 DELETE"""
        sql = "DELETE FROM users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_drop_table(self):
        """测试拒绝 DROP TABLE"""
        sql = "DROP TABLE users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_truncate(self):
        """测试拒绝 TRUNCATE"""
        sql = "TRUNCATE TABLE users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_alter(self):
        """测试拒绝 ALTER TABLE"""
        sql = "ALTER TABLE users ADD COLUMN new_col VARCHAR(100)"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_create(self):
        """测试拒绝 CREATE TABLE"""
        sql = "CREATE TABLE hackers (id SERIAL PRIMARY KEY)"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_create_index(self):
        """测试拒绝 CREATE INDEX"""
        sql = "CREATE INDEX idx_hack ON users(email)"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_grant(self):
        """测试拒绝 GRANT"""
        sql = "GRANT ALL ON users TO public"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_revoke(self):
        """测试拒绝 REVOKE"""
        sql = "REVOKE ALL ON users FROM public"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_execute(self):
        """测试拒绝 EXECUTE"""
        sql = "EXECUTE my_function()"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_vacuum(self):
        """测试拒绝 VACUUM"""
        sql = "VACUUM ANALYZE users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    # === 注入攻击测试 ===

    def test_reject_cte_injection(self):
        """测试 CTE 注入攻击"""
        sql = "WITH x AS (SELECT * FROM users) DROP TABLE users"
        is_valid, error = self.validator.validate(sql)
        assert is_valid is False
        assert "DROP" in error or "CTE" in error or "禁止" in error

    def test_reject_cte_delete_injection(self):
        """测试 CTE DELETE 注入"""
        sql = "WITH x AS (DELETE FROM users) SELECT * FROM x"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_cte_insert_injection(self):
        """测试 CTE INSERT 注入"""
        sql = "WITH x AS (INSERT INTO users VALUES (1)) SELECT * FROM users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_cte_update_injection(self):
        """测试 CTE UPDATE 注入"""
        sql = "WITH x AS (UPDATE users SET name='hack') SELECT * FROM users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_multiple_statements(self):
        """测试多语句注入"""
        sql = "SELECT * FROM users; DROP TABLE users;"
        is_valid, error = self.validator.validate(sql)
        assert is_valid is False
        assert "多语句" in error or ";" in error

    def test_reject_implicit_multi_statement(self):
        """测试隐式多语句"""
        sql = "SELECT * FROM users WHERE id = 1; DELETE FROM users;"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_comment_hidden_drop(self):
        """测试注释隐藏危险操作"""
        sql = "SELECT * FROM users /* ; DROP TABLE users; */"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_comment_multi_statement(self):
        """测试注释后多语句"""
        sql = "SELECT * FROM users; -- DROP TABLE users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_union_injection(self):
        """测试 UNION 注入 (尝试访问其他表)"""
        sql = "SELECT * FROM users UNION SELECT * FROM pg_password"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_nested_comment(self):
        """测试嵌套注释"""
        sql = "SELECT * FROM users /* /* DROP TABLE */ */"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_semi_colon_after_comment(self):
        """测试注释后分号"""
        sql = "SELECT * FROM users /* comment */; DROP TABLE users;"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    # === 系统表/Schema 访问拒绝 ===

    def test_reject_pg_catalog(self):
        """测试拒绝访问 pg_catalog"""
        sql = "SELECT * FROM pg_catalog.pg_tables"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_pg_password(self):
        """测试拒绝访问 pg_password (敏感表)"""
        sql = "SELECT * FROM pg_password"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_information_schema(self):
        """测试拒绝访问 information_schema"""
        sql = "SELECT * FROM information_schema.tables"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_pg_user(self):
        """测试拒绝访问 pg_user"""
        sql = "SELECT * FROM pg_user"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_pg_shadow(self):
        """测试拒绝访问 pg_shadow (密码哈希)"""
        sql = "SELECT * FROM pg_shadow"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_system_schema(self):
        """测试拒绝系统 Schema"""
        sql = "SELECT schemaname FROM pg_namespace"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False


class TestSQLValidatorEdgeCases:
    """SQL 验证器边界情况测试"""

    def setup_method(self):
        self.validator = SQLValidator()

    def test_empty_sql(self):
        """测试空 SQL"""
        is_valid, error = self.validator.validate("")
        assert is_valid is False
        assert "空" in error or "无效" in error

    def test_whitespace_only(self):
        """测试只有空白的 SQL"""
        is_valid, _ = self.validator.validate("   \t\n  ")
        assert is_valid is False

    def test_only_comment(self):
        """测试只有注释的 SQL"""
        sql = "/* This is a comment */"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_valid_sql_with_leading_comment(self):
        """测试带注释的有效 SQL"""
        sql = "/* 获取用户 */ SELECT * FROM users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_lowercase_select(self):
        """测试小写 select"""
        sql = "select * from users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_mixed_case_keywords(self):
        """测试混合大小写关键字"""
        sql = "SELECT id FROM users WHERE active = true"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_quoted_identifiers(self):
        """测试带引号的标识符"""
        sql = 'SELECT "user-name", "select" FROM "my-table"'
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_numeric_constant(self):
        """测试数值常量"""
        sql = "SELECT * FROM users WHERE id = 1 AND score > 99.5"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_string_with_single_quote(self):
        """测试包含单引号的字符串"""
        sql = "SELECT * FROM users WHERE name = 'O''Brien'"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_string_with_escaped_quotes(self):
        """测试转义引号"""
        sql = "SELECT * FROM users WHERE name = E'\\'hacker\\''"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_parameterized_query_style(self):
        """测试参数化查询风格 (虽然实际不用，但验证不误判)"""
        sql = "SELECT * FROM users WHERE id = :id"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_null_check(self):
        """测试 NULL 检查"""
        sql = "SELECT * FROM users WHERE email IS NULL OR name IS NOT NULL"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_alias_with_as(self):
        """测试带 AS 的别名"""
        sql = "SELECT u.id AS user_id FROM users AS u"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_window_function(self):
        """测试窗口函数"""
        sql = """SELECT id, name,
                        ROW_NUMBER() OVER (PARTITION BY status ORDER BY created_at) as rn
                 FROM orders"""
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_recursive_cte(self):
        """测试递归 CTE"""
        sql = """WITH RECURSIVE cnt(x) AS (
                     SELECT 1
                     UNION ALL
                     SELECT x+1 FROM cnt WHERE x < 10
                 )
                 SELECT * FROM cnt"""
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True


class TestSQLExtractTables:
    """SQL 表名提取测试"""

    def setup_method(self):
        self.validator = SQLValidator()

    def test_extract_single_table(self):
        """测试提取单个表名"""
        tables = self.validator.extract_tables("SELECT * FROM users")
        assert "users" in tables

    def test_extract_multiple_tables(self):
        """测试提取多个表名"""
        sql = "SELECT * FROM users JOIN orders ON users.id = orders.user_id"
        tables = self.validator.extract_tables(sql)
        assert "users" in tables
        assert "orders" in tables

    def test_extract_subquery_tables(self):
        """测试提取子查询中的表"""
        sql = "SELECT * FROM (SELECT * FROM users) AS u"
        tables = self.validator.extract_tables(sql)
        assert "users" in tables

    def test_extract_cte_tables(self):
        """测试提取 CTE 中的表"""
        sql = "WITH active_users AS (SELECT * FROM users) SELECT * FROM active_users"
        tables = self.validator.extract_tables(sql)
        assert "users" in tables
```

### 3.4 服务层测试 (test_services.py)

**测试文件**: `tests/test_services.py`

```python
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from src.services.database import create_pool
from src.services.schema import SchemaService
from src.services.ai_client import AIClient


class TestDatabaseService:
    """数据库服务测试套件"""

    @pytest.mark.asyncio
    async def test_create_pool(self):
        """测试连接池创建"""
        with patch('asyncpg.create_pool') as mock_create:
            mock_pool = AsyncMock()
            mock_create.return_value = mock_pool

            pool = await create_pool("postgresql://localhost:5432/test")

            mock_create.assert_called_once()
            assert pool == mock_pool

    @pytest.mark.asyncio
    async def test_create_pool_with_ssl(self):
        """测试带 SSL 的连接池创建"""
        with patch('asyncpg.create_pool') as mock_create:
            mock_pool = AsyncMock()
            mock_create.return_value = mock_pool

            pool = await create_pool(
                "postgresql://localhost:5432/test",
                ssl=True
            )

            call_kwargs = mock_create.call_args[1]
            assert call_kwargs['ssl'] == 'prefer'

    @pytest.mark.asyncio
    async def test_test_connection_success(self):
        """测试连接成功"""
        with patch('asyncpg.create_pool') as mock_create:
            mock_pool = AsyncMock()
            mock_conn = AsyncMock()
            mock_conn.fetchval = AsyncMock(return_value=1)
            mock_pool.acquire.return_value.__aenter__ = AsyncMock(return_value=mock_conn)
            mock_pool.acquire.return_value.__aexit__ = AsyncMock()
            mock_create.return_value = mock_pool

            result = await test_connection(mock_pool)
            assert result is True

    @pytest.mark.asyncio
    async def test_test_connection_failure(self):
        """测试连接失败"""
        mock_pool = AsyncMock()
        mock_pool.acquire.side_effect = Exception("Connection refused")

        result = await test_connection(mock_pool)
        assert result is False


class TestSchemaService:
    """Schema 服务测试套件"""

    @pytest.mark.asyncio
    async def test_get_schema_info_cached(self):
        """测试缓存的 Schema 信息"""
        mock_pool = AsyncMock()
        mock_conn = AsyncMock()
        mock_conn.fetch = AsyncMock(return_value=[])
        mock_conn.fetchval = AsyncMock(return_value=None)
        mock_pool.acquire.return_value.__aenter__ = AsyncMock(return_value=mock_conn)
        mock_pool.acquire.return_value.__aexit__ = AsyncMock()

        service = SchemaService(mock_pool)

        # 首次加载
        schema1 = await service.get_schema_info()
        assert schema1 is not None

        # 第二次应该使用缓存
        schema2 = await service.get_schema_info(force_refresh=False)
        assert schema2 == schema1

    @pytest.mark.asyncio
    async def test_get_schema_info_force_refresh(self):
        """测试强制刷新 Schema"""
        mock_pool = AsyncMock()
        mock_conn = AsyncMock()
        mock_conn.fetch = AsyncMock(return_value=[])
        mock_conn.fetchval = AsyncMock(return_value=None)
        mock_pool.acquire.return_value.__aenter__ = AsyncMock(return_value=mock_conn)
        mock_pool.acquire.return_value.__aexit__ = AsyncMock()

        service = SchemaService(mock_pool)

        # 首次加载
        await service.get_schema_info()
        call_count = mock_conn.fetch.call_count

        # 强制刷新
        await service.get_schema_info(force_refresh=True)
        assert mock_conn.fetch.call_count > call_count

    def test_format_schema_for_ai(self):
        """测试 Schema 格式化"""
        mock_pool = AsyncMock()
        service = SchemaService(mock_pool)

        schema_info = MagicMock()
        schema_info.tables = [
            MagicMock(
                name="users",
                columns=[
                    MagicMock(name="id", data_type="INTEGER", is_nullable=False, is_primary_key=True),
                    MagicMock(name="name", data_type="VARCHAR", is_nullable=True, is_primary_key=False),
                ]
            )
        ]

        formatted = service.format_schema_for_ai(schema_info)

        assert "表 users" in formatted
        assert "id: INTEGER" in formatted
        assert "primary key" in formatted
        assert "name: VARCHAR" in formatted


class TestAIClient:
    """AI 客户端测试套件"""

    @pytest.mark.asyncio
    async def test_generate_sql(self):
        """测试 SQL 生成"""
        with patch('openai.AsyncOpenAI') as MockClient:
            mock_client = AsyncMock()
            mock_response = MagicMock()
            mock_response.choices = [MagicMock()]
            mock_response.choices[0].message.content = "SELECT * FROM users"
            mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
            MockClient.return_value = mock_client

            client = AIClient(api_key="test-key", model="gpt-4o-mini")
            result = await client.generate_sql(
                schema_info="用户表: id, name",
                user_query="查询所有用户"
            )

            assert result == "SELECT * FROM users"

    @pytest.mark.asyncio
    async def test_generate_sql_error(self):
        """测试 SQL 生成错误处理"""
        with patch('openai.AsyncOpenAI') as MockClient:
            mock_client = AsyncMock()
            mock_response = MagicMock()
            mock_response.choices = [MagicMock()]
            mock_response.choices[0].message.content = "ERROR: 无法生成查询"
            mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
            MockClient.return_value = mock_client

            client = AIClient(api_key="test-key", model="gpt-4o-mini")
            result = await client.generate_sql(
                schema_info="用户表: id, name",
                user_query="invalid query"
            )

            assert result.startswith("ERROR:")

    @pytest.mark.asyncio
    async def test_validate_result_yes(self):
        """测试结果验证 - 通过"""
        with patch('openai.AsyncOpenAI') as MockClient:
            mock_client = AsyncMock()
            mock_response = MagicMock()
            mock_response.choices = [MagicMock()]
            mock_response.choices[0].message.content = "YES - 结果符合查询需求"
            mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
            MockClient.return_value = mock_client

            client = AIClient(api_key="test-key", model="gpt-4o-mini")
            is_valid, reason = await client.validate_result(
                user_query="查询用户",
                sql="SELECT * FROM users",
                result_preview='[{"id": 1}]'
            )

            assert is_valid is True

    @pytest.mark.asyncio
    async def test_validate_result_no(self):
        """测试结果验证 - 不通过"""
        with patch('openai.AsyncOpenAI') as MockClient:
            mock_client = AsyncMock()
            mock_response = MagicMock()
            mock_response.choices = [MagicMock()]
            mock_response.choices[0].message.content = "NO - 返回结果不符合需求"
            mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
            MockClient.return_value = mock_client

            client = AIClient(api_key="test-key", model="gpt-4o-mini")
            is_valid, reason = await client.validate_result(
                user_query="查询用户",
                sql="SELECT * FROM products",  # 错误的表
                result_preview='[{"id": 1}]'
            )

            assert is_valid is False

    @pytest.mark.asyncio
    async def test_generate_sql_with_custom_prompt(self):
        """测试自定义提示词"""
        with patch('openai.AsyncOpenAI') as MockClient:
            mock_client = AsyncMock()
            mock_response = MagicMock()
            mock_response.choices = [MagicMock()]
            mock_response.choices[0].message.content = "SELECT id FROM users"
            mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
            MockClient.return_value = mock_client

            client = AIClient(api_key="test-key", model="gpt-4o-mini")
            custom_prompt = "只返回 ID 列"

            await client.generate_sql(
                schema_info="用户表: id, name",
                user_query="查询用户 ID",
                system_prompt=custom_prompt
            )

            # 验证提示词被使用
            call_args = mock_client.chat.completions.create.call_args
            messages = call_args[1]['messages']
            assert messages[0]['role'] == 'system'
            assert custom_prompt in messages[0]['content']
```

### 3.5 工具层测试 (test_tools.py)

**测试文件**: `tests/test_tools.py`

```python
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from src.tools.query import register_query_tool
from src.tools.explain import register_explain_tool
from src.tools.schema import register_schema_tool


class TestQueryTool:
    """Query 工具测试套件"""

    @pytest.mark.asyncio
    async def test_query_sql_mode(self):
        """测试 SQL 模式查询"""
        # Mock 所有依赖
        mock_pool = AsyncMock()
        mock_schema_service = AsyncMock()
        mock_schema_info = MagicMock()
        mock_schema_info.tables = []
        mock_schema_service.get_schema_info = AsyncMock(return_value=mock_schema_info)
        mock_schema_service.format_schema_for_ai = MagicMock(return_value="")

        mock_ai_client = AsyncMock()
        mock_ai_client.generate_sql = AsyncMock(return_value="SELECT * FROM users")

        mock_validator = MagicMock()
        mock_validator.validate = MagicMock(return_value=(True, None))

        # 由于 FastMCP 工具注册复杂性，这里测试内部逻辑
        # 实际测试需要集成测试环境

    @pytest.mark.asyncio
    async def test_query_result_mode(self):
        """测试结果模式查询"""
        mock_pool = AsyncMock()
        mock_conn = AsyncMock()
        mock_conn.fetch = AsyncMock(return_value=[{"id": 1, "name": "test"}])
        mock_conn.execute = AsyncMock()
        mock_pool.acquire.return_value.__aenter__ = AsyncMock(return_value=mock_conn)
        mock_pool.acquire.return_value.__aexit__ = AsyncMock()

        mock_schema_service = AsyncMock()
        mock_schema_service.get_schema_info = AsyncMock(return_value=MagicMock())

        mock_ai_client = AsyncMock()
        mock_ai_client.generate_sql = AsyncMock(return_value="SELECT * FROM users")
        mock_ai_client.validate_result = AsyncMock(return_value=(True, ""))

        mock_validator = MagicMock()
        mock_validator.validate = MagicMock(return_value=(True, None))


class TestExplainTool:
    """Explain 工具测试套件"""

    @pytest.mark.asyncio
    async def test_explain_success(self):
        """测试解释成功"""
        mock_schema_service = AsyncMock()
        mock_schema_info = MagicMock()
        mock_schema_info.tables = []
        mock_schema_service.get_schema_info = AsyncMock(return_value=mock_schema_info)
        mock_schema_service.format_schema_for_ai = MagicMock(return_value="")

        mock_ai_client = AsyncMock()
        mock_ai_client.generate_sql = AsyncMock(return_value="SELECT * FROM users")

        mock_validator = MagicMock()
        mock_validator.validate = MagicMock(return_value=(True, None))
        mock_validator.extract_tables = MagicMock(return_value=["users"])

        # 测试内部逻辑
        schema_info = await mock_schema_service.get_schema_info()
        sql = await mock_ai_client.generate_sql("", "查询所有用户")
        is_valid, _ = mock_validator.validate(sql)

        assert is_valid is True

    @pytest.mark.asyncio
    async def test_explain_ai_error(self):
        """测试 AI 错误处理"""
        mock_ai_client = AsyncMock()
        mock_ai_client.generate_sql = AsyncMock(return_value="ERROR: 无法理解查询")

        sql = await mock_ai_client.generate_sql("", "invalid")
        assert sql.startswith("ERROR:")


class TestSchemaTool:
    """Schema 工具测试套件"""

    @pytest.mark.asyncio
    async def test_get_schema_summary(self):
        """测试获取 Schema 摘要"""
        mock_schema_service = AsyncMock()
        mock_schema_info = MagicMock()
        mock_table = MagicMock()
        mock_table.name = "users"
        mock_table.columns = [MagicMock(), MagicMock()]
        mock_table.comment = "用户表"
        mock_schema_info.tables = [mock_table]
        mock_schema_info.database = "testdb"
        mock_schema_info.schema = "public"
        mock_schema_service.get_schema_info = AsyncMock(return_value=mock_schema_info)
        mock_schema_service._cache_time = None

        result = await mock_schema_service.get_schema_info()

        assert result == mock_schema_info
        assert len(result.tables) == 1

    @pytest.mark.asyncio
    async def test_get_schema_force_refresh(self):
        """测试强制刷新 Schema"""
        mock_schema_service = AsyncMock()
        mock_schema_service.get_schema_info = AsyncMock(return_value=MagicMock())

        # 强制刷新
        await mock_schema_service.get_schema_info(force_refresh=True)

        mock_schema_service.get_schema_info.assert_called_with(force_refresh=True)
```

---

## 4. 集成测试详细设计

### 4.1 测试文件结构

```
tests/
├── __init__.py
├── conftest.py
├── test_config.py
├── test_models.py
├── test_sql_validator.py
├── test_services.py
├── test_tools.py
└── integration/
    ├── __init__.py
    ├── test_database_integration.py
    ├── test_query_flow.py
    ├── test_schema_flow.py
    └── test_security_integration.py
```

### 4.2 数据库集成测试 (integration/test_database_integration.py)

```python
import pytest
import pytest_asyncio
from src.services.database import create_pool, test_connection
from src.services.schema import SchemaService


# 需要 testcontainers 或本地 PostgreSQL
@pytest_asyncio.fixture
async def db_pool():
    """数据库连接池 fixture"""
    pool = await create_pool(
        "postgresql://postgres:postgres@localhost:5432/testdb",
        min_size=1,
        max_size=5
    )
    yield pool
    await pool.close()


@pytest.mark.asyncio
async def test_db_connection(db_pool):
    """测试数据库连接"""
    assert await test_connection(db_pool) is True


@pytest.mark.asyncio
async def test_basic_query(db_pool):
    """测试基本查询"""
    async with db_pool.acquire() as conn:
        result = await conn.fetchval("SELECT 1")
        assert result == 1


@pytest.mark.asyncio
async def test_schema_loading(db_pool):
    """测试 Schema 加载"""
    service = SchemaService(db_pool)
    schema_info = await service.get_schema_info()

    assert schema_info is not None
    assert schema_info.database == "testdb"
    assert schema_info.schema == "public"


@pytest.mark.asyncio
async def test_schema_cache(db_pool):
    """测试 Schema 缓存"""
    service = SchemaService(db_pool)

    # 首次加载
    schema1 = await service.get_schema_info()

    # 第二次应该命中缓存
    schema2 = await service.get_schema_info(force_refresh=False)

    assert schema1 == schema2


@pytest.mark.asyncio
async def test_schema_force_refresh(db_pool):
    """测试强制刷新 Schema"""
    service = SchemaService(db_pool)

    # 首次加载
    await service.get_schema_info()

    # 强制刷新
    schema = await service.get_schema_info(force_refresh=True)

    assert schema is not None


@pytest.mark.asyncio
async def test_query_execution(db_pool):
    """测试查询执行"""
    async with db_pool.acquire() as conn:
        rows = await conn.fetch("SELECT * FROM users")
        assert len(rows) >= 0


@pytest.mark.asyncio
async def test_transaction_rollback(db_pool):
    """测试事务回滚"""
    async with db_pool.acquire() as conn:
        async with conn.transaction():
            await conn.execute("SELECT 1")
            # 模拟错误，事务应该回滚
            raise Exception("Test rollback")
```

### 4.3 查询流程集成测试 (integration/test_query_flow.py)

```python
import pytest
import pytest_asyncio
from unittest.mock import AsyncMock, patch
from src.services.database import create_pool
from src.services.schema import SchemaService
from src.services.sql_validator import SQLValidator
from src.services.ai_client import AIClient


@pytest_asyncio.fixture
async def pool():
    pool = await create_pool(
        "postgresql://postgres:postgres@localhost:5432/testdb"
    )
    yield pool
    await pool.close()


class TestQueryFlow:
    """完整查询流程测试"""

    @pytest.mark.asyncio
    async def test_natural_language_to_sql_flow(self, pool):
        """测试自然语言转 SQL 完整流程"""
        # 1. 加载 Schema
        schema_service = SchemaService(pool)
        schema_info = await schema_service.get_schema_info()
        schema_text = schema_service.format_schema_for_ai(schema_info)

        assert schema_text != ""
        assert "users" in schema_text

    @pytest.mark.asyncio
    async def test_sql_generation_and_validation_flow(self, pool):
        """测试 SQL 生成和验证流程"""
        schema_service = SchemaService(pool)
        validator = SQLValidator()

        # 模拟 AI 生成的 SQL
        generated_sql = "SELECT * FROM users WHERE is_active = true"

        # 验证 SQL
        is_valid, error = validator.validate(generated_sql)

        assert is_valid is True
        assert error is None

    @pytest.mark.asyncio
    async def test_query_execution_flow(self, pool):
        """测试查询执行流程"""
        async with pool.acquire() as conn:
            # 设置超时
            await conn.execute("SET statement_timeout = '30s'")

            # 执行查询
            rows = await conn.fetch("SELECT * FROM users LIMIT 10")

            # 验证结果
            assert len(rows) <= 10

    @pytest.mark.asyncio
    async def test_result_truncation_flow(self, pool):
        """测试结果截断流程"""
        schema_service = SchemaService(pool)
        validator = SQLValidator()
        max_rows = 100

        async with pool.acquire() as conn:
            # 模拟大量结果
            rows = list(range(200))

            # 截断
            truncated = rows[:max_rows]

            assert len(truncated) == max_rows
            assert len(rows) == 200
```

### 4.4 安全集成测试 (integration/test_security_integration.py)

```python
import pytest
import pytest_asyncio
from src.services.database import create_pool
from src.services.sql_validator import SQLValidator


@pytest_asyncio.fixture
async def pool():
    pool = await create_pool(
        "postgresql://postgres:postgres@localhost:5432/testdb"
    )
    yield pool
    await pool.close()


class TestSecurityIntegration:
    """安全集成测试"""

    @pytest.mark.asyncio
    async def test_rejected_sql_not_executed(self, pool):
        """测试被拒绝的 SQL 不会执行"""
        validator = SQLValidator()
        dangerous_sql = "DROP TABLE users"

        is_valid, error = validator.validate(dangerous_sql)

        assert is_valid is False

        # 尝试执行应该失败
        async with pool.acquire() as conn:
            try:
                await conn.execute(dangerous_sql)
                pytest.fail("Dangerous SQL should not execute")
            except Exception:
                pass  # 预期失败

    @pytest.mark.asyncio
    async def test_cte_injection_protection(self, pool):
        """测试 CTE 注入防护"""
        validator = SQLValidator()

        # CTE 注入尝试
        malicious_sql = "WITH x AS (DELETE FROM users) SELECT * FROM x"

        is_valid, error = validator.validate(malicious_sql)

        assert is_valid is False

    @pytest.mark.asyncio
    async def test_multi_statement_protection(self, pool):
        """测试多语句防护"""
        validator = SQLValidator()

        # 多语句尝试
        malicious_sql = "SELECT * FROM users; DELETE FROM users;"

        is_valid, error = validator.validate(malicious_sql)

        assert is_valid is False

    @pytest.mark.asyncio
    async def test_system_table_access_denied(self, pool):
        """测试系统表访问被拒绝"""
        validator = SQLValidator()

        # 尝试访问系统表
        sql = "SELECT * FROM pg_tables"

        is_valid, error = validator.validate(sql)

        assert is_valid is False
```

---

## 5. E2E 测试详细设计

### 5.1 测试场景

```python
# tests/e2e/test_full_workflow.py
import pytest


class TestE2EWorkflows:
    """端到端工作流测试"""

    def test_complete_query_workflow(self):
        """
        完整查询工作流测试:
        1. 用户发送自然语言查询
        2. AI 生成 SQL
        3. SQL 验证通过
        4. 执行查询
        5. 返回结果
        """
        pass

    def test_explain_workflow(self):
        """
        Explain 工作流测试:
        1. 用户请求解释查询
        2. AI 生成 SQL
        3. 返回 SQL 和分析
        """
        pass

    def test_schema_inspection_workflow(self):
        """
        Schema 检查工作流测试:
        1. 用户请求 Schema 信息
        2. 返回表结构
        """
        pass
```

### 5.2 MCP 协议测试

```python
# tests/e2e/test_mcp_protocol.py
import pytest
from mcp.testing import MCPClient


class TestMCPProtocol:
    """MCP 协议测试"""

    @pytest.fixture
    def mcp_client(self):
        """MCP 客户端 fixture"""
        return MCPClient("python -m src.main")

    def test_query_tool_registration(self, mcp_client):
        """测试 query 工具注册"""
        tools = mcp_client.list_tools()
        assert "query" in [t.name for t in tools]

    def test_explain_tool_registration(self, mcp_client):
        """测试 explain 工具注册"""
        tools = mcp_client.list_tools()
        assert "explain" in [t.name for t in tools]

    def test_schema_tool_registration(self, mcp_client):
        """测试 get_schema 工具注册"""
        tools = mcp_client.list_tools()
        assert "get_schema" in [t.name for t in tools]

    def test_query_tool_execution(self, mcp_client):
        """测试 query 工具执行"""
        result = mcp_client.call_tool("query", {
            "query": "查询所有用户",
            "return_mode": "sql"
        })
        assert result is not None
```

---

## 6. 性能测试

### 6.1 测试场景

```python
# tests/performance/test_performance.py
import pytest
import time


class TestPerformance:
    """性能测试套件"""

    def test_sql_validation_performance(self):
        """SQL 验证性能测试"""
        from src.services.sql_validator import SQLValidator

        validator = SQLValidator()
        sql = "SELECT * FROM users WHERE id = 1"

        # 预热
        for _ in range(10):
            validator.validate(sql)

        # 性能测试
        iterations = 1000
        start = time.time()
        for _ in range(iterations):
            validator.validate(sql)
        elapsed = time.time() - start

        # 验证性能
        assert elapsed < 1.0  # 1000 次验证 < 1 秒
        assert (elapsed / iterations) * 1000 < 1  # 每次 < 1ms

    def test_schema_format_performance(self):
        """Schema 格式化性能测试"""
        from src.services.schema import SchemaService

        # Mock Schema 数据
        mock_pool = None  # Mock
        service = SchemaService(mock_pool)

        # 大量表
        schema_info = MagicMock()
        schema_info.tables = [
            MagicMock(
                name=f"table_{i}",
                columns=[
                    MagicMock(name=f"col_{j}", data_type="INTEGER")
                    for j in range(10)
                ]
            )
            for i in range(100)
        ]

        start = time.time()
        formatted = service.format_schema_for_ai(schema_info)
        elapsed = time.time() - start

        assert elapsed < 1.0
        assert len(formatted) > 0

    @pytest.mark.asyncio
    async def test_concurrent_queries(self):
        """并发查询测试"""
        import asyncio
        from src.services.database import create_pool

        # 创建连接池
        pool = await create_pool(
            "postgresql://localhost:5432/testdb",
            max_size=10
        )

        async def simple_query():
            async with pool.acquire() as conn:
                return await conn.fetchval("SELECT 1")

        # 并发执行
        start = time.time()
        tasks = [simple_query() for _ in range(100)]
        results = await asyncio.gather(*tasks)
        elapsed = time.time() - start

        # 验证
        assert len(results) == 100
        assert all(r == 1 for r in results)
        assert elapsed < 10  # 100 个并发查询 < 10 秒
```

---

## 7. 测试数据管理

### 7.1 测试数据工厂

```python
# tests/factories.py
from factory import Factory, Faker, LazyAttribute
import datetime


class UserFactory(Factory):
    class Meta:
        model = dict

    id = Faker('pyint')
    username = Faker('user_name')
    email = Faker('email')
    created_at = LazyAttribute(lambda _: datetime.datetime.now())


class ProductFactory(Factory):
    class Meta:
        model = dict

    id = Faker('pyint')
    name = Faker('word')
    price = Faker('pydecimal', left_digits=2, right_digits=2, positive=True)
    stock = Faker('pyint', min_value=0, max_value=1000)
```

### 7.2 测试数据 fixtures

```python
# tests/fixtures/data.py
import pytest


@pytest.fixture
def sample_users():
    """示例用户数据"""
    return [
        {"id": 1, "username": "alice", "email": "alice@example.com"},
        {"id": 2, "username": "bob", "email": "bob@example.com"},
        {"id": 3, "username": "charlie", "email": "charlie@example.com"},
    ]


@pytest.fixture
def sample_products():
    """示例产品数据"""
    return [
        {"id": 1, "name": "Widget A", "price": 19.99, "stock": 100},
        {"id": 2, "name": "Widget B", "price": 29.99, "stock": 50},
    ]


@pytest.fixture
def sample_orders():
    """示例订单数据"""
    return [
        {"id": 1, "user_id": 1, "total": 59.97, "status": "completed"},
        {"id": 2, "user_id": 1, "total": 29.99, "status": "pending"},
        {"id": 3, "user_id": 2, "total": 99.98, "status": "completed"},
    ]
```

---

## 8. CI/CD 测试流程

### 8.1 GitHub Actions Workflow

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  unit-test:
    runs-on: ubuntu-latest
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

      - name: Run unit tests
        run: |
          pytest tests/ --ignore=tests/integration --ignore=tests/e2e -v

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.xml

  integration-test:
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

      - name: Run integration tests
        env:
          PG_MCP_POSTGRES_DSN: postgresql://postgres:postgres@localhost:5432/testdb
          PG_MCP_OPENAI_API_KEY: sk-test-key
        run: |
          pytest tests/integration/ -v

  security-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install security tools
        run: |
          pip install safety bandit

      - name: Run security checks
        run: |
          safety check
          bandit -r src/

      - name: Run SQL injection tests
        run: |
          pytest tests/test_sql_validator.py -v --tb=short
```

### 8.2 测试覆盖率要求

```yaml
# .github/workflows/coverage.yml
- name: Check coverage
  run: |
    coverage report --fail-under=80
    coverage json -o coverage.json
```

### 8.3 测试报告配置

```python
# pytest.ini
[tool.pytest.ini_options]
addopts = """
    -v --tb=short
    --strict-markers
    --disable-warnings
    -p no:cacheprovider
    --coverage-report=term-missing
    --junit-xml=test-results.xml
    --html=pytest_report.html
"""
```

---

## 9. 测试覆盖率和质量标准

### 9.1 覆盖率目标

| 模块 | 最低覆盖率 | 目标覆盖率 |
|------|-----------|------------|
| config.py | 90% | 95% |
| models/* | 90% | 95% |
| services/sql_validator.py | 95% | 100% |
| services/schema.py | 80% | 90% |
| services/ai_client.py | 70% | 80% |
| tools/* | 70% | 80% |
| **全局** | **80%** | **85%** |

### 9.2 必须覆盖的场景

#### SQL 验证器必须 100% 覆盖

```python
# test_sql_validator.py 中必须包含
class TestSQLValidatorCritical:
    """
    这些测试用例必须全部通过，一个失败即阻塞发布
    """

    def test_reject_all_dangerous_statements(self):
        """测试所有危险语句类型都被拒绝"""
        dangerous = [
            "INSERT INTO users VALUES (1)",
            "UPDATE users SET name='x'",
            "DELETE FROM users",
            "DROP TABLE users",
            "TRUNCATE users",
            "ALTER TABLE users ADD COLUMN x",
            "CREATE TABLE hackers (id int)",
            "GRANT ALL ON users TO public",
            "REVOKE ALL ON users FROM public",
        ]
        for sql in dangerous:
            is_valid, _ = self.validator.validate(sql)
            assert is_valid is False, f"Should reject: {sql}"

    def test_block_all_injection_patterns(self):
        """测试所有注入模式都被拦截"""
        injections = [
            "WITH x AS (DROP TABLE users) SELECT * FROM x",
            "SELECT * FROM users; DROP TABLE users;",
            "SELECT * FROM users /* DROP TABLE */",
            "SELECT * FROM pg_tables",
        ]
        for sql in injections:
            is_valid, _ = self.validator.validate(sql)
            assert is_valid is False, f"Should block injection: {sql}"

    def test_allow_all_safe_select_patterns(self):
        """测试所有安全 SELECT 模式都通过"""
        safe_queries = [
            "SELECT * FROM users",
            "SELECT id, name FROM users WHERE id = 1",
            "SELECT * FROM users JOIN orders ON users.id = orders.user_id",
            "WITH active AS (SELECT * FROM users) SELECT * FROM active",
            "SELECT COUNT(*) FROM users",
        ]
        for sql in safe_queries:
            is_valid, error = self.validator.validate(sql)
            assert is_valid is True, f"Should allow: {sql}, error: {error}"
```

### 9.3 测试质量检查清单

```
发布前检查清单:
├── [ ] 所有 P0 测试通过
├── [ ] SQL 验证器测试 100% 通过
├── [ ] 安全测试 100% 通过
├── [ ] 单元测试覆盖率 >= 80%
├── [ ] 集成测试通过
├── [ ] 代码通过 lint 检查 (ruff, black, mypy)
├── [ ] 无安全漏洞 (bandit, safety)
├── [ ] 文档已更新
└── [ ] 性能测试通过 (响应时间 < 3s)
```

---

## 10. 测试执行指南

### 10.1 运行所有测试

```bash
# 运行所有测试
pytest

# 运行特定测试文件
pytest tests/test_sql_validator.py

# 运行特定测试类
pytest tests/test_sql_validator.py::TestSQLValidatorRejected

# 运行特定测试方法
pytest tests/test_sql_validator.py::TestSQLValidatorRejected::test_reject_insert

# 带覆盖率
pytest --cov=src --cov-report=term-missing

# 带详细输出
pytest -v --tb=long
```

### 10.2 运行不同级别测试

```bash
# 只运行单元测试
pytest tests/ --ignore=tests/integration --ignore=tests/e2e

# 只运行集成测试
pytest tests/integration/

# 只运行 E2E 测试
pytest tests/e2e/

# 只运行安全测试
pytest tests/test_sql_validator.py -v
```

### 10.3 调试测试

```bash
# 打印 SQL 验证详情
pytest tests/test_sql_validator.py -v -s

# 停止在第一个失败
pytest -x

# 显示本地变量
pytest --tb=locals

# 对比预期与实际
pytest --assert=plain
```

---

## 11. 附录

### 11.1 测试用例速查表

| 测试类型 | 文件 | 优先级 | 预计数量 |
|----------|------|--------|----------|
| 配置测试 | test_config.py | P1 | 12 |
| 模型测试 | test_models.py | P1 | 20 |
| SQL 验证测试 | test_sql_validator.py | P0 | 60 |
| 服务测试 | test_services.py | P1 | 15 |
| 工具测试 | test_tools.py | P1 | 10 |
| 集成测试 | integration/*.py | P1 | 20 |
| E2E 测试 | e2e/*.py | P2 | 5 |
| 性能测试 | performance/*.py | P2 | 5 |

### 11.2 Mock 对象速查

```python
# 常用 Mock fixture
@pytest.fixture
def mock_pool():
    """Mock 数据库连接池"""
    pool = AsyncMock()
    conn = AsyncMock()
    pool.acquire.return_value.__aenter__ = AsyncMock(return_value=conn)
    pool.acquire.return_value.__aexit__ = AsyncMock()
    return pool

@pytest.fixture
def mock_ai_client():
    """Mock AI 客户端"""
    client = AsyncMock()
    client.generate_sql = AsyncMock(return_value="SELECT * FROM users")
    client.validate_result = AsyncMock(return_value=(True, ""))
    return client

@pytest.fixture
def mock_schema_service():
    """Mock Schema 服务"""
    service = AsyncMock()
    service.get_schema_info = AsyncMock(return_value=MagicMock())
    service.format_schema_for_ai = MagicMock(return_value="表 users: id, name")
    return service
```

### 11.3 测试环境变量

```bash
# 测试环境变量配置
export PG_MCP_POSTGRES_DSN="postgresql://postgres@localhost:5432/testdb"
export PG_MCP_OPENAI_API_KEY="sk-test-key-for-unit-tests"
export PG_MCP_OPENAI_MODEL="gpt-4o-mini"
export PG_MCP_MAX_RESULT_ROWS=100
export PG_MCP_QUERY_TIMEOUT=30
```

---

**文档结束**
