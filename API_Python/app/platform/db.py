from typing import Optional
import asyncpg
from app.core.config import config

_pool: Optional[asyncpg.Pool] = None

async def init_pool() -> asyncpg.Pool:
    global _pool
    if _pool is None:
        _pool = await asyncpg.create_pool(
            host=config.db_host,
            port=config.db_port,
            user=config.db_user,
            password=config.db_password,
            database=config.db_name,
            min_size=config.db_pool_min,
            max_size=config.db_pool_max,
        )
    return _pool

async def close_pool() -> None:
    global _pool
    if _pool is not None:
        await _pool.close()
        _pool = None

def get_pool() -> asyncpg.Pool:
    if _pool is None:
        raise RuntimeError("El pool de base de datos no ha sido inicializado.")
    return _pool

async def ping() -> None:
    pool = get_pool()
    async with pool.acquire() as conn:
        await conn.execute("SELECT 1;")
