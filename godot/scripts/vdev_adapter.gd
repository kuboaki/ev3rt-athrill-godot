extends Node

const BODY_OFFSET := 32
const MOTOR_OFFSET := 4
const POWER_A_OFFSET := BODY_OFFSET + MOTOR_OFFSET
const POWER_C_OFFSET := BODY_OFFSET + MOTOR_OFFSET + 2 * 4
const SENSOR_OFFSET := 4
const REFLECT_INDEX := 2
const ULTRASONIC_INDEX := 21
const TOUCH_0_INDEX := 27
const TOUCH_1_INDEX := 30

var rx_path := ""
var cargo_loaded := false

@export var transporter: Node3D
@export var cargo: Node3D

var tx_path := ""
var last_power_a := 999
var last_power_c := 999

const COURSE_HORIZONTAL_STRAIGHT := 0.300
const COURSE_VERTICAL_STRAIGHT := 0.094
const COURSE_CORNER_RADIUS := 0.145
const COURSE_ARC_SEGMENTS := 24

const LINE_HALF_WIDTH := 0.026 * 0.5
const REFLECT_ON_LINE := 5
const REFLECT_OFF_LINE := 50

var color_sensor_point: Node3D
var course_points := PackedVector2Array()
var reflect_value := REFLECT_ON_LINE

const ULTRASONIC_NO_DETECTION_MM := 2550
const ULTRASONIC_MAX_DISTANCE_M := 2.55

@export var delivery_wall: MeshInstance3D

var ultrasonic_origin: Node3D
var ultrasonic_distance_mm := ULTRASONIC_NO_DETECTION_MM

@export var ultrasonic_ray: MeshInstance3D

const BUMPER_CONTACT_TOLERANCE_M := 0.005
const GARAGE_WALL_WIDTH_M := 0.120
const WALL_HALF_THICKNESS_M := 0.005 * 0.5

@export var garage_wall: MeshInstance3D

var bumper_point: Node3D
var bumper_pressed := false

const BUMPER_LEFT_SHOULDER_OFFSET := Vector3(
	-0.0811,
	0.0,
	0.02117
)
const BUMPER_LEFT_NOSE_OFFSET := Vector3(
	-0.0650,
	0.0,
	0.0
)
const BUMPER_RIGHT_NOSE_OFFSET := Vector3(
	0.0651,
	0.0,
	0.0
)
const BUMPER_RIGHT_SHOULDER_OFFSET := Vector3(
	0.0816,
	0.0,
	0.02117
)

var ultrasonic_ray_mesh: CylinderMesh
var ultrasonic_ray_material: StandardMaterial3D

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
	
	if transporter != null:
		color_sensor_point = transporter.find_child(
			"ColorSensorPoint",
			true,
			false
		) as Node3D
		ultrasonic_origin = transporter.find_child(
			"UltrasonicSensorOrigin",
			true,
			false
		) as Node3D
		bumper_point = transporter.find_child(
			"BumperFrontExtreme",
			true,
			false
		) as Node3D

	build_course_points()

	if color_sensor_point == null:
		push_error("ColorSensorPoint was not found")
	if ultrasonic_origin == null:
		push_error("UltrasonicSensorOrigin was not found")
	if delivery_wall == null:
		push_error("DeliveryWall was not assigned")
	if bumper_point == null:
		push_error("BumperCompatibilityPoint was not found")
	if garage_wall == null:
		push_error("GarageWall was not assigned")
		
	setup_ultrasonic_ray_visual()
	update_cargo_visibility()

func _physics_process(_delta: float) -> void:
	update_color_sensor()
	update_ultrasonic_sensor()
	update_bumper_sensor()
	update_ultrasonic_ray_visual()
	write_vdev_rx()
	read_vdev_tx()


func read_vdev_tx() -> void:
	if not FileAccess.file_exists(tx_path):
		return

	var file := FileAccess.open(tx_path, FileAccess.READ)
	if file == null:
		return

	var data := file.get_buffer(64)
	file.close()

	if data.size() < 48:
		return

	if data.slice(0, 4).get_string_from_ascii() != "ETTX":
		return

	var power_a := data.decode_s32(POWER_A_OFFSET)
	var power_c := data.decode_s32(POWER_C_OFFSET)

	if transporter != null:
		transporter.set_motor_power(power_a, power_c)

	if (
		power_a != last_power_a
		or power_c != last_power_c
	):
		print(
			"Motor changed: A=",
			power_a,
			" C=",
			power_c
		)
		last_power_a = power_a
		last_power_c = power_c
		
func sensor_file_offset(index: int) -> int:
	return BODY_OFFSET + SENSOR_OFFSET + index * 4


func write_vdev_rx() -> void:
	if not FileAccess.file_exists(rx_path):
		return

	var file := FileAccess.open(rx_path, FileAccess.READ_WRITE)
	if file == null:
		return

	file.seek(0)
	file.store_buffer("ETRX".to_ascii_buffer())
	file.store_32(1)
	file.store_64(0)
	file.store_64(0)
	file.store_32(512)
	file.store_32(512)

	# 第1段階では安全な固定値。
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
	
func _unhandled_input(event: InputEvent) -> void:
	if not (
		event is InputEventKey
		and event.pressed
		and not event.echo
	):
		return

	if (
		event.keycode == KEY_L
		or event.physical_keycode == KEY_L
	):
		cargo_loaded = not cargo_loaded
		update_cargo_visibility()
		print("Cargo loaded: ", cargo_loaded)

func build_course_points() -> void:
	course_points.clear()

	var corner_x := COURSE_HORIZONTAL_STRAIGHT * 0.5
	var corner_z := COURSE_VERTICAL_STRAIGHT * 0.5

	append_course_arc(
		Vector2(corner_x, -corner_z),
		-PI * 0.5
	)
	append_course_arc(
		Vector2(corner_x, corner_z),
		0.0
	)
	append_course_arc(
		Vector2(-corner_x, corner_z),
		PI * 0.5
	)
	append_course_arc(
		Vector2(-corner_x, -corner_z),
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
		var closest := Geometry2D.get_closest_point_to_segment(
			point,
			course_points[index],
			course_points[index + 1]
		)
		minimum_distance = min(
			minimum_distance,
			point.distance_to(closest)
		)

	return minimum_distance


func update_color_sensor() -> void:
	if color_sensor_point == null:
		reflect_value = REFLECT_OFF_LINE
		return

	var sensor_world := color_sensor_point.global_position
	var sensor_on_course := Vector2(
		sensor_world.x,
		sensor_world.z
	)

	reflect_value = (
		REFLECT_ON_LINE
		if distance_to_course(sensor_on_course)
			<= LINE_HALF_WIDTH
		else REFLECT_OFF_LINE
	)

# Stage 1 compatibility model:
# Use one center ray to match the verified 2D implementation.
# A future physical model may replace this with a conical field of view.
func update_ultrasonic_sensor() -> void:
	ultrasonic_distance_mm = ULTRASONIC_NO_DETECTION_MM

	if (
		ultrasonic_origin == null
		or delivery_wall == null
	):
		return

	var ray_start_3d := ultrasonic_origin.global_position
	var ray_direction_3d := (
		ultrasonic_origin.global_transform.basis.x
	).normalized()

	var ray_start := Vector2(
		ray_start_3d.x,
		ray_start_3d.z
	)
	var ray_end := ray_start + Vector2(
		ray_direction_3d.x,
		ray_direction_3d.z
	) * ULTRASONIC_MAX_DISTANCE_M

	var wall_half_width := 0.080 * 0.5
	var wall_center := Vector2(
		delivery_wall.global_position.x,
		delivery_wall.global_position.z
	)
	var wall_start := wall_center + Vector2(
		-wall_half_width,
		0.0
	)
	var wall_end := wall_center + Vector2(
		wall_half_width,
		0.0
	)

	var hit = Geometry2D.segment_intersects_segment(
		ray_start,
		ray_end,
		wall_start,
		wall_end
	)

	if hit != null:
		ultrasonic_distance_mm = int(
			ray_start.distance_to(hit) * 1000.0
		)
		

func setup_ultrasonic_ray_visual() -> void:
	if ultrasonic_ray == null:
		push_error("UltrasonicRay was not assigned")
		return

	ultrasonic_ray_mesh = CylinderMesh.new()
	ultrasonic_ray_mesh.top_radius = 0.0015
	ultrasonic_ray_mesh.bottom_radius = 0.0015
	ultrasonic_ray_mesh.height = 0.40

	ultrasonic_ray_material = StandardMaterial3D.new()
	ultrasonic_ray_material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
	)
	ultrasonic_ray_material.albedo_color = Color(
		0.15,
		0.8,
		1.0
	)

	ultrasonic_ray_mesh.material = ultrasonic_ray_material
	ultrasonic_ray.mesh = ultrasonic_ray_mesh
	
func update_ultrasonic_ray_visual() -> void:
	if (
		ultrasonic_ray == null
		or ultrasonic_origin == null
		or ultrasonic_ray_mesh == null
		or ultrasonic_ray_material == null
	):
		return

	var detected := (
		ultrasonic_distance_mm
		< ULTRASONIC_NO_DETECTION_MM
	)
	var length_m := (
		float(ultrasonic_distance_mm) / 1000.0
		if detected
		else 0.40
	)

	ultrasonic_ray_mesh.height = length_m
	ultrasonic_ray_material.albedo_color = (
		Color(1.0, 0.25, 0.15)
		if detected
		else Color(0.15, 0.8, 1.0)
	)

	var start := ultrasonic_origin.global_position
	var direction := (
		ultrasonic_origin.global_transform.basis.x
	).normalized()
	var midpoint := start + direction * length_m * 0.5

	ultrasonic_ray.global_position = midpoint

	var up := Vector3.UP
	var axis := up.cross(direction)
	var dot: float = clampf(
		up.dot(direction),
		-1.0,
		1.0
	)

	if axis.length_squared() > 0.000001:
		ultrasonic_ray.global_basis = Basis(
			axis.normalized(),
			acos(dot)
		)


func update_bumper_sensor() -> void:
	bumper_pressed = false

	if (
		bumper_point == null
		or garage_wall == null
	):
		return

	var bumper_points := PackedVector2Array([
		bumper_outline_point(
			BUMPER_LEFT_SHOULDER_OFFSET
		),
		bumper_outline_point(
			BUMPER_LEFT_NOSE_OFFSET
		),
		bumper_outline_point(
			BUMPER_RIGHT_NOSE_OFFSET
		),
		bumper_outline_point(
			BUMPER_RIGHT_SHOULDER_OFFSET
		),
	])

	var wall_center_3d := garage_wall.global_position
	var wall_lateral_3d := (
		garage_wall.global_transform.basis.x
	).normalized()
	var wall_half_width := GARAGE_WALL_WIDTH_M * 0.5

	var wall_start_3d := (
		wall_center_3d
		- wall_lateral_3d * wall_half_width
	)
	var wall_end_3d := (
		wall_center_3d
		+ wall_lateral_3d * wall_half_width
	)

	var wall_start := Vector2(
		wall_start_3d.x,
		wall_start_3d.z
	)
	var wall_end := Vector2(
		wall_end_3d.x,
		wall_end_3d.z
	)

	var minimum_distance: float = INF

	for index in range(bumper_points.size() - 1):
		minimum_distance = minf(
			minimum_distance,
			segment_distance(
				bumper_points[index],
				bumper_points[index + 1],
				wall_start,
				wall_end
			)
		)

	var contact_distance := (
		BUMPER_CONTACT_TOLERANCE_M
		+ WALL_HALF_THICKNESS_M
	)

	bumper_pressed = (
		minimum_distance <= contact_distance
	)
	
func bumper_outline_point(offset: Vector3) -> Vector2:
	var point_3d := bumper_point.to_global(offset)
	return Vector2(point_3d.x, point_3d.z)


func segment_distance(
	a_start: Vector2,
	a_end: Vector2,
	b_start: Vector2,
	b_end: Vector2
) -> float:
	var intersection: Variant = (
		Geometry2D.segment_intersects_segment(
			a_start,
			a_end,
			b_start,
			b_end
		)
	)
	if intersection != null:
		return 0.0

	var closest_a_start: Vector2 = (
		Geometry2D.get_closest_point_to_segment(
			a_start,
			b_start,
			b_end
		)
	)
	var closest_a_end: Vector2 = (
		Geometry2D.get_closest_point_to_segment(
			a_end,
			b_start,
			b_end
		)
	)
	var closest_b_start: Vector2 = (
		Geometry2D.get_closest_point_to_segment(
			b_start,
			a_start,
			a_end
		)
	)
	var closest_b_end: Vector2 = (
		Geometry2D.get_closest_point_to_segment(
			b_end,
			a_start,
			a_end
		)
	)

	return minf(
		minf(
			a_start.distance_to(closest_a_start),
			a_end.distance_to(closest_a_end)
		),
		minf(
			b_start.distance_to(closest_b_start),
			b_end.distance_to(closest_b_end)
		)
	)

func update_cargo_visibility() -> void:
	if cargo != null:
		cargo.visible = cargo_loaded
