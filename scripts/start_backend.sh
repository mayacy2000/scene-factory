#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$PROJECT_DIR/backend"

cd "$BACKEND_DIR"

if [ ! -d ".venv" ]; then
    echo "Virtual environment not found. Run scripts/setup_backend.sh first."
    exit 1
fi

source .venv/bin/activate

echo "=== Starting Scene Factory Backend ==="
echo "URL: http://localhost:8000"
echo "API docs: http://localhost:8000/docs"
echo ""

uvicorn main:app --host 127.0.0.1 --port 8000 --reload
