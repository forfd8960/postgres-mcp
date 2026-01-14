"""Tests for SQL validator with access control."""

import pytest
from src.services.sql_validator import SQLValidator


class TestSQLValidatorAccessControl:
    """Tests for SQL validator table/column access control."""

    def setup_method(self):
        """Set up test fixtures."""
        pass

    def test_valid_select_without_access_control(self):
        """Test that valid SELECT works without access control."""
        validator = SQLValidator()
        is_valid, error, details = validator.validate(
            "SELECT id, name FROM users WHERE id = 1"
        )
        assert is_valid is True
        assert error is None
        assert details is not None
        assert len(details["tables"]) > 0

    def test_blocks_table_with_blocked_tables(self):
        """Test that blocked tables are rejected."""
        validator = SQLValidator(blocked_tables={"users", "passwords"})
        is_valid, error, details = validator.validate(
            "SELECT * FROM users"
        )
        assert is_valid is False
        assert "users" in error.lower()

    def test_blocks_column_with_blocked_columns(self):
        """Test that blocked columns are rejected."""
        validator = SQLValidator(
            blocked_columns={"users": {"password", "ssn"}}
        )
        is_valid, error, details = validator.validate(
            "SELECT id, password FROM users"
        )
        assert is_valid is False
        assert "password" in error.lower()

    def test_allows_unblocked_columns(self):
        """Test that unblocked columns are allowed."""
        validator = SQLValidator(
            blocked_columns={"users": {"password"}}
        )
        is_valid, error, details = validator.validate(
            "SELECT id, name FROM users"
        )
        assert is_valid is True

    def test_allows_table_with_allowed_tables(self):
        """Test that only allowed tables are accessible."""
        validator = SQLValidator(allowed_tables={"products", "orders"})
        is_valid, error, details = validator.validate(
            "SELECT * FROM products"
        )
        assert is_valid is True

    def test_blocks_table_not_in_allowed_list(self):
        """Test that tables not in allowed list are blocked."""
        validator = SQLValidator(allowed_tables={"products"})
        is_valid, error, details = validator.validate(
            "SELECT * FROM users"
        )
        assert is_valid is False
        assert "未授权" in error or "not authorized" in error.lower()

    def test_blocks_column_not_in_allowed_list(self):
        """Test that columns not in allowed list are blocked."""
        validator = SQLValidator(
            allowed_columns={"users": {"id", "name"}}
        )
        is_valid, error, details = validator.validate(
            "SELECT id, password FROM users"
        )
        assert is_valid is False
        assert "password" in error.lower() or "未授权" in error

    def test_extracts_table_details(self):
        """Test that table information is extracted correctly."""
        validator = SQLValidator()
        is_valid, error, details = validator.validate(
            "SELECT u.id, o.total FROM users u JOIN orders o ON u.id = o.user_id"
        )
        assert is_valid is True
        tables = {t["name"].lower() for t in details["tables"]}
        assert "users" in tables
        assert "orders" in tables

    def test_extracts_column_details(self):
        """Test that column information is extracted correctly."""
        validator = SQLValidator()
        is_valid, error, details = validator.validate(
            "SELECT id, name, price FROM products"
        )
        assert is_valid is True
        columns = {c["name"].lower() for c in details["columns"]}
        assert "id" in columns
        assert "name" in columns
        assert "price" in columns

    def test_blocks_system_tables(self):
        """Test that system tables are blocked."""
        validator = SQLValidator()
        is_valid, error, details = validator.validate(
            "SELECT * FROM pg_tables"
        )
        assert is_valid is False
        assert "系统表" in error or "information_schema" in error.lower()

    def test_set_blocked_tables_runtime(self):
        """Test updating blocked tables at runtime."""
        validator = SQLValidator()
        validator.set_blocked_tables({"users", "orders"})

        is_valid, error, _ = validator.validate(
            "SELECT * FROM users"
        )
        assert is_valid is False

        is_valid, error, _ = validator.validate(
            "SELECT * FROM products"
        )
        assert is_valid is True

    def test_set_blocked_columns_runtime(self):
        """Test updating blocked columns at runtime."""
        validator = SQLValidator()
        validator.set_blocked_columns({"users": {"password"}})

        is_valid, error, _ = validator.validate(
            "SELECT password FROM users"
        )
        assert is_valid is False

        is_valid, error, _ = validator.validate(
            "SELECT name FROM users"
        )
        assert is_valid is True

    def test_validate_explain_returns_details(self):
        """Test that validate_explain also returns details."""
        validator = SQLValidator()
        is_valid, error, details = validator.validate_explain(
            "SELECT * FROM users"
        )
        assert is_valid is True
        assert details is not None

    def test_extract_tables_compatibility(self):
        """Test that extract_tables still works for backward compatibility."""
        validator = SQLValidator()
        tables = validator.extract_tables(
            "SELECT * FROM users JOIN orders ON users.id = orders.user_id"
        )
        assert "users" in tables
        assert "orders" in tables

    def test_case_insensitive_blocking(self):
        """Test that blocking is case insensitive."""
        validator = SQLValidator(blocked_tables={"USERS"})
        is_valid, error, _ = validator.validate(
            "SELECT * FROM users"
        )
        assert is_valid is False

        is_valid, error, _ = validator.validate(
            "SELECT * FROM Users"
        )
        assert is_valid is False

    def test_combined_blocked_and_allowed(self):
        """Test combined blocked tables and allowed columns."""
        validator = SQLValidator(
            blocked_tables={"audit_logs"},
            blocked_columns={"users": {"ssn"}}
        )

        # Blocked table should be rejected
        is_valid, error, _ = validator.validate("SELECT * FROM audit_logs")
        assert is_valid is False

        # Blocked column should be rejected
        is_valid, error, _ = validator.validate("SELECT ssn FROM users")
        assert is_valid is False

        # Valid query should pass
        is_valid, error, _ = validator.validate("SELECT name FROM users")
        assert is_valid is True
