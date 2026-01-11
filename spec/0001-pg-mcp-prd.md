# Postgres MCP Server 产品需求文档

**文档版本**: v1.0
**创建日期**: 2026-01-10
**文档编号**: 0001-pg-mcp-prd

---

## 1. 项目概述

### 1.1 背景

本项目旨在使用 Python 实现一个 MCP (Model Context Protocol) 服务器，为用户提供基于自然语言的 PostgreSQL 数据库查询能力。用户可以通过自然语言描述查询需求，MCP 服务器将根据需求生成对应的 SQL 查询语句，并返回 SQL 语句本身或查询结果。

### 1.2 项目目标

- 构建一个轻量级、可扩展的 PostgreSQL MCP 服务器
- 支持自然语言到 SQL 的智能转换
- 提供安全的查询执行机制
- 确保返回结果的准确性和完整性

### 1.3 目标用户

- 数据分析师：需要快速查询数据库但对 SQL 语法不熟悉
- 开发人员：需要快速验证数据查询逻辑
- 产品经理：需要自助获取业务数据

---

## 2. 功能需求

### 2.1 核心功能

#### FR-001: 自然语言查询转 SQL

**描述**: 用户输入自然语言描述的查询需求，系统将其转换为有效的 PostgreSQL 查询语句。

**输入**:
- 自然语言查询描述（中文/英文）
- 数据库上下文信息

**输出**:
- 生成的 SQL 语句

**触发条件**: 用户发送查询请求

#### FR-002: SQL 查询执行

**描述**: 在验证生成的 SQL 仅包含 SELECT 语句后，执行查询并返回结果。

**输入**:
- 验证通过的 SQL 语句

**输出**:
- 查询结果集（JSON 格式）

**触发条件**: 用户请求返回查询结果而非 SQL 本身

#### FR-003: 返回模式选择

**描述**: 根据用户请求，返回 SQL 语句或执行查询后的结果。

**输入**: 用户请求（指定返回类型）

**输出**:
- 模式 A: 仅返回 SQL 语句
- 模式 B: 返回 SQL 执行结果

---

### 2.2 系统功能

#### FR-004: 数据库发现与连接

**描述**: MCP 服务器启动时，自动发现并连接配置的 PostgreSQL 数据库。

**功能要求**:
- 读取数据库连接配置
- 验证数据库连接有效性
- 支持多个数据库实例

#### FR-005: Schema 信息缓存

**描述**: 服务器启动时，收集并缓存所有可访问数据库的 Schema 信息。

**缓存内容**:
- 数据库名称
- 表结构（表名、列名、数据类型、约束）
- 视图定义
- 自定义类型（ENUM、COMPOSITE 等）
- 索引信息
- 外键关系

**缓存更新机制**:
- 启动时全量加载
- 支持手动刷新缓存

#### FR-006: SQL 安全性验证

**描述**: 验证生成的 SQL 仅包含安全的查询操作。

**验证规则**:
- 仅允许 SELECT 语句
- 拒绝 INSERT、UPDATE、DELETE、DROP、TRUNCATE 等修改性操作
- 拒绝 WITH xx DROP 类型的恶意注入

#### FR-007: SQL 语法验证

**描述**: 确保生成的 SQL 语句语法正确，能够在目标数据库上执行。

**验证方式**:
- 执行 EXPLAIN 或 EXPLAIN ANALYZE
- 捕获并处理语法错误

#### FR-008: 查询结果验证

**描述**: 使用 AI 验证返回结果是否符合用户查询意图。

**验证内容**:
- 结果是否为空
- 结果是否包含有效数据
- 结果是否符合查询语义

---

## 3. 非功能需求

### 3.1 性能需求

| 指标 | 要求 |
|------|------|
| 启动时间 | < 5 秒（包含 Schema 缓存） |
| SQL 生成响应时间 | < 3 秒 |
| 结果验证时间 | < 2 秒 |
| Schema 缓存大小 | 依据数据库规模，支持至少 1000+ 表 |

### 3.2 安全需求

| 需求 ID | 描述 |
|---------|------|
| SEC-001 | 不允许执行任何修改数据的 SQL |
| SEC-002 | 数据库连接凭证安全存储 |
| SEC-003 | SQL 注入防护 |
| SEC-004 | 查询超时保护（建议 30 秒） |
| SEC-005 | 返回结果条数限制（建议最多 1000 条） |

### 3.3 可靠性需求

| 需求 ID | 描述 |
|---------|------|
| REL-001 | 数据库连接断开时自动重试（最多 3 次） |
| REL-002 | Schema 缓存加载失败时记录日志并继续启动 |
| REL-003 | AI 服务不可用时返回错误信息 |

### 3.4 可扩展性需求

| 需求 ID | 描述 |
|---------|------|
| EXT-001 | 支持添加新的数据库配置 |
| EXT-002 | 支持更换 AI 模型提供商 |
| EXT-003 | 支持自定义系统提示词 |

---

## 4. 技术需求

### 4.1 AI 模型集成

#### TR-001: OpenAI GPT 模型

| 配置项 | 值 |
|--------|-----|
| 模型名称 | gpt-5-mini（建议使用 gpt-4o-mini 或 gpt-3.5-turbo） |
| API 调用方式 | OpenAI Chat Completion API |
| 输入 | 用户自然语言 + Schema 描述 |
| 输出 | 结构化 SQL 语句 |

#### TR-002: AI 提示词设计

**SQL 生成提示词模板**:
```
你是一个 PostgreSQL 专家。用户想要查询数据库。

可用的数据库 Schema 信息:
{schema_info}

用户的查询需求: {user_query}

请生成对应的 PostgreSQL SELECT 语句。只返回 SQL 代码，不要其他解释。
如果无法生成有效的查询，返回 "ERROR: {原因}"
```

**结果验证提示词模板**:
```
用户原始需求: {user_query}

生成的 SQL: {sql}

查询结果: {result_preview}

请判断这个结果是否符合用户的查询需求？
只回答 "YES" 或 "NO"，以及简短的原因。
```

### 4.2 数据库支持

#### TR-003: PostgreSQL 版本支持

| 版本 | 支持状态 |
|------|----------|
| PostgreSQL 12 | 测试验证 |
| PostgreSQL 13 | 测试验证 |
| PostgreSQL 14 | 测试验证 |
| PostgreSQL 15 | 测试验证 |
| PostgreSQL 16 | 测试验证 |
| PostgreSQL 17 | 测试验证 |

#### TR-004: Schema 信息收集

**SQL 模板**:

```sql
-- 获取所有表信息
SELECT table_name, table_schema
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog', 'information_schema');

-- 获取表结构信息
SELECT
    c.table_name,
    c.column_name,
    c.data_type,
    c.is_nullable,
    c.column_default,
    c.character_maximum_length
FROM information_schema.columns c
WHERE c.table_schema = '{schema}'
ORDER BY c.ordinal_position;

-- 获取索引信息
SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = '{schema}';

-- 获取外键关系
SELECT
    conname,
    pg_get_constraintdef(oid)
FROM pg_constraint
WHERE contype = 'f'
AND connamespace = (SELECT oid FROM pg_namespace WHERE nspname = '{schema}');
```

### 4.3 MCP 协议支持

#### TR-005: MCP Server 实现

- 遵循 MCP 协议规范
- 实现标准 MCP 工具接口
- 支持 MCP SSE（Server-Sent Events）传输

---

## 5. 配置需求

### 5.1 环境变量配置

| 变量名 | 必填 | 描述 | 示例 |
|--------|------|------|------|
| POSTGRES_DSN | 是 | 数据库连接字符串 | postgresql://user:pass@localhost:5432/db |
| OPENAI_API_KEY | 是 | OpenAI API 密钥 | sk-xxx |
| OPENAI_MODEL | 否 | 使用的模型名称 | gpt-4o-mini |
| MAX_RESULT_ROWS | 否 | 最大返回行数 | 1000 |
| QUERY_TIMEOUT | 否 | 查询超时时间（秒） | 30 |
| SCHEMA_CACHE_TTL | 否 | Schema 缓存时间（秒） | 3600 |

### 5.2 数据库连接配置

**支持的连接方式**:
- 标准连接字符串（DSN）
- 环境变量分离配置（PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD）
- SSL/TLS 支持

---

## 6. 输入输出规格

### 6.1 输入规格

#### 工具调用输入

```typescript
interface QueryInput {
  // 自然语言查询描述
  query: string;
  // 可选：指定数据库名称（默认为主数据库）
  database?: string;
  // 可选：返回模式
  returnMode: 'sql' | 'result';
  // 可选：查询参数（用于 SQL 注入防护）
  parameters?: Record<string, any>;
}
```

### 6.2 输出规格

#### SQL 模式输出

```typescript
interface SqlModeOutput {
  status: 'success' | 'error';
  mode: 'sql';
  sql: string;
  explanation?: string;
  error?: string;
}
```

#### 结果模式输出

```typescript
interface ResultModeOutput {
  status: 'success' | 'error';
  mode: 'result';
  sql: string;
  rows: Array<Record<string, any>>;
  rowCount: number;
  executionTime: number; // 毫秒
  validation?: {
    isValid: boolean;
    reason?: string;
  };
  error?: string;
}
```

---

## 7. 错误处理

### 7.1 错误类型

| 错误码 | 错误类型 | 描述 |
|--------|----------|------|
| ERR_001 | 数据库连接失败 | 无法连接到配置的数据库 |
| ERR_002 | Schema 加载失败 | 无法加载数据库 Schema 信息 |
| ERR_003 | AI 服务错误 | OpenAI API 调用失败 |
| ERR_004 | SQL 生成失败 | 无法根据用户输入生成 SQL |
| ERR_005 | SQL 安全验证失败 | 生成的 SQL 包含不允许的操作 |
| ERR_006 | SQL 执行失败 | SQL 语法错误或执行超时 |
| ERR_007 | 结果验证失败 | AI 认为结果不符合用户需求 |
| ERR_008 | 无效请求 | 输入参数不完整或格式错误 |

### 7.2 错误响应格式

```json
{
  "status": "error",
  "error": {
    "code": "ERR_XXX",
    "message": "人类可读的错误描述",
    "details": {} // 可选的调试信息
  }
}
```

---

## 8. 限制与约束

### 8.1 功能限制

| 限制项 | 描述 |
|--------|------|
| 仅支持 SELECT | 不支持任何数据修改操作 |
| 单表/多表查询 | 支持 JOIN 操作，但限制最多 5 表联查 |
| 聚合查询 | 支持 COUNT、SUM、AVG、MAX、MIN 等 |
| 子查询 | 支持标准子查询语法 |
| 复杂查询 | 限制使用 CTEs（WITH 子句） |

### 8.2 安全约束

- **禁止**: 任何形式的 DML 操作（INSERT、UPDATE、DELETE）
- **禁止**: DDL 操作（CREATE、DROP、ALTER）
- **禁止**: 事务控制语句（BEGIN、COMMIT、ROLLBACK）
- **禁止**: 权限控制语句（GRANT、REVOKE）
- **禁止**: 系统表/函数访问

---

## 9. 验收标准

### 9.1 功能验收标准

- [ ] 服务器能够正常启动并加载所有配置数据库的 Schema
- [ ] 根据自然语言查询能够生成有效的 PostgreSQL SELECT 语句
- [ ] 生成的 SQL 能够通过安全性检查
- [ ] 执行的 SQL 能够返回正确的结果
- [ ] AI 能够验证返回结果的合理性
- [ ] 能够根据用户请求返回 SQL 或查询结果

### 9.2 性能验收标准

- [ ] 启动时间 < 5 秒
- [ ] SQL 生成时间 < 3 秒
- [ ] 验证通过后执行时间 < 10 秒

### 9.3 安全验收标准

- [ ] 无法执行任何非 SELECT 语句
- [ ] SQL 注入尝试被正确拦截
- [ ] 查询结果限制生效

---

## 10. 未来扩展方向

### 10.2 潜在功能

| 功能 | 优先级 | 描述 |
|------|--------|------|
| 多数据库支持 | P0 | 支持连接多个 PostgreSQL 数据库 |
| 缓存优化 | P1 | 支持 Schema 增量更新 |
| 结果格式化 | P1 | 支持多种输出格式（CSV、Markdown） |
| 查询历史 | P2 | 记录用户查询历史 |
| 自定义规则 | P2 | 支持配置 SQL 生成规则 |
| 多模型支持 | P3 | 支持 Claude、Gemini 等其他 AI 模型 |

---

## 11. 术语表

| 术语 | 定义 |
|------|------|
| MCP | Model Context Protocol，模型上下文协议 |
| DSN | Data Source Name，数据源名称 |
| Schema | 数据库模式，包含表、视图、类型等结构定义 |
| LLM | Large Language Model，大语言模型 |
| DML | Data Manipulation Language，数据操作语言 |
| DDL | Data Definition Language，数据定义语言 |

---

## 12. 附录

### 12.1 参考资料

- [MCP Protocol Specification](https://spec.modelcontextprotocol.io/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [OpenAI API Documentation](https://platform.openai.com/docs)

### 12.2 相关文档

- `./spec/instructions.md` - 原始需求说明
- `./spec/0002-pg-mcp-arch.md` - 架构设计文档（待创建）

---

**文档结束**
