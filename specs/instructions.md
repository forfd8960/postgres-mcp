# Instructions

主要的需求是
    使用 Python 创建一个Postgres的mcp：用户可以给特定自然语言描述的查询的需求，然后mcp server 根据结果来返回一个SQL或者返回这个查询的结果。mcp的服务器在启动的时候，应该读取它都有哪些可以访问的数据库，并且缓存这些数据库的schema：了解每一个数据库下面都有哪些 table/view/types/index 等等，然后根据这些信息以及用户的输入去调用OpenAI的大模型（gpt-5-mini）来生成 SQL。之后mcp server应该来校验这个sql只允许查询的语句然后测试这个sql确保它能够执行并且返回有意义的结果：这里也可以把用户的输入生成的sql以及返回的结果的一部分调用openai来确认这样可以确保它的结果是不是有意义。最后根据用户的输入是返回SQL还是返回SQL查询之后的结果来返回相应的内容根据这些需求帮我构建一个详细的需求文档，先不要著急去做设计，等我review完这个需求文档之后呢我们再来讨论设计，文档放在 ./specs/0001-pg-mcp-prd.md 文件中。


## 构建设计文档

根据 ./specs/0001-pg-mcp-prd.md 文档，使用 FastMCP、Asyncpg、SQLGlot、Pydantic以及openai 构建 pg-mcp 的设计文档，文档放在 ./specs/0002-pg-mcp-design.md 文件中。

## 构建实现

根据 ./specs/0002-pg-mcp-design.md 文档，构建 pg-mcp 的实现计划，think ultra hard，文档放在 ./specs/0003-pg-mcp-impl-plan.md 文件中。

## 实现

根据 ./specs/0003-pg-mcp-impl-plan.md 和 ./specs/0002-pg-mcp-design.md 文档，使用 sub agent 完整实现 pg-mcp phase 0-4。代码放在 当前目录下.

根据 ./specs/0003-pg-mcp-impl-plan.md 和 ./specs/0002-pg-mcp-design.md 文档，使用 sub agent 完整实现 pg-mcp phase 5。代码放在 当前目录下.

## Test Plan

根据 ./specs/0003-pg-mcp-impl-plan.md 和 ./specs/0002-pg-mcp-design.md 文档，构建 pg-mcp 的测试计划，think ultra hard，文档放在 ./specs/0005-pg-mcp-test-plan.md 文件中。

# Test

根据 ./specs/0001-pg-mcp-prd.md 在 ./fixtures 下构建三个有意义的数据库，分别有少量，中等量级，以及大量的 table/view/types/index 等schema，且有足够多的数据。生成这三个数据库的 sql 文件，并构建 Makefile 来重建这些测试数据库。

commit 然后你来建立和测试这几个数据库确保可用  

## Gen Test SQL

根据 ./specs/0005-pg-mcp-test-plan.md 文 and ./specs/0002-pg-mcp-design.md 文档，生成 pg-mcp 的针对三个测试数据库(参考 ./fixtures/ 下的 SQL) 的自然语言查询示例，用于测试 PostgreSQL MCP 服务器的 SQL 生成能力。查询按难度级别（简单→中等→复杂→高级）组织。生成 内容写入 ./fixtures/TEST_QUERIES.md 文件，

case 格式为:
```markdown
* case number: case name
    自然语言：有多少用户？
    期望 SQL：SELECT COUNT(*) FROM users;
```

## Run Test

对于 postgres-mcp，将这个 mcp 添加到 claude code 中，打开一个 claude code headless cli 选择 ./fixtures/TEST_QUERIES.md 下面的某些 query，运行，查看是否调用这个 mcp，结果是否符合预期

直接用本地的 `uvx --from . python -m src.main` 来运行 mcp server

## Build Skills

在当前项目下创建一个新的 skill，要求：

- 1. 首先通过 psql (localhost:5432, postgres, postgres) 探索这几个数据库：db_pg_mcp_small、db_pg_mcp_medium、db_pg_mcp_large，了解它们都有哪些 table/view/types/index 等等，每个数据库生成一个 md 文件，作为 skill 的 reference。
- 2. 用户可以给特定自然语言描述的查询的需求，skill 根据用户输入找到相应的数据库的 reference 文件，然后根据这些信息以及用户的输入来生成正确的 SQL。SQL只允许查询语句，不能有任何的写操作，不能有任何安全漏洞比如 SQL 注入，不能有任何危险的操作比如 sleep，不能有任何的敏感信息比如 API Key 等。
- 3. 使用 psql 测试这个 SQL 确保它能够执行并且返回有意义的结果。如果执行失败，则深度思考，重新生成 SQL，回到第 3 步。
- 4. 把用户的输入生成的 SQL，以及返回的结果的一部分进行分析来确认结果是不是有意义，根据分析打个分数。10分非常 confident，0分非常不 confident。如果小于 7 分，则深度思考，重新生成 SQL，回到第 3 步。
- 5. 最后根据用户的输入是返回 SQL 还是返回 SQL 查询之后的结果（默认）来返回相应的内容

## New Features

- Although multi-database and security control features were promised in the design, they have not actually been enabled: the server always uses a single executor and cannot enforce table/column access restrictions or EXPLAIN policies, which may lead to requests accessing the wrong database, and sensitive objects cannot be protected. 
- Resilience and observability modules (such as rate limiting, retry/backoff mechanisms, metrics/tracing systems) remain only at the design level and have not yet been integrated into the actual request processing workflow. 
- Response/model defects (duplicate to_dict methods, unused configuration fields) and insufficient test coverage have caused the current system behavior to deviate from the implementation plan and made effective verification difficult.

update design and implementation markdown to cover these features, and then implement them step by step.