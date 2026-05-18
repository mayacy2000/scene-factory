from pydantic_settings import BaseSettings
from pathlib import Path


class Settings(BaseSettings):
    app_name: str = "Scene Factory"
    app_version: str = "0.1.0"

    database_url: str = f"sqlite:///{Path.home()}/Documents/SceneFactory/scene_factory.db"
    projects_base_path: str = str(Path.home() / "Documents" / "SceneFactory" / "Projects")

    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "llama3.2"
    ollama_timeout: int = 120

    comfyui_base_url: str = "http://localhost:8001"
    comfyui_output_dir: str = str(Path.home() / "Documents" / "ComyfyUA" / "output")

    local_only_mode: bool = True
    cloud_upload_approval: str = "always_ask"  # always_ask, ask_new, ask_sensitive, never_ask

    runpod_api_key: str = ""
    per_job_spend_limit: float = 10.0
    monthly_spend_limit: float = 50.0

    class Config:
        env_file = ".env"
        extra = "allow"


settings = Settings()
