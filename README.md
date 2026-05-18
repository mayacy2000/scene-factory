# Scene Factory

**AI Video Production Station** — Mac-native app that turns stories, novels, and scripts into cinematic highlight videos, entirely on your local machine.

Story prompt → Script → Scenes → Storyboard images → MP4 video with captions — no cloud required.

---

## What it does

1. **Write or paste a story prompt** — Scene Factory generates a full cinematic script using a local LLM (Ollama / llama3.2)
2. **Break it into scenes and shots** — AI generates a shot-by-shot breakdown with camera directions, mood, and duration
3. **Generate storyboard images** — Each shot is rendered by ComfyUI (Stable Diffusion) running locally on your GPU
4. **Render a video preview** — Storyboard frames are assembled into an MP4 with Ken Burns motion, crossfade transitions, and optional dialogue caption overlays
5. **Approve and iterate** — Every output is versioned; regenerate any scene, shot, or storyboard independently

---

## Architecture

```
SwiftUI macOS App  ←→  FastAPI Backend  (port 8000)
                              │
                 ┌────────────┼────────────┐
                 ▼            ▼            ▼
           Ollama LLM    ComfyUI SD     SQLite DB
          (port 11434)  (port 8001)   + local files
          script/scene  storyboard    ~/Documents/
          generation    images        SceneFactory/
```

**Target machine:** Mac Studio M2 Max, 32 GB unified memory  
**Minimum:** macOS 14, Apple Silicon (MPS GPU acceleration)

---

## Quick Start

### 1. Backend

```bash
./scripts/setup_backend.sh   # create venv, install dependencies
./scripts/start_backend.sh   # start FastAPI on http://localhost:8000
```

API docs: [http://localhost:8000/docs](http://localhost:8000/docs)

### 2. Ollama (local LLM)

```bash
brew install ollama
ollama serve
ollama pull llama3.2
```

### 3. ComfyUI (local image generation)

Install [ComfyUI Desktop](https://github.com/Comfy-Org/desktop/releases) — it runs on port 8001 by default on Mac.

Then download a checkpoint model (e.g. [DreamShaper 8](https://civitai.com/models/4384/dreamshaper)) and place it in ComfyUI's `models/checkpoints/` folder.

### 4. ffmpeg (video assembly)

```bash
brew install ffmpeg
```

### 5. SwiftUI app

```bash
brew install xcodegen
cd SceneFactoryApp
xcodegen generate
open SceneFactory.xcodeproj
```

---

## API Overview

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/projects` | Create project |
| `POST` | `/api/projects/{id}/story` | Save story prompt |
| `POST` | `/api/projects/{id}/story/generate-script` | Generate script via Ollama |
| `POST` | `/api/projects/{id}/story/generate-scenes` | Break script into scenes + shots |
| `POST` | `/api/projects/{id}/scenes` | Create scene manually |
| `POST` | `/api/projects/{id}/scenes/{id}/shots` | Create shot manually |
| `POST` | `/api/projects/{id}/scenes/{id}/shots/generate` | AI-generate shots for a scene |
| `POST` | `/api/shots/{id}/storyboards/generate` | Generate storyboard images via ComfyUI |
| `GET`  | `/api/shots/{id}/storyboards/{id}/image` | Serve storyboard image |
| `POST` | `/api/shots/{id}/storyboards/{id}/approve` | Approve a storyboard |
| `POST` | `/api/projects/{id}/video/render` | Render MP4 preview (background job) |
| `GET`  | `/api/projects/{id}/video/previews/{id}/stream` | Stream the rendered video |
| `GET`  | `/api/system/status` | Check Ollama + ComfyUI availability |

---

## Video Render Options

```json
POST /api/projects/{id}/video/render
{
  "resolution": "768x512",
  "fps": 24,
  "crossfade_duration": 0.5,
  "show_captions": true,
  "scene_ids": null
}
```

- **show_captions** — Burns dialogue text and speaker labels onto each frame using Pillow
- **scene_ids** — Render a subset of scenes; `null` renders all
- Shot durations are pulled from the database (calculated from word count for dialogue scenes)

---

## Project Structure

```
backend/
├── main.py                  FastAPI entry point
├── models.py                SQLAlchemy ORM (Project → Story → Scene → Shot → Storyboard)
├── schemas.py               Pydantic v2 request/response schemas
├── config.py                Settings (URLs, paths, spend limits)
├── database.py              SQLite engine, WAL mode, session factory
├── routers/
│   ├── projects.py          Project CRUD + folder init
│   ├── stories.py           Script, scene, shot generation + manual creation
│   ├── storyboards.py       ComfyUI job management, image serve, approval
│   ├── video.py             MP4 render jobs, preview streaming
│   ├── assets.py            File upload (characters, locations, objects)
│   └── settings.py          App config API + system status
└── services/
    ├── ollama_service.py    LLM prompts: script, scenes, shots, story bible, SD prompts
    ├── comfyui_service.py   Workflow builder, job queue, output polling
    ├── video_service.py     ffmpeg assembly: Ken Burns + xfade + Pillow caption overlay
    └── storage_service.py   Project folder structure management

SceneFactoryApp/
├── AppState.swift           @MainActor ObservableObject — full app state
├── Services/APIService.swift  HTTP client for all backend endpoints
└── Views/
    ├── DashboardView.swift
    ├── NewProjectView.swift
    ├── ScriptStudioView.swift
    ├── SceneBuilderView.swift
    ├── StoryboardView.swift
    ├── AssetLibraryView.swift
    └── SettingsView.swift

scripts/
├── setup_backend.sh         Python venv + pip install
└── start_backend.sh         uvicorn with hot reload
```

---

## Development Phases

| Phase | Status | Description |
|-------|--------|-------------|
| 0 — Foundation | ✅ Done | SwiftUI scaffold, FastAPI, SQLite schema, project folder structure |
| 1 — Story to Storyboard | ✅ Done | Prompt → script → scenes → shots → ComfyUI storyboard images |
| 5 — Video Preview | ✅ Done | ffmpeg MP4 assembly, Ken Burns zoom, crossfades, caption overlays |
| 2 — Scene editing | 🔜 Next | Full scene/shot CRUD, approval states UI |
| 3 — Asset intelligence | 🔜 | Auto-analyze uploaded character/location photos |
| 4 — Storyboard board | 🔜 | Multi-version grid with manual prompt editing |
| 6 — Timeline + Export | 🔜 | Timeline editor, MP4/MOV/ProRes export |
| 7 — Cloud rendering | 🔜 | RunPod integration for GPU-heavy jobs |
| 8 — Advanced regen | 🔜 | Inpainting, time-range regeneration |

---

## Core Principles

1. **Never render until approved** — Script and storyboard must be approved before any render job starts
2. **Everything is versioned** — Scripts, storyboards, and videos are all versioned and independently regenerable
3. **Local first** — All AI (LLM + image generation) runs on-device; cloud only when explicitly requested

---

## Configuration

Settings are stored in `.env` (copy `.env.example`) and editable live via `PUT /api/settings`:

| Key | Default | Description |
|-----|---------|-------------|
| `ollama_base_url` | `http://localhost:11434` | Ollama server |
| `ollama_model` | `llama3.2` | Model for script/scene generation |
| `comfyui_base_url` | `http://localhost:8001` | ComfyUI server |
| `comfyui_output_dir` | `~/Documents/ComyfyUA/output` | ComfyUI output folder |
| `local_only_mode` | `true` | Block all cloud uploads |
| `per_job_spend_limit` | `10.0` | Max $ per cloud render job |
| `monthly_spend_limit` | `50.0` | Max $ per month on cloud |

---

## License

MIT
