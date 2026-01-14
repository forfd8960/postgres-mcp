# src/services/sql_validator.py
"""SQL validation services - Critical security component."""

import re
import sqlglot
from sqlglot.errors import ParseError
from typing import Optional, Set, Dict, List, Any


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
        r"\bCONNECT\b",  # Prevent cross-database attempts
        r"\bUSE\b",       # MySQL-style database switching
        r"\bWITH\s+.*\bDROP\b",  # CTE injection prevention
    ]

    def __init__(
        self,
        allowed_statements: Optional[Set[str]] = None,
        blocked_tables: Optional[Set[str]] = None,
        blocked_columns: Optional[Dict[str, Set[str]]] = None,
        allowed_tables: Optional[Set[str]] = None,
        allowed_columns: Optional[Dict[str, Set[str]]] = None
    ):
        """Initialize the SQL validator with access control.

        Args:
            allowed_statements: Set of allowed statement types.
            blocked_tables: Set of table names to block access to.
            blocked_columns: Dict mapping table names to blocked column sets.
            allowed_tables: If set, only these tables are allowed.
            allowed_columns: Dict mapping table names to allowed column sets.
        """
        self.allowed_statements = allowed_statements or self.ALLOWED_STATEMENTS
        self.blocked_tables = set(t.lower() for t in (blocked_tables or set()))
        self.blocked_columns = {
            k.lower(): set(c.lower() for c in v)
            for k, v in (blocked_columns or {}).items()
        }
        self.allowed_tables = set(t.lower() for t in (allowed_tables or set()))
        self.allowed_columns = {
            k.lower(): set(c.lower() for c in v)
            for k, v in (allowed_columns or {}).items()
        }

        self._compiled_patterns = [
            re.compile(p, re.IGNORECASE) for p in self.FORBIDDEN_PATTERNS
        ]

    def validate(self, sql: str) -> tuple[bool, Optional[str], Optional[dict]]:
        """Validate an SQL statement for security and access control.

        Args:
            sql: The SQL statement to validate.

        Returns:
            A tuple of (is_valid, error_message, details).
            Details contains additional info like tables/columns involved.
        """
        details: Dict[str, Any] = {"tables": [], "columns": []}

        # Step 1: Remove comments
        cleaned_sql = self._remove_comments(sql)

        # Step 2: Regex pattern check (must be BEFORE sqlglot parsing)
        for pattern in self._compiled_patterns:
            if pattern.search(cleaned_sql):
                return False, "检测到禁止的关键词", None

        # Step 3: Basic syntax check + single statement constraint
        try:
            statements = sqlglot.parse(cleaned_sql, read="postgres")
        except ParseError as e:
            return False, f"SQL 语法错误: {str(e)}", None

        if len(statements) != 1:
            return False, "仅允许单条 SELECT 语句", None

        parsed = statements[0]

        # Step 4: Check statement type
        statement_type = type(parsed).__name__.upper()
        if statement_type not in self.allowed_statements:
            return False, f"不允许的语句类型: {statement_type}", None

        # Step 5: Extract tables and columns
        tables = self._extract_tables_info(parsed)
        details["tables"] = tables

        # Check blocked tables
        for table in tables:
            table_name = table["name"].lower()
            if table_name in self.blocked_tables:
                return False, f"禁止访问表: {table['name']}", details

        # Check allowed tables (if configured)
        if self.allowed_tables and not any(
            t["name"].lower() in self.allowed_tables for t in tables
        ):
            return False, "未授权访问的表", details

        # Step 6: Check column access
        columns = self._extract_columns_info(parsed)
        details["columns"] = columns

        for col in columns:
            col_name = col["name"].lower()
            table_name = col["table"].lower() if col["table"] else None

            # Check blocked columns
            if table_name and table_name in self.blocked_columns:
                if col_name in self.blocked_columns[table_name]:
                    return False, f"禁止访问列: {col['table']}.{col['name']}", details

            # Check allowed columns (if configured)
            if self.allowed_columns:
                if table_name and table_name in self.allowed_columns:
                    if col_name not in self.allowed_columns[table_name]:
                        return False, f"未授权访问列: {col['table']}.{col['name']}", details
                elif not table_name:
                    # Column without table context - check if any table allows it
                    allowed_anywhere = any(
                        col_name in cols for cols in self.allowed_columns.values()
                    )
                    if not allowed_anywhere:
                        return False, f"未授权访问列: {col['name']}", details

        # Step 7: System table/schema blocking
        system_tables = [t for t in tables if self._is_system_table(t["name"])]
        if system_tables:
            return False, "禁止访问系统表或 information_schema", details

        # Step 8: CTE injection detection
        if self._contains_forbidden_cte(cleaned_sql):
            return False, "CTE 子句包含危险操作", details

        return True, None, details

    def _extract_tables_info(self, parsed) -> List[dict]:
        """Extract table information from parsed SQL.

        Args:
            parsed: The parsed SQL expression.

        Returns:
            List of table info dicts with name and alias.
        """
        tables = []
        seen = set()

        for node in parsed.walk():
            if isinstance(node, sqlglot.exp.Table):
                table_name = node.name
                if table_name.lower() not in seen:
                    seen.add(table_name.lower())
                    tables.append({
                        "name": table_name,
                        "alias": node.alias if node.alias else None,
                        "schema": node.db if hasattr(node, 'db') else None
                    })

        return tables

    def _extract_columns_info(self, parsed) -> List[dict]:
        """Extract column information from parsed SQL.

        Args:
            parsed: The parsed SQL expression.

        Returns:
            List of column info dicts with name, table, and alias.
        """
        columns = []
        seen = set()

        # Build a map of table aliases to actual table names
        table_alias_map: Dict[str, str] = {}
        table_nodes: List[sqlglot.exp.Table] = []
        for node in parsed.walk():
            if isinstance(node, sqlglot.exp.Table):
                table_name = node.name
                alias = node.alias
                if alias:
                    table_alias_map[alias.lower()] = table_name.lower()
                table_alias_map[table_name.lower()] = table_name.lower()
                table_nodes.append(node)

        for node in parsed.walk():
            if isinstance(node, sqlglot.exp.Column):
                col_name = node.name

                # Find the table context for this column
                table_ref = None
                current = node
                while current is not None:
                    # Check if column is part of a Select's expressions
                    if isinstance(current, sqlglot.exp.Select):
                        # Look through FROM clause to find table
                        from_clause = current.args.get('from')
                        if from_clause:
                            table_expr = from_clause.this
                            if isinstance(table_expr, sqlglot.exp.Table):
                                table_ref = table_expr.name.lower()
                    current = getattr(current, 'parent', None)

                # Try to find table by looking at column's context
                # Check if column is under a Join (for JOIN queries)
                if not table_ref:
                    for table_node in table_nodes:
                        # Check if this table contains the column in its expression
                        pass

                # If we still don't have a table, try to infer from table nodes
                if not table_ref and table_nodes:
                    # For simple queries with single table, use that table
                    if len(table_nodes) == 1:
                        table_ref = table_nodes[0].name.lower()

                # Create unique key
                key = f"{table_ref or ''}.{col_name}".lower()
                if key not in seen:
                    seen.add(key)
                    columns.append({
                        "name": col_name,
                        "table": table_ref,
                        "alias": None
                    })

        return columns

    def _is_system_table(self, table_name: str) -> bool:
        """Check if a table is a system table.

        Args:
            table_name: The table name to check.

        Returns:
            True if it's a system table.
        """
        name_lower = table_name.lower()
        return (
            name_lower.startswith(self.SYSTEM_SCHEMA_PREFIXES) or
            name_lower == "information_schema"
        )

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

    def validate_explain(self, sql: str) -> tuple[bool, Optional[str], Optional[dict]]:
        """Validate SQL using EXPLAIN syntax.

        Args:
            sql: The SQL statement to validate.

        Returns:
            A tuple of (is_valid, error_message, details).
        """
        # Validate the original SQL first
        is_valid, error, details = self.validate(sql)
        if not is_valid:
            return is_valid, error, details

        # Try to validate with EXPLAIN prefix (informational only)
        explain_sql = f"EXPLAIN {sql}"
        try:
            statements = sqlglot.parse(explain_sql, read="postgres")
            if len(statements) == 1:
                return True, None, details
        except ParseError:
            pass

        # If EXPLAIN parsing fails but original SQL is valid, still return success
        return True, None, details

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

    def set_blocked_tables(self, tables: Set[str]) -> None:
        """Update blocked tables at runtime.

        Args:
            tables: Set of table names to block.
        """
        self.blocked_tables = set(t.lower() for t in tables)

    def set_blocked_columns(self, columns: Dict[str, Set[str]]) -> None:
        """Update blocked columns at runtime.

        Args:
            columns: Dict mapping table names to blocked column sets.
        """
        self.blocked_columns = {
            k.lower(): set(c.lower() for c in v)
            for k, v in columns.items()
        }

    def set_allowed_tables(self, tables: Set[str]) -> None:
        """Update allowed tables at runtime.

        Args:
            tables: Set of table names to allow (all others blocked).
        """
        self.allowed_tables = set(t.lower() for t in tables)

    def set_allowed_columns(self, columns: Dict[str, Set[str]]) -> None:
        """Update allowed columns at runtime.

        Args:
            columns: Dict mapping table names to allowed column sets.
        """
        self.allowed_columns = {
            k.lower(): set(c.lower() for c in v)
            for k, v in columns.items()
        }
