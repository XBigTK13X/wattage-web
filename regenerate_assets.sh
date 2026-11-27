#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="${SCRIPT_DIR}/tools"

uv --project "${TOOLS_DIR}" run python "${TOOLS_DIR}/build_assets.py" "$@"
python3 "${TOOLS_DIR}/validate_repo.py"
