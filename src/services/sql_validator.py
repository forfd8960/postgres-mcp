# src/services/sql_validator.py
"""SQL validation services - Critical security component."""

import re
import sqlglot
from sqlglot.errors import ParseError
from typing import Optional


class SQLValidator:
    """SQL security validator.

    This is a critical security component that validates SQL statements
    to prevent SQL injection and unauthorized operations.
    """

    # Allowed statement types
    ALLOWED_STATEMENTS = {"SELECT"}

    # System schema prefixes to block
    SYSTEM_SCHEMA_PREFIXES = ("pg_", "information_schema")

    # Forbidden patterns for dangerous keywords
    FORBIDDEN_PATTERNS = [
        r"\bINSERT\b",
        r"\bUPDATE\b",
        r"\bDELETE\b",
        r"\bDROP\b",
        r"\bTRUNCATE\b",
        r"\bALTER\b",
        r"\bCREATE\b",
        r"\bGRANT\b",
        r"\bREVOKE\b",
        r"\bEXECUTE\b",
        r"\bWITH\s+.*\bDROP\b",  # CTE injection prevention
    ]

    def __init__(
        self,
        allowed_statements: Optional[set[str]] = None
    ):
        """Initialize the SQL validator.

        Args:
            allowed_statements: Set of allowed statement types.
        """
        self.allowed_statements = allowed_statements or self.ALLOWED_STATEMENTS
        self._compiled_patterns = [
            re.compile(p, re.IGNORECASE) for p in self.FORBIDDEN_PATTERNS
        ]

    def validate(self, sql: str) -> tuple[bool, Optional[str]]:
        """Validate an SQL statement for security.

        Args:
            sql: The SQL statement to validate.

        Returns:
            A tuple of (is_valid, error_message).
        """
        # Step 1: Remove comments
        cleaned_sql = self._remove_comments(sql)

        # Step 2: Basic syntax check + single statement constraint
        try:
            statements = sqlglot.parse(cleaned_sql, read="postgres")
        except ParseError as e:
            return False, f"SQL 语法错误: {str(e)}"

        if len(statements) != 1:
            return False, "仅允许单条 SELECT 语句"

        parsed = statements[0]

        # Step 3: Check statement type
        statement_type = type(parsed).__name__.upper()
        if statement_type not in self.allowed_statements:
            return False, f"不允许的语句类型: {statement_type}"

        # Step 4: Regex pattern check
        for pattern in self._compiled_patterns:
            if pattern.search(cleaned_sql):
                return False, "检测到禁止的关键词"

        # Step 5: System table/schema blocking
        tables = {t.name for t in parsed.find_all(sqlglot.exp.Table)}
        if any(
            str(tbl).lower().startswith(self.SYSTEM_SCHEMA_PREFIXES)
            for tbl in tables
        ):
            return False, "禁止访问系统表或 information_schema"

        # Step 6: CTE injection detection
        if self._contains_forbidden_cte(cleaned_sql):
            return False, "CTE 子句包含危险操作"

        return True, None

    def extract_tables(self, sql: str) -> list[str]:
        """Extract table names from an SQL statement.

        Args:
            sql: The SQL statement to analyze.

        Returns:
            A list of table names found in the statement.
        """
        try:
            parsed = sqlglot.parse_one(sql, read="postgres")
            tables = []

            # Walk through all table references
            for node in parsed.walk():
                if isinstance(node, sqlglot.exp.Table):
                    tables.append(node.name)

            return list(set(tables))
        except ParseError:
            return []

    def _remove_comments(self, sql: str) -> str:
        """Remove SQL comments from the statement.

        Args:
            sql: The SQL statement with possible comments.

        Returns:
            The SQL statement without comments.
        """
        # Remove /* ... */ style comments
        sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.DOTALL)
        # Remove -- style comments
        sql = re.sub(r"--.*$", "", sql, flags=re.MULTILINE)
        return sql.strip()

    def _contains_forbidden_cte(self, sql: str) -> bool:
        """Check if the SQL contains forbidden CTE operations.

        Args:
            sql: The SQL statement to check.

        Returns:
            True if forbidden CTE operations are found.
        """
        sql_upper = sql.upper()

        # Check if WITH clause contains dangerous operations
        with_match = re.search(
            r"WITH\s+(\w+)\s+AS\s*\([^)]*([^\)]*)\)",
            sql_upper,
            re.DOTALL
        )
        if with_match:
            cte_body = with_match.group(2)
            dangerous_keywords = ["DROP", "DELETE", "INSERT", "UPDATE", "ALTER"]
            for kw in dangerous_keywords:
                if kw in cte_body:
                    return True

        return False

    def validate_explain(self, sql: str) -> tuple[bool, Optional[str]]:
        """Validate SQL using EXPLAIN syntax.

        Args:
            sql: The SQL statement to validate.

        Returns:
            A tuple of (is_valid, error_message).
        """
        explain_sql = f"EXPLAIN {sql}"
        return self.validate(explain_sql)
