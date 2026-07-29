#!/bin/bash
set -e

# Build a Godot wasmcart .wasc archive — Kenney 3D Platformer
# Usage: bash pack.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_DIR="${SCRIPT_DIR}/project"
# Try nothreads variant first, fall back to threaded
# The runtime wasm. GODOT_WASMCART points at a godot-wasmcart checkout; the
# default assumes it sits beside this repo. Prefer the nothreads build, since
# a wasmcart host does not give the cart threads.
GODOT_WASMCART="${GODOT_WASMCART:-${SCRIPT_DIR}/../../godot-wasmcart}"
GODOT_BIN="${GODOT_WASMCART}/godot/bin"
GODOT_WASM="${GODOT_BIN}/godot.wasmcart.template_release.wasm32.nothreads.wasm"
if [ ! -f "${GODOT_WASM}" ]; then
    GODOT_WASM="${GODOT_BIN}/godot.wasmcart.template_release.wasm32.wasm"
fi
# The packer. WASMCART_REPO points at a wasmcart checkout; without one the
# published CLI works just as well (npx wasmcart pack ...).
WASMCART_REPO="${WASMCART_REPO:-${SCRIPT_DIR}/../../wasmcart}"
WASMCART_PACK="${WASMCART_REPO}/bin/wasmcart-pack.js"
MAKE_PCK="${SCRIPT_DIR}/../make_pck.mjs"
ASSETS_DIR="${SCRIPT_DIR}/wasc_assets"

# Check prerequisites
if [ ! -f "${GODOT_WASM}" ]; then
    echo "Error: Godot .wasm not found at ${GODOT_WASM}"
    echo "Build it first: cd "${GODOT_WASMCART}/godot" && scons platform=wasmcart target=template_release production=yes"
    exit 1
fi

if [ ! -f "${WASMCART_PACK}" ]; then
    echo "Error: wasmcart-pack not found at ${WASMCART_PACK}"
    exit 1
fi

if [ ! -d "${PROJ_DIR}/.godot/imported" ]; then
    echo "Error: No imported assets found. Run prepare.sh first."
    exit 1
fi

# Step 1: Create game.pck from project directory
echo "Creating game.pck..."
node "${MAKE_PCK}" "${PROJ_DIR}" "${SCRIPT_DIR}/game.pck" --patch-renderer

# Step 2: Prepare assets directory
rm -rf "${ASSETS_DIR}"
mkdir -p "${ASSETS_DIR}"
cp "${SCRIPT_DIR}/game.pck" "${ASSETS_DIR}/"

# Step 3: Pack into .wasc
echo "Packing kenney_platformer.wasc..."
node "${WASMCART_PACK}" \
    --wasm "${GODOT_WASM}" \
    --assets "${ASSETS_DIR}" \
    --name "Kenney 3D Platformer" \
    --width 1280 --height 720 \
    -o "${SCRIPT_DIR}/kenney_platformer.wasc"

# Clean up
rm -rf "${ASSETS_DIR}"
rm -f "${SCRIPT_DIR}/game.pck"

echo ""
echo "Done! Test with:"
echo "  node ~/code/cliemu/wasmcart/bin/wasmcart-screenshot.js ${SCRIPT_DIR}/kenney_platformer.wasc --frames 300 -o /tmp/kenney_test.png"
echo "  npx wasmcart kenney_platformer.wasc"
