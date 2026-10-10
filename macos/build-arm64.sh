#!/usr/bin/env bash
#
# Build the pause_click plugin natively for Apple Silicon (arm64) VLC 3.0.x.
#
# Requirements:
#   - Xcode Command Line Tools (clang)     : xcode-select --install
#   - /Applications/VLC.app (arm64 native VLC 3.0.x)
#
# The VLC plugin SDK headers matching the installed VLC version are downloaded
# automatically from download.videolan.org into build/.
#
# Usage:
#   macos/build-arm64.sh            # build only  -> build/dist/libpause_click_plugin.dylib
#   macos/build-arm64.sh --install  # build and copy into VLC.app (quit VLC first)
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VLC_APP="${VLC_APP:-/Applications/VLC.app}"
VLC_LIB="${VLC_APP}/Contents/MacOS/lib"
PLUGIN_DIR="${VLC_APP}/Contents/MacOS/plugins"
BUILD_DIR="${ROOT}/build"

# --- detect VLC version ---
VLC_VER="$("${VLC_APP}/Contents/MacOS/VLC" --version 2>/dev/null | sed -n 's/^VLC version \([0-9.]*\).*/\1/p' | head -1)"
if [ -z "${VLC_VER}" ]; then
  echo "Could not detect the VLC version at ${VLC_APP}" >&2
  exit 1
fi
echo "Detected VLC version: ${VLC_VER}"

SRC="${ROOT}/src/pause_click.c"
INC="${BUILD_DIR}/vlc-${VLC_VER}/include"

# --- fetch plugin SDK headers if missing ---
if [ ! -f "${INC}/vlc_plugin.h" ]; then
  echo "Fetching VLC ${VLC_VER} headers..."
  mkdir -p "${BUILD_DIR}"
  TARBALL="${BUILD_DIR}/vlc-${VLC_VER}.tar.xz"
  if [ ! -f "${TARBALL}" ]; then
    curl -fsSL "https://download.videolan.org/pub/videolan/vlc/${VLC_VER}/vlc-${VLC_VER}.tar.xz" -o "${TARBALL}"
  fi
  tar -xf "${TARBALL}" -C "${BUILD_DIR}" "vlc-${VLC_VER}/include"
  # generated public headers (libvlc_version.h etc.) are taken from VLC.app
  cp "${VLC_APP}/Contents/MacOS/include/vlc/"*.h "${INC}/vlc/"
fi

# --- module entry symbol suffix, taken from a bundled plugin (e.g. 3_0_0f) ---
MODULE_SYMBOL="$(nm -gU "${PLUGIN_DIR}/libadjust_plugin.dylib" \
  | sed -n 's/.* _vlc_entry__\([0-9a-z_]*\)$/\1/p' | head -1)"
echo "Module entry symbol suffix: ${MODULE_SYMBOL}"

OUT="${BUILD_DIR}/dist/libpause_click_plugin.dylib"
mkdir -p "${BUILD_DIR}/dist"

echo "Compiling..."
clang -std=gnu11 -fPIC -DPIC \
  -D__PLUGIN__ -DMODULE_SYMBOL="${MODULE_SYMBOL}" -DMODULE_STRING='"pause_click"' \
  -I"${ROOT}" -I"${ROOT}/src" -I"${INC}" \
  -g0 -O2 -w \
  -bundle -o "${OUT}" "${SRC}" \
  -L"${VLC_LIB}" -lvlccore

strip -x "${OUT}"
# arm64 binaries must be signed; an ad-hoc signature is enough because VLC.app
# has the com.apple.security.cs.disable-library-validation entitlement.
codesign --force --sign - "${OUT}"

echo "Built: ${OUT}"
file "${OUT}"

# --- install ---
if [ "${1:-}" = "--install" ]; then
  if pgrep -x VLC >/dev/null; then
    echo "Please quit VLC first." >&2
    exit 1
  fi
  cp "${OUT}" "${PLUGIN_DIR}/"
  echo "Installed to ${PLUGIN_DIR}/"
  echo "If VLC does not pick it up, launch it once with --reset-plugins-cache."
fi
