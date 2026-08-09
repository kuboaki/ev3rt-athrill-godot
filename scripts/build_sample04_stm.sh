#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS_DIR="${EV3RT_GODOT_DEPS_DIR:-$(dirname "${PROJECT_DIR}")}"

EV3RT_DIR="${DEPS_DIR}/ev3rt-athrill-v850e2m"
TOOLCHAIN_DIR="${V850_TOOLCHAIN_DIR:-${PROJECT_DIR}/toolchain/work/install/v850-elf-gcc-linux-arm64}"
SOURCE_WORKSPACE_DIR="${PROJECT_DIR}/uml_seminar_ev3"
EV3RT_WORKSPACE_DIR="${EV3RT_DIR}/sdk/uml_seminar_ev3"
APP_NAME="sample04-01-stm"

if [ ! -x "${TOOLCHAIN_DIR}/bin/v850-elf-gcc" ]; then
    echo "ERROR: GNUV850 toolchain was not found: ${TOOLCHAIN_DIR}" >&2
    exit 1
fi

if [ ! -d "${EV3RT_DIR}/sdk/common" ]; then
    echo "ERROR: ev3rt-athrill-v850e2m was not found: ${EV3RT_DIR}" >&2
    exit 1
fi

if ! ruby -e 'require "shell"' >/dev/null 2>&1; then
    echo 'ERROR: Ruby gem "shell" is required.' >&2
    echo "Install it with: sudo gem install shell" >&2
    exit 1
fi

mkdir -p "${EV3RT_WORKSPACE_DIR}"
cp -a "${SOURCE_WORKSPACE_DIR}/." "${EV3RT_WORKSPACE_DIR}/"

export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"

cd "${EV3RT_WORKSPACE_DIR}"
make realclean
make img="${APP_NAME}"
cp asp "${APP_NAME}/asp"

echo
echo "${APP_NAME} build completed."
echo "Image: ${EV3RT_WORKSPACE_DIR}/${APP_NAME}/asp"
"${TOOLCHAIN_DIR}/bin/v850-elf-readelf" \
    -p .comment \
    "${EV3RT_WORKSPACE_DIR}/${APP_NAME}/asp" |
    grep 'GCC:' |
    sort -u
