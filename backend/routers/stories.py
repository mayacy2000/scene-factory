from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, status
from sqlalchemy.orm import Session
from typing import List, Optional
import asyncio

from database import get_db
import models as m
import schemas as s
from services import ollama_service

router = APIRouter(prefix="/projects/{project_id}", tags=["stories"])


def _get_project(project_id: str, db: Session) -> m.Project:
    proj = db.query(m.Project).filter(m.Project.id == project_id).first()
    if not proj:
        raise HTTPException(404, "Project not found")
    return proj


@router.get("/story", response_model=Optional[s.StoryOut])
def get_story(project_id: str, db: Session = Depends(get_db)):
    _get_project(project_id, db)
    story = db.query(m.Story).filter(m.Story.project_id == project_id).order_by(m.Story.created_at.desc()).first()
    return story


@router.post("/story", response_model=s.StoryOut, status_code=status.HTTP_201_CREATED)
def create_story(project_id: str, body: s.StoryCreate, db: Session = Depends(get_db)):
    _get_project(project_id, db)
    story = m.Story(project_id=project_id, prompt=body.prompt)
    db.add(story)
    db.commit()
    db.refresh(story)
    return story


@router.post("/story/generate-script", response_model=s.StoryVersionOut)
async def generate_script(
    project_id: str,
    body: s.ScriptGenerateRequest,
    db: Session = Depends(get_db),
):
    proj = _get_project(project_id, db)
    story = db.query(m.Story).filter(m.Story.project_id == project_id).order_by(m.Story.created_at.desc()).first()
    if not story:
        raise HTTPException(400, "No story prompt found. Create a story first.")

    available = await ollama_service.check_available()
    if not available:
        raise HTTPException(503, "Ollama is not available. Please start Ollama and try again.")

    lang = body.language or proj.language or "english"
    script_text = await ollama_service.generate_script(story.prompt, lang)

    existing_count = db.query(m.StoryVersion).filter(m.StoryVersion.story_id == story.id).count()
    version = m.StoryVersion(
        story_id=story.id,
        version_number=existing_count + 1,
        script_content=script_text,
        visual_style_recommendation="cinematic",
        approval_status="draft",
    )
    db.add(version)
    db.commit()
    db.refresh(version)
    return version


@router.post("/story/generate-scenes")
async def generate_scenes(project_id: str, db: Session = Depends(get_db)):
    proj = _get_project(project_id, db)
    story = db.query(m.Story).filter(m.Story.project_id == project_id).order_by(m.Story.created_at.desc()).first()
    if not story:
        raise HTTPException(400, "No story found.")

    latest_version = (
        db.query(m.StoryVersion)
        .filter(m.StoryVersion.story_id == story.id)
        .order_by(m.StoryVersion.version_number.desc())
        .first()
    )
    if not latest_version or not latest_version.script_content:
        raise HTTPException(400, "No script found. Generate a script first.")

    available = await ollama_service.check_available()
    if not available:
        raise HTTPException(503, "Ollama is not available.")

    breakdown = await ollama_service.generate_scene_breakdown(
        script=latest_version.script_content,
        prompt=story.prompt,
    )

    if "error" in breakdown:
        raise HTTPException(500, f"Scene breakdown generation failed: {breakdown.get('error')}")

    db.query(m.Scene).filter(m.Scene.project_id == project_id).delete()

    created_scenes = []
    for scene_data in breakdown.get("scenes", []):
        scene = m.Scene(
            project_id=project_id,
            story_version_id=latest_version.id,
            scene_number=scene_data.get("scene_number", 1),
            title=scene_data.get("title", ""),
            description=scene_data.get("description", ""),
            location=scene_data.get("location", ""),
            mood=scene_data.get("mood", ""),
            time_of_day=scene_data.get("time_of_day", "day"),
        )
        db.add(scene)
        db.flush()

        for shot_data in scene_data.get("shots", []):
            shot = m.Shot(
                scene_id=scene.id,
                shot_number=shot_data.get("shot_number", 1),
                description=shot_data.get("description", ""),
                duration_preset=shot_data.get("duration_preset", "standard_cinematic"),
                duration_seconds=_preset_to_seconds(shot_data.get("duration_preset", "standard_cinematic")),
                camera_movement=shot_data.get("camera_movement", ""),
                lighting=shot_data.get("lighting", ""),
                mood=shot_data.get("mood", ""),
                style=shot_data.get("style", "cinematic"),
                characters=shot_data.get("characters", []),
                objects=shot_data.get("objects", []),
                audio_cues=shot_data.get("audio_cues", ""),
                location=shot_data.get("location", ""),
                prompt=shot_data.get("suggested_prompt", ""),
            )
            db.add(shot)

        created_scenes.append(scene)

    latest_version.scene_outline = breakdown.get("scenes", [])
    latest_version.visual_style_recommendation = breakdown.get("visual_style_recommendation", "cinematic")

    db.commit()
    return {
        "scenes_created": len(created_scenes),
        "visual_style": breakdown.get("visual_style_recommendation"),
    }


@router.post("/story/generate-bible", response_model=s.StoryBibleOut)
async def generate_bible(project_id: str, db: Session = Depends(get_db)):
    proj = _get_project(project_id, db)
    story = db.query(m.Story).filter(m.Story.project_id == project_id).order_by(m.Story.created_at.desc()).first()
    if not story:
        raise HTTPException(400, "No story found.")

    latest_version = (
        db.query(m.StoryVersion)
        .filter(m.StoryVersion.story_id == story.id)
        .order_by(m.StoryVersion.version_number.desc())
        .first()
    )

    available = await ollama_service.check_available()
    if not available:
        raise HTTPException(503, "Ollama is not available.")

    characters = [c.name for c in db.query(m.Character).filter(m.Character.project_id == project_id).all()]
    locations = [l.name for l in db.query(m.Location).filter(m.Location.project_id == project_id).all()]

    bible_data = await ollama_service.generate_story_bible(
        prompt=story.prompt,
        script=latest_version.script_content if latest_version else "",
        characters=characters,
        locations=locations,
    )

    existing = db.query(m.StoryBible).filter(m.StoryBible.project_id == project_id).first()
    if existing:
        for k, v in bible_data.items():
            if hasattr(existing, k) and k not in ("error", "raw"):
                setattr(existing, k, v)
        bible = existing
    else:
        filtered = {k: v for k, v in bible_data.items() if k not in ("error", "raw") and hasattr(m.StoryBible, k)}
        bible = m.StoryBible(project_id=project_id, **filtered)
        db.add(bible)

    db.commit()
    db.refresh(bible)
    return bible


@router.get("/story/versions", response_model=List[s.StoryVersionOut])
def list_versions(project_id: str, db: Session = Depends(get_db)):
    _get_project(project_id, db)
    story = db.query(m.Story).filter(m.Story.project_id == project_id).order_by(m.Story.created_at.desc()).first()
    if not story:
        return []
    return story.versions


@router.post("/story/approve")
def approve_version(project_id: str, version_id: str, db: Session = Depends(get_db)):
    _get_project(project_id, db)
    version = db.query(m.StoryVersion).filter(m.StoryVersion.id == version_id).first()
    if not version:
        raise HTTPException(404, "Version not found")
    version.approval_status = "approved"
    db.commit()
    return {"status": "approved", "version_id": version_id}


@router.get("/scenes", response_model=List[s.SceneOut])
def list_scenes(project_id: str, db: Session = Depends(get_db)):
    _get_project(project_id, db)
    return db.query(m.Scene).filter(m.Scene.project_id == project_id).order_by(m.Scene.scene_number).all()


@router.post("/scenes", response_model=s.SceneOut, status_code=201)
def create_scene(project_id: str, body: s.SceneCreate, db: Session = Depends(get_db)):
    _get_project(project_id, db)
    scene = m.Scene(project_id=project_id, **body.model_dump())
    db.add(scene)
    db.commit()
    db.refresh(scene)
    return scene


@router.post("/scenes/{scene_id}/shots/generate")
async def generate_shots_for_scene(project_id: str, scene_id: str, db: Session = Depends(get_db)):
    scene = db.query(m.Scene).filter(m.Scene.id == scene_id, m.Scene.project_id == project_id).first()
    if not scene:
        raise HTTPException(404, "Scene not found")

    story = db.query(m.Story).filter(m.Story.project_id == project_id).order_by(m.Story.created_at.desc()).first()

    available = await ollama_service.check_available()
    if not available:
        raise HTTPException(503, "Ollama is not available.")

    breakdown = await ollama_service.generate_shots_for_scene(
        scene_title=scene.title or f"Scene {scene.scene_number}",
        scene_description=scene.description or "",
        location=scene.location or "",
        mood=scene.mood or "",
        story_prompt=story.prompt if story else "",
    )

    db.query(m.Shot).filter(m.Shot.scene_id == scene_id).delete()
    created = []
    for i, shot_data in enumerate(breakdown.get("shots", []), 1):
        shot = m.Shot(
            scene_id=scene_id,
            shot_number=shot_data.get("shot_number", i),
            description=shot_data.get("description", ""),
            duration_preset=shot_data.get("duration_preset", "standard_cinematic"),
            duration_seconds=_preset_to_seconds(shot_data.get("duration_preset", "standard_cinematic")),
            camera_movement=shot_data.get("camera_movement", ""),
            lighting=shot_data.get("lighting", ""),
            mood=shot_data.get("mood", ""),
            style=shot_data.get("style", "cinematic"),
            characters=shot_data.get("characters", []),
            objects=shot_data.get("objects", []),
            audio_cues=shot_data.get("audio_cues", ""),
            location=shot_data.get("location", scene.location or ""),
            prompt=shot_data.get("suggested_prompt", ""),
        )
        db.add(shot)
        created.append(shot)

    db.commit()
    for shot in created:
        db.refresh(shot)
    return [s.ShotOut.model_validate(shot) for shot in created]


@router.post("/scenes/{scene_id}/shots", response_model=s.ShotOut, status_code=201)
def create_shot(project_id: str, scene_id: str, body: s.ShotCreate, db: Session = Depends(get_db)):
    scene = db.query(m.Scene).filter(m.Scene.id == scene_id, m.Scene.project_id == project_id).first()
    if not scene:
        raise HTTPException(404, "Scene not found")
    shot = m.Shot(scene_id=scene_id, **body.model_dump())
    db.add(shot)
    db.commit()
    db.refresh(shot)
    return shot


@router.get("/scenes/{scene_id}/shots", response_model=List[s.ShotOut])
def list_shots(project_id: str, scene_id: str, db: Session = Depends(get_db)):
    scene = db.query(m.Scene).filter(m.Scene.id == scene_id, m.Scene.project_id == project_id).first()
    if not scene:
        raise HTTPException(404, "Scene not found")
    return scene.shots


@router.put("/scenes/{scene_id}/shots/{shot_id}", response_model=s.ShotOut)
def update_shot(project_id: str, scene_id: str, shot_id: str, body: s.ShotUpdate, db: Session = Depends(get_db)):
    shot = db.query(m.Shot).filter(m.Shot.id == shot_id, m.Shot.scene_id == scene_id).first()
    if not shot:
        raise HTTPException(404, "Shot not found")
    for field, val in body.model_dump(exclude_none=True).items():
        setattr(shot, field, val)
    db.commit()
    db.refresh(shot)
    return shot


@router.post("/scenes/{scene_id}/shots/{shot_id}/feedback", response_model=s.FeedbackOut)
def add_feedback(project_id: str, scene_id: str, shot_id: str, body: s.FeedbackCreate, db: Session = Depends(get_db)):
    shot = db.query(m.Shot).filter(m.Shot.id == shot_id, m.Shot.scene_id == scene_id).first()
    if not shot:
        raise HTTPException(404, "Shot not found")
    fb = m.Feedback(
        shot_id=shot_id,
        version=body.version,
        feedback_text=body.feedback_text,
        locked_elements=body.locked_elements or [],
        status="pending",
    )
    db.add(fb)
    db.commit()
    db.refresh(fb)
    return fb


def _preset_to_seconds(preset: str) -> float:
    return {
        "fast_trailer": 2.5,
        "standard_cinematic": 4.0,
        "slow_dramatic": 6.5,
        "long_atmospheric": 10.0,
    }.get(preset, 4.0)
