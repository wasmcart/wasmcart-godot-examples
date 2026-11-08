#!/bin/bash
set -e

# Build a Godot wasmcart .wasc archive for testing
# Usage: bash pack.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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

# Step 1: Create game.pck
echo "Creating game.pck..."
node "${SCRIPT_DIR}/make_pck.mjs" "${SCRIPT_DIR}/game.pck"

# Step 2: Prepare assets directory
rm -rf "${ASSETS_DIR}"
mkdir -p "${ASSETS_DIR}"
cp "${SCRIPT_DIR}/game.pck" "${ASSETS_DIR}/"

# Step 3: Pack into .wasc
echo "Packing hello_godot.wasc..."
# The cart's version is this repo's (the tag at a clean v<semver> tag, else
# <last tag>-dev.g<commit>; wasmcart-pack 0.40.0 or later), not the Godot
# runtime's checkout. CART_VERSION sets it by hand.
node "${WASMCART_PACK}" \
    --wasm "${GODOT_WASM}" \
    --assets "${ASSETS_DIR}" \
    --name "Hello Godot" \
    --version-from "${SCRIPT_DIR}" ${CART_VERSION:+--version "${CART_VERSION}"} \
    --width 640 --height 480 \
    -o "${SCRIPT_DIR}/hello_godot.wasc"

# Clean up
rm -rf "${ASSETS_DIR}"
rm -f "${SCRIPT_DIR}/game.pck"

echo ""
echo "Done! Test with:"
echo "  npx wasmcart hello_godot.wasc"
