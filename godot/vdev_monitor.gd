extends Label

var tx_path := ""
var rx_path := ""

const BODY_OFFSET := 32
const MOTOR_OFFSET := 4
const POWER_A_OFFSET := BODY_OFFSET + MOTOR_OFFSET
const POWER_C_OFFSET := BODY_OFFSET + MOTOR_OFFSET + 2 * 4

var poll_elapsed := 0.0
var reflect_value := 5
var last_power_a := 999
var last_power_c := 999

const SENSOR_OFFSET := 4
const REFLECT_INDEX := 2
const ULTRASONIC_INDEX := 21
const TOUCH_0_INDEX := 27
const TOUCH_1_INDEX := 30

var motor_power_a := 0
var motor_power_c := 0

var robot_position := Vector2.ZERO
var robot_angle := 0.0

const PIXELS_PER_CM := 5.0
const MM_PER_PIXEL := 10.0 / PIXELS_PER_CM

const MOTOR_SPEED_SCALE := 1.5

const BODY_LENGTH := 23.0 * PIXELS_PER_CM
const BODY_WIDTH := 18.0 * PIXELS_PER_CM
const WHEEL_DIAMETER := 5.8 * PIXELS_PER_CM
const WHEEL_WIDTH := 2.9 * PIXELS_PER_CM
const WHEEL_DISTANCE := 11.8 * PIXELS_PER_CM

const COURSE_CENTER := Vector2(650.0, 350.0)
const COURSE_HORIZONTAL_STRAIGHT := 30.0 * PIXELS_PER_CM
const COURSE_VERTICAL_STRAIGHT := 9.4 * PIXELS_PER_CM
const COURSE_CORNER_RADIUS := 14.5 * PIXELS_PER_CM
const COURSE_ARC_SEGMENTS := 16

const LINE_WIDTH := 2.6 * PIXELS_PER_CM
const LINE_HALF_WIDTH := LINE_WIDTH * 0.5

const COLOR_SENSOR_FORWARD_OFFSET := 8.0 * PIXELS_PER_CM
const COLOR_SENSOR_RIGHT_OFFSET := 5.6 * PIXELS_PER_CM
const REFLECT_ON_LINE := 5
const REFLECT_OFF_LINE := 50

var color_sensor_position := Vector2.ZERO
var course_points := PackedVector2Array()

const WALL_X := 1000.0

# 暫定値。Blenderモデル確認後に実位置へ合わせる。
const ULTRASONIC_FORWARD_OFFSET := 10.0 * PIXELS_PER_CM
const BUMPER_FORWARD_OFFSET := 11.0 * PIXELS_PER_CM

var ultrasonic_sensor_position := Vector2.ZERO
var bumper_position := Vector2.ZERO

var ultrasonic_distance_mm := 5000
var bumper_pressed := false
var cargo_loaded := false


func _ready() -> void:
	var project_dir := ProjectSettings.globalize_path("res://")
	var default_vdev_dir := project_dir.path_join(
		"../../ev3rt-athrill-v850e2m/"
		+ "sdk/uml_seminar_ev3/sample04-01-stm"
	).simplify_path()

	var vdev_dir := OS.get_environment("EV3RT_VDEV_DIR")
	if vdev_dir.is_empty():
		vdev_dir = default_vdev_dir

	tx_path = vdev_dir.path_join("athrill_mmap.bin")
	rx_path = vdev_dir.path_join("unity_mmap.bin")
	var robot_texture: Texture2D = preload(
	    "res://assets/robot_top.png"
	)
	build_course_points()
	reset_robot()
	update_line_sensor()
	update_environment_sensors()
	add_theme_font_size_override("font_size", 24)
	position = Vector2(30, 30)
	text = "Waiting for VDEV data..."

func _physics_process(delta: float) -> void:
	update_robot(delta)
	update_line_sensor()
	update_environment_sensors()
	queue_redraw()

	poll_elapsed += delta

	if poll_elapsed < 0.01:
		return

	poll_elapsed = 0.0
	write_vdev_rx()
	read_vdev_tx()


func read_vdev_tx() -> void:
	if not FileAccess.file_exists(tx_path):
		text = "VDEV file not found:\n" + tx_path
		return

	var file := FileAccess.open(tx_path, FileAccess.READ)

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
	motor_power_a = power_a
	motor_power_c = power_c
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
		+ "ULTRASONIC: %d mm\n" % ultrasonic_distance_mm
		+ "BUMPER: %s\n" % bumper_pressed
		+ "CARGO LOADED: %s (L key)\n" % cargo_loaded
		+ "version: %d\n" % version
		+ "micon_simtime: %d\n" % micon_simtime
		+ "unity_simtime: %d\n" % unity_simtime
		+ "POWER_A (left): %d\n" % power_a
		+ "POWER_C (right): %d" % power_c
	)

func sensor_file_offset(index: int) -> int:
	return BODY_OFFSET + SENSOR_OFFSET + index * 4


func write_vdev_rx() -> void:
	if not FileAccess.file_exists(rx_path):
		return

	var file := FileAccess.open(rx_path, FileAccess.READ_WRITE)

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
	file.store_32(ultrasonic_distance_mm)

	file.seek(sensor_file_offset(TOUCH_0_INDEX))
	file.store_32(4095 if bumper_pressed else 0)

	file.seek(sensor_file_offset(TOUCH_1_INDEX))
	file.store_32(4095 if cargo_loaded else 0)

	file.flush()
	file.close()

func reset_robot() -> void:
	# 下側直線を左向きに走り、時計回りに外エッジを追う。
	robot_angle = PI

	var bottom_line_y := (
		COURSE_CENTER.y
		+ COURSE_VERTICAL_STRAIGHT * 0.5
		+ COURSE_CORNER_RADIUS
	)
	var sensor_start := Vector2(
		COURSE_CENTER.x,
		bottom_line_y
	)

	var forward := Vector2(cos(robot_angle), sin(robot_angle))
	var right := Vector2(-sin(robot_angle), cos(robot_angle))

	# カラーセンサーがライン中心に載る位置から、
	# 取付オフセットを逆算して車体中心を置く。
	robot_position = (
		sensor_start
		- forward * COLOR_SENSOR_FORWARD_OFFSET
		- right * COLOR_SENSOR_RIGHT_OFFSET
	)

func _input(event: InputEvent) -> void:
	if not (
		event is InputEventKey
		and event.pressed
		and not event.echo
	):
		return

	match event.keycode:
		KEY_SPACE:
			reset_robot()
		KEY_L:
			cargo_loaded = not cargo_loaded
			print("Cargo loaded: ", cargo_loaded)

func update_robot(delta: float) -> void:
	var left_speed := float(motor_power_a) * MOTOR_SPEED_SCALE
	var right_speed := float(motor_power_c) * MOTOR_SPEED_SCALE

	var linear_speed := (left_speed + right_speed) * 0.5
	# GodotのY軸は下向きなので、正の画面角度は右旋回。
	var angular_speed := (left_speed - right_speed) / WHEEL_DISTANCE

	robot_angle += angular_speed * delta

	var forward := Vector2(cos(robot_angle), sin(robot_angle))
	robot_position += forward * linear_speed * delta

	var viewport_size := get_viewport_rect().size
	robot_position.x = clamp(robot_position.x, 30.0, viewport_size.x - 30.0)
	robot_position.y = clamp(robot_position.y, 30.0, viewport_size.y - 30.0)

func build_course_points() -> void:
	course_points.clear()

	var corner_x := COURSE_HORIZONTAL_STRAIGHT * 0.5
	var corner_y := COURSE_VERTICAL_STRAIGHT * 0.5

	append_course_arc(
		COURSE_CENTER + Vector2(corner_x, -corner_y),
		-PI * 0.5
	)
	append_course_arc(
		COURSE_CENTER + Vector2(corner_x, corner_y),
		0.0
	)
	append_course_arc(
		COURSE_CENTER + Vector2(-corner_x, corner_y),
		PI * 0.5
	)
	append_course_arc(
		COURSE_CENTER + Vector2(-corner_x, -corner_y),
		PI
	)

	if not course_points.is_empty():
		course_points.append(course_points[0])


func append_course_arc(
	center: Vector2,
	start_angle: float
) -> void:
	for step in range(COURSE_ARC_SEGMENTS + 1):
		var ratio := float(step) / float(COURSE_ARC_SEGMENTS)
		var angle := start_angle + ratio * PI * 0.5
		course_points.append(
			center
			+ Vector2(cos(angle), sin(angle))
			* COURSE_CORNER_RADIUS
		)

func distance_to_course(point: Vector2) -> float:
	var minimum_distance := INF

	for index in range(course_points.size() - 1):
		var closest_point := Geometry2D.get_closest_point_to_segment(
			point,
			course_points[index],
			course_points[index + 1]
		)
		minimum_distance = min(
			minimum_distance,
			point.distance_to(closest_point)
		)

	return minimum_distance

func update_line_sensor() -> void:
	var forward := Vector2(cos(robot_angle), sin(robot_angle))
	var right := Vector2(-sin(robot_angle), cos(robot_angle))

	color_sensor_position = (
		robot_position
		+ forward * COLOR_SENSOR_FORWARD_OFFSET
		+ right * COLOR_SENSOR_RIGHT_OFFSET
	)

	var distance_from_line := distance_to_course(
		color_sensor_position
	)

	var new_reflect_value := (
		REFLECT_ON_LINE
		if distance_from_line <= LINE_HALF_WIDTH
		else REFLECT_OFF_LINE
	)

	if new_reflect_value != reflect_value:
		reflect_value = new_reflect_value
		print("REFLECT changed to: ", reflect_value)


func update_environment_sensors() -> void:
	var forward := Vector2(cos(robot_angle), sin(robot_angle))

	ultrasonic_sensor_position = (
		robot_position
		+ forward * ULTRASONIC_FORWARD_OFFSET
	)
	bumper_position = (
		robot_position
		+ forward * BUMPER_FORWARD_OFFSET
	)

	ultrasonic_distance_mm = 5000
	bumper_pressed = false


func _draw() -> void:
	# A1用紙の角丸矩形コース
	if course_points.size() >= 2:
		draw_polyline(
			course_points,
			Color(0.15, 0.15, 0.15),
			LINE_WIDTH,
			true
		)

	# 荷下ろし地点の壁
	draw_line(
		Vector2(WALL_X, COURSE_CENTER.y - 90.0),
		Vector2(WALL_X, COURSE_CENTER.y + 90.0),
		Color(0.8, 0.25, 0.2),
		10.0
	)

	# 差動二輪ロボット
	draw_set_transform(robot_position, robot_angle)

	draw_rect(
		Rect2(
			-BODY_LENGTH * 0.5,
			-BODY_WIDTH * 0.5,
			BODY_LENGTH,
			BODY_WIDTH
		),
		Color(0.2, 0.55, 0.9),
		true
	)

	draw_rect(
		Rect2(
			-WHEEL_DIAMETER * 0.5,
			-WHEEL_DISTANCE * 0.5 - WHEEL_WIDTH * 0.5,
			WHEEL_DIAMETER,
			WHEEL_WIDTH
		),
		Color(0.08, 0.08, 0.08),
		true
	)
	draw_rect(
		Rect2(
			-WHEEL_DIAMETER * 0.5,
			WHEEL_DISTANCE * 0.5 - WHEEL_WIDTH * 0.5,
			WHEEL_DIAMETER,
			WHEEL_WIDTH
		),
		Color(0.08, 0.08, 0.08),
		true
	)
	if cargo_loaded:
		draw_rect(
			Rect2(-10, -10, 20, 20),
			Color(0.95, 0.65, 0.15),
			true
		)
	draw_line(
		Vector2.ZERO,
		Vector2(BODY_LENGTH * 0.5 + 10.0, 0),
		Color(1.0, 0.8, 0.1),
		4.0
	)

	draw_set_transform(Vector2.ZERO, 0.0)

	var sensor_color := (
		Color(0.1, 0.9, 0.2)
		if reflect_value == REFLECT_ON_LINE
		else Color(0.95, 0.2, 0.2)
	)

	draw_line(
		robot_position,
		color_sensor_position,
		Color(0.7, 0.7, 0.7),
		2.0
	)
	draw_circle(
		color_sensor_position,
		7.0,
		sensor_color
	)
	draw_circle(
		ultrasonic_sensor_position,
		5.0,
		Color(0.2, 0.8, 1.0)
	)

	draw_circle(
		bumper_position,
		5.0,
		Color(1.0, 0.1, 0.1)
		if bumper_pressed
		else Color(0.6, 0.6, 0.6)
	)
