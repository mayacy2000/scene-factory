#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$PROJECT_DIR/backend"

echo "=== Scene Factory — Backend Setup ==="
echo ""

# Check Python
if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 not found. Install Python 3.11+ from python.org"
    exit 1
fi

PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo "Python: $PYTHON_VERSION"

# Create virtualenv
cd "$BACKEND_DIR"
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment…"
    python3 -m venv .venv
fi

source .venv/bin/activate

# Install dependencies
echo "Installing dependencies…"
pip install --upgrade pip -q
pip install -r requirements.txt -q

echo ""
echo "=== Setup complete! ==="
echo ""
echo "To start the backend:"
echo "  ./scripts/start_backend.sh"
echo ""
echo "=== Local service requirements ==="
echo ""
echo "1. Ollama (for script/scene generation):"
echo "   brew install ollama"
echo "   ollama serve"
echo "   ollama pull llama3.2"
echo ""
echo "2. ComfyUI (for storyboard image generation):"
echo "   git clone https://github.com/comfyanonymous/ComfyUI"
echo "   cd ComfyUI && pip install -r requirements.txt"
echo "   python main.py --port 8188"
echo "   # Add at least one checkpoint model to models/checkpoints/"
echo ""
