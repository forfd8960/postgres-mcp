# src/models/schema.py
"""Schema-related data models."""

from pydantic import BaseModel, Field, ConfigDict
from typing import Optional
from enum import Enum


class DataType(str, Enum):
    """Data type enumeration."""

    INTEGER = "INTEGER"
    BIGINT = "BIGINT"
    SMALLINT = "SMALLINT"
    DECIMAL = "DECIMAL"
    NUMERIC = "NUMERIC"
    REAL = "REAL"
    DOUBLE_PRECISION = "DOUBLE_PRECISION"
    VARCHAR = "VARCHAR"
    CHAR = "CHAR"
    TEXT = "TEXT"
    BOOLEAN = "BOOLEAN"
    DATE = "DATE"
    TIME = "TIME"
    TIMESTAMP = "TIMESTAMP"
    TIMESTAMPTZ = "TIMESTAMPTZ"
    JSON = "JSON"
    JSONB = "JSONB"
    UUID = "UUID"
    ARRAY = "ARRAY"
    OTHER = "OTHER"


class ColumnInfo(BaseModel):
    """Column information model."""

    name: str
    data_type: str
    is_nullable: bool = False
    is_primary_key: bool = False
    default_value: Optional[str] = None
    max_length: Optional[int] = None


class TableInfo(BaseModel):
    """Table information model."""

    name: str
    schema_name: str = Field(alias="schema")
    columns: list[ColumnInfo]
    comment: Optional[str] = None

    model_config = ConfigDict(populate_by_name=True)


class IndexInfo(BaseModel):
    """Index information model."""

    name: str
    table_name: str
    columns: list[str]
    is_unique: bool = False
    definition: str


class ForeignKeyInfo(BaseModel):
    """Foreign key information model."""

    name: str
    columns: list[str]
    ref_table: str
    ref_columns: list[str]


class SchemaInfo(BaseModel):
    """Schema information model."""

    database: str
    schema_name: str = Field(alias="schema")
    tables: list[TableInfo]
    views: list[str] = Field(default_factory=list)
    indexes: list[IndexInfo] = Field(default_factory=list)
    foreign_keys: list[ForeignKeyInfo] = Field(default_factory=list)
    enums: list[str] = Field(default_factory=list)

    model_config = ConfigDict(populate_by_name=True)
