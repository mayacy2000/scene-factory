from pathlib import Path
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from typing import List

from database import get_db
import models as m
import schemas as s
from services import video_service, storage_service

router = APIRouter(prefix="/projects/{project_id}/video", tags=["video"])


def _get_project(project_id: str, db: Session) -> m.Project:
    proj = db.query(m.Project).filter(m.Project.id == project_id).first()
    if not proj:
        raise HTTPException(404, "Project not found")
    return proj


def _collect_shots(project_id: str, scene_ids: list[str] | None, db: Session) -> list[dict]:
    """
    Gather shots that have an approved (or any) storyboard image, ordered scene→shot.
    Returns list of {image_path, duration, shot_id, scene_id}.
    """
    query = (
        db.query(m.Scene)
        .filter(m.Scene.project_id == project_id)
        .order_by(m.Scene.scene_number)
    )
    if scene_ids:
        query = query.filter(m.Scene.id.in_(scene_ids))
    scenes = query.all()

    items = []
    for scene in scenes:
        shots = sorted(scene.shots, key=lambda s: s.shot_number)
        for shot in shots:
            sb = (
                db.query(m.StoryboardVersion)
                .filter(m.StoryboardVersion.shot_id == shot.id)
                .filter(m.StoryboardVersion.approval_status == "approved")
                .order_by(m.StoryboardVersion.version_number.desc())
                .first()
            )
            if not sb:
                sb = (
                    db.query(m.StoryboardVersion)
                    .filter(m.StoryboardVersion.shot_id == shot.id)
                    .filter(~m.StoryboardVersion.image_path.like("pending:%"))
                    .filter(m.StoryboardVersion.image_path.isnot(None))
                    .order_by(m.StoryboardVersion.version_number.desc())
                    .first()
                )
            if sb and sb.image_path and not sb.image_path.startswith("pending:"):
                p = Path(sb.image_path)
                if p.exists():
                    items.append({
                        "image_path": str(p),
                        "duration": shot.duration_seconds or 4.0,
                        "shot_id": shot.id,
                        "scene_id": scene.id,
                        "caption": shot.description or "",
                    })
    return items


async def _do_render(preview_id: str, project_id: str, shots: list[dict], output_path: Path,
                     resolution: str, fps: int, crossfade: float, show_captions: bool = False):
    from database import SessionLocal
    db = SessionLocal()
    try:
        preview = db.query(m.ProjectVideoPreview).filter(m.ProjectVideoPreview.id == preview_id).first()
        if not preview:
            return
        preview.status = "rendering"
        db.commit()

        try:
            result = await video_service.render_preview(
                shots=shots,
                output_path=output_path,
                resolution=resolution,
                fps=fps,
                crossfade=crossfade,
                show_captions=show_captions,
            )
            preview.video_path = result["path"]
            preview.duration_seconds = result["duration_seconds"]
            preview.shot_count = result["shot_count"]
            preview.status = "ready"
            preview.completed_at = datetime.utcnow()
        except Exception as e:
            preview.status = "failed"
            preview.error_message = str(e)[:1000]

        db.commit()
    finally:
        db.close()


@router.post("/render", response_model=s.ProjectVideoPreviewOut, status_code=202)
async def render_video(
    project_id: str,
    body: s.VideoRenderRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    proj = _get_project(project_id, db)

    shots = _collect_shots(project_id, body.scene_ids, db)
    if not shots:
        raise HTTPException(400, "No storyboard images found. Generate storyboards first.")

    existing_count = db.query(m.ProjectVideoPreview).filter(
        m.ProjectVideoPreview.project_id == project_id
    ).count()

    preview_folder = Path(storage_service.project_folder(project_id)) / "previews"
    version_number = existing_count + 1
    output_path = preview_folder / f"preview_v{version_number}.mp4"

    preview = m.ProjectVideoPreview(
        project_id=project_id,
        version_number=version_number,
        resolution=body.resolution,
        fps=body.fps,
        scene_count=len({s["scene_id"] for s in shots}),
        shot_count=len(shots),
        status="pending",
    )
    db.add(preview)
    db.commit()
    db.refresh(preview)

    background_tasks.add_task(
        _do_render,
        preview_id=preview.id,
        project_id=project_id,
        shots=shots,
        output_path=output_path,
        resolution=body.resolution,
        fps=body.fps,
        crossfade=body.crossfade_duration,
        show_captions=body.show_captions,
    )

    return preview


@router.get("/previews", response_model=List[s.ProjectVideoPreviewOut])
def list_previews(project_id: str, db: Session = Depends(get_db)):
    _get_project(project_id, db)
    return (
        db.query(m.ProjectVideoPreview)
        .filter(m.ProjectVideoPreview.project_id == project_id)
        .order_by(m.ProjectVideoPreview.version_number.desc())
        .all()
    )


@router.get("/previews/{preview_id}", response_model=s.ProjectVideoPreviewOut)
def get_preview(project_id: str, preview_id: str, db: Session = Depends(get_db)):
    _get_project(project_id, db)
    preview = db.query(m.ProjectVideoPreview).filter(
        m.ProjectVideoPreview.id == preview_id,
        m.ProjectVideoPreview.project_id == project_id,
    ).first()
    if not preview:
        raise HTTPException(404, "Preview not found")
    return preview


@router.get("/previews/{preview_id}/stream")
def stream_preview(project_id: str, preview_id: str, db: Session = Depends(get_db)):
    _get_project(project_id, db)
    preview = db.query(m.ProjectVideoPreview).filter(
        m.ProjectVideoPreview.id == preview_id,
        m.ProjectVideoPreview.project_id == project_id,
    ).first()
    if not preview:
        raise HTTPException(404, "Preview not found")
    if preview.status == "rendering":
        raise HTTPException(202, "Video is still rendering")
    if preview.status == "failed":
        raise HTTPException(500, f"Render failed: {preview.error_message}")
    if not preview.video_path or not Path(preview.video_path).exists():
        raise HTTPException(404, "Video file not found")
    return FileResponse(
        preview.video_path,
        media_type="video/mp4",
        filename=f"preview_v{preview.version_number}.mp4",
    )
