extends Node3D

const INITIAL_POSITION := Vector3(0.08, 0.0, 0.248)
const INITIAL_YAW := PI * 0.5

const MOTOR_SPEED_SCALE := 0.003
const WHEEL_DISTANCE := 0.118

var motor_power_a := 0
var motor_power_c := 0
var yaw := INITIAL_YAW


func _ready() -> void:
	reset_robot()


func _physics_process(delta: float) -> void:
	update_robot(delta)


func reset_robot() -> void:
	position = INITIAL_POSITION
	yaw = INITIAL_YAW
	rotation = Vector3(0.0, yaw, 0.0)


func update_robot(delta: float) -> void:
	var left_speed := float(motor_power_a) * MOTOR_SPEED_SCALE
	var right_speed := float(motor_power_c) * MOTOR_SPEED_SCALE

	var linear_speed := (left_speed + right_speed) * 0.5
	var angular_speed := (
		left_speed - right_speed
	) / WHEEL_DISTANCE

	yaw += angular_speed * delta
	rotation.y = yaw

	var forward := -global_transform.basis.z
	position += forward * linear_speed * delta


func set_motor_power(
	power_a: int,
	power_c: int
) -> void:
	motor_power_a = power_a
	motor_power_c = power_c


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_SPACE
	):
		reset_robot()
