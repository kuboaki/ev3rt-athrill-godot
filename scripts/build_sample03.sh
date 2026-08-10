#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS_DIR="${EV3RT_GODOT_DEPS_DIR:-$(dirname "${PROJECT_DIR}")}"
"${PROJECT_DIR}/scripts/prepare_ev3rt.sh"

EV3RT_DIR="${DEPS_DIR}/ev3rt-athrill-v850e2m"
TOOLCHAIN_DIR="${V850_TOOLCHAIN_DIR:-${PROJECT_DIR}/toolchain/work/install/v850-elf-gcc-linux-arm64}"
SOURCE_APP_DIR="${PROJECT_DIR}/workspace/sample03"
EV3RT_WORKSPACE_DIR="${EV3RT_DIR}/sdk/workspace"
DEST_APP_DIR="${EV3RT_WORKSPACE_DIR}/sample03"

if [ ! -x "${TOOLCHAIN_DIR}/bin/v850-elf-gcc" ]; then
    echo "ERROR: GNUV850 toolchain was not found: ${TOOLCHAIN_DIR}" >&2
    echo "Run ./toolchain/build_gcc_rh850_arm64.sh first." >&2
    exit 1
fi

if [ ! -f "${EV3RT_WORKSPACE_DIR}/Makefile" ]; then
    echo "ERROR: ev3rt-athrill-v850e2m was not found: ${EV3RT_DIR}" >&2
    exit 1
fi

if ! ruby -e 'require "shell"' >/dev/null 2>&1; then
    echo 'ERROR: Ruby gem "shell" is required.' >&2
    echo "Install it with: sudo gem install shell" >&2
    exit 1
fi

mkdir -p "${DEST_APP_DIR}"
cp -a "${SOURCE_APP_DIR}/." "${DEST_APP_DIR}/"

export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"

cd "${EV3RT_WORKSPACE_DIR}"
make realclean
make img=sample03
cp asp "${DEST_APP_DIR}/asp"

echo
echo "sample03 build completed."
echo "Image: ${DEST_APP_DIR}/asp"
"${TOOLCHAIN_DIR}/bin/v850-elf-readelf" -p .comment "${DEST_APP_DIR}/asp" |
    grep 'GCC:' |
    sort -u
