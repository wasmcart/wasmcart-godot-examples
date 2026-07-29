#!/bin/bash
set -e

# Prepare Kenney 3D Platformer for wasmcart packaging
# Clones the repo, patches for gl_compatibility, and runs Godot editor headless import

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_DIR="${SCRIPT_DIR}/project"
GODOT_EDITOR="${GODOT_EDITOR:-/tmp/Godot_v4.4-stable_linux.x86_64}"

# Clone if needed
if [ ! -d "${PROJ_DIR}" ]; then
    echo "Cloning Kenney 3D Platformer..."
    git clone --depth 1 https://github.com/KenneyNL/Starter-Kit-3D-Platformer.git "${PROJ_DIR}"
fi

# Check for Godot editor
if [ ! -f "${GODOT_EDITOR}" ]; then
    echo "Error: Godot editor not found at ${GODOT_EDITOR}"
    echo "Download: wget -O /tmp/godot_editor.zip https://github.com/godotengine/godot/releases/download/4.4-stable/Godot_v4.4-stable_linux.x86_64.zip && cd /tmp && unzip godot_editor.zip"
    echo "Or set GODOT_EDITOR=/path/to/godot"
    exit 1
fi

# Clean previous binary imports (keep .import files — they contain _subresources
# settings like generate/physics that are critical for collision shapes)
echo "Cleaning previous binary imports..."
rm -rf "${PROJ_DIR}/.godot"

# Patch project.godot for gl_compatibility
echo "Patching project.godot..."
sed -i 's/config\/features=PackedStringArray("4.5", "Forward Plus")/config\/features=PackedStringArray("4.4", "GL Compatibility")/' "${PROJ_DIR}/project.godot"
# Add renderer setting if not present
if ! grep -q 'renderer/rendering_method' "${PROJ_DIR}/project.godot"; then
    sed -i '/^\[rendering\]/a renderer\/rendering_method="gl_compatibility"' "${PROJ_DIR}/project.godot"
fi

# Run headless import (creates .godot/imported/ with binary assets)
echo "Running Godot headless import (this may take a moment)..."
cd "${PROJ_DIR}"
"${GODOT_EDITOR}" --headless --import 2>&1 | grep -E "^ERROR" | head -5 || true

echo ""
echo "Import complete. Run pack.sh to build .wasc"
