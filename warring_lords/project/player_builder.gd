const GC = preload("res://game_constants.gd")

static func create_player(index: int) -> Dictionary:
	return {
		"index": index,
		"alive": true,
		"color": GC.PLAYER_COLORS[index],
		"corner_x": GC.CORNERS[index][0] * GC.ARENA_W / 2.0,
		"corner_z": GC.CORNERS[index][1] * GC.ARENA_H / 2.0,
		"dir_x": -GC.CORNERS[index][0],
		"dir_z": -GC.CORNERS[index][1],
		"bricks": [],
		"king": null,
		"paddle": null,
		"paddle_t": 0.5,
		"catch_cooldown": 0.0,
		"paddle_scale": 1.0,
		"powerup_timer": 0.0,
		"catch_bar": null,
		"catch_bar_mat": null,
		"rockets": 0,
		"rocket_visuals": [],
		"paddle_on_fire": false,
		"fire_timer": 0.0,
		"fire_particles": null,
		"elbow_x": 0.0,
		"elbow_z": 0.0,
		"wall_a_z": 0.0,
		"wall_b_x": 0.0,
	}

static func build_all(parent: Node3D, p: Dictionary) -> void:
	_make_king(parent, p)
	_make_castle_bricks(parent, p)
	_make_paddle(parent, p)

static func compute_path_boundaries() -> Array:
	var wall_a_len := GC.CASTLE_W - GC.PADDLE_LENGTH / 2.0
	var wall_b_len := GC.CASTLE_H - GC.PADDLE_LENGTH / 2.0
	var corner_arc_len := PI / 2.0 * GC.PADDLE_OFFSET
	var total_len := wall_a_len + corner_arc_len + wall_b_len
	return [wall_a_len / total_len, (wall_a_len + corner_arc_len) / total_len]

# --- King ---

static var _knight_scene: Node = null

static func _load_knight_scene() -> Node:
	if _knight_scene != null:
		return _knight_scene
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file("res://models/Knight.glb", state)
	if err == OK:
		_knight_scene = doc.generate_scene(state)
	return _knight_scene

static func _tint_meshes(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var is_blade := node.name.find("Sword") >= 0
		var mesh := mi.mesh
		if mesh:
			for surf_idx in range(mesh.get_surface_count()):
				var orig_mat := mesh.surface_get_material(surf_idx)
				if is_blade:
					var silver := StandardMaterial3D.new()
					silver.albedo_color = Color(0.85, 0.85, 0.9)
					silver.metallic = 0.9
					silver.roughness = 0.15
					silver.emission_enabled = true
					silver.emission = Color(0.7, 0.7, 0.8) * 0.3
					silver.emission_energy_multiplier = 1.0
					mi.set_surface_override_material(surf_idx, silver)
				elif orig_mat and orig_mat is StandardMaterial3D:
					var tinted := orig_mat.duplicate() as StandardMaterial3D
					tinted.albedo_color = tinted.albedo_color.lerp(color, 0.5)
					tinted.emission_enabled = true
					tinted.emission = color * 0.3
					tinted.emission_energy_multiplier = 1.5
					mi.set_surface_override_material(surf_idx, tinted)
				else:
					var mat := StandardMaterial3D.new()
					mat.albedo_color = color
					mat.emission_enabled = true
					mat.emission = color * 0.2
					mi.set_surface_override_material(surf_idx, mat)
	for child in node.get_children():
		_tint_meshes(child, color)

static func _make_king(parent: Node3D, p: Dictionary) -> void:
	var body := StaticBody3D.new()
	var cell := GC.BRICK_D + GC.BRICK_GAP
	var kx: float = p["corner_x"] + p["dir_x"] * 5.5 * cell
	var kz: float = p["corner_z"] + p["dir_z"] * 2.0 * cell
	body.position = Vector3(kx, 0.0, kz)
	body.collision_layer = 1 << (2 + p["index"])
	body.collision_mask = 0

	var shape := SphereShape3D.new()
	shape.radius = GC.KING_RADIUS
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = GC.WALL_HEIGHT / 2.0
	body.add_child(col)

	var pivot := Node3D.new()
	pivot.name = "KingPivot"
	body.add_child(pivot)

	# Load Knight model
	var template := _load_knight_scene()
	if template:
		var model := template.duplicate()
		model.name = "KingModel"
		model.scale = Vector3(0.22, 0.22, 0.22)
		model.rotation.y = PI  # face -Z so look_at works correctly
		_tint_meshes(model, p["color"])
		pivot.add_child(model)
	else:
		# Fallback: simple colored sphere if model fails to load
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = GC.KING_RADIUS
		mi.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = p["color"]
		mat.emission_enabled = true
		mat.emission = p["color"] * 0.4
		mi.material_override = mat
		mi.position.y = GC.WALL_HEIGHT / 2.0
		pivot.add_child(mi)

	body.set_meta("type", "king")
	body.set_meta("player_index", p["index"])
	parent.add_child(body)
	p["king"] = body

# --- Castle Bricks ---

static func _make_castle_bricks(parent: Node3D, p: Dictionary) -> void:
	var cx: float = p["corner_x"]
	var cz: float = p["corner_z"]
	var dx: int = p["dir_x"]
	var dz: int = p["dir_z"]
	var cell := GC.BRICK_D + GC.BRICK_GAP
	var castle_end_x: float = cx + dx * GC.CASTLE_W
	var castle_end_z: float = cz + dz * GC.CASTLE_H
	p["bricks"] = []

	var rings := [
		[[6, "h", false], [2, "v", false]],
		[[1, "h", true], [6, "h", false], [1, "v", true], [2, "v", false]],
		[[7, "h", false], [3, "v", false]],
		[[1, "h", true], [7, "h", false], [1, "v", true], [3, "v", false]],
	]

	for ring_idx in range(rings.size()):
		var ring: Array = rings[ring_idx]
		var hp := 1
		var depth := 3 - ring_idx
		var a_z: float = castle_end_z - dz * (depth + 0.5) * cell
		var b_x: float = castle_end_x - dx * (depth + 1.5) * cell
		var h_cursor := 0.0
		var v_cursor := 0.0

		for seg in ring:
			var count: int = seg[0]
			var orient: String = seg[1]
			var is_half: bool = seg[2]

			for _i in range(count):
				var brick_cells := 1 if is_half else 2
				var length := GC.BRICK_D if is_half else GC.BRICK_W
				if orient == "h":
					var bx: float = cx + dx * (h_cursor + brick_cells / 2.0) * cell
					_spawn_brick(parent, p, Vector3(bx, GC.WALL_HEIGHT / 2.0, a_z),
						Vector3(length, GC.BRICK_H, GC.BRICK_D), hp)
					h_cursor += brick_cells
				else:
					var bz: float = cz + dz * (v_cursor + brick_cells / 2.0) * cell
					_spawn_brick(parent, p, Vector3(b_x, GC.WALL_HEIGHT / 2.0, bz),
						Vector3(GC.BRICK_D, GC.BRICK_H, length), hp)
					v_cursor += brick_cells

static func _spawn_brick(parent: Node3D, p: Dictionary, pos: Vector3, size: Vector3, hp: int) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1 << (2 + p["index"])
	body.collision_mask = 0
	body.set_meta("hp", hp)
	body.set_meta("max_hp", hp)
	body.set_meta("player_index", p["index"])
	body.set_meta("type", "brick")

	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	var brightness := 0.5 + 0.5 * (float(hp) / 3.0)
	mat.albedo_color = p["color"] * brightness
	mat.metallic = 0.15
	mat.roughness = 0.7
	mi.material_override = mat
	body.add_child(mi)

	parent.add_child(body)
	p["bricks"].append(body)

# --- Paddle ---

static func _make_paddle(parent: Node3D, p: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (2 + p["index"])
	body.collision_mask = 2
	body.set_meta("type", "paddle")
	body.set_meta("player_index", p["index"])

	var shape := BoxShape3D.new()
	shape.size = Vector3(GC.PADDLE_LENGTH, GC.WALL_HEIGHT, 0.25)
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(GC.PADDLE_LENGTH, GC.WALL_HEIGHT, 0.25)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = p["color"]
	mat.metallic = 0.5
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = p["color"] * 0.5
	mat.emission_energy_multiplier = 2.0
	mi.material_override = mat
	body.add_child(mi)

	# Catch cooldown bar
	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(GC.PADDLE_LENGTH, 0.04, 0.08)
	bar.mesh = bar_mesh
	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = Color(1.0, 1.0, 1.0)
	bar_mat.emission_enabled = true
	bar_mat.emission = Color(1.0, 1.0, 1.0)
	bar_mat.emission_energy_multiplier = 1.5
	bar.material_override = bar_mat
	var back_z: float = -float(p["dir_z"]) * 0.08
	bar.position = Vector3(0, GC.WALL_HEIGHT / 2.0, back_z)
	bar.scale.x = 0.0
	body.add_child(bar)
	p["catch_bar"] = bar
	p["catch_bar_mat"] = bar_mat

	var dx: int = p["dir_x"]
	var dz: int = p["dir_z"]
	var cx: float = p["corner_x"]
	var cz: float = p["corner_z"]
	var ex: float = cx + dx * GC.CASTLE_W
	var ez: float = cz + dz * GC.CASTLE_H
	p["elbow_x"] = ex
	p["elbow_z"] = ez
	p["wall_a_z"] = ez + dz * GC.PADDLE_OFFSET
	p["wall_b_x"] = ex + dx * GC.PADDLE_OFFSET

	parent.add_child(body)
	p["paddle"] = body

static func update_paddle_position(p: Dictionary, t_wall_a_end: float, t_corner_end: float) -> void:
	var paddle: StaticBody3D = p["paddle"]
	if paddle == null:
		return
	var t: float = p["paddle_t"]
	var cx: float = p["corner_x"]
	var dx: int = p["dir_x"]
	var dz: int = p["dir_z"]
	var ex: float = p["elbow_x"]
	var ez: float = p["elbow_z"]

	var wall_a_start_x: float = cx + dx * GC.PADDLE_LENGTH / 2.0
	var wall_b_end_z: float = p["corner_z"] + dz * GC.PADDLE_LENGTH / 2.0
	var wall_b_rot := PI / 2.0 * float(dx * dz)

	var px: float
	var pz: float
	var rot_y: float

	if t < t_wall_a_end:
		var lt: float = t / t_wall_a_end
		px = lerp(wall_a_start_x, ex, lt)
		pz = p["wall_a_z"]
		rot_y = 0.0
	elif t > t_corner_end:
		var lt: float = (t - t_corner_end) / (1.0 - t_corner_end)
		px = p["wall_b_x"]
		pz = lerp(ez, wall_b_end_z, lt)
		rot_y = wall_b_rot
	else:
		var lt: float = (t - t_wall_a_end) / (t_corner_end - t_wall_a_end)
		var a0: float = atan2(float(dz), 0.0)
		var a1: float = atan2(0.0, float(dx))
		var angle: float = lerp_angle(a0, a1, lt)
		px = ex + cos(angle) * GC.PADDLE_OFFSET
		pz = ez + sin(angle) * GC.PADDLE_OFFSET
		rot_y = lerp_angle(0.0, wall_b_rot, lt)

	paddle.position = Vector3(px, GC.WALL_HEIGHT / 2.0, pz)
	paddle.rotation.y = rot_y

static func update_paddle_mesh(p: Dictionary) -> void:
	var paddle: StaticBody3D = p["paddle"]
	if paddle == null or not is_instance_valid(paddle):
		return
	var scale_factor: float = p.get("paddle_scale", 1.0)
	var length: float = GC.PADDLE_LENGTH * scale_factor
	var col := paddle.get_child(0) as CollisionShape3D
	if col:
		var shape := col.shape as BoxShape3D
		if shape:
			shape.size = Vector3(length, GC.WALL_HEIGHT, 0.25)
	var mi := paddle.get_child(1) as MeshInstance3D
	if mi:
		var bm := mi.mesh as BoxMesh
		if bm:
			bm.size = Vector3(length, GC.WALL_HEIGHT, 0.25)

static func get_paddle_outward(p: Dictionary) -> Vector3:
	var paddle: StaticBody3D = p["paddle"]
	if paddle and is_instance_valid(paddle):
		var local_z: Vector3 = paddle.basis * Vector3(0, 0, 1)
		local_z.y = 0.0
		local_z = local_z.normalized()
		var corner := Vector3(p["corner_x"], 0, p["corner_z"])
		var paddle_to_corner := (corner - paddle.position)
		paddle_to_corner.y = 0.0
		if local_z.dot(paddle_to_corner) < 0:
			return local_z
		else:
			return -local_z
	return Vector3(p["dir_x"], 0, p["dir_z"]).normalized()
