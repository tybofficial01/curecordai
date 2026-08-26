"""
Shared pytest fixtures.

`db_session` opens a real connection through the app's configured async engine
(`app.database.engine`, same DATABASE_URL the app itself uses) and wraps it in an outer
transaction that is always rolled back at teardown, so nothing a test does via it is ever
persisted and no separate test database needs to be provisioned. `client` layers an httpx
AsyncClient against the real FastAPI app on top of that, overriding `get_db` so request
handlers see the same rollback-wrapped session.

Neither fixture is exercised by every test - a test only pays the cost of a DB connection
if it actually requests `db_session` or `client`.
"""
from collections.abc import AsyncGenerator

import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import engine, get_db
from app.main import app


@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    async with engine.connect() as conn:
        trans = await conn.begin()
        session = AsyncSession(bind=conn, expire_on_commit=False)
        try:
            yield session
        finally:
            await session.close()
            await trans.rollback()


@pytest_asyncio.fixture
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    async def _override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = _override_get_db
    transport = ASGITransport(app=app)
    try:
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            yield ac
    finally:
        app.dependency_overrides.pop(get_db, None)
