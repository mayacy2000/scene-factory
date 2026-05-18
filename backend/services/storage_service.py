import shutil
import json
from pathlib import Path
from config import settings


def project_folder(project_id: str) -> Path:
    return Path(settings.projects_base_path) / project_id


def init_project_folder(project_id: str, title: str) -> str:
    base = project_folder(project_id)
    subdirs = [
        "story/script_versions",
        "assets/characters",
        "assets/locations",
        "assets/objects",
        "assets/style_references",
        "assets/audio_references",
        "storyboards",
        "previews",
        "final_renders",
        "captions",
        "audio",
        "exports",
        "logs",
    ]
    for sub in subdirs:
        (base / sub).mkdir(parents=True, exist_ok=True)

    meta = {
        "project_id": project_id,
        "title": title,
        "version": "0.1.0",
    }
    (base / "project.json").write_text(json.dumps(meta, indent=2))
    return str(base)


def storyboard_folder(project_id: str, scene_number: int, shot_number: int) -> Path:
    p = project_folder(project_id) / "storyboards" / f"scene_{scene_number:03d}" / f"shot_{shot_number:03d}"
    p.mkdir(parents=True, exist_ok=True)
    return p


def asset_folder(project_id: str, asset_type: str) -> Path:
    type_map = {
        "character": "characters",
        "location": "locations",
        "object": "objects",
        "style": "style_references",
        "audio": "audio_references",
        "voice": "audio_references",
        "music": "audio_references",
        "narration": "audio_references",
        "video": "exports",
    }
    sub = type_map.get(asset_type, asset_type)
    p = project_folder(project_id) / "assets" / sub
    p.mkdir(parents=True, exist_ok=True)
    return p


def save_uploaded_file(project_id: str, asset_type: str, filename: str, data: bytes) -> str:
    folder = asset_folder(project_id, asset_type)
    dest = folder / filename
    dest.write_bytes(data)
    return str(dest)


def delete_project_folder(project_id: str) -> None:
    base = project_folder(project_id)
    if base.exists():
        shutil.rmtree(base)


def export_project_bundle(project_id: str, dest_path: str) -> str:
    base = project_folder(project_id)
    shutil.make_archive(dest_path, "zip", base)
    return dest_path + ".zip"
