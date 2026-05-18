# Scene Factory

**AI Video Production Station** — Mac-native app that turns stories into cinematic video highlights.

## Architecture

```
SwiftUI macOS App  ←→  FastAPI Backend (port 8000)
                           ↓
                   Ollama (port 11434) — script, scenes, story bible
                   ComfyUI (port 8188) — storyboard images
                   SQLite — project database
                   ~/Documents/SceneFactory/ — project files
```

## Quick Start

### 1. Set up the backend

```bash
./scripts/setup_backend.sh
./scripts/start_backend.sh
```

The API will run at `http://localhost:8000`. Interactive docs at `http://localhost:8000/docs`.

### 2. Start Ollama (LLM for script generation)

```bash
brew install ollama
ollama serve
ollama pull llama3.2        # recommended: llama3.2 or mistral
```

### 3. Start ComfyUI (for storyboard image generation)

```bash
git clone https://github.com/comfyanonymous/ComfyUI
cd ComfyUI
pip install -r requirements.txt
# Download a checkpoint model to ComfyUI/models/checkpoints/
python main.py --port 8188
```

Download a free model: https://huggingface.co/runwayml/stable-diffusion-v1-5

### 4. Open the SwiftUI app in Xcode

**Option A — xcodegen (recommended):**
```bash
brew install xcodegen
cd SceneFactoryApp
xcodegen generate
open SceneFactory.xcodeproj
```

**Option B — manual Xcode setup:**
1. Open Xcode → File → New → Project → macOS App
2. Name: `SceneFactory`, Interface: SwiftUI, Language: Swift
3. Delete the generated files
4. Drag all files from `SceneFactoryApp/` into the project
5. Add entitlements from `SceneFactory.entitlements`

## Project Flow (MVP-0)

```
New Project → Story Prompt → Generate Script → Generate Scenes & Shots
           → Asset Library (upload character/location/object photos)
           → Scene Builder → Select Shot → Generate Storyboards
           → Approve Storyboard → (ready for video preview)
```

## Directory Structure

```
backend/
  main.py            FastAPI entry point
  models.py          SQLAlchemy ORM models
  schemas.py         Pydantic request/response schemas
  config.py          App configuration
  database.py        SQLite engine + session
  routers/
    projects.py      Project CRUD
    stories.py       Story, script, scene generation
    assets.py        File upload & management
    storyboards.py   Storyboard generation & approval
    settings.py      App settings & system status
  services/
    ollama_service.py   LLM integration
    comfyui_service.py  Image generation integration
    storage_service.py  File system management

SceneFactoryApp/
  SceneFactoryApp.swift   App entry point
  AppState.swift          Central state management
  ContentView.swift       Root view + navigation
  Models/Models.swift     Swift data models
  Services/APIService.swift  HTTP client
  Views/
    DashboardView.swift    Project list
    NewProjectView.swift   Project creation wizard
    ScriptStudioView.swift Script writing & generation
    SceneBuilderView.swift Scene & shot breakdown
    StoryboardView.swift   Storyboard generation & approval
    AssetLibraryView.swift Asset upload & management
    SettingsView.swift     App configuration

scripts/
  setup_backend.sh   Install Python dependencies
  start_backend.sh   Start FastAPI server
```

## Development Phases

| Phase | Status | Description |
|-------|--------|-------------|
| 0 — Foundation | ✅ Built | SwiftUI app, FastAPI backend, SQLite, project structure |
| 1 — MVP-0 | ✅ Built | Story prompt → script → scenes → assets → storyboard |
| 2 — Scene system | 🔜 Next | Full scene/shot editing, approval states |
| 3 — Asset intelligence | 🔜 | Auto-analyze uploaded assets |
| 4 — Storyboard board | 🔜 | Multi-version grid with manual editing |
| 5 — Low-res preview | 🔜 | Video preview via ComfyUI |
| 6 — Timeline/Export | 🔜 | Simple timeline, MP4/MOV export |
| 7 — Cloud rendering | 🔜 | RunPod integration |
| 8 — Advanced regen | 🔜 | Time-range regeneration, inpainting |

## Key Principles

1. **No cloud until approved** — Script and storyboard must be approved before any cloud render.
2. **Everything versioned** — Every output (script, storyboard, video) is versioned and regenerable.
3. **Local first** — All AI runs locally; cloud only when the user explicitly chooses it.
