@tool
extends MeshInstance3D

const HORIZONTAL_STRAIGHT := 0.300
const VERTICAL_STRAIGHT := 0.094
const CORNER_RADIUS := 0.145
const LINE_WIDTH := 0.026
const ARC_SEGMENTS := 24
# const LINE_HEIGHT := 0.0005
const LINE_HEIGHT := 0.002


func _ready() -> void:
	build_course_mesh()


func build_course_mesh() -> void:
	var centerline := build_centerline()
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var count := centerline.size()

	for index in range(count):
		var previous := centerline[(index - 1 + count) % count]
		var current := centerline[index]
		var following := centerline[(index + 1) % count]

		var tangent := (following - previous).normalized()
		var side := Vector2(-tangent.y, tangent.x)
		var half_width := LINE_WIDTH * 0.5

		var left := current + side * half_width
		var right := current - side * half_width

		vertices.append(Vector3(left.x, LINE_HEIGHT, left.y))
		vertices.append(Vector3(right.x, LINE_HEIGHT, right.y))

	for index in range(count):
		var following := (index + 1) % count

		var left_a := index * 2
		var right_a := left_a + 1
		var left_b := following * 2
		var right_b := left_b + 1

		indices.append_array([
			left_a, left_b, right_a,
			right_a, left_b, right_b,
		])

	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var generated_mesh := ArrayMesh.new()
	generated_mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		arrays
	)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.03, 0.03, 0.03)
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	generated_mesh.surface_set_material(0, material)

	mesh = generated_mesh


func build_centerline() -> PackedVector2Array:
	var points := PackedVector2Array()
	var corner_x := HORIZONTAL_STRAIGHT * 0.5
	var corner_y := VERTICAL_STRAIGHT * 0.5

	append_arc(
		points,
		Vector2(corner_x, -corner_y),
		-PI * 0.5
	)
	append_arc(
		points,
		Vector2(corner_x, corner_y),
		0.0
	)
	append_arc(
		points,
		Vector2(-corner_x, corner_y),
		PI * 0.5
	)
	append_arc(
		points,
		Vector2(-corner_x, -corner_y),
		PI
	)

	return points


func append_arc(
	points: PackedVector2Array,
	center: Vector2,
	start_angle: float
) -> void:
	for step in range(ARC_SEGMENTS + 1):
		var ratio := float(step) / float(ARC_SEGMENTS)
		var angle := start_angle + ratio * PI * 0.5

		points.append(
			center
			+ Vector2(cos(angle), sin(angle))
			* CORNER_RADIUS
		)
