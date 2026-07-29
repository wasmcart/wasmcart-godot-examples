const GC = preload("res://game_constants.gd")
const PlayerBuilder = preload("res://player_builder.gd")
const Effects = preload("res://effects.gd")
const AudioManager = preload("res://audio_manager.gd")

var active_items := []
var active_rockets := []
var active_molotovs := []

static var _bottle_scene: Node = null

static func _load_bottle_scene() -> Node:
	if _bottle_scene != null:
		return _bottle_scene
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file("res://models/bottle.glb", state)
	if err == OK:
		_bottle_scene = doc.generate_scene(state)
	return _bottle_scene

static func _make_bottle_model(emissive: bool) -> Node3D:
	var scene := _load_bottle_scene()
	if scene == null:
		var root := Node3D.new()
		var mi := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.03
		mesh.bottom_radius = 0.05
		mesh.height = 0.2
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.5, 0.15, 0.7)
		mi.material_override = mat
		root.add_child(mi)
		return root
	var instance := scene.duplicate() as Node3D
	_tint_bottle_meshes(instance, emissive)
	return instance

static func _tint_bottle_meshes(node: Node, emissive: bool) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 0.45, 0.1, 0.7)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.metallic = 0.3
		mat.roughness = 0.2
		if emissive:
			mat.emission_enabled = true
			mat.emission = Color(0.1, 0.3, 0.05)
			mat.emission_energy_multiplier = 1.0
		mi.material_override = mat
	for child in node.get_children():
		_tint_bottle_meshes(child, emissive)

var _parent: Node3D
var _audio: AudioManager
var _game  # reference to main for brick hit callback

func _init(parent: Node3D, audio: AudioManager, game) -> void:
	_parent = parent
	_audio = audio
	_game = game

func place_dots(players: Array) -> void:
	for p in players:
		var bricks: Array = p["bricks"]
		var count := mini(GC.POWERUP_COUNT, bricks.size())
		var indices := []
		for i in range(bricks.size()):
			indices.append(i)
		for i in range(indices.size() - 1, 0, -1):
			var j := randi() % (i + 1)
			var tmp: int = indices[i]
			indices[i] = indices[j]
			indices[j] = tmp
		for i in range(count):
			var brick: StaticBody3D = bricks[indices[i]]
			var roll := randf()
			var ptype: int
			if roll < 0.25:
				ptype = GC.PowerupType.ENLARGE
			elif roll < 0.5:
				ptype = GC.PowerupType.SHRINK
			elif roll < 0.75:
				ptype = GC.PowerupType.ROCKET
			else:
				ptype = GC.PowerupType.MOLOTOV
			brick.set_meta("has_powerup", true)
			brick.set_meta("powerup_type", ptype)
			var dot := MeshInstance3D.new()
			var dot_mesh := SphereMesh.new()
			dot_mesh.radius = 0.06
			dot_mesh.height = 0.12
			dot.mesh = dot_mesh
			var dot_mat := StandardMaterial3D.new()
			dot_mat.albedo_color = Color(1.0, 1.0, 1.0)
			dot_mat.emission = Color(0.8, 0.8, 0.8)
			dot_mat.emission_enabled = true
			dot_mat.emission_energy_multiplier = 2.0
			dot.material_override = dot_mat
			dot.position.y = GC.BRICK_H / 2.0 + 0.06
			brick.add_child(dot)

func _make_plus_shape() -> Node3D:
	var root := Node3D.new()
	var green_mat := StandardMaterial3D.new()
	green_mat.albedo_color = Color(0.2, 1.0, 0.3)
	green_mat.emission_enabled = true
	green_mat.emission = Color(0.1, 0.8, 0.2)
	green_mat.emission_energy_multiplier = 3.0
	var grey_mat := StandardMaterial3D.new()
	grey_mat.albedo_color = Color(0.6, 0.6, 0.6)
	grey_mat.metallic = 0.3
	grey_mat.roughness = 0.5
	# Horizontal bar (green)
	var h_bar := MeshInstance3D.new()
	var h_mesh := BoxMesh.new()
	h_mesh.size = Vector3(0.28, 0.08, 0.08)
	h_bar.mesh = h_mesh
	h_bar.material_override = green_mat
	root.add_child(h_bar)
	# Vertical bar (green)
	var v_bar := MeshInstance3D.new()
	var v_mesh := BoxMesh.new()
	v_mesh.size = Vector3(0.08, 0.28, 0.08)
	v_bar.mesh = v_mesh
	v_bar.material_override = green_mat
	root.add_child(v_bar)
	# Depth bar (grey)
	var d_bar := MeshInstance3D.new()
	var d_mesh := BoxMesh.new()
	d_mesh.size = Vector3(0.08, 0.08, 0.28)
	d_bar.mesh = d_mesh
	d_bar.material_override = grey_mat
	root.add_child(d_bar)
	return root

func _make_minus_shape() -> Node3D:
	var root := Node3D.new()
	var red_mat := StandardMaterial3D.new()
	red_mat.albedo_color = Color(1.0, 0.2, 0.2)
	red_mat.emission_enabled = true
	red_mat.emission = Color(0.8, 0.1, 0.1)
	red_mat.emission_energy_multiplier = 3.0
	var grey_mat := StandardMaterial3D.new()
	grey_mat.albedo_color = Color(0.6, 0.6, 0.6)
	grey_mat.metallic = 0.3
	grey_mat.roughness = 0.5
	# Single horizontal bar — red front/back, grey ends
	var h_bar := MeshInstance3D.new()
	var h_mesh := BoxMesh.new()
	h_mesh.size = Vector3(0.28, 0.08, 0.12)
	h_bar.mesh = h_mesh
	h_bar.material_override = red_mat
	root.add_child(h_bar)
	# Grey cap left
	var cap_l := MeshInstance3D.new()
	var cl_mesh := BoxMesh.new()
	cl_mesh.size = Vector3(0.04, 0.08, 0.12)
	cap_l.mesh = cl_mesh
	cap_l.position.x = -0.16
	cap_l.material_override = grey_mat
	root.add_child(cap_l)
	# Grey cap right
	var cap_r := MeshInstance3D.new()
	var cr_mesh := BoxMesh.new()
	cr_mesh.size = Vector3(0.04, 0.08, 0.12)
	cap_r.mesh = cr_mesh
	cap_r.position.x = 0.16
	cap_r.material_override = grey_mat
	root.add_child(cap_r)
	return root

func _make_rocket_item() -> Node3D:
	var root := Node3D.new()
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.7, 0.7, 0.7)
	body_mat.metallic = 0.5
	body_mat.roughness = 0.3
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(1.0, 0.3, 0.0)
	nose_mat.emission_enabled = true
	nose_mat.emission = Color(1.0, 0.2, 0.0)
	nose_mat.emission_energy_multiplier = 2.0
	var fin_mat := StandardMaterial3D.new()
	fin_mat.albedo_color = Color(0.9, 0.2, 0.0)
	# Body cylinder
	var body := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.06
	bm.bottom_radius = 0.06
	bm.height = 0.35
	body.mesh = bm
	body.material_override = body_mat
	root.add_child(body)
	# Nose cone on top
	var nose := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.0
	nm.bottom_radius = 0.06
	nm.height = 0.16
	nose.mesh = nm
	nose.position.y = 0.25
	nose.material_override = nose_mat
	root.add_child(nose)
	# Fins at bottom
	for f in range(4):
		var fin := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.12, 0.1, 0.015)
		fin.mesh = fm
		var angle := f * TAU / 4.0
		fin.position = Vector3(cos(angle) * 0.07, -0.14, sin(angle) * 0.07)
		fin.material_override = fin_mat
		root.add_child(fin)
	return root

func spawn_item(pos: Vector3, ptype: int, target_player: int, source_player: int, players: Array) -> void:
	if target_player < 0 or target_player >= 4:
		return
	if not players[target_player]["alive"]:
		return
	var item := Node3D.new()
	item.position = pos
	if ptype == GC.PowerupType.ENLARGE:
		var shape := _make_plus_shape()
		item.add_child(shape)
	elif ptype == GC.PowerupType.SHRINK:
		var shape := _make_minus_shape()
		item.add_child(shape)
	else:
		if ptype == GC.PowerupType.ROCKET:
			var rkt := _make_rocket_item()
			item.add_child(rkt)
		else:
			var bottle := _make_bottle_model(false)
			bottle.scale = Vector3(0.6, 0.6, 0.6)
			item.add_child(bottle)
	if ptype != GC.PowerupType.MOLOTOV:
		var light_color := Color(1, 1, 1)
		if ptype == GC.PowerupType.ENLARGE:
			light_color = Color(0.2, 1.0, 0.3)
		elif ptype == GC.PowerupType.SHRINK:
			light_color = Color(1.0, 0.2, 0.2)
		elif ptype == GC.PowerupType.ROCKET:
			light_color = Color(1.0, 0.6, 0.1)
		var light := OmniLight3D.new()
		light.light_color = light_color
		light.light_energy = 0.8
		light.omni_range = 1.5
		light.omni_attenuation = 1.5
		item.add_child(light)
	item.set_meta("powerup_type", ptype)
	item.set_meta("target_player", target_player)
	item.set_meta("source_player", source_player)
	_parent.add_child(item)
	active_items.append(item)

func process_items(delta: float, players: Array) -> void:
	var to_remove := []
	for item in active_items:
		if not is_instance_valid(item):
			to_remove.append(item)
			continue
		var target_idx: int = item.get_meta("target_player")
		if target_idx < 0 or target_idx >= players.size() or not players[target_idx]["alive"]:
			item.queue_free()
			to_remove.append(item)
			continue
		var king: StaticBody3D = players[target_idx]["king"]
		if king == null or not is_instance_valid(king):
			item.queue_free()
			to_remove.append(item)
			continue
		var target_pos := king.position
		target_pos.y = GC.WALL_HEIGHT / 2.0
		var dir: Vector3 = (target_pos - item.position)
		dir.y = 0.0
		var dist: float = dir.length()
		var paddle: StaticBody3D = players[target_idx]["paddle"]
		if paddle and is_instance_valid(paddle):
			var paddle_dist: float = (paddle.position - item.position).length()
			if paddle_dist < 0.5:
				var source_idx: int = item.get_meta("source_player")
				_apply_powerup(target_idx, item.get_meta("powerup_type"), source_idx, players)
				item.queue_free()
				to_remove.append(item)
				continue
		if dist < 0.3:
			item.queue_free()
			to_remove.append(item)
			continue
		item.position += dir.normalized() * GC.POWERUP_DRIFT_SPEED * delta
		item.position.y = GC.WALL_HEIGHT / 2.0
		var child := item.get_child(0) as Node3D
		if child:
			child.rotation.y += delta * 4.0
			child.rotation.x += delta * 2.5
			child.rotation.z += delta * 1.5
	for item in to_remove:
		active_items.erase(item)

func _apply_powerup(player_idx: int, ptype: int, source_player: int, players: Array) -> void:
	var p: Dictionary = players[player_idx]
	_audio.play_sound(_audio.snd_countdown, -3.0)
	if ptype == GC.PowerupType.ENLARGE:
		p["paddle_scale"] = 1.6
		p["powerup_timer"] = GC.POWERUP_EFFECT_DURATION
		PlayerBuilder.update_paddle_mesh(p)
	elif ptype == GC.PowerupType.SHRINK:
		p["paddle_scale"] = 0.5
		p["powerup_timer"] = GC.POWERUP_EFFECT_DURATION
		PlayerBuilder.update_paddle_mesh(p)
	elif ptype == GC.PowerupType.ROCKET:
		if p["rockets"] < GC.MAX_ROCKETS:
			p["rockets"] += 1
			update_rocket_visuals(p)
	elif ptype == GC.PowerupType.MOLOTOV:
		_launch_molotov(player_idx, source_player, players)

func update_rocket_visuals(p: Dictionary) -> void:
	for vis in p["rocket_visuals"]:
		if is_instance_valid(vis):
			vis.queue_free()
	p["rocket_visuals"] = []
	var paddle: StaticBody3D = p["paddle"]
	if paddle == null or not is_instance_valid(paddle):
		return
	var count: int = p["rockets"]
	var front_z: float = float(p["dir_z"]) * 0.18
	for i in range(count):
		var rocket_node := Node3D.new()
		var x_off: float = -0.2 if i == 0 else 0.2
		rocket_node.position = Vector3(x_off, 0.0, front_z)
		var body_mi := MeshInstance3D.new()
		var body_mesh := CylinderMesh.new()
		body_mesh.top_radius = 0.03
		body_mesh.bottom_radius = 0.03
		body_mesh.height = 0.22
		body_mi.mesh = body_mesh
		var body_mat := StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.7, 0.7, 0.7)
		body_mat.metallic = 0.6
		body_mat.roughness = 0.3
		body_mi.material_override = body_mat
		rocket_node.add_child(body_mi)
		var nose := MeshInstance3D.new()
		var nose_mesh := CylinderMesh.new()
		nose_mesh.top_radius = 0.0
		nose_mesh.bottom_radius = 0.03
		nose_mesh.height = 0.08
		nose.mesh = nose_mesh
		nose.position.y = 0.15
		var nose_mat := StandardMaterial3D.new()
		nose_mat.albedo_color = Color(1.0, 0.3, 0.0)
		nose_mat.emission_enabled = true
		nose_mat.emission = Color(1.0, 0.2, 0.0)
		nose_mat.emission_energy_multiplier = 1.5
		nose.material_override = nose_mat
		rocket_node.add_child(nose)
		var fin_mat := StandardMaterial3D.new()
		fin_mat.albedo_color = Color(0.9, 0.2, 0.0)
		for f in range(4):
			var fin := MeshInstance3D.new()
			var fin_mesh := BoxMesh.new()
			fin_mesh.size = Vector3(0.06, 0.06, 0.01)
			fin.mesh = fin_mesh
			var angle := f * TAU / 4.0
			fin.position = Vector3(cos(angle) * 0.04, -0.1, sin(angle) * 0.04)
			fin.material_override = fin_mat
			rocket_node.add_child(fin)
		paddle.add_child(rocket_node)
		p["rocket_visuals"].append(rocket_node)

func fire_rocket(player_idx: int, players: Array) -> void:
	var p: Dictionary = players[player_idx]
	if p["rockets"] <= 0:
		return
	p["rockets"] -= 1
	var paddle: StaticBody3D = p["paddle"]
	if paddle == null or not is_instance_valid(paddle):
		update_rocket_visuals(p)
		return
	var outward := PlayerBuilder.get_paddle_outward(p)
	var launch_pos := paddle.position + outward * 0.3
	launch_pos.y = GC.WALL_HEIGHT / 2.0
	update_rocket_visuals(p)
	_audio.play_explosion()

	var rocket := Node3D.new()
	rocket.position = launch_pos

	# All geometry in a child so we can orient the parent with look_at
	var model := Node3D.new()
	rocket.add_child(model)

	# Rocket body — built along -Z (forward)
	var body_mi := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.07
	body_mesh.bottom_radius = 0.07
	body_mesh.height = 0.5
	body_mi.mesh = body_mesh
	body_mi.rotation.x = PI / 2.0  # lay cylinder along Z
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.7, 0.7, 0.7)
	body_mat.metallic = 0.6
	body_mat.roughness = 0.3
	body_mi.material_override = body_mat
	model.add_child(body_mi)

	# Nose cone — tip at front (-Z)
	var nose := MeshInstance3D.new()
	var nose_mesh := CylinderMesh.new()
	nose_mesh.top_radius = 0.0
	nose_mesh.bottom_radius = 0.07
	nose_mesh.height = 0.18
	nose.mesh = nose_mesh
	nose.rotation.x = PI / 2.0
	nose.position.z = -0.34
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(1.0, 0.3, 0.0)
	nose_mat.emission_enabled = true
	nose_mat.emission = Color(1.0, 0.2, 0.0)
	nose_mat.emission_energy_multiplier = 2.5
	nose.material_override = nose_mat
	model.add_child(nose)

	# Fins at the tail (+Z)
	var fin_mat := StandardMaterial3D.new()
	fin_mat.albedo_color = Color(0.9, 0.2, 0.0)
	fin_mat.metallic = 0.3
	for f in range(4):
		var fin := MeshInstance3D.new()
		var fin_mesh := BoxMesh.new()
		fin_mesh.size = Vector3(0.14, 0.14, 0.02)
		fin.mesh = fin_mesh
		var angle := f * TAU / 4.0
		fin.position = Vector3(cos(angle) * 0.08, sin(angle) * 0.08, 0.24)
		fin.material_override = fin_mat
		model.add_child(fin)

	# Engine glow at tail
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.1)
	light.light_energy = 3.0
	light.omni_range = 4.0
	light.omni_attenuation = 1.5
	light.position.z = 0.3
	model.add_child(light)

	# Smoke trail — thick billowing smoke from the tail
	var trail := GPUParticles3D.new()
	trail.emitting = true
	trail.amount = 40
	trail.lifetime = 0.8
	trail.fixed_fps = 30
	trail.local_coords = false
	trail.position.z = 0.3
	var tmat := ParticleProcessMaterial.new()
	tmat.direction = Vector3(0, 1, 0)
	tmat.spread = 30.0
	tmat.initial_velocity_min = 0.3
	tmat.initial_velocity_max = 1.5
	tmat.gravity = Vector3(0, 1.5, 0)
	tmat.scale_min = 0.8
	tmat.scale_max = 2.5
	tmat.damping_min = 1.0
	tmat.damping_max = 3.0
	var smoke_grad := Gradient.new()
	smoke_grad.set_offset(0, 0.0)
	smoke_grad.set_color(0, Color(1.0, 0.7, 0.1, 0.9))
	smoke_grad.add_point(0.15, Color(1.0, 0.4, 0.05, 0.8))
	smoke_grad.add_point(0.4, Color(0.6, 0.6, 0.6, 0.5))
	smoke_grad.set_offset(1, 1.0)
	smoke_grad.set_color(1, Color(0.3, 0.3, 0.3, 0.0))
	var smoke_gtex := GradientTexture1D.new()
	smoke_gtex.gradient = smoke_grad
	tmat.color_ramp = smoke_gtex
	# Scale curve: start small (fire), grow into big smoke puffs
	var scale_curve := CurveTexture.new()
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.3))
	sc.add_point(Vector2(0.2, 0.7))
	sc.add_point(Vector2(1.0, 1.0))
	scale_curve.curve = sc
	tmat.scale_curve = scale_curve
	trail.process_material = tmat
	var smoke_mesh := QuadMesh.new()
	smoke_mesh.size = Vector2(0.25, 0.25)
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.vertex_color_use_as_albedo = true
	smoke_mat.emission_enabled = true
	smoke_mat.emission = Color(1.0, 0.5, 0.1)
	smoke_mat.emission_energy_multiplier = 2.0
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var smoke_tex := Effects._get_smoke_tex()
	if smoke_tex:
		smoke_mat.albedo_texture = smoke_tex
	smoke_mesh.material = smoke_mat
	trail.draw_pass_1 = smoke_mesh
	model.add_child(trail)

	# Orient rocket: -Z faces travel direction via look_at
	rocket.set_meta("direction", outward)
	rocket.set_meta("player_index", player_idx)
	var target_pos := launch_pos + outward
	target_pos.y = launch_pos.y
	_parent.add_child(rocket)
	rocket.look_at(target_pos, Vector3.UP)
	active_rockets.append(rocket)

func process_rockets(delta: float, players: Array) -> void:
	var to_remove := []
	for rocket in active_rockets:
		if not is_instance_valid(rocket):
			to_remove.append(rocket)
			continue
		var dir: Vector3 = rocket.get_meta("direction")
		rocket.position += dir * GC.ROCKET_SPEED * delta
		rocket.position.y = GC.WALL_HEIGHT / 2.0
		var hw := GC.ARENA_W / 2.0
		var hh := GC.ARENA_H / 2.0
		if absf(rocket.position.x) > hw or absf(rocket.position.z) > hh:
			rocket.queue_free()
			to_remove.append(rocket)
			continue
		var hit := false
		for p in players:
			if not p["alive"]:
				continue
			for brick in p["bricks"]:
				if not is_instance_valid(brick):
					continue
				var dist: float = (brick.position - rocket.position).length()
				if dist < 0.35:
					_game.last_hit_player = rocket.get_meta("player_index")
					_game.on_brick_hit(brick)
					Effects.spawn_rocket_explosion(_parent, rocket.position)
					_audio.play_explosion()
					rocket.queue_free()
					to_remove.append(rocket)
					hit = true
					break
			if hit:
				break
	for rocket in to_remove:
		active_rockets.erase(rocket)

func _launch_molotov(thrower_idx: int, target_idx: int, players: Array) -> void:
	var thrower: Dictionary = players[thrower_idx]
	var target: Dictionary = players[target_idx]
	var king: StaticBody3D = thrower["king"]
	if king == null or not is_instance_valid(king):
		return
	if not target["alive"]:
		return
	var target_king: StaticBody3D = target["king"]
	if target_king == null or not is_instance_valid(target_king):
		return

	var start_pos := king.position
	start_pos.y = GC.WALL_HEIGHT / 2.0
	var end_pos := target_king.position
	end_pos.y = GC.WALL_HEIGHT / 2.0

	var molotov := Node3D.new()
	molotov.position = start_pos

	# Bottle model from GLB
	var bottle := _make_bottle_model(true)
	bottle.scale = Vector3(0.8, 0.8, 0.8)
	molotov.add_child(bottle)
	# Rag cloth sticking out the top (small tilted box)
	var rag := MeshInstance3D.new()
	var rag_mesh := BoxMesh.new()
	rag_mesh.size = Vector3(0.02, 0.07, 0.02)
	rag.mesh = rag_mesh
	rag.position.y = 0.58
	rag.rotation.z = 0.3
	var rag_mat := StandardMaterial3D.new()
	rag_mat.albedo_color = Color(0.8, 0.7, 0.5)
	rag_mat.roughness = 0.9
	rag.material_override = rag_mat
	molotov.add_child(rag)

	# Fire on the rag — bright and visible
	var fire := GPUParticles3D.new()
	fire.emitting = true
	fire.amount = 24
	fire.lifetime = 0.35
	fire.fixed_fps = 30
	fire.position.y = 0.62
	var fmat := ParticleProcessMaterial.new()
	fmat.direction = Vector3(0, 1, 0)
	fmat.spread = 25.0
	fmat.initial_velocity_min = 0.5
	fmat.initial_velocity_max = 1.5
	fmat.gravity = Vector3(0, 2.0, 0)
	fmat.scale_min = 0.5
	fmat.scale_max = 1.2
	var fire_grad := Gradient.new()
	fire_grad.set_color(0, Color(1.0, 1.0, 0.5, 1.0))
	fire_grad.add_point(0.3, Color(1.0, 0.6, 0.0, 0.9))
	fire_grad.set_color(1, Color(0.8, 0.2, 0.0, 0.0))
	var fire_gtex := GradientTexture1D.new()
	fire_gtex.gradient = fire_grad
	fmat.color_ramp = fire_gtex
	fire.process_material = fmat
	var fmesh := QuadMesh.new()
	fmesh.size = Vector2(0.1, 0.1)
	var fmesh_mat := StandardMaterial3D.new()
	fmesh_mat.vertex_color_use_as_albedo = true
	fmesh_mat.emission_enabled = true
	fmesh_mat.emission = Color(1.0, 0.6, 0.1)
	fmesh_mat.emission_energy_multiplier = 6.0
	fmesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fmesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmesh_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var ftex := Effects._get_fire_tex()
	if ftex:
		fmesh_mat.albedo_texture = ftex
	fmesh.material = fmesh_mat
	fire.draw_pass_1 = fmesh
	molotov.add_child(fire)

	# Light from the flame — bright
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.1)
	light.light_energy = 4.0
	light.omni_range = 5.0
	light.omni_attenuation = 1.5
	light.position.y = 0.62
	molotov.add_child(light)

	molotov.set_meta("start_pos", start_pos)
	molotov.set_meta("end_pos", end_pos)
	molotov.set_meta("elapsed", 0.0)
	molotov.set_meta("target_player", target_idx)
	molotov.set_meta("thrower", thrower_idx)
	_parent.add_child(molotov)
	active_molotovs.append(molotov)
	_audio.play_explosion()

func process_molotovs(delta: float, players: Array) -> void:
	var to_remove := []
	for molotov in active_molotovs:
		if not is_instance_valid(molotov):
			to_remove.append(molotov)
			continue
		var elapsed: float = molotov.get_meta("elapsed") + delta
		molotov.set_meta("elapsed", elapsed)
		var t: float = elapsed / GC.MOLOTOV_FLIGHT_TIME
		# Interpolate position with arc
		var start_pos: Vector3 = molotov.get_meta("start_pos")
		var end_pos: Vector3 = molotov.get_meta("end_pos")
		var pos := start_pos.lerp(end_pos, t)
		pos.y += sin(t * PI) * GC.MOLOTOV_ARC_HEIGHT
		molotov.position = pos
		molotov.rotation.z += delta * 6.0

		# Ground position for XZ collision (ignore arc height)
		var ground_pos := Vector3(pos.x, GC.WALL_HEIGHT / 2.0, pos.z)
		var ti: int = molotov.get_meta("target_player")

		# Check paddle collision first — blocked, paddle catches fire
		if ti >= 0 and ti < players.size() and players[ti]["alive"]:
			var paddle: StaticBody3D = players[ti]["paddle"]
			if paddle and is_instance_valid(paddle):
				var pdiff: Vector3 = ground_pos - paddle.position
				pdiff.y = 0.0
				if pdiff.length() < 0.6:
					_set_paddle_on_fire(players[ti])
					Effects.spawn_molotov_explosion(_parent, ground_pos)
					_audio.play_explosion()
					molotov.queue_free()
					to_remove.append(molotov)
					continue

		# Check brick collision — destroys one brick and stops
		var hit_brick := false
		if ti >= 0 and ti < players.size() and players[ti]["alive"]:
			for brick in players[ti]["bricks"]:
				if not is_instance_valid(brick):
					continue
				var bdiff: Vector3 = ground_pos - brick.position
				bdiff.y = 0.0
				if bdiff.length() < 0.4:
					_game.last_hit_player = molotov.get_meta("thrower")
					_game.on_brick_hit(brick)
					Effects.spawn_molotov_explosion(_parent, ground_pos)
					_audio.play_explosion()
					molotov.queue_free()
					to_remove.append(molotov)
					hit_brick = true
					break
		if hit_brick:
			continue

		if t >= 1.0:
			# Made it through everything — hit the king
			Effects.spawn_molotov_explosion(_parent, ground_pos)
			_audio.play_explosion()
			if players[ti]["alive"] and players[ti]["king"] and is_instance_valid(players[ti]["king"]):
				_game.on_king_hit(players[ti]["king"])
			molotov.queue_free()
			to_remove.append(molotov)
			continue
	for molotov in to_remove:
		active_molotovs.erase(molotov)

func _set_paddle_on_fire(p: Dictionary) -> void:
	p["paddle_on_fire"] = true
	p["fire_timer"] = GC.PADDLE_FIRE_DURATION
	# Remove old fire particles if any
	var old_fp: GPUParticles3D = p["fire_particles"]
	if old_fp and is_instance_valid(old_fp):
		old_fp.queue_free()
	var paddle: StaticBody3D = p["paddle"]
	if paddle == null or not is_instance_valid(paddle):
		return
	# Add fire particles to paddle
	var fire := GPUParticles3D.new()
	fire.emitting = true
	fire.amount = 30
	fire.lifetime = 0.6
	fire.fixed_fps = 30
	var fmat := ParticleProcessMaterial.new()
	fmat.direction = Vector3(0, 1, 0)
	fmat.spread = 40.0
	fmat.initial_velocity_min = 0.5
	fmat.initial_velocity_max = 2.0
	fmat.gravity = Vector3(0, 2.0, 0)
	fmat.scale_min = 0.5
	fmat.scale_max = 1.5
	var fgrad := Gradient.new()
	fgrad.set_color(0, Color(1.0, 0.8, 0.1, 0.9))
	fgrad.add_point(0.3, Color(1.0, 0.4, 0.0, 0.7))
	fgrad.set_color(1, Color(0.3, 0.1, 0.0, 0.0))
	var fgtex := GradientTexture1D.new()
	fgtex.gradient = fgrad
	fmat.color_ramp = fgtex
	fire.process_material = fmat
	var fmesh := QuadMesh.new()
	fmesh.size = Vector2(0.12, 0.12)
	var fmesh_mat := StandardMaterial3D.new()
	fmesh_mat.vertex_color_use_as_albedo = true
	fmesh_mat.emission_enabled = true
	fmesh_mat.emission = Color(1.0, 0.4, 0.0)
	fmesh_mat.emission_energy_multiplier = 3.0
	fmesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fmesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmesh_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var ftex2 := Effects._get_fire_tex()
	if ftex2:
		fmesh_mat.albedo_texture = ftex2
	fmesh.material = fmesh_mat
	fire.draw_pass_1 = fmesh
	fire.position.y = GC.WALL_HEIGHT / 2.0
	paddle.add_child(fire)
	p["fire_particles"] = fire

func clear() -> void:
	for item in active_items:
		if is_instance_valid(item):
			item.queue_free()
	active_items.clear()
	for rocket in active_rockets:
		if is_instance_valid(rocket):
			rocket.queue_free()
	active_rockets.clear()
	for molotov in active_molotovs:
		if is_instance_valid(molotov):
			molotov.queue_free()
	active_molotovs.clear()
