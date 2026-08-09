#!/usr/bin/env python3
"""Minimal experiment: write EV3RT VDEV RX (sensor) values into unity_mmap.bin,
then read back VDEV TX (motor) values from athrill_mmap.bin after running athrill2.

VDEV wire format (from athrill-target-ARMv7-A src/device/peripheral/inc/vdev.h,
target/gr_peach_gcc/athrill/vdev.h, pil/include/ev3_vdev_common.h):

  RX file (unity_mmap.bin) = data the EV3RT app reads as sensors:
    [0:4)   header magic "ETRX"
    [4:8)   version = 1
    [8:16)  reserved
    [16:24) unity_simtime (uint64) -- external side's sim clock, paces athrill
    [24:28) ext_off = 512
    [28:32) ext_size = 512
    [32:)   body: 32-bit words at BODY_OFF + EV3_SENSOR_OFF_TYPE(index)
            EV3_SENSOR_OFF = 4 (byte offset of sensor block within body)
            EV3_SENSOR_OFF_TYPE(index) = 4 + index*4

  TX file (athrill_mmap.bin) = data the EV3RT app writes (motors/LED):
    [0:4)   header magic "ETTX"
    [4:8)   version = 1
    [8:16)  micon_simtime (uint64) -- EV3RT/athrill side's sim clock
    [16:24) unity_simtime (uint64) -- echoed back
    [24:28) ext_off = 512
    [28:32) ext_size = 512
    [32:)   body: 32-bit words at BODY_OFF + EV3_MOTOR_OFF_TYPE(index)
            EV3_MOTOR_OFF = 4, EV3_MOTOR_OFF_TYPE(index) = 4 + index*4
"""
import struct
import sys

HEAD_SIZE = 32
BODY_OFF = 32

# --- RX (sensor) slot indices, from ev3_vdev_common.h ---
SENSOR_OFF = 4
SENSOR_INX_REFLECT = 2
SENSOR_INX_ULTRASONIC = 21
SENSOR_INX_TOUCH_0 = 27   # touch_sensor  (EV3_PORT_1, bumper)
SENSOR_INX_TOUCH_1 = 30   # touch_sensor2 (EV3_PORT_2, carrier/cargo)

def sensor_addr(index):
    return BODY_OFF + SENSOR_OFF + index * 4

# --- TX (motor) slot indices ---
MOTOR_OFF = 4
MOTOR_INX_POWER_A = 0  # left_motor
MOTOR_INX_POWER_C = 2  # right_motor

def motor_addr(index):
    return BODY_OFF + MOTOR_OFF + index * 4


def write_rx(path):
    with open(path, "r+b") as f:
        f.write(b"ETRX")
        f.write(struct.pack("<I", 1))       # version
        f.write(b"\x00" * 8)                 # reserved
        f.write(struct.pack("<Q", 0))        # unity_simtime
        f.write(struct.pack("<II", 512, 512))  # ext_off, ext_size
        assert f.tell() == HEAD_SIZE

        def put(index, value):
            f.seek(sensor_addr(index))
            f.write(struct.pack("<i", value))

        put(SENSOR_INX_REFLECT, 5)        # < LM_THRESHOLD(20) -> "on the line"
        put(SENSOR_INX_ULTRASONIC, 500)   # 50cm -> outside wd_threshold(10cm), no wall
        put(SENSOR_INX_TOUCH_0, 0)        # bumper: not pressed
        put(SENSOR_INX_TOUCH_1, 4095)     # carrier: pressed (ADC_RES=4095, threshold 2047)
    print(f"wrote sensor values into {path}")


def read_tx(path):
    with open(path, "rb") as f:
        data = f.read()
    magic = data[0:4]
    version = struct.unpack_from("<I", data, 4)[0]
    micon_simtime = struct.unpack_from("<Q", data, 8)[0]
    unity_simtime = struct.unpack_from("<Q", data, 16)[0]
    power_a = struct.unpack_from("<i", data, motor_addr(MOTOR_INX_POWER_A))[0]
    power_c = struct.unpack_from("<i", data, motor_addr(MOTOR_INX_POWER_C))[0]
    print(f"TX header: magic={magic} version={version} micon_simtime={micon_simtime} unity_simtime={unity_simtime}")
    print(f"POWER_A(left)={power_a} POWER_C(right)={power_c}")


if __name__ == "__main__":
    mode = sys.argv[1]
    path = sys.argv[2]
    if mode == "write_rx":
        write_rx(path)
    elif mode == "read_tx":
        read_tx(path)
    else:
        print("usage: vdev_poke.py {write_rx|read_tx} <path>")
        sys.exit(1)
