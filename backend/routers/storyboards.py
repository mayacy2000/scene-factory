from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from typing import List

from database import get_db
import models as m
import schemas as s
from services import comfyui_service, ollama_service, storage_service

router = APIRouter(prefix="/shots", tags=["storyboards"])


def _get_shot(shot_id: str, db: Session) -> m.Shot:
    shot = db.query(m.Shot).filter(m.Shot.id == shot_id).first()
    if not shot:
        raise HTTPException(404, "Shot not found")
    return shot


@router.get("/{shot_id}/storyboards", response_model=List[s.StoryboardVersionOut])
def list_storyboards(shot_id: str, db: Session = Depends(get_db)):
    _get_shot(shot_id, db)
    return (
        db.query(m.StoryboardVersion)
        .filter(m.StoryboardVersion.shot_id == shot_id)
        .order_by(m.StoryboardVersion.version_number)
        .all()
    )


@router.post("/{shot_id}/storyboards/generate")
async def generate_storyboards(
    shot_id: str,
    body: s.StoryboardGenerateRequest,
    db: Session = Depends(get_db),
):
    shot = _get_shot(shot_id, db)
    scene = db.query(m.Scene).filter(m.Scene.id == shot.scene_id).first()
    project_id = scene.project_id if scene else None

    comfy_available = await comfyui_service.check_available()

    existing_count = db.query(m.StoryboardVersion).filter(m.StoryboardVersion.shot_id == shot_id).count()

    results = []
    for i in range(body.count):
        version_number = existing_count + i + 1

        prompt = shot.prompt or ""
        if not prompt or len(prompt) < 20:
            ollama_ok = await ollama_service.check_available()
            if ollama_ok:
                chars = shot.characters or []
                prompt = await ollama_service.generate_storyboard_prompt(
                    shot_description=shot.description or "cinematic scene",
                    style=body.style or shot.style or "cinematic",
                    characters=chars,
                    location=shot.location or "",
                )
            else:
                prompt = f"{shot.description or 'cinematic scene'}, {shot.style or 'dramatic lighting'}, high quality, cinematic"

        sb = m.StoryboardVersion(
            shot_id=shot_id,
            version_number=version_number,
            prompt_used=prompt,
            negative_prompt_used=shot.negative_prompt or "blurry, low quality, distorted",
            style=body.style or shot.style,
            camera_angle=body.camera_angle,
            lighting=body.lighting or shot.lighting,
            steps=body.steps,
            cfg_scale=body.cfg_scale,
            resolution=body.resolution,
            approval_status="pending",
        )

        if comfy_available:
            try:
                result = await comfyui_service.generate_storyboard_image(
                    prompt=prompt,
                    negative_prompt=shot.negative_prompt or "",
                    seed=body.seed if body.seed else -1,
                    steps=body.steps,
                    cfg_scale=body.cfg_scale,
                    resolution=body.resolution,
                    model=body.model,
                    output_prefix=f"sb_{shot_id[:8]}_v{version_number}",
                )
                sb.seed = result.get("seed")
                sb.model_used = result.get("model")
                sb.image_path = f"pending:{result['prompt_id']}"
            except Exception as e:
                sb.image_path = None
        else:
            sb.image_path = None

        db.add(sb)
        results.append(sb)

    db.commit()
    for sb in results:
        db.refresh(sb)

    return [s.StoryboardVersionOut.model_validate(sb) for sb in results]


@router.post("/{shot_id}/storyboards/{sb_id}/approve")
def approve_storyboard(shot_id: str, sb_id: str, db: Session = Depends(get_db)):
    sb = db.query(m.StoryboardVersion).filter(
        m.StoryboardVersion.id == sb_id,
        m.StoryboardVersion.shot_id == shot_id,
    ).first()
    if not sb:
        raise HTTPException(404, "Storyboard not found")

    db.query(m.StoryboardVersion).filter(
        m.StoryboardVersion.shot_id == shot_id,
        m.StoryboardVersion.id != sb_id,
    ).update({"approval_status": "rejected"})

    sb.approval_status = "approved"
    shot = _get_shot(shot_id, db)
    shot.approval_status = "approved"
    db.commit()
    return {"status": "approved", "storyboard_id": sb_id}


@router.post("/{shot_id}/storyboards/{sb_id}/reject")
def reject_storyboard(shot_id: str, sb_id: str, db: Session = Depends(get_db)):
    sb = db.query(m.StoryboardVersion).filter(
        m.StoryboardVersion.id == sb_id,
        m.StoryboardVersion.shot_id == shot_id,
    ).first()
    if not sb:
        raise HTTPException(404, "Storyboard not found")
    sb.approval_status = "rejected"
    db.commit()
    return {"status": "rejected", "storyboard_id": sb_id}


@router.post("/{shot_id}/storyboards/{sb_id}/feedback")
def storyboard_feedback(shot_id: str, sb_id: str, body: s.StoryboardFeedback, db: Session = Depends(get_db)):
    sb = db.query(m.StoryboardVersion).filter(
        m.StoryboardVersion.id == sb_id,
        m.StoryboardVersion.shot_id == shot_id,
    ).first()
    if not sb:
        raise HTTPException(404, "Storyboard not found")

    fb = m.Feedback(
        shot_id=shot_id,
        version=sb.version_number,
        feedback_text=body.feedback_text,
        locked_elements=body.locked_elements or [],
        status="regenerate_requested",
    )
    db.add(fb)
    db.commit()
    return {"status": "feedback_saved", "storyboard_id": sb_id}


@router.get("/{shot_id}/storyboards/{sb_id}/status")
async def storyboard_status(shot_id: str, sb_id: str, db: Session = Depends(get_db)):
    sb = db.query(m.StoryboardVersion).filter(
        m.StoryboardVersion.id == sb_id,
        m.StoryboardVersion.shot_id == shot_id,
    ).first()
    if not sb:
        raise HTTPException(404, "Storyboard not found")
    if not sb.image_path or not sb.image_path.startswith("pending:"):
        return {"status": "ready" if sb.image_path else "no_image", "image_path": sb.image_path}

    prompt_id = sb.image_path[len("pending:"):]
    resolved = await _resolve_pending(sb, prompt_id, db)
    return {"status": "ready" if resolved else "pending", "image_path": sb.image_path}


@router.get("/{shot_id}/storyboards/{sb_id}/image")
async def serve_storyboard_image(shot_id: str, sb_id: str, db: Session = Depends(get_db)):
    sb = db.query(m.StoryboardVersion).filter(
        m.StoryboardVersion.id == sb_id,
        m.StoryboardVersion.shot_id == shot_id,
    ).first()
    if not sb or not sb.image_path:
        raise HTTPException(404, "Storyboard image not found")

    if sb.image_path.startswith("pending:"):
        prompt_id = sb.image_path[len("pending:"):]
        resolved = await _resolve_pending(sb, prompt_id, db)
        if not resolved:
            raise HTTPException(202, "Image is still being generated")

    p = Path(sb.image_path)
    if not p.exists():
        raise HTTPException(404, "Image file missing from disk")
    return FileResponse(str(p), media_type="image/png")


async def _resolve_pending(sb: m.StoryboardVersion, prompt_id: str, db: Session) -> bool:
    """Try to resolve a pending ComfyUI job. Returns True if image is now on disk."""
    import httpx
    from config import settings

    try:
        async with httpx.AsyncClient(timeout=5) as client:
            r = await client.get(f"{settings.comfyui_base_url}/history/{prompt_id}")
            history = r.json()
    except Exception:
        return False

    if prompt_id not in history:
        return False

    job = history[prompt_id]
    if not job.get("status", {}).get("completed"):
        return False

    outputs = job.get("outputs", {})
    comfy_out = Path(settings.comfyui_output_dir)
    src_path: Path | None = None
    for node_output in outputs.values():
        for img in node_output.get("images", []):
            filename = img["filename"]
            subfolder = img.get("subfolder", "")
            candidate = (comfy_out / subfolder / filename) if subfolder else (comfy_out / filename)
            if candidate.exists():
                src_path = candidate
                break
        if src_path:
            break

    if not src_path:
        return False

    shot = db.query(m.Shot).filter(m.Shot.id == sb.shot_id).first()
    scene = db.query(m.Scene).filter(m.Scene.id == shot.scene_id).first() if shot else None
    if scene:
        dest_folder = storage_service.storyboard_folder(
            scene.project_id, scene.scene_number, shot.shot_number
        )
    else:
        dest_folder = Path(settings.projects_base_path) / "storyboards"
        dest_folder.mkdir(parents=True, exist_ok=True)

    dest = dest_folder / f"v{sb.version_number}{src_path.suffix}"
    import shutil
    shutil.copy2(src_path, dest)
    sb.image_path = str(dest)
    db.commit()
    return True
