from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List

from database import get_db
import models as m
import schemas as s
from services import ollama_service, comfyui_service
from config import settings as app_settings

router = APIRouter(tags=["settings"])

DEFAULT_SETTINGS = {
    "local_only_mode": ("true", "boolean"),
    "cloud_upload_approval": ("always_ask", "string"),
    "ollama_model": ("llama3.2", "string"),
    "ollama_base_url": ("http://localhost:11434", "string"),
    "comfyui_base_url": ("http://localhost:8188", "string"),
    "user_mode": ("beginner", "string"),
    "default_language": ("english", "string"),
    "default_storyboard_count": ("3", "integer"),
    "default_resolution": ("768x512", "string"),
    "per_job_spend_limit": ("10.00", "float"),
    "monthly_spend_limit": ("50.00", "float"),
}


def _ensure_defaults(db: Session):
    for key, (value, vtype) in DEFAULT_SETTINGS.items():
        exists = db.query(m.AppSetting).filter(m.AppSetting.key == key).first()
        if not exists:
            db.add(m.AppSetting(key=key, value=value, value_type=vtype))
    db.commit()


@router.get("/settings", response_model=List[s.SettingOut])
def get_settings(db: Session = Depends(get_db)):
    _ensure_defaults(db)
    return db.query(m.AppSetting).order_by(m.AppSetting.key).all()


@router.put("/settings", response_model=s.SettingOut)
def update_setting(body: s.SettingUpdate, db: Session = Depends(get_db)):
    setting = db.query(m.AppSetting).filter(m.AppSetting.key == body.key).first()
    if setting:
        setting.value = body.value
        setting.value_type = body.value_type
    else:
        setting = m.AppSetting(key=body.key, value=body.value, value_type=body.value_type)
        db.add(setting)
    db.commit()
    db.refresh(setting)
    return setting


@router.get("/system/status", response_model=s.SystemStatus)
async def system_status(db: Session = Depends(get_db)):
    _ensure_defaults(db)

    ollama_setting = db.query(m.AppSetting).filter(m.AppSetting.key == "ollama_base_url").first()
    comfy_setting = db.query(m.AppSetting).filter(m.AppSetting.key == "comfyui_base_url").first()
    local_only_setting = db.query(m.AppSetting).filter(m.AppSetting.key == "local_only_mode").first()

    ollama_url = ollama_setting.value if ollama_setting else "http://localhost:11434"
    comfy_url = comfy_setting.value if comfy_setting else "http://localhost:8188"
    local_only = (local_only_setting.value == "true") if local_only_setting else True

    ollama_ok = await ollama_service.check_available()
    comfy_ok = await comfyui_service.check_available()

    return s.SystemStatus(
        ollama=s.ServiceStatus(
            name="Ollama",
            available=ollama_ok,
            url=ollama_url,
            details="Local LLM for script and scene generation" if ollama_ok else "Not reachable — start with: ollama serve",
        ),
        comfyui=s.ServiceStatus(
            name="ComfyUI",
            available=comfy_ok,
            url=comfy_url,
            details="Local image generation engine" if comfy_ok else "Not reachable — start ComfyUI on port 8188",
        ),
        local_only_mode=local_only,
    )
