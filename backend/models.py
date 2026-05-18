import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Integer, Float, Boolean, Text, JSON,
    DateTime, ForeignKey,
)
from sqlalchemy.orm import relationship
from database import Base


def new_id() -> str:
    return str(uuid.uuid4())


class Project(Base):
    __tablename__ = "projects"

    id = Column(String, primary_key=True, default=new_id)
    title = Column(String(255), nullable=False)
    description = Column(Text)
    genre = Column(String(100))
    tone = Column(String(100))
    visual_style = Column(String(100))
    status = Column(String(50), default="new")          # new | in_progress | complete
    user_mode = Column(String(50), default="beginner")  # beginner | advanced
    local_only = Column(Boolean, default=True)
    folder_path = Column(String(500))
    language = Column(String(50), default="english")    # english | arabic | bilingual
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    stories = relationship("Story", back_populates="project", cascade="all, delete-orphan")
    story_bible = relationship("StoryBible", back_populates="project", uselist=False, cascade="all, delete-orphan")
    characters = relationship("Character", back_populates="project", cascade="all, delete-orphan")
    locations = relationship("Location", back_populates="project", cascade="all, delete-orphan")
    objects = relationship("StoryObject", back_populates="project", cascade="all, delete-orphan")
    assets = relationship("Asset", back_populates="project", cascade="all, delete-orphan")
    scenes = relationship("Scene", back_populates="project", cascade="all, delete-orphan")
    render_jobs = relationship("RenderJob", back_populates="project", cascade="all, delete-orphan")
    exports = relationship("Export", back_populates="project", cascade="all, delete-orphan")
    video_previews = relationship("ProjectVideoPreview", back_populates="project", cascade="all, delete-orphan")


class Story(Base):
    __tablename__ = "stories"

    id = Column(String, primary_key=True, default=new_id)
    project_id = Column(String, ForeignKey("projects.id"), nullable=False)
    prompt = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    project = relationship("Project", back_populates="stories")
    versions = relationship("StoryVersion", back_populates="story", cascade="all, delete-orphan", order_by="StoryVersion.version_number")


class StoryVersion(Base):
    __tablename__ = "story_versions"

    id = Column(String, primary_key=True, default=new_id)
    story_id = Column(String, ForeignKey("stories.id"), nullable=False)
    version_number = Column(Integer, nullable=False)
    script_content = Column(Text)
    scene_outline = Column(JSON)                        # list[{scene_number, title, description}]
    visual_style_recommendation = Column(String(200))
    approval_status = Column(String(50), default="draft")  # draft | approved | rejected
    created_at = Column(DateTime, default=datetime.utcnow)

    story = relationship("Story", back_populates="versions")


class StoryBible(Base):
    __tablename__ = "story_bibles"

    id = Column(String, primary_key=True, default=new_id)
    project_id = Column(String, ForeignKey("projects.id"), unique=True, nullable=False)
    title = Column(String(255))
    genre = Column(String(100))
    tone = Column(String(100))
    visual_style = Column(String(200))
    narrative_summary = Column(Text)
    main_themes = Column(JSON)
    character_arcs = Column(JSON)
    timeline = Column(JSON)
    important_events = Column(JSON)
    voice_narration_style = Column(Text)
    continuity_rules = Column(JSON)
    approved_visual_refs = Column(JSON)
    approved_prompt_rules = Column(JSON)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    project = relationship("Project", back_populates="story_bible")


class Character(Base):
    __tablename__ = "characters"

    id = Column(String, primary_key=True, default=new_id)
    project_id = Column(String, ForeignKey("projects.id"), nullable=False)
    name = Column(String(200), nullable=False)
    age = Column(String(50))
    appearance = Column(Text)
    clothing = Column(Text)
    personality = Column(Text)
    visual_rules = Column(Text)
    voice_type = Column(String(100))
    language = Column(String(100))
    accent = Column(String(100))
    speaking_style = Column(Text)
    arc = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

    project = relationship("Project", back_populates="characters")


class Location(Base):
    __tablename__ = "locations"

    id = Column(String, primary_key=True, default=new_id)
    project_id = Column(String, ForeignKey("projects.id"), nullable=False)
    name = Column(String(200), nullable=False)
    description = Column(Text)
    visual_rules = Column(Text)
    time_period = Column(String(100))
    created_at = Column(DateTime, default=datetime.utcnow)

    project = relationship("Project", back_populates="locations")


class StoryObject(Base):
    __tablename__ = "story_objects"

    id = Column(String, primary_key=True, default=new_id)
    project_id = Column(String, ForeignKey("projects.id"), nullable=False)
    name = Column(String(200), nullable=False)
    description = Column(Text)
    role_in_story = Column(Text)
    continuity_notes = Column(Text)
    scenes_appear_in = Column(JSON)
    created_at = Column(DateTime, default=datetime.utcnow)

    project = relationship("Project", back_populates="objects")


class Asset(Base):
    __tablename__ = "assets"

    id = Column(String, primary_key=True, default=new_id)
    project_id = Column(String, ForeignKey("projects.id"), nullable=False)
    asset_type = Column(String(100))        # character | location | object | style | audio | voice | video | music | narration
    name = Column(String(255))
    description = Column(Text)
    file_path = Column(String(500))
    file_name = Column(String(255))
    file_size = Column(Integer)
    mime_type = Column(String(100))
    quality_score = Column(Float)
    lighting_quality = Column(String(50))
    image_clarity = Column(String(50))
    background_complexity = Column(String(50))
    suitability = Column(String(50))
    suggested_fixes = Column(Text)
    linked_entity_id = Column(String)
    linked_entity_type = Column(String(50))
    created_at = Column(DateTime, default=datetime.utcnow)

    project = relationship("Project", back_populates="assets")


class Scene(Base):
    __tablename__ = "scenes"

    id = Column(String, primary_key=True, default=new_id)
    project_id = Column(String, ForeignKey("projects.id"), nullable=False)
    story_version_id = Column(String, ForeignKey("story_versions.id"))
    scene_number = Column(Integer, nullable=False)
    title = Column(String(255))
    description = Column(Text)
    location = Column(String(255))
    mood = Column(String(100))
    time_of_day = Column(String(50))
    status = Column(String(50), default="draft")  # draft | approved
    created_at = Column(DateTime, default=datetime.utcnow)

    project = relationship("Project", back_populates="scenes")
    shots = relationship("Shot", back_populates="scene", cascade="all, delete-orphan", order_by="Shot.shot_number")


class Shot(Base):
    __tablename__ = "shots"

    id = Column(String, primary_key=True, default=new_id)
    scene_id = Column(String, ForeignKey("scenes.id"), nullable=False)
    shot_number = Column(Integer, nullable=False)
    description = Column(Text)
    duration_preset = Column(String(50), default="standard_cinematic")
    duration_seconds = Column(Float, default=4.0)
    camera_movement = Column(String(200))
    lighting = Column(String(200))
    mood = Column(String(100))
    style = Column(String(200))
    characters = Column(JSON)
    objects = Column(JSON)
    audio_cues = Column(Text)
    location = Column(String(255))
    prompt = Column(Text)
    negative_prompt = Column(Text)
    references = Column(JSON)
    generation_settings = Column(JSON)
    approval_status = Column(String(50), default="pending")  # pending | approved | rejected
    created_at = Column(DateTime, default=datetime.utcnow)

    scene = relationship("Scene", back_populates="shots")
    storyboards = relationship("StoryboardVersion", back_populates="shot", cascade="all, delete-orphan")
    preview_versions = relationship("VideoPreviewVersion", back_populates="shot", cascade="all, delete-orphan")
    final_renders = relationship("FinalVideoVersion", back_populates="shot", cascade="all, delete-orphan")
    feedback_entries = relationship("Feedback", back_populates="shot", cascade="all, delete-orphan")


class StoryboardVersion(Base):
    __tablename__ = "storyboard_versions"

    id = Column(String, primary_key=True, default=new_id)
    shot_id = Column(String, ForeignKey("shots.id"), nullable=False)
    version_number = Column(Integer, nullable=False)
    image_path = Column(String(500))
    prompt_used = Column(Text)
    negative_prompt_used = Column(Text)
    seed = Column(Integer)
    style = Column(String(200))
    camera_angle = Column(String(100))
    lighting = Column(String(200))
    model_used = Column(String(200))
    sampler = Column(String(100))
    steps = Column(Integer)
    cfg_scale = Column(Float)
    resolution = Column(String(50))
    approval_status = Column(String(50), default="pending")  # pending | approved | rejected
    created_at = Column(DateTime, default=datetime.utcnow)

    shot = relationship("Shot", back_populates="storyboards")


class VideoPreviewVersion(Base):
    __tablename__ = "video_preview_versions"

    id = Column(String, primary_key=True, default=new_id)
    shot_id = Column(String, ForeignKey("shots.id"), nullable=False)
    version_number = Column(Integer, nullable=False)
    video_path = Column(String(500))
    resolution = Column(String(50))
    duration = Column(Float)
    approval_status = Column(String(50), default="pending")
    locked_elements = Column(JSON)
    created_at = Column(DateTime, default=datetime.utcnow)

    shot = relationship("Shot", back_populates="preview_versions")


class FinalVideoVersion(Base):
    __tablename__ = "final_video_versions"

    id = Column(String, primary_key=True, default=new_id)
    shot_id = Column(String, ForeignKey("shots.id"), nullable=False)
    version_number = Column(Integer, nullable=False)
    video_path = Column(String(500))
    resolution = Column(String(50))
    approval_status = Column(String(50), default="pending")
    created_at = Column(DateTime, default=datetime.utcnow)

    shot = relationship("Shot", back_populates="final_renders")


class ProjectVideoPreview(Base):
    __tablename__ = "project_video_previews"

    id = Column(String, primary_key=True, default=new_id)
    project_id = Column(String, ForeignKey("projects.id"), nullable=False)
    version_number = Column(Integer, nullable=False, default=1)
    video_path = Column(String(500))
    resolution = Column(String(50), default="768x512")
    duration_seconds = Column(Float)
    shot_count = Column(Integer)
    scene_count = Column(Integer)
    fps = Column(Integer, default=24)
    status = Column(String(50), default="pending")   # pending | rendering | ready | failed
    error_message = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    completed_at = Column(DateTime)

    project = relationship("Project", back_populates="video_previews")


class Feedback(Base):
    __tablename__ = "feedback"

    id = Column(String, primary_key=True, default=new_id)
    shot_id = Column(String, ForeignKey("shots.id"), nullable=False)
    version = Column(Integer)
    feedback_text = Column(Text)
    locked_elements = Column(JSON)
    status = Column(String(50), default="pending")   # pending | regenerate_requested | applied
    created_at = Column(DateTime, default=datetime.utcnow)

    shot = relationship("Shot", back_populates="feedback_entries")


class RenderJob(Base):
    __tablename__ = "render_jobs"

    id = Column(String, primary_key=True, default=new_id)
    project_id = Column(String, ForeignKey("projects.id"), nullable=False)
    shot_ids = Column(JSON)
    provider = Column(String(100))   # local | runpod
    status = Column(String(50), default="pending")
    estimated_cost = Column(Float)
    actual_cost = Column(Float)
    estimated_time_minutes = Column(Integer)
    started_at = Column(DateTime)
    completed_at = Column(DateTime)
    created_at = Column(DateTime, default=datetime.utcnow)

    project = relationship("Project", back_populates="render_jobs")


class AppSetting(Base):
    __tablename__ = "app_settings"

    id = Column(String, primary_key=True, default=new_id)
    key = Column(String(100), unique=True, nullable=False)
    value = Column(Text)
    value_type = Column(String(50), default="string")   # string | boolean | integer | float | json
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Export(Base):
    __tablename__ = "exports"

    id = Column(String, primary_key=True, default=new_id)
    project_id = Column(String, ForeignKey("projects.id"), nullable=False)
    format = Column(String(50))         # mp4 | mov | prores
    aspect_ratio = Column(String(20))   # 16:9 | 9:16 | 1:1
    resolution = Column(String(50))     # 1080p | 4k
    file_path = Column(String(500))
    created_at = Column(DateTime, default=datetime.utcnow)

    project = relationship("Project", back_populates="exports")
