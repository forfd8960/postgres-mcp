# src/models/database.py
"""Database-related data models."""

from pydantic import BaseModel
from typing import Optional


class DatabaseConfig(BaseModel):
    """Database configuration model."""

    name: str
    dsn: str
    ssl: bool = False


class ConnectionStatus(BaseModel):
    """Connection status model."""

    database: str
    connected: bool
    latency_ms: Optional[float] = None
    error: Optional[str] = None
