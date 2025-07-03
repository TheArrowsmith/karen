#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "🔧 Installing PyInstaller and dependencies..."
pip3 install --upgrade -r requirements.txt pyinstaller==6.6.0

echo "🚀 Building karen_backend binary..."
pyinstaller \
  --name karen_backend \
  --onefile \
  --target-arch universal2 \
  --hidden-import=uvloop \
  --hidden-import=pydantic \
  --collect-all spacy \
  --collect-all langchain_openai \
  --collect-all langgraph \
  main.py

echo "✅ Build complete! Binary located at: dist/karen_backend"