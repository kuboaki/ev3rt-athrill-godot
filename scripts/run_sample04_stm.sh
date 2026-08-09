#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS_DIR="${EV3RT_GODOT_DEPS_DIR:-$(dirname "${PROJECT_DIR}")}"

ATHRILL_BIN="${DEPS_DIR}/athrill-target-v850e2m/athrill/bin/linux/athrill2"
APP_DIR="${DEPS_DIR}/ev3rt-athrill-v850e2m/sdk/uml_seminar_ev3/sample04-01-stm"
TIMEOUT_CLOCKS="${ATHRILL_TIMEOUT_CLOCKS:-3000000000}"

if [ "$(nproc)" -gt 1 ]; then
    DEFAULT_CPU=1
else
    DEFAULT_CPU=0
fi
HOST_CPU="${ATHRILL_HOST_CPU:-${DEFAULT_CPU}}"

if [ ! -x "${ATHRILL_BIN}" ]; then
    echo "ERROR: Athrill was not found: ${ATHRILL_BIN}" >&2
    exit 1
fi

for required in \
    asp \
    memory_mmap.txt \
    device_config_mmap_sync.txt
do
    if [ ! -f "${APP_DIR}/${required}" ]; then
        echo "ERROR: Missing ${APP_DIR}/${required}" >&2
        echo "Run ./scripts/build_sample04_stm.sh first." >&2
        exit 1
    fi
done

cd "${APP_DIR}"

dd if=/dev/zero of=athrill_mmap.bin bs=8192 count=1 status=none
dd if=/dev/zero of=unity_mmap.bin bs=8192 count=1 status=none

python3 "${PROJECT_DIR}/scripts/vdev_poke.py" \
    write_rx \
    unity_mmap.bin

echo "Starting Athrill on host CPU ${HOST_CPU}"
echo "Timeout clocks: ${TIMEOUT_CLOCKS}"
echo "Press Ctrl-C to stop."

exec taskset -c "${HOST_CPU}" nice -n 15 \
    "${ATHRILL_BIN}" \
    -c1 \
    -t"${TIMEOUT_CLOCKS}" \
    -mmemory_mmap.txt \
    -ddevice_config_mmap_sync.txt \
    asp
