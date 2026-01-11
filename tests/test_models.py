# tests/test_models.py
"""Tests for data models."""

import pytest
from src.models.query import (
    QueryRequest,
    SqlModeResponse,
    ResultModeResponse,
    ReturnMode,
)
from src.models.schema import (
    ColumnInfo,
    TableInfo,
    IndexInfo,
    ForeignKeyInfo,
    SchemaInfo,
    DataType,
)
from src.models.database import DatabaseConfig, ConnectionStatus


class TestQueryModels:
    """Query model tests."""

    def test_query_request_defaults(self):
        """Test QueryRequest default values."""
        req = QueryRequest(query="test query")
        assert req.return_mode.value == "sql"
        assert req.database is None
        assert req.parameters is None

    def test_query_request_full(self):
        """Test QueryRequest with all fields."""
        req = QueryRequest(
            query="find users",
            database="mydb",
            return_mode=ReturnMode.RESULT,
            parameters={"limit": 10}
        )
        assert req.query == "find users"
        assert req.database == "mydb"
        assert req.return_mode == ReturnMode.RESULT
        assert req.parameters == {"limit": 10}

    def test_sql_mode_response_success(self):
        """Test SqlModeResponse success."""
        resp = SqlModeResponse(
            status="success",
            sql="SELECT * FROM users"
        )
        assert resp.mode == "sql"
        assert resp.error is None
        assert resp.explanation is None

    def test_sql_mode_response_with_explanation(self):
        """Test SqlModeResponse with explanation."""
        resp = SqlModeResponse(
            status="success",
            sql="SELECT * FROM users",
            explanation="Generated SQL"
        )
        assert resp.explanation == "Generated SQL"

    def test_sql_mode_response_error(self):
        """Test SqlModeResponse error."""
        resp = SqlModeResponse(
            status="error",
            sql="",
            error="Invalid query"
        )
        assert resp.status == "error"
        assert resp.error == "Invalid query"

    def test_result_mode_response(self):
        """Test ResultModeResponse."""
        resp = ResultModeResponse(
            status="success",
            sql="SELECT * FROM users",
            rows=[{"id": 1, "name": "test"}],
            row_count=1,
            execution_time_ms=10.5
        )
        assert resp.mode == "result"
        assert resp.row_count == 1
        assert len(resp.rows) == 1

    def test_result_mode_response_with_validation(self):
        """Test ResultModeResponse with validation."""
        resp = ResultModeResponse(
            status="success",
            sql="SELECT * FROM users",
            rows=[{"id": 1}],
            validation={"is_valid": True, "reason": "Looks good"}
        )
        assert resp.validation is not None
        assert resp.validation["is_valid"] is True


class TestSchemaModels:
    """Schema model tests."""

    def test_column_info_basic(self):
        """Test ColumnInfo basic fields."""
        col = ColumnInfo(name="id", data_type="INTEGER")
        assert col.name == "id"
        assert col.data_type == "INTEGER"
        assert col.is_nullable is False
        assert col.is_primary_key is False

    def test_column_info_full(self):
        """Test ColumnInfo with all fields."""
        col = ColumnInfo(
            name="email",
            data_type="VARCHAR",
            is_nullable=True,
            is_primary_key=False,
            default_value="''",
            max_length=255
        )
        assert col.is_nullable is True
        assert col.max_length == 255

    def test_table_info(self):
        """Test TableInfo."""
        col = ColumnInfo(name="id", data_type="INTEGER", is_primary_key=True)
        table = TableInfo(
            name="users",
            schema="public",
            columns=[col],
            comment="User table"
        )
        assert len(table.columns) == 1
        assert table.columns[0].is_primary_key is True
        assert table.comment == "User table"

    def test_index_info(self):
        """Test IndexInfo."""
        idx = IndexInfo(
            name="idx_users_email",
            table_name="users",
            columns=["email"],
            is_unique=False,
            definition="CREATE INDEX idx_users_email ON users(email)"
        )
        assert idx.is_unique is False
        assert "email" in idx.columns

    def test_foreign_key_info(self):
        """Test ForeignKeyInfo."""
        fk = ForeignKeyInfo(
            name="fk_orders_user",
            columns=["user_id"],
            ref_table="users",
            ref_columns=["id"]
        )
        assert fk.columns == ["user_id"]
        assert fk.ref_table == "users"

    def test_schema_info(self):
        """Test SchemaInfo."""
        col = ColumnInfo(name="id", data_type="INTEGER")
        table = TableInfo(name="users", schema="public", columns=[col])
        schema = SchemaInfo(
            database="mydb",
            schema="public",
            tables=[table],
            views=["user_view"],
            indexes=[],
            foreign_keys=[],
            enums=["user_status"]
        )
        assert schema.database == "mydb"
        assert len(schema.tables) == 1
        assert "user_view" in schema.views
        assert "user_status" in schema.enums

    def test_data_type_enum(self):
        """Test DataType enum values."""
        assert DataType.INTEGER.value == "INTEGER"
        assert DataType.VARCHAR.value == "VARCHAR"
        assert DataType.TIMESTAMP.value == "TIMESTAMP"
        assert DataType.JSONB.value == "JSONB"


class TestDatabaseModels:
    """Database model tests."""

    def test_database_config(self):
        """Test DatabaseConfig."""
        config = DatabaseConfig(
            name="mydb",
            dsn="postgresql://localhost:5432/mydb",
            ssl=True
        )
        assert config.name == "mydb"
        assert config.ssl is True

    def test_connection_status_success(self):
        """Test ConnectionStatus success."""
        status = ConnectionStatus(
            database="mydb",
            connected=True,
            latency_ms=10.5
        )
        assert status.connected is True
        assert status.latency_ms == 10.5

    def test_connection_status_error(self):
        """Test ConnectionStatus error."""
        status = ConnectionStatus(
            database="mydb",
            connected=False,
            error="Connection refused"
        )
        assert status.connected is False
        assert status.error == "Connection refused"
