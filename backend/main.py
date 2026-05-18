from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
from pathlib import Path

from config import settings
from database import engine, Base

import models  # registers all ORM models
from routers import projects, stories, assets, storyboards, settings as settings_router, video


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    Path(settings.projects_base_path).mkdir(parents=True, exist_ok=True)
    yield


app = FastAPI(
    title="Scene Factory API",
    description="Local AI video production station backend",
    version=settings.app_version,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:8080", "http://127.0.0.1:*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(projects.router, prefix="/api")
app.include_router(stories.router, prefix="/api")
app.include_router(assets.router, prefix="/api")
app.include_router(storyboards.router, prefix="/api")
app.include_router(settings_router.router, prefix="/api")
app.include_router(video.router, prefix="/api")


@app.get("/")
def root():
    return {"name": settings.app_name, "version": settings.app_version, "status": "running"}


@app.get("/health")
def health():
    return {"status": "ok"}
