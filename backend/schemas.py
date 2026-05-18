from pydantic import BaseModel, Field
from typing import Optional, List, Any
from datetime import datetime


# ── Projects ──────────────────────────────────────────────────────────────────

class ProjectCreate(BaseModel):
    title: str
    description: Optional[str] = None
    genre: Optional[str] = None
    tone: Optional[str] = None
    visual_style: Optional[str] = None
    user_mode: str = "beginner"
    local_only: bool = True
    language: str = "english"


class ProjectUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    genre: Optional[str] = None
    tone: Optional[str] = None
    visual_style: Optional[str] = None
    status: Optional[str] = None
    user_mode: Optional[str] = None
    local_only: Optional[bool] = None
    language: Optional[str] = None


class ProjectOut(BaseModel):
    id: str
    title: str
    description: Optional[str]
    genre: Optional[str]
    tone: Optional[str]
    visual_style: Optional[str]
    status: str
    user_mode: str
    local_only: bool
    folder_path: Optional[str]
    language: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# ── Stories ───────────────────────────────────────────────────────────────────

class StoryCreate(BaseModel):
    prompt: str


class StoryVersionOut(BaseModel):
    id: str
    story_id: str
    version_number: int
    script_content: Optional[str]
    scene_outline: Optional[Any]
    visual_style_recommendation: Optional[str]
    approval_status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class StoryOut(BaseModel):
    id: str
    project_id: str
    prompt: str
    created_at: datetime
    versions: List[StoryVersionOut] = []

    model_config = {"from_attributes": True}


class ScriptGenerateRequest(BaseModel):
    language: str = "english"


class StoryBibleOut(BaseModel):
    id: str
    project_id: str
    title: Optional[str]
    genre: Optional[str]
    tone: Optional[str]
    visual_style: Optional[str]
    narrative_summary: Optional[str]
    main_themes: Optional[Any]
    character_arcs: Optional[Any]
    timeline: Optional[Any]
    important_events: Optional[Any]
    voice_narration_style: Optional[str]
    continuity_rules: Optional[Any]
    approved_visual_refs: Optional[Any]
    approved_prompt_rules: Optional[Any]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# ── Scenes & Shots ────────────────────────────────────────────────────────────

class SceneCreate(BaseModel):
    scene_number: int
    title: Optional[str] = None
    description: Optional[str] = None
    location: Optional[str] = None
    mood: Optional[str] = None
    time_of_day: str = "day"


class SceneOut(BaseModel):
    id: str
    project_id: str
    scene_number: int
    title: Optional[str]
    description: Optional[str]
    location: Optional[str]
    mood: Optional[str]
    time_of_day: Optional[str]
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class ShotCreate(BaseModel):
    shot_number: int
    description: Optional[str] = None
    duration_preset: str = "standard_cinematic"
    duration_seconds: float = 4.0
    camera_movement: Optional[str] = None
    lighting: Optional[str] = None
    mood: Optional[str] = None
    style: Optional[str] = None
    characters: Optional[List[str]] = None
    objects: Optional[List[str]] = None
    audio_cues: Optional[str] = None
    location: Optional[str] = None
    prompt: Optional[str] = None
    negative_prompt: Optional[str] = None


class ShotUpdate(BaseModel):
    description: Optional[str] = None
    duration_preset: Optional[str] = None
    duration_seconds: Optional[float] = None
    camera_movement: Optional[str] = None
    lighting: Optional[str] = None
    mood: Optional[str] = None
    style: Optional[str] = None
    characters: Optional[List[str]] = None
    objects: Optional[List[str]] = None
    audio_cues: Optional[str] = None
    location: Optional[str] = None
    prompt: Optional[str] = None
    negative_prompt: Optional[str] = None
    approval_status: Optional[str] = None


class ShotOut(BaseModel):
    id: str
    scene_id: str
    shot_number: int
    description: Optional[str]
    duration_preset: str
    duration_seconds: float
    camera_movement: Optional[str]
    lighting: Optional[str]
    mood: Optional[str]
    style: Optional[str]
    characters: Optional[Any]
    objects: Optional[Any]
    audio_cues: Optional[str]
    location: Optional[str]
    prompt: Optional[str]
    negative_prompt: Optional[str]
    approval_status: str
    created_at: datetime

    model_config = {"from_attributes": True}


# ── Assets ────────────────────────────────────────────────────────────────────

class AssetOut(BaseModel):
    id: str
    project_id: str
    asset_type: Optional[str]
    name: Optional[str]
    description: Optional[str]
    file_path: Optional[str]
    file_name: Optional[str]
    file_size: Optional[int]
    mime_type: Optional[str]
    quality_score: Optional[float]
    lighting_quality: Optional[str]
    image_clarity: Optional[str]
    background_complexity: Optional[str]
    suitability: Optional[str]
    suggested_fixes: Optional[str]
    linked_entity_id: Optional[str]
    linked_entity_type: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}


# ── Storyboards ───────────────────────────────────────────────────────────────

class StoryboardGenerateRequest(BaseModel):
    count: int = 3
    style: Optional[str] = None
    camera_angle: Optional[str] = None
    lighting: Optional[str] = None
    seed: Optional[int] = None
    steps: int = 20
    cfg_scale: float = 7.0
    resolution: str = "768x512"
    model: Optional[str] = None


class StoryboardFeedback(BaseModel):
    feedback_text: str
    locked_elements: Optional[List[str]] = None


class StoryboardVersionOut(BaseModel):
    id: str
    shot_id: str
    version_number: int
    image_path: Optional[str]
    prompt_used: Optional[str]
    seed: Optional[int]
    style: Optional[str]
    camera_angle: Optional[str]
    lighting: Optional[str]
    model_used: Optional[str]
    resolution: Optional[str]
    approval_status: str
    created_at: datetime

    model_config = {"from_attributes": True}


# ── Feedback ──────────────────────────────────────────────────────────────────

class FeedbackCreate(BaseModel):
    version: int
    feedback_text: str
    locked_elements: Optional[List[str]] = None


class FeedbackOut(BaseModel):
    id: str
    shot_id: str
    version: Optional[int]
    feedback_text: Optional[str]
    locked_elements: Optional[Any]
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


# ── Settings ──────────────────────────────────────────────────────────────────

class SettingUpdate(BaseModel):
    key: str
    value: str
    value_type: str = "string"


class SettingOut(BaseModel):
    id: str
    key: str
    value: Optional[str]
    value_type: str
    updated_at: datetime

    model_config = {"from_attributes": True}


# ── System ────────────────────────────────────────────────────────────────────

class ServiceStatus(BaseModel):
    name: str
    available: bool
    url: str
    details: Optional[str] = None


class SystemStatus(BaseModel):
    ollama: ServiceStatus
    comfyui: ServiceStatus
    local_only_mode: bool


# ── Video ─────────────────────────────────────────────────────────────────────

class VideoRenderRequest(BaseModel):
    resolution: str = "768x512"
    fps: int = 24
    crossfade_duration: float = 0.5
    scene_ids: Optional[List[str]] = None   # None = all scenes
    show_captions: bool = False


class ProjectVideoPreviewOut(BaseModel):
    id: str
    project_id: str
    version_number: int
    video_path: Optional[str]
    resolution: Optional[str]
    duration_seconds: Optional[float]
    shot_count: Optional[int]
    scene_count: Optional[int]
    fps: Optional[int]
    status: str
    error_message: Optional[str]
    created_at: datetime
    completed_at: Optional[datetime]

    model_config = {"from_attributes": True}
