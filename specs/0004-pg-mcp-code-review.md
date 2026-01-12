# pg-mcp Code Review (against 0002 design & 0003 impl plan)

## Summary
- Overall structure follows the planned layering (config → models → services → tools → main) and basic safety checks are in place via `SQLValidator`.
- Key gaps: parameterized execution is not wired, the result-validation toggle is ignored, schema models diverge from the design, and the MCP app lifecycle/context usage is unfinished.

## Findings
1. **High – Parameters ignored, raw SQL executed**: The `query` tool accepts `parameters` but never binds them; SQL is executed as a raw string, so callers cannot safely pass values and the design goal of parameterized execution is unmet. This also violates the impl plan step “使用 asyncpg 参数化执行”. See [src/tools/query.py#L35-L183](src/tools/query.py#L35-L183).
2. **Medium – Result validation toggle unused**: `enable_result_validation` in settings is not honored; result validation runs unconditionally in `_execute_and_validate`, diverging from the config contract in the design doc. See [src/config.py#L31-L37](src/config.py#L31-L37) and [src/tools/query.py#L155-L168](src/tools/query.py#L155-L168).
3. **Medium – Schema model field mismatch**: The design specifies a `schema` field, but models expose `schema_name` (with alias). Attribute access via `.schema` now fails (tests and design examples still use `.schema`). This breaks backward compatibility with the spec and current tests. See [src/models/schema.py#L45-L85](src/models/schema.py#L45-L85) and usage in [tests/test_models.py#L58-L86](tests/test_models.py#L58-L86).
4. **Medium – Schema service caching gaps**: `get_schema_info` returns cached entries without per-database isolation and may return `None` when a specific database key was never cached; `_cache_time` is global, so TTL applies across databases. Also, views/enums are never populated though the model exposes them. See [src/services/schema.py#L33-L137](src/services/schema.py#L33-L137) and [src/services/schema.py#L180-L214](src/services/schema.py#L180-L214).
5. **Medium – MCP lifecycle/context not aligned with design**: The design/plan expects tools to be registered within a FastMCP lifespan/context; `create_mcp_app` is unused and tools are registered in `run_server` without using `mcp.context`. This leaves dead code and diverges from the recommended pattern in the impl plan. See [src/main.py#L65-L83](src/main.py#L65-L83) and [src/main.py#L129-L173](src/main.py#L129-L173).
6. **Low – OpenAI key treated as optional**: `openai_api_key` defaults to an empty string, contrary to the design requirement that it is mandatory. This can delay failures to runtime. See [src/config.py#L20-L24](src/config.py#L20-L24).
7. **Low – Query timeout and row limit enforcement**: Timeouts are set via a string `SET LOCAL` and row limits are enforced only client-side; the plan called for explicit limiting. Consider applying `LIMIT` or slicing via SQL to reduce server-side load. See [src/tools/query.py#L135-L168](src/tools/query.py#L135-L168).
8. **Info – Missing view/enum collection**: `SchemaService` does not collect views or enum types though the models expose them, so AI context may be incomplete. See [src/services/schema.py#L33-L214](src/services/schema.py#L33-L214).

## Recommendations
- Wire parameter binding through to asyncpg (`conn.fetch(sql, *params)` with placeholders) and refuse execution if parameters are provided but not bound.
- Respect `enable_result_validation` and short-circuit AI validation when disabled.
- Restore `schema` as the public attribute (keep alias if needed) or add property accessors to preserve spec-compatibility and unblock tests.
- Rework `SchemaService` cache to be keyed per database with a per-key TTL, and populate views/enums or drop them from the model if out of scope.
- Consolidate startup: use `create_mcp_app` with `context_lifespan_factory` and register tools within the FastMCP context per the design/plan.
- Make `openai_api_key` required (no empty default) to fail fast on misconfiguration.
- Enforce row limits and timeouts at the SQL layer where feasible.
