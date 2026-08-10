#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS_DIR="${EV3RT_GODOT_DEPS_DIR:-$(dirname "${PROJECT_DIR}")}"
EV3RT_DIR="${DEPS_DIR}/ev3rt-athrill-v850e2m"
PATCH_DIR="${PROJECT_DIR}/patches/ev3rt-athrill-v850e2m"

if [ ! -d "${EV3RT_DIR}/.git" ]; then
    echo "ERROR: ev3rt-athrill-v850e2m was not found: ${EV3RT_DIR}" >&2
    exit 1
fi

for patch_file in "${PATCH_DIR}"/*.patch; do
    patch_name="$(basename "${patch_file}")"

    if git -C "${EV3RT_DIR}" apply --check "${patch_file}" 2>/dev/null; then
        git -C "${EV3RT_DIR}" apply "${patch_file}"
        echo "Applied ${patch_name}"
    elif git -C "${EV3RT_DIR}" apply --reverse --check "${patch_file}" 2>/dev/null; then
        echo "Already applied: ${patch_name}"
    else
        echo "ERROR: Patch cannot be applied cleanly: ${patch_name}" >&2
        exit 1
    fi
done
