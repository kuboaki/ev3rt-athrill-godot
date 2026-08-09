extends Label

const TX_PATH := "/home/parallels/Projects/ev3rt_godot/ev3rt-athrill-v850e2m/sdk/workspace/sample03/athrill_mmap.bin"

const BODY_OFFSET := 32
const MOTOR_OFFSET := 4
const POWER_A_OFFSET := BODY_OFFSET + MOTOR_OFFSET
const POWER_C_OFFSET := BODY_OFFSET + MOTOR_OFFSET + 2 * 4

var poll_elapsed := 0.0
var toggle_elapsed := 0.0
var reflect_value := 5
var last_power_a := 999
var last_power_c := 999

const RX_PATH := "/home/parallels/Projects/ev3rt_godot/ev3rt-athrill-v850e2m/sdk/workspace/sample03/unity_mmap.bin"

const SENSOR_OFFSET := 4
const REFLECT_INDEX := 2
const ULTRASONIC_INDEX := 21
const TOUCH_0_INDEX := 27
const TOUCH_1_INDEX := 30

var motor_power_a := 0
var motor_power_c := 0

var robot_position := Vector2(500, 350)
var robot_angle := 0.0

const MOTOR_SPEED_SCALE := 3.0
const WHEEL_DISTANCE := 80.0

func _ready() -> void:
	add_theme_font_size_override("font_size", 24)
	position = Vector2(30, 30)
	text = "Waiting for VDEV data..."

func _process(delta: float) -> void:
	toggle_elapsed += delta

	if toggle_elapsed >= 10.0:
		toggle_elapsed = 0.0
		reflect_value = 50 if reflect_value == 5 else 5
		print("REFLECT changed to: ", reflect_value)

	poll_elapsed += delta

	if poll_elapsed < 0.1:
		return

	poll_elapsed = 0.0
	write_vdev_rx()
	read_vdev_tx()


func read_vdev_tx() -> void:
	if not FileAccess.file_exists(TX_PATH):
		text = "VDEV file not found:\n" + TX_PATH
		return

	var file := FileAccess.open(TX_PATH, FileAccess.READ)

	if file == null:
		text = "Cannot open VDEV file"
		return

	var data := file.get_buffer(64)
	file.close()

	if data.size() < 48:
		text = "VDEV data is too short: %d bytes" % data.size()
		return

	var magic := data.slice(0, 4).get_string_from_ascii()

	if magic != "ETTX":
		text = "Invalid TX magic: %s" % magic
		return

	var version := data.decode_u32(4)
	var micon_simtime := data.decode_u64(8)
	var unity_simtime := data.decode_u64(16)
	var power_a := data.decode_s32(POWER_A_OFFSET)
	var power_c := data.decode_s32(POWER_C_OFFSET)
	if power_a != last_power_a or power_c != last_power_c:
		print(
			"Motor changed: REFLECT=", reflect_value,
			" A=", power_a,
			" C=", power_c
		)
		last_power_a = power_a
		last_power_c = power_c

	text = (
		"VDEV connected\n"
		+ "REFLECT input: %d\n" % reflect_value
		+ "version: %d\n" % version
		+ "micon_simtime: %d\n" % micon_simtime
		+ "unity_simtime: %d\n" % unity_simtime
		+ "POWER_A (left): %d\n" % power_a
		+ "POWER_C (right): %d" % power_c
	)

func sensor_file_offset(index: int) -> int:
	return BODY_OFFSET + SENSOR_OFFSET + index * 4


func write_vdev_rx() -> void:
	if not FileAccess.file_exists(RX_PATH):
		return

	var file := FileAccess.open(RX_PATH, FileAccess.READ_WRITE)

	if file == null:
		return

	# RXヘッダー
	file.seek(0)
	file.store_buffer("ETRX".to_ascii_buffer())
	file.store_32(1)       # version
	file.store_64(0)       # reserved
	file.store_64(0)       # unity_simtime（時刻同期は後で実装）
	file.store_32(512)     # ext_off
	file.store_32(512)     # ext_size

	# 仮のセンサー値
	file.seek(sensor_file_offset(REFLECT_INDEX))
	file.store_32(reflect_value)
	file.seek(sensor_file_offset(ULTRASONIC_INDEX))
	file.store_32(500)     # 500 mm = 50 cm

	file.seek(sensor_file_offset(TOUCH_0_INDEX))
	file.store_32(0)       # バンパー：押されていない

	file.seek(sensor_file_offset(TOUCH_1_INDEX))
	file.store_32(4095)    # 荷台：押されている

	file.flush()
	file.close()

func _input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_SPACE
	):
		reflect_value = 50 if reflect_value == 5 else 5
