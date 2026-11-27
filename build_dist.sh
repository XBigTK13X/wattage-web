#!/bin/bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIRECTORY="${SCRIPT_DIRECTORY}/dist"
PRESETS_FILE="${SCRIPT_DIRECTORY}/export_presets.cfg"
TEMPLATE_FILE="${SCRIPT_DIRECTORY}/export_presets.cfg.template"

BUILD_MODE="debug"
if [[ "${1:-}" == "--release" ]]; then
	BUILD_MODE="release"
elif [[ -n "${1:-}" ]]; then
	echo "Usage: $0 [--release]" >&2
	exit 1
fi

GODOT_BINARY="${GODOT_BINARY:-}"
if [[ -z "${GODOT_BINARY}" ]]; then
	if command -v godot >/dev/null 2>&1; then
		GODOT_BINARY="$(command -v godot)"
	elif command -v godot4 >/dev/null 2>&1; then
		GODOT_BINARY="$(command -v godot4)"
	else
		echo "Error: godot or godot4 not found in PATH. Set GODOT_BINARY to the Godot executable." >&2
		exit 1
	fi
fi

if [[ ! -f "${PRESETS_FILE}" ]]; then
	cp "${TEMPLATE_FILE}" "${PRESETS_FILE}"
fi

mkdir -p "${OUTPUT_DIRECTORY}"

LINUX_OUTPUT="${OUTPUT_DIRECTORY}/wattage-web.x86_64"
ANDROID_OUTPUT="${OUTPUT_DIRECTORY}/wattage-web.apk"

if [[ "${BUILD_MODE}" == "release" ]]; then
	"${GODOT_BINARY}" --headless --path "${SCRIPT_DIRECTORY}" --export-release "Linux" "${LINUX_OUTPUT}"
	"${GODOT_BINARY}" --headless --path "${SCRIPT_DIRECTORY}" --export-release "Android" "${ANDROID_OUTPUT}"
else
	"${GODOT_BINARY}" --headless --path "${SCRIPT_DIRECTORY}" --export-release "Linux" "${LINUX_OUTPUT}"
	"${GODOT_BINARY}" --headless --path "${SCRIPT_DIRECTORY}" --export-debug "Android" "${ANDROID_OUTPUT}"
fi

chmod +x "${LINUX_OUTPUT}"

echo "Created:"
echo "  ${LINUX_OUTPUT}"
echo "  ${ANDROID_OUTPUT}"
