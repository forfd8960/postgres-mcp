"""Multi-database connection pool manager."""

import asyncio
import logging
from typing import Optional, Dict, Any
from dataclasses import dataclass, field

import asyncpg

from src.models.database import DatabaseConfig

logger = logging.getLogger("multi-db-manager")


@dataclass
class PoolConfig:
    """Pool configuration for a single database."""
    name: str
    min_size: int = 1
    max_size: int = 10
    timeout: int = 30
    ssl: bool = False


class MultiDatabaseManager:
    """Manages multiple database connection pools.

    This class provides:
    - Single DSN connection (backward compatible)
    - Multiple database pools support
    - Pool health checks
    - Connection status monitoring
    """

    def __init__(self):
        self._pools: Dict[str, asyncpg.Pool] = {}
        self._configs: Dict[str, PoolConfig] = {}
        self._default_pool: Optional[asyncpg.Pool] = None
        self._default_dsn: Optional[str] = None
        self._default_ssl: bool = False

    def configure_default(self, dsn: str, ssl: bool = False) -> None:
        """Configure the default database connection.

        Args:
            dsn: Database connection string.
            ssl: Whether to use SSL.
        """
        self._default_dsn = dsn
        self._default_ssl = ssl
        logger.info("Configured default database: %s", dsn[:50] + "...")

    def add_database(self, config: DatabaseConfig) -> None:
        """Add a database configuration.

        Args:
            config: Database configuration.
        """
        pool_config = PoolConfig(
            name=config.name,
            ssl=config.ssl,
            min_size=getattr(config, 'pool_min', 1),
            max_size=getattr(config, 'pool_max', 10),
            timeout=getattr(config, 'pool_timeout', 30)
        )
        self._configs[config.name] = pool_config
        logger.info("Added database config: %s", config.name)

    async def get_pool(self, database: Optional[str] = None) -> asyncpg.Pool:
        """Get or create a connection pool for the specified database.

        Args:
            database: Database name. If None, uses default database.

        Returns:
            Connection pool for the specified database.

        Raises:
            ValueError: If database not found and no default configured.
        """
        db_name = database or "default"

        # Return existing pool if available
        if db_name in self._pools:
            pool = self._pools[db_name]
            if not pool._closed:
                return pool
            # Pool is closed, remove it
            del self._pools[db_name]

        # Check if we have a config for this database
        if db_name in self._configs:
            config = self._configs[db_name]
            return await self._create_pool(db_name, config.dsn, config)

        # Use default database
        if self._default_dsn:
            if db_name == "default":
                return await self._get_or_create_default_pool()
            # For named databases without config, try to use DSN with database name
            # This is a fallback for backward compatibility
            return await self._create_pool(db_name, self._default_dsn, PoolConfig(name=db_name))

        raise ValueError(f"No pool configured for database: {db_name}")

    async def _get_or_create_default_pool(self) -> asyncpg.Pool:
        """Get or create the default connection pool."""
        if self._default_pool and not self._default_pool._closed:
            return self._default_pool

        if not self._default_dsn:
            raise ValueError("No default database configured")

        pool = await self._create_pool(
            "default",
            self._default_dsn,
            PoolConfig(name="default", ssl=self._default_ssl)
        )
        self._default_pool = pool
        return pool

    async def _create_pool(
        self,
        name: str,
        dsn: str,
        config: Optional[PoolConfig] = None
    ) -> asyncpg.Pool:
        """Create a new connection pool.

        Args:
            name: Database name.
            dsn: Database connection string.
            config: Pool configuration.

        Returns:
            Created connection pool.
        """
        pool_config = config or PoolConfig(name=name)
        logger.info("Creating pool for %s: min=%d, max=%d", name, pool_config.min_size, pool_config.max_size)

        pool = await asyncpg.create_pool(
            dsn=dsn,
            min_size=pool_config.min_size,
            max_size=pool_config.max_size,
            ssl=pool_config.ssl if pool_config.ssl else None,
            command_timeout=pool_config.timeout,
            server_settings={
                "search_path": "public"
            }
        )

        self._pools[name] = pool
        logger.info("Pool created successfully for: %s", name)
        return pool

    async def test_connection(self, database: Optional[str] = None) -> Dict[str, Any]:
        """Test database connection.

        Args:
            database: Database name to test.

        Returns:
            Dictionary with connection status.
        """
        try:
            pool = await self.get_pool(database)
            async with pool.acquire() as conn:
                start_time = asyncio.get_event_loop().time()
                await conn.fetchval("SELECT 1")
                latency_ms = (asyncio.get_event_loop().time() - start_time) * 1000

                return {
                    "database": database or "default",
                    "connected": True,
                    "latency_ms": latency_ms,
                    "error": None
                }
        except Exception as e:
            logger.error("Connection test failed for %s: %s", database, e)
            return {
                "database": database or "default",
                "connected": False,
                "latency_ms": None,
                "error": str(e)
            }

    async def get_all_status(self) -> Dict[str, Dict[str, Any]]:
        """Get connection status for all configured databases.

        Returns:
            Dictionary of database status.
        """
        status = {}

        # Test default
        if self._default_dsn or "default" in self._pools:
            status["default"] = await self.test_connection("default")

        # Test all configured databases
        for name in self._configs:
            if name != "default":
                status[name] = await self.test_connection(name)

        return status

    async def close(self, database: Optional[str] = None) -> None:
        """Close a connection pool.

        Args:
            database: Database name. If None, closes all pools.
        """
        if database:
            if database in self._pools:
                pool = self._pools[database]
                await pool.close()
                del self._pools[database]
                logger.info("Closed pool for: %s", database)
        else:
            # Close all pools
            for name, pool in list(self._pools.items()):
                await pool.close()
                logger.info("Closed pool for: %s", name)
            self._pools.clear()

            if self._default_pool:
                await self._default_pool.close()
                self._default_pool = None

        logger.info("All connection pools closed")

    def is_healthy(self, database: Optional[str] = None) -> bool:
        """Check if a database pool is healthy.

        Args:
            database: Database name.

        Returns:
            True if pool is healthy.
        """
        db_name = database or "default"
        pool = self._pools.get(db_name)
        return pool is not None and not pool._closed

    @property
    def pool_count(self) -> int:
        """Get number of active pools."""
        return len([p for p in self._pools.values() if not p._closed])
