# src/services/database.py
"""Database connection services."""

import asyncpg
from typing import Optional


async def create_pool(
    dsn: str,
    min_size: int = 1,
    max_size: int = 10,
    ssl: bool = False,
    timeout: int = 30
) -> asyncpg.Pool:
    """Create a PostgreSQL connection pool.

    Args:
        dsn: Database connection string.
        min_size: Minimum pool size.
        max_size: Maximum pool size.
        ssl: Whether to use SSL.
        timeout: Connection timeout in seconds.

    Returns:
        An asyncpg connection pool.
    """
    pool = await asyncpg.create_pool(
        dsn=dsn,
        min_size=min_size,
        max_size=max_size,
        ssl=ssl if ssl else None,
        command_timeout=timeout
    )
    return pool


async def test_connection(pool: asyncpg.Pool) -> tuple[bool, float | None, str | None]:
    """Test if a database connection is available.

    Args:
        pool: The connection pool to test.

    Returns:
        A tuple of (is_connected, latency_ms, error_message).
    """
    import time

    try:
        start_time = time.perf_counter()
        async with pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        latency_ms = (time.perf_counter() - start_time) * 1000
        return True, latency_ms, None
    except Exception as e:
        return False, None, str(e)


async def close_pool(pool: asyncpg.Pool) -> None:
    """Close a connection pool.

    Args:
        pool: The connection pool to close.
    """
    await pool.close()
