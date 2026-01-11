# tests/test_sql_validator.py
"""Tests for the SQL validator service."""

import pytest
from src.services.sql_validator import SQLValidator


class TestSQLValidator:
    """SQL Validator test suite."""

    def setup_method(self):
        """Set up test fixtures."""
        self.validator = SQLValidator()

    # === Valid SQL tests ===

    def test_valid_select(self):
        """Test valid SELECT statement."""
        sql = "SELECT id, name FROM users WHERE id = 1"
        is_valid, error = self.validator.validate(sql)
        assert is_valid is True
        assert error is None

    def test_select_with_join(self):
        """Test SELECT with JOIN."""
        sql = "SELECT u.name, o.total FROM users u JOIN orders o ON u.id = o.user_id"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_subquery(self):
        """Test SELECT with subquery."""
        sql = "SELECT * FROM users WHERE id IN (SELECT user_id FROM orders)"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_cte(self):
        """Test SELECT with CTE."""
        sql = "WITH active_users AS (SELECT * FROM users WHERE active = true) SELECT * FROM active_users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_case_insensitive(self):
        """Test case-insensitive validation."""
        sql = "SeLeCt * FrOm users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_aggregates(self):
        """Test SELECT with aggregate functions."""
        sql = "SELECT COUNT(*), SUM(amount) FROM orders GROUP BY user_id"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_order_limit(self):
        """Test SELECT with ORDER BY and LIMIT."""
        sql = "SELECT * FROM users ORDER BY created_at DESC LIMIT 10"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_select_with_like(self):
        """Test SELECT with LIKE operator."""
        sql = "SELECT * FROM users WHERE name LIKE '%test%'"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    # === Rejection tests ===

    def test_reject_insert(self):
        """Test INSERT statement rejection."""
        sql = "INSERT INTO users (name) VALUES ('test')"
        is_valid, error = self.validator.validate(sql)
        assert is_valid is False
        assert "INSERT" in error

    def test_reject_update(self):
        """Test UPDATE statement rejection."""
        sql = "UPDATE users SET name = 'hacked' WHERE id = 1"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_delete(self):
        """Test DELETE statement rejection."""
        sql = "DELETE FROM users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_drop(self):
        """Test DROP statement rejection."""
        sql = "DROP TABLE users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_cte_injection(self):
        """Test CTE injection rejection."""
        sql = "WITH x AS (SELECT * FROM users) DROP TABLE users"
        is_valid, error = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_multiple_statements(self):
        """Test multiple statement rejection."""
        sql = "SELECT * FROM users; DROP TABLE users;"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_hidden_drop_in_comment(self):
        """Test rejection of hidden DROP in comment."""
        sql = "SELECT * FROM users /* ; DROP TABLE users; */"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_system_table(self):
        """Test system table access rejection."""
        sql = "SELECT * FROM pg_password"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_information_schema(self):
        """Test information_schema access rejection."""
        sql = "SELECT * FROM information_schema.tables"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_truncate(self):
        """Test TRUNCATE statement rejection."""
        sql = "TRUNCATE TABLE users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_alter(self):
        """Test ALTER statement rejection."""
        sql = "ALTER TABLE users ADD COLUMN email VARCHAR(255)"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_create(self):
        """Test CREATE statement rejection."""
        sql = "CREATE TABLE hackers (id INT)"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_grant(self):
        """Test GRANT statement rejection."""
        sql = "GRANT ALL ON users TO hacker"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_revoke(self):
        """Test REVOKE statement rejection."""
        sql = "REVOKE ALL ON users FROM hacker"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_execute(self):
        """Test EXECUTE statement rejection."""
        sql = "EXECUTE malicious_function()"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_union_injection(self):
        """Test UNION-based SQL injection rejection."""
        sql = "SELECT * FROM users UNION SELECT * FROM users; DROP TABLE users;"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_comment_embedded_drop(self):
        """Test rejection of DROP hidden in comment within statement."""
        sql = "SELECT * /* DROP */ FROM users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_semicolon_injection(self):
        """Test semicolon-separated statement injection rejection."""
        sql = "SELECT * FROM users; DELETE FROM users;"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_nested_cte_injection(self):
        """Test nested CTE injection rejection."""
        sql = "WITH a AS (SELECT 1), b AS (SELECT * FROM users DROP TABLE users) SELECT * FROM a"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_select_from_pg_catalog(self):
        """Test pg_catalog table access rejection."""
        sql = "SELECT * FROM pg_catalog.pg_tables"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_select_from_information_schema(self):
        """Test information_schema access rejection."""
        sql = "SELECT * FROM information_schema.columns"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_with_delete(self):
        """Test CTE with DELETE rejection."""
        sql = "WITH x AS (DELETE FROM users) SELECT * FROM x"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_with_insert(self):
        """Test CTE with INSERT rejection."""
        sql = "WITH x AS (INSERT INTO users SELECT * FROM users) SELECT * FROM x"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_with_update(self):
        """Test CTE with UPDATE rejection."""
        sql = "WITH x AS (UPDATE users SET name='x') SELECT * FROM x"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_alter_sequence(self):
        """Test ALTER SEQUENCE rejection."""
        sql = "ALTER SEQUENCE users_id_seq RESTART WITH 1000"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_copy(self):
        """Test COPY statement rejection."""
        sql = "COPY users TO '/tmp/data.csv'"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_vacuum(self):
        """Test VACUUM statement rejection."""
        sql = "VACUUM ANALYZE users"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_load(self):
        """Test LOAD statement rejection."""
        sql = "LOAD '/lib/libc.so.6'"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_reject_do_block(self):
        """Test DO block rejection."""
        sql = "DO $$ BEGIN PERFORM pg_sleep(0); END $$"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is False

    def test_select_with_window_functions(self):
        """Test SELECT with window functions is allowed."""
        sql = "SELECT id, name, ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) as rank FROM employees"
        is_valid, error = self.validator.validate(sql)
        assert is_valid is True
        assert error is None

    def test_select_with_distinct_on(self):
        """Test SELECT with DISTINCT ON is allowed."""
        sql = "SELECT DISTINCT ON (id) id, name, created_at FROM users ORDER BY id, created_at"
        is_valid, error = self.validator.validate(sql)
        assert is_valid is True
        assert error is None

    # === Comment removal tests ===

    def test_comment_removal(self):
        """Test that comments are properly removed."""
        sql = "SELECT id FROM users -- this is a comment"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    def test_multiline_comment_removal(self):
        """Test multiline comment removal."""
        sql = "SELECT id FROM users /* comment */ WHERE id = 1"
        is_valid, _ = self.validator.validate(sql)
        assert is_valid is True

    # === Table extraction tests ===

    def test_extract_tables_simple(self):
        """Test simple table extraction."""
        sql = "SELECT * FROM users"
        tables = self.validator.extract_tables(sql)
        assert "users" in tables

    def test_extract_tables_join(self):
        """Test table extraction from JOIN."""
        sql = "SELECT * FROM users u JOIN orders o ON u.id = o.user_id"
        tables = self.validator.extract_tables(sql)
        assert "users" in tables
        assert "orders" in tables

    def test_extract_tables_subquery(self):
        """Test table extraction from subquery."""
        sql = "SELECT * FROM users WHERE id IN (SELECT user_id FROM orders)"
        tables = self.validator.extract_tables(sql)
        assert "users" in tables
        assert "orders" in tables

    def test_extract_tables_cte(self):
        """Test table extraction from CTE."""
        sql = "WITH active_users AS (SELECT * FROM users) SELECT * FROM active_users"
        tables = self.validator.extract_tables(sql)
        assert "users" in tables
