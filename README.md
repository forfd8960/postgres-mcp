# pg-mcp: PostgreSQL MCP Server

A Model Context Protocol (MCP) server that enables natural language queries to PostgreSQL databases using AI. Built with FastMCP, asyncpg, SQLGlot, and OpenAI.

## Features

- **Natural Language to SQL**: Convert natural language queries to PostgreSQL SELECT statements
- **SQL Security Validation**: Multi-layer security checks prevent unauthorized operations
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

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `PG_MCP_OPENAI_API_KEY` | Yes | OpenAI API key | - |
| `PG_MCP_OPENAI_MODEL` | No | OpenAI model name | `gpt-4o-mini` |
| `PG_MCP_POSTGRES_DSN` | Yes | PostgreSQL connection string | `postgresql://localhost:5432/postgres` |
| `PG_MCP_MAX_RESULT_ROWS` | No | Max rows to return | `1000` |
| `PG_MCP_QUERY_TIMEOUT` | No | Query timeout (seconds) | `30` |
| `PG_MCP_SCHEMA_CACHE_TTL` | No | Schema cache TTL (seconds) | `3600` |

### Example .env file

```bash
export PG_MCP_OPENAI_API_KEY="sk-your-api-key"
export PG_MCP_OPENAI_MODEL="gpt-4o-mini"
export PG_MCP_POSTGRES_DSN="postgresql://user:pass@localhost:5432/mydb"
export PG_MCP_MAX_RESULT_ROWS=100
export PG_MCP_QUERY_TIMEOUT=30
```

## Usage

### Running the Server

```bash
# Using command line arguments
python -m src.main --dsn "postgresql://..." --api-key "sk-..."

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
  "return_mode": "result",  // or "sql"
  "database": null,
  "parameters": null
}
```

**Parameters:**
- `query` (required): Natural language query description
- `return_mode`: `"sql"` returns SQL only, `"result"` returns query results
- `database`: Optional database name
- `parameters`: Optional query parameters

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
  "format": "summary"  // or "full"
}
```

## Security

The server implements multiple security layers:

1. **Statement Type Restriction**: Only SELECT statements are allowed
2. **Keyword Blocking**: Dangerous keywords (INSERT, UPDATE, DELETE, DROP, etc.) are blocked
3. **System Table Protection**: Access to `pg_*` and `information_schema` is blocked
4. **CTE Injection Prevention**: WITH clause injection attacks are detected
5. **Comment Stripping**: SQL comments are removed before validation
6. **Single Statement Enforcement**: Only one statement per query

## Testing

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=src --cov-report=term-missing

# Run specific test file
pytest tests/test_sql_validator.py -v

# Run integration tests (requires PostgreSQL)
pytest tests/test_integration.py -v -m integration

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
│   │   └── exceptions.py     # Exception classes
│   ├── models/
│   │   ├── query.py          # Query request/response models
│   │   ├── schema.py         # Schema data models
│   │   └── database.py       # Database models
│   ├── services/
│   │   ├── database.py       # Connection pool management
│   │   ├── sql_validator.py  # SQL security validation
│   │   ├── ai_client.py      # OpenAI client
│   │   └── schema.py         # Schema collection service
│   └── tools/
│       ├── query.py          # query MCP tool
│       ├── explain.py        # explain MCP tool
│       └── schema.py         # schema MCP tool
├── tests/
│   ├── test_sql_validator.py # SQL validator tests
│   ├── test_models.py        # Model tests
│   ├── test_config.py        # Configuration tests
│   └── test_integration.py   # Integration tests
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

## License

MIT
