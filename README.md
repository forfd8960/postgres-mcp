# pg-mcp: PostgreSQL MCP Server

A Model Context Protocol (MCP) server that enables natural language queries to PostgreSQL databases using AI. Built with FastMCP, asyncpg, SQLGlot, and OpenAI.

## Features

- **Natural Language to SQL**: Convert natural language queries to PostgreSQL SELECT statements
- **Multi-Database Support**: Connect to multiple PostgreSQL databases with independent connection pools
- **SQL Security Validation**: Multi-layer security checks prevent unauthorized operations
- **Access Control**: Table-level and column-level access restrictions
- **Rate Limiting**: Sliding window and token bucket rate limiting for API protection
- **Resilience Patterns**: Circuit breaker, retry with exponential backoff, and timeouts
- **Observability**: Metrics collection and request tracing
- **Schema Awareness**: Automatically discovers and caches database schema information
- **Result Validation**: AI-powered validation of query results
- **MCP Protocol**: Fully compatible with MCP clients (Claude Desktop, etc.)

## Tech Stack

| Component | Technology |
|-----------|------------|
| MCP Framework | FastMCP |
| Database Driver | asyncpg |
| SQL Parsing | SQLGlot |
| Data Validation | Pydantic v2 |
| Configuration | pydantic-settings |
| AI Integration | OpenAI SDK |
| Runtime | Python 3.11+ / asyncio |

## Installation

```bash
# Clone the repository
git clone <repository-url>
cd postgres-mcp

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/macOS
# or
.\venv\Scripts\activate   # Windows

# Install dependencies
pip install -e ".[dev]"
```

## Configuration

Configure via environment variables:

### Database Configuration

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `PG_MCP_POSTGRES_DSN` | Yes* | PostgreSQL connection string | `postgresql://localhost:5432/postgres` |
| `PG_MCP_DATABASES` | No | JSON array of database configs (see below) | `[]` |

### OpenAI Configuration

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `PG_MCP_OPENAI_API_KEY` | Yes | OpenAI API key | - |
| `PG_MCP_OPENAI_MODEL` | No | OpenAI model name | `gpt-4o-mini` |
| `PG_MCP_OPENAI_BASE_URL` | No | OpenAI base URL | - |
| `PG_MCP_OPENAI_TIMEOUT` | No | OpenAI timeout (seconds) | `30` |

### Query Configuration

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `PG_MCP_MAX_RESULT_ROWS` | No | Max rows to return | `1000` |
| `PG_MCP_QUERY_TIMEOUT` | No | Query timeout (seconds) | `30` |
| `PG_MCP_SCHEMA_CACHE_TTL` | No | Schema cache TTL (seconds) | `3600` |

### Security Configuration

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `PG_MCP_ALLOWED_STATEMENTS` | No | Comma-separated allowed statement types | `SELECT` |
| `PG_MCP_ENABLE_ACCESS_CONTROL` | No | Enable table/column access control | `false` |
| `PG_MCP_BLOCKED_TABLES` | No | JSON array of blocked table names | `[]` |
| `PG_MCP_BLOCKED_COLUMNS` | No | JSON dict of table -> blocked columns | `{}` |

### Rate Limiting Configuration

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `PG_MCP_RATE_LIMIT_ENABLED` | No | Enable rate limiting | `true` |
| `PG_MCP_RATE_LIMIT_REQUESTS` | No | Max requests per window | `100` |
| `PG_MCP_RATE_LIMIT_WINDOW` | No | Time window (seconds) | `60` |

### Resilience Configuration

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `PG_MCP_RETRY_MAX_ATTEMPTS` | No | Max retry attempts | `3` |
| `PG_MCP_RETRY_BASE_DELAY` | No | Initial delay between retries | `1.0` |
| `PG_MCP_RETRY_MAX_DELAY` | No | Max delay between retries | `60.0` |
| `PG_MCP_RETRY_MULTIPLIER` | No | Delay multiplier | `2.0` |

### Observability Configuration

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `PG_MCP_METRICS_ENABLED` | No | Enable metrics collection | `true` |
| `PG_MCP_TRACING_ENABLED` | No | Enable request tracing | `false` |
| `PG_MCP_LOG_REQUESTS` | No | Log request details | `true` |

### Multi-Database Configuration

For multiple databases, use JSON configuration:

```bash
export PG_MCP_DATABASES='[
  {
    "name": "default",
    "dsn": "postgresql://user:pass@localhost:5432/maindb",
    "pool_min": 1,
    "pool_max": 10,
    "ssl": false
  },
  {
    "name": "analytics",
    "dsn": "postgresql://user:pass@localhost:5432/analytics",
    "pool_min": 2,
    "pool_max": 20,
    "ssl": true
  }
]'
```

### Example .env file

```bash
# OpenAI
export PG_MCP_OPENAI_API_KEY="sk-your-api-key"
export PG_MCP_OPENAI_MODEL="gpt-4o-mini"

# Database
export PG_MCP_POSTGRES_DSN="postgresql://user:pass@localhost:5432/mydb"

# Limits
export PG_MCP_MAX_RESULT_ROWS=100
export PG_MCP_QUERY_TIMEOUT=30

# Security (optional)
export PG_MCP_ENABLE_ACCESS_CONTROL=true
export PG_MCP_BLOCKED_TABLES='["users", "passwords", "credentials"]'
export PG_MCP_BLOCKED_COLUMNS='{"users": ["password", "ssn"]}'

# Rate Limiting
export PG_MCP_RATE_LIMIT_ENABLED=true
export PG_MCP_RATE_LIMIT_REQUESTS=100
export PG_MCP_RATE_LIMIT_WINDOW=60

# Resilience
export PG_MCP_RETRY_MAX_ATTEMPTS=3
export PG_MCP_RETRY_BASE_DELAY=1.0
export PG_MCP_RETRY_MAX_DELAY=60.0
```

## Usage

### Running the Server

```bash
# Using environment variables
python -m src.main

# With Claude Desktop
# Add to your claude_desktop_config.json:
{
  "mcpServers": {
    "postgres": {
      "command": "python",
      "args": ["-m", "src.main"],
      "env": {
        "PG_MCP_OPENAI_API_KEY": "sk-...",
        "PG_MCP_POSTGRES_DSN": "postgresql://..."
      }
    }
  }
}
```

### Available MCP Tools

#### query

Query the database using natural language.

```json
{
  "query": "Find all users who registered in the last week",
  "return_mode": "result",
  "database": null,
  "parameters": null
}
```

**Parameters:**
- `query` (required): Natural language query description
- `return_mode`: `"sql"` returns SQL only, `"result"` returns query results
- `database`: Optional database name (for multi-database setup)
- `parameters`: Optional query parameters for parameterized queries

#### explain

Explain a natural language query and show the generated SQL.

```json
{
  "query": "Count users by status",
  "database": null
}
```

#### get_schema

Get database schema information.

```json
{
  "refresh": false,
  "format": "summary",
  "database": null
}
```

## Security

The server implements multiple security layers:

1. **Statement Type Restriction**: Only SELECT statements are allowed by default
2. **Keyword Blocking**: Dangerous keywords (INSERT, UPDATE, DELETE, DROP, etc.) are blocked
3. **System Table Protection**: Access to `pg_*` and `information_schema` is blocked
4. **CTE Injection Prevention**: WITH clause injection attacks are detected
5. **Comment Stripping**: SQL comments are removed before validation
6. **Single Statement Enforcement**: Only one statement per query
7. **Access Control** (optional):
   - Block specific tables entirely
   - Block specific columns within tables
   - Allow only specific tables/columns

## Rate Limiting

Two rate limiting strategies are available:

### Sliding Window

Counts requests in a rolling time window. Blocks when limit exceeded.

```python
from src.services.rate_limiter import SlidingWindowRateLimiter

limiter = SlidingWindowRateLimiter(
    max_requests=100,    # Max requests per window
    window_seconds=60,   # Time window size
    block_duration=0     # Block duration (0 = no block)
)
```

### Token Bucket

Allows burst traffic up to max burst size while maintaining average rate.

```python
from src.services.rate_limiter import TokenBucketRateLimiter

limiter = TokenBucketRateLimiter(
    rate_per_second=10.0,  # Token refill rate
    max_burst=100          # Max burst size
)
```

## Resilience Patterns

### Circuit Breaker

Prevents cascade failures by temporarily stopping requests to failing services.

```python
from src.services.resilience import CircuitBreaker, CircuitBreakerConfig

config = CircuitBreakerConfig(
    failure_threshold=5,    # Failures before opening
    success_threshold=3,    # Successes in half-open to close
    timeout_seconds=60.0    # Time in open state
)

breaker = CircuitBreaker("database", config)

@breaker
async def risky_operation():
    ...
```

### Retry with Backoff

Automatically retries failed operations with exponential backoff.

```python
from src.services.resilience import with_retry

@with_retry(
    max_attempts=3,
    base_delay=1.0,
    max_delay=60.0,
    multiplier=2.0,
    jitter=True
)
async def unreliable_api_call():
    ...
```

### Timeout

Add timeout protection to operations.

```python
from src.services.resilience import with_timeout

@with_timeout(seconds=30)
async def timed_operation():
    ...
```

## Observability

### Metrics

Collect and aggregate request metrics:

```python
from src.services.metrics import get_metrics_collector

collector = get_metrics_collector()
collector.record_request(
    operation="query",
    success=True,
    duration_ms=150.0,
    error_type=None
)

summary = collector.get_operation_summary("query")
print(summary.avg_duration_ms)
print(summary.success_rate)
```

### Tracing

Track individual requests:

```python
from src.services.metrics import trace_operation

with trace_operation("query", database="default", user_id="123") as trace_id:
    result = await execute_query(...)
    # Metrics and traces automatically recorded
```

## Testing

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=src --cov-report=term-missing

# Run specific test file
pytest tests/test_sql_validator.py -v

# Run security tests
pytest tests/test_security.py -v

# Run resilience tests
pytest tests/test_resilience.py -v

# Run metrics tests
pytest tests/test_metrics.py -v

# Run linters
ruff check src/ tests/
black --check src/ tests/
mypy src/
```

## Project Structure

```
postgres-mcp/
├── src/
│   ├── __init__.py
│   ├── __main__.py           # Entry point
│   ├── main.py               # FastMCP application
│   ├── config.py             # Configuration management
│   ├── utils/
│   │   ├── constants.py      # Error codes
│   │   └── formatting.py     # Output formatting
│   ├── models/
│   │   ├── query.py          # Query request/response models
│   │   ├── schema.py         # Schema data models
│   │   └── database.py       # Database models
│   ├── services/
│   │   ├── __init__.py       # Service exports
│   │   ├── database.py       # Connection pool management
│   │   ├── multi_db.py       # Multi-database pool manager
│   │   ├── sql_validator.py  # SQL security + access control
│   │   ├── ai_client.py      # OpenAI client
│   │   ├── schema.py         # Schema collection service
│   │   ├── rate_limiter.py   # Rate limiting
│   │   ├── resilience.py     # Circuit breaker, retry, timeout
│   │   └── metrics.py        # Metrics and tracing
│   └── tools/
│       ├── __init__.py       # Tool exports
│       ├── query.py          # query MCP tool
│       ├── explain.py        # explain MCP tool
│       └── schema.py         # schema MCP tool
├── tests/
│   ├── __init__.py
│   ├── conftest.py           # Pytest configuration
│   ├── test_sql_validator.py # SQL validator tests
│   ├── test_security.py      # Access control tests
│   ├── test_resilience.py    # Rate limiter, circuit breaker tests
│   ├── test_metrics.py       # Metrics and tracing tests
│   ├── test_models.py        # Model tests
│   ├── test_config.py        # Configuration tests
│   └── test_integration.py   # Integration tests
├── specs/
│   ├── 0001-pg-mcp-prd.md    # Product requirements
│   ├── 0002-pg-mcp-design.md # Technical design
│   └── 0003-pg-mcp-impl-plan.md # Implementation plan
├── pyproject.toml
└── README.md
```

## Error Codes

| Code | Description |
|------|-------------|
| `ERR_001` | Database connection failed |
| `ERR_002` | Schema load failed |
| `ERR_003` | AI service error |
| `ERR_004` | SQL generation failed |
| `ERR_005` | SQL security check failed |
| `ERR_006` | SQL execution failed |
| `ERR_007` | Result validation failed |
| `ERR_008` | Invalid request |
| `ERR_009` | Rate limit exceeded |
| `ERR_010` | Query timeout |

## License

MIT
