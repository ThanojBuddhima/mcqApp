from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.database import Base, engine


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        await conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS grade VARCHAR(10)"))
    yield
    await engine.dispose()


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

cors_kwargs: dict = {
    "allow_credentials": True,
    "allow_methods": ["*"],
    "allow_headers": ["*"],
}
if settings.is_development and settings.cors_allow_localhost_regex:
    cors_kwargs["allow_origins"] = settings.cors_origins_list
    cors_kwargs["allow_origin_regex"] = r"http://(localhost|127\.0\.0\.1)(:\d+)?"
else:
    cors_kwargs["allow_origins"] = settings.cors_origins_list

app.add_middleware(CORSMiddleware, **cors_kwargs)

app.include_router(api_router, prefix=settings.api_v1_prefix)


@app.get("/")
async def root():
    return {"message": "MCQ Platform API", "docs": "/docs"}
