#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
ARCHIVE_NAME="${ARCHIVE_NAME:-procurement-warehouse-database-project.zip}"
ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"

if ! command -v zip >/dev/null 2>&1; then
  echo "zip command not found. Install zip first." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
rm -f "$ARCHIVE_PATH"

cd "$ROOT_DIR"

zip -r "$ARCHIVE_PATH" \
  README.md \
  requirements.txt \
  .env.example \
  docs \
  scripts \
  sql \
  tests \
  ui \
  -x "*.pyc" \
     "*/__pycache__/*" \
     ".pytest_cache/*" \
     ".venv/*" \
     ".env" \
     "dist/*" \
     "*.DS_Store" >/dev/null

echo "Created share archive:"
echo "  $ARCHIVE_PATH"
echo
echo "The archive excludes:"
echo "  .env"
echo "  .venv"
echo "  __pycache__"
echo "  .pytest_cache"
