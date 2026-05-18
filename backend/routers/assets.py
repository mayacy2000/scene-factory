import io
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from typing import List, Optional

from database import get_db
import models as m
import schemas as s
from services import storage_service

router = APIRouter(prefix="/projects/{project_id}/assets", tags=["assets"])

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
ALLOWED_AUDIO_TYPES = {"audio/mpeg", "audio/wav", "audio/ogg", "audio/m4a", "audio/mp4"}
ALLOWED_VIDEO_TYPES = {"video/mp4", "video/quicktime", "video/x-msvideo"}
MAX_FILE_SIZE = 100 * 1024 * 1024  # 100 MB


@router.get("", response_model=List[s.AssetOut])
def list_assets(
    project_id: str,
    asset_type: Optional[str] = None,
    db: Session = Depends(get_db),
):
    q = db.query(m.Asset).filter(m.Asset.project_id == project_id)
    if asset_type:
        q = q.filter(m.Asset.asset_type == asset_type)
    return q.order_by(m.Asset.created_at.desc()).all()


@router.post("", response_model=s.AssetOut, status_code=status.HTTP_201_CREATED)
async def upload_asset(
    project_id: str,
    file: UploadFile = File(...),
    asset_type: str = Form(...),
    name: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    linked_entity_id: Optional[str] = Form(None),
    linked_entity_type: Optional[str] = Form(None),
    db: Session = Depends(get_db),
):
    proj = db.query(m.Project).filter(m.Project.id == project_id).first()
    if not proj:
        raise HTTPException(404, "Project not found")

    data = await file.read()
    if len(data) > MAX_FILE_SIZE:
        raise HTTPException(413, "File too large (max 100 MB)")

    file_path = storage_service.save_uploaded_file(
        project_id=project_id,
        asset_type=asset_type,
        filename=file.filename or "upload",
        data=data,
    )

    asset = m.Asset(
        project_id=project_id,
        asset_type=asset_type,
        name=name or file.filename,
        description=description,
        file_path=file_path,
        file_name=file.filename,
        file_size=len(data),
        mime_type=file.content_type,
        linked_entity_id=linked_entity_id,
        linked_entity_type=linked_entity_type,
    )
    db.add(asset)
    db.commit()
    db.refresh(asset)
    return asset


@router.get("/{asset_id}", response_model=s.AssetOut)
def get_asset(project_id: str, asset_id: str, db: Session = Depends(get_db)):
    asset = db.query(m.Asset).filter(m.Asset.id == asset_id, m.Asset.project_id == project_id).first()
    if not asset:
        raise HTTPException(404, "Asset not found")
    return asset


@router.get("/{asset_id}/file")
def serve_asset_file(project_id: str, asset_id: str, db: Session = Depends(get_db)):
    asset = db.query(m.Asset).filter(m.Asset.id == asset_id, m.Asset.project_id == project_id).first()
    if not asset or not asset.file_path:
        raise HTTPException(404, "Asset file not found")
    p = Path(asset.file_path)
    if not p.exists():
        raise HTTPException(404, "Asset file missing from disk")
    return FileResponse(str(p), media_type=asset.mime_type or "application/octet-stream")


@router.delete("/{asset_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_asset(project_id: str, asset_id: str, db: Session = Depends(get_db)):
    asset = db.query(m.Asset).filter(m.Asset.id == asset_id, m.Asset.project_id == project_id).first()
    if not asset:
        raise HTTPException(404, "Asset not found")
    if asset.file_path:
        p = Path(asset.file_path)
        if p.exists():
            p.unlink()
    db.delete(asset)
    db.commit()
