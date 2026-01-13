# src/services/schema.py
"""Schema collection and management services."""

import re
import logging
from datetime import datetime, timedelta
from typing import Optional
import asyncpg

from src.models.schema import (
    SchemaInfo,
    TableInfo,
    ColumnInfo,
    IndexInfo,
    ForeignKeyInfo,
)

logger = logging.getLogger("schema-service")

class SchemaService:
    """Schema information service with caching."""

    def __init__(self, pool: asyncpg.Pool, cache_ttl: int = 60):
        """Initialize the schema service.

        Args:
            pool: The database connection pool.
            cache_ttl: Cache time-to-live in seconds.
        """
        self.pool = pool
        self.cache_ttl = cache_ttl
        self._cache: dict[str, SchemaInfo] = {}
        self._cache_time: Optional[datetime] = None

    async def get_schema_info(
        self,
        force_refresh: bool = False,
        database: str = "default"
    ) -> SchemaInfo:
        """Get database schema information.

        Args:
            force_refresh: Force refresh the cache.
            database: Database name (for multi-database support).

        Returns:
            The schema information.
        """
        # Check cache validity for specific database
        if not force_refresh and self._is_cache_valid():
            cached = self._cache.get(database)
            if cached:
                return cached
            # Fall back to default database cache
            default_cache = self._cache.get("default")
            if default_cache:
                return default_cache

        # Load from database
        try:
            async with self.pool.acquire() as conn:
                schemas = await self._get_schemas(conn)
                tables = await self._get_tables(conn)
                indexes = await self._get_indexes(conn)
                foreign_keys = await self._get_foreign_keys(conn)
        except Exception as e:
            # Clear cache on error (e.g., table no longer exists)
            self.clear_cache()
            logger.warning("Schema fetch failed, cache cleared: %s", e)
            raise

        schema_info = SchemaInfo(
            database=database,
            schemas=schemas,
            tables=tables,
            indexes=indexes,
            foreign_keys=foreign_keys
        )

        logger.info("Fetched schema info from database '%s': %s", database, schema_info.model_dump())

        # Update cache
        self._cache[database] = schema_info
        self._cache_time = datetime.utcnow()

        return schema_info

    def format_schema_for_ai(self, schema_info: SchemaInfo) -> str:
        """Format schema information for AI consumption.

        Args:
            schema_info: The schema information to format.

        Returns:
            A formatted string representation.
        """
        lines = []
        # Group tables by schema
        schema_tables: dict[str, list] = {}
        for table in schema_info.tables:
            schema = table.schema_name
            if schema not in schema_tables:
                schema_tables[schema] = []
            schema_tables[schema].append(table)

        for schema_name, tables in schema_tables.items():
            if schema_name != "public":
                lines.append(f"Schema: {schema_name}")
            for table in tables:
                columns = []
                for col in table.columns:
                    col_desc = f"  - {col.name}: {col.data_type}"
                    if col.is_nullable:
                        col_desc += " (nullable)"
                    if col.is_primary_key:
                        col_desc += " (primary key)"
                    columns.append(col_desc)

                lines.append(f"表 {table.name}:")
                lines.extend(columns)
                lines.append("")

        return "\n".join(lines)

    async def _get_tables(self, conn: asyncpg.Connection) -> list[TableInfo]:
        """Get all table information from the database.

        Args:
            conn: The database connection.

        Returns:
            A list of table information.
        """
        rows = await conn.fetch("""
            SELECT
                t.table_name,
                t.table_schema,
                obj_description(
                    (t.table_schema || '.' || t.table_name)::regclass,
                    'pg_class'
                ) as comment
            FROM information_schema.tables t
            WHERE t.table_schema NOT IN ('pg_catalog', 'information_schema')
                AND t.table_type = 'BASE TABLE'
            ORDER BY t.table_schema, t.table_name
        """)

        tables = []
        for row in rows:
            table_name = row["table_name"]
            columns = await self._get_columns(conn, table_name, row["table_schema"])
            tables.append(TableInfo(
                name=table_name,
                schema_name=row["table_schema"],
                columns=columns,
                comment=row["comment"]
            ))

        return tables

    async def _get_schemas(self, conn: asyncpg.Connection) -> list[str]:
        """Get all schema names from the database.

        Args:
            conn: The database connection.

        Returns:
            A list of schema names.
        """
        rows = await conn.fetch("""
            SELECT schema_name
            FROM information_schema.schemata
            WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
            ORDER BY schema_name
        """)
        return [row["schema_name"] for row in rows]

    async def _get_columns(
        self,
        conn: asyncpg.Connection,
        table_name: str,
        schema_name: str
    ) -> list[ColumnInfo]:
        """Get column information for a table.

        Args:
            conn: The database connection.
            table_name: The table name.
            schema: The schema name.

        Returns:
            A list of column information.
        """
        rows = await conn.fetch("""
            SELECT
                column_name,
                data_type,
                is_nullable,
                column_default,
                character_maximum_length,
                pg_get_serial_sequence($1, column_name) IS NOT NULL as is_serial
            FROM information_schema.columns
            WHERE table_schema = $2 AND table_name = $1
            ORDER BY ordinal_position
        """, table_name, schema_name)

        columns = []
        for row in rows:
            is_pk = await self._is_primary_key(
                conn, table_name, schema_name, row["column_name"]
            )
            columns.append(ColumnInfo(
                name=row["column_name"],
                data_type=row["data_type"],
                is_nullable=row["is_nullable"] == "YES",
                is_primary_key=is_pk,
                default_value=row["column_default"],
                max_length=row["character_maximum_length"]
            ))

        return columns

    async def _is_primary_key(
        self,
        conn: asyncpg.Connection,
        table_name: str,
        schema_name: str,
        column_name: str
    ) -> bool:
        """Check if a column is a primary key.

        Args:
            conn: The database connection.
            table_name: The table name.
            schema: The schema name.
            column_name: The column name.

        Returns:
            True if the column is a primary key.
        """
        row = await conn.fetchval("""
            SELECT 1 FROM information_schema.table_constraints tc
            JOIN information_schema.constraint_column_usage ccu
                ON tc.constraint_name = ccu.constraint_name
            WHERE tc.table_schema = $1
                AND tc.table_name = $2
                AND tc.constraint_type = 'PRIMARY KEY'
                AND ccu.column_name = $3
        """, schema_name, table_name, column_name)

        return row is not None

    async def _get_indexes(
        self,
        conn: asyncpg.Connection
    ) -> list[IndexInfo]:
        """Get index information from the database.

        Args:
            conn: The database connection.

        Returns:
            A list of index information.
        """
        rows = await conn.fetch("""
            SELECT indexname, indexdef, tablename
            FROM pg_indexes
            WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
        """)

        indexes = []
        for row in rows:
            # Extract columns from index definition
            indexdef = row["indexdef"]
            columns = self._extract_index_columns(indexdef)

            indexes.append(IndexInfo(
                name=row["indexname"],
                table_name=row["tablename"],
                columns=columns,
                is_unique="UNIQUE" in indexdef.upper(),
                definition=indexdef
            ))

        return indexes

    def _extract_index_columns(self, indexdef: str) -> list[str]:
        """Extract column names from index definition.

        Args:
            indexdef: The index definition string.

        Returns:
            A list of column names.
        """
        # Simple extraction for common index patterns
        match = re.search(r"\(([^)]+)\)", indexdef)
        if match:
            cols = match.group(1).split(",")
            return [c.strip().strip('"') for c in cols]
        return []

    async def _get_foreign_keys(
        self,
        conn: asyncpg.Connection
    ) -> list[ForeignKeyInfo]:
        """Get foreign key information from the database.

        Args:
            conn: The database connection.

        Returns:
            A list of foreign key information.
        """
        rows = await conn.fetch("""
            SELECT
                conname,
                pg_get_constraintdef(oid) as condef,
                confrelid::regclass AS ref_table
            FROM pg_constraint
            WHERE contype = 'f'
        """)

        foreign_keys = []
        for row in rows:
            condef = row["condef"]
            # Extract column names from constraint definition
            columns_match = re.search(
                r"\(([^)]+)\)",
                condef
            )
            ref_columns_match = re.search(
                r"FOREIGN KEY\s*\(([^)]+)\)\s*REFERENCES\s+\w+\(([^)]+)\)",
                condef,
                re.IGNORECASE
            )

            if columns_match and ref_columns_match:
                columns = [c.strip() for c in columns_match.group(1).split(",")]
                ref_columns = [
                    c.strip() for c in ref_columns_match.group(2).split(",")
                ]

                foreign_keys.append(ForeignKeyInfo(
                    name=row["conname"],
                    columns=columns,
                    ref_table=str(row["ref_table"]),
                    ref_columns=ref_columns
                ))

        return foreign_keys

    def _is_cache_valid(self) -> bool:
        """Check if the cache is still valid.

        Returns:
            True if the cache is valid.
        """
        if self._cache_time is None:
            return False
        return datetime.utcnow() - self._cache_time < timedelta(
            seconds=self.cache_ttl
        )

    def clear_cache(self) -> None:
        """Clear the schema cache."""
        self._cache.clear()
        self._cache_time = None
