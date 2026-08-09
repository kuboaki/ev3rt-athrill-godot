#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS_DIR="${EV3RT_GODOT_DEPS_DIR:-$(dirname "${PROJECT_DIR}")}"

ATHRILL_TARGET_DIR="${DEPS_DIR}/athrill-target-v850e2m"
ATHRILL_CORE_DIR="${ATHRILL_TARGET_DIR}/athrill"
PATCH_FILE="${PROJECT_DIR}/patches/athrill-target-v850e2m/0001-fix-eof-handling-on-arm64.patch"

if [ ! -f "${ATHRILL_TARGET_DIR}/build_linux/Makefile" ]; then
    echo "ERROR: athrill-target-v850e2m was not found: ${ATHRILL_TARGET_DIR}" >&2
    exit 1
fi

if git -C "${ATHRILL_CORE_DIR}" apply --check "${PATCH_FILE}" 2>/dev/null; then
    git -C "${ATHRILL_CORE_DIR}" apply "${PATCH_FILE}"
    echo "Applied ARM64 EOF handling patch."
elif git -C "${ATHRILL_CORE_DIR}" apply --reverse --check "${PATCH_FILE}" 2>/dev/null; then
    echo "ARM64 EOF handling patch is already applied."
else
    echo "ERROR: ARM64 EOF handling patch cannot be applied cleanly." >&2
    exit 1
fi

make -C "${ATHRILL_TARGET_DIR}/build_linux" clean
make -C "${ATHRILL_TARGET_DIR}/build_linux" timer32=true etrobo_optimize=true

echo
echo "Athrill build completed."
echo "Binary: ${ATHRILL_CORE_DIR}/bin/linux/athrill2"
"${ATHRILL_CORE_DIR}/bin/linux/athrill2" 2>&1 | head -5 || true
