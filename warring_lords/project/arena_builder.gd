const GC = preload("res://game_constants.gd")

static func setup(parent: Node3D) -> Camera3D:
	_make_env(parent)
	var cam := _make_camera()
	parent.add_child(cam)
	_make_floor(parent)
	return cam

static func _make_env(parent: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.15, 0.12, 0.1)
	env.ambient_light_energy = 0.4
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

	var dl := DirectionalLight3D.new()
	dl.light_color = Color(1.0, 0.95, 0.85)
	dl.light_energy = 0.7
	dl.rotation_degrees = Vector3(-60, 30, 0)
	dl.shadow_enabled = true
	parent.add_child(dl)

	var fl := DirectionalLight3D.new()
	fl.light_color = Color(0.4, 0.45, 0.7)
	fl.light_energy = 0.3
	fl.rotation_degrees = Vector3(-40, -150, 0)
	parent.add_child(fl)

static func _make_camera() -> Camera3D:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	var cam_angle := -70.0
	var cam_height := 20.0
	var cam_z_offset := cam_height * tan(deg_to_rad(90.0 - abs(cam_angle)))
	camera.position = Vector3(0, cam_height, cam_z_offset)
	camera.rotation_degrees = Vector3(cam_angle, 0, 0)
	camera.size = GC.ARENA_H * sin(deg_to_rad(abs(cam_angle)))
	return camera

static func _make_floor(parent: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(GC.ARENA_W + 2.0, GC.ARENA_H + 2.0)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.07, 0.1)
	mat.metallic = 0.2
	mat.roughness = 0.8
	mi.material_override = mat
	mi.position = Vector3(0, -0.01, 0)
	parent.add_child(mi)
