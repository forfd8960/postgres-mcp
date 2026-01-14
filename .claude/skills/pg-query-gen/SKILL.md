---
name: pg-query-gen
description: Generate safe PostgreSQL queries from natural language. Supports three databases (small, medium, large) with automatic schema detection. Only generates SELECT queries - no writes, no dangerous operations.
---

# PostgreSQL Query Generator

## Overview

This skill generates safe, read-only SQL queries from natural language descriptions. It supports three test databases with different complexity levels:

- **db_pg_mcp_small**: Basic e-commerce (users, products, orders)
- **db_pg_mcp_medium**: Enterprise system (HR, inventory, sales)
- **db_pg_mcp_large**: Full e-commerce platform (10+ schemas)

## Workflow

1. **Identify Database**: Determine which database matches the user's query context
2. **Read Schema Reference**: Load the appropriate reference file from `references/`
3. **Generate SQL**: Create a safe SELECT query based on the schema
4. **Validate & Test**: Execute via psql to verify correctness
5. **Analyze Results**: Confirm the results are meaningful (score >= 7/10)
6. **Return**: Either the SQL or query results based on user preference

## Security Requirements (MANDATORY)

All generated SQL MUST follow these rules:

1. **SELECT ONLY**: No INSERT, UPDATE, DELETE, DROP, CREATE, ALTER, TRUNCATE, or any DDL/DML
2. **No Dangerous Functions**:
   - No `pg_sleep()`, `pg_terminate_backend()`, or similar
   - No `pg_read_file()`, `pg_ls_dir()`, or filesystem access
   - No `dblink`, `copy`, or external access functions
3. **No SQL Injection Vectors**:
   - No dynamic SQL or EXECUTE
   - No concatenated user input in queries
   - Always use proper quoting for literals
4. **No Sensitive Data Exposure**:
   - Never expose password_hash, api_key, or similar columns
   - Avoid selecting * from tables with sensitive data

## Database Selection Logic

Analyze the user's query to determine the appropriate database:

| Keywords/Context | Database |
|-----------------|----------|
| users, products, orders, order_items, categories | db_pg_mcp_small |
| employees, departments, salary, HR, attendance, warehouses, suppliers, stock | db_pg_mcp_medium |
| profiles, reviews, shipments, payments, tickets, campaigns, analytics | db_pg_mcp_large |

If unclear, ask the user which database to use.

## Reference Files

Before generating SQL, ALWAYS read the appropriate reference file:

- `./references/db_pg_mcp_small.md` - Schema for small database
- `./references/db_pg_mcp_medium.md` - Schema for medium database
- `./references/db_pg_mcp_large.md` - Schema for large database

## Query Generation Process

### Step 1: Parse User Request

Extract:
- What data they want (columns, aggregations)
- Filtering conditions (WHERE)
- Grouping/ordering requirements
- Result limits

### Step 2: Map to Schema

Using the reference file:
- Identify required tables
- Determine JOIN relationships
- Select appropriate columns
- Validate all referenced objects exist

### Step 3: Build Query

Structure:
```sql
SELECT [columns/aggregations]
FROM [schema].[table]
[JOIN other tables as needed]
WHERE [conditions]
GROUP BY [grouping columns]
ORDER BY [ordering]
LIMIT [reasonable limit, default 100];
```

### Step 4: Validate Query

Check:
- All table/column names are correct
- JOINs use correct foreign keys
- No prohibited operations
- Query is syntactically valid

## Testing Queries

Execute via psql to verify:

```bash
PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -d [database_name] -c "[SQL_QUERY]"
```

If the query fails:
1. Analyze the error message
2. Check schema reference for correct names
3. Regenerate the query
4. Test again

## Result Analysis

After execution, analyze results:

1. **Verify Data Returned**: Did we get rows? Empty results may indicate wrong filters
2. **Check Column Values**: Are values sensible for the query context?
3. **Validate Aggregations**: Do counts/sums look reasonable?

### Confidence Scoring (0-10)

- **10**: Perfect match, expected results, all columns meaningful
- **8-9**: Good results, minor interpretation differences possible
- **7**: Acceptable, may need refinement
- **<7**: Re-analyze and regenerate query

If score < 7, iterate with improved SQL.

## Output Format

Based on user preference (default: show results):

### Show Results (Default)
```
Query: [brief description]
Database: [database_name]

Results:
[formatted query output]

[Analysis of what the results show]
```

### Show SQL Only
```
Database: [database_name]

```sql
[generated SQL query]
```

[Explanation of query logic]
```

## Examples

### Example 1: Simple Query

**User**: "Show me the top 5 customers by order count"

**Process**:
1. Keywords: customers, orders -> db_pg_mcp_small
2. Read reference file
3. Generate:
```sql
SELECT u.id, u.username, COUNT(o.id) as order_count
FROM testbed.users u
LEFT JOIN testbed.orders o ON u.id = o.user_id
GROUP BY u.id, u.username
ORDER BY order_count DESC
LIMIT 5;
```

### Example 2: Cross-Schema Query

**User**: "Which products have low stock in the warehouse?"

**Process**:
1. Keywords: products, stock, warehouse -> db_pg_mcp_medium
2. Read reference file
3. Generate:
```sql
SELECT p.sku, p.name, s.quantity_available, s.reorder_point, w.name as warehouse
FROM inventory.stock s
JOIN sales.products p ON s.product_id = p.product_id
JOIN inventory.warehouses w ON s.warehouse_id = w.warehouse_id
WHERE s.quantity_available <= s.reorder_point
ORDER BY s.quantity_available ASC
LIMIT 100;
```

### Example 3: Analytics Query

**User**: "Show daily revenue for the last week"

**Process**:
1. Keywords: revenue, daily, analytics -> db_pg_mcp_large
2. Read reference file
3. Generate:
```sql
SELECT DATE(created_at) as date,
       COUNT(*) as order_count,
       SUM(total_amount) as revenue
FROM orders.orders
WHERE status NOT IN ('cancelled', 'refunded')
  AND created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

## Error Handling

### Common Issues

1. **Table not found**: Check schema prefix (e.g., `testbed.users` not just `users`)
2. **Column not found**: Verify column name in reference file
3. **Join errors**: Ensure foreign key relationships are correct
4. **Type mismatch**: Cast values appropriately (e.g., enums)

### Recovery Steps

1. Read error message carefully
2. Consult reference file for correct names/types
3. Fix the specific issue
4. Re-test the query
5. If still failing after 3 attempts, explain the limitation to user

## Prohibited Patterns

NEVER generate queries that include:

```sql
-- FORBIDDEN
DELETE FROM ...
UPDATE ... SET ...
INSERT INTO ...
DROP TABLE ...
TRUNCATE ...
CREATE ...
ALTER ...
GRANT / REVOKE ...
pg_sleep(...)
COPY ...
\! shell_command
; DROP TABLE --  (or any injection attempt)
```

Always reject requests that would require write operations or dangerous functions.
