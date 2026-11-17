#!/usr/bin/env bash
# Makes the voice lines in tools/voices/lines.json into App/Voices/*.m4a with Kokoro.
# Needs Python 3 and ffmpeg. The first run downloads Kokoro (about 350 MB) into tools/voices/models.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

if [ ! -d .venv ]; then
  python3 -m venv .venv
  .venv/bin/pip install --quiet kokoro-onnx soundfile
fi

mkdir -p models
BASE=https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0
[ -f models/kokoro-v1.0.onnx ] || curl -sSL -o models/kokoro-v1.0.onnx "$BASE/kokoro-v1.0.onnx"
[ -f models/voices-v1.0.bin ] || curl -sSL -o models/voices-v1.0.bin "$BASE/voices-v1.0.bin"

.venv/bin/python generate.py "$@"
