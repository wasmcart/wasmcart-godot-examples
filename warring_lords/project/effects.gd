
static var _fire_tex: ImageTexture = null
static var _smoke_tex: ImageTexture = null

static func _load_texture(path: String) -> ImageTexture:
	var img := Image.new()
	var err := img.load(path)
	if err == OK:
		return ImageTexture.create_from_image(img)
	return null

static func _get_fire_tex() -> ImageTexture:
	if _fire_tex == null:
		_fire_tex = _load_texture("res://textures/fire.png")
	return _fire_tex

static func _get_smoke_tex() -> ImageTexture:
	if _smoke_tex == null:
		_smoke_tex = _load_texture("res://textures/smoke.png")
	return _smoke_tex

static func _make_fire_mat(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tex := _get_fire_tex()
	if tex:
		mat.albedo_texture = tex
	return mat

static func _make_smoke_mat(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tex := _get_smoke_tex()
	if tex:
		mat.albedo_texture = tex
	return mat

static func spawn_brick_particles(parent: Node3D, pos: Vector3, color: Color) -> void:
	var burst := GPUParticles3D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 12
	burst.lifetime = 0.6
	burst.fixed_fps = 30
	burst.position = pos
	var bmat := ParticleProcessMaterial.new()
	bmat.direction = Vector3(0, 1, 0)
	bmat.spread = 90.0
	bmat.initial_velocity_min = 2.0
	bmat.initial_velocity_max = 5.0
	bmat.gravity = Vector3(0, -8, 0)
	bmat.scale_min = 0.3
	bmat.scale_max = 0.8
	var bgrad := Gradient.new()
	bgrad.set_color(0, color)
	bgrad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var bgtex := GradientTexture1D.new()
	bgtex.gradient = bgrad
	bmat.color_ramp = bgtex
	burst.process_material = bmat
	# Brick debris stays as small boxes (not billboard)
	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(0.08, 0.08, 0.08)
	var pmat := StandardMaterial3D.new()
	pmat.vertex_color_use_as_albedo = true
	pmat.emission_enabled = true
	pmat.emission = color
	pmat.emission_energy_multiplier = 1.5
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmesh.material = pmat
	burst.draw_pass_1 = bmesh
	parent.add_child(burst)
	_auto_free(burst, 1.0)

static func spawn_king_explosion(parent: Node3D, pos: Vector3, color: Color) -> void:
	var burst := GPUParticles3D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 32
	burst.lifetime = 1.0
	burst.fixed_fps = 30
	burst.position = pos
	var bmat := ParticleProcessMaterial.new()
	bmat.direction = Vector3(0, 1, 0)
	bmat.spread = 180.0
	bmat.initial_velocity_min = 3.0
	bmat.initial_velocity_max = 8.0
	bmat.gravity = Vector3(0, -5, 0)
	bmat.scale_min = 0.3
	bmat.scale_max = 1.5
	bmat.damping_min = 1.0
	bmat.damping_max = 3.0
	var bgrad := Gradient.new()
	bgrad.set_color(0, Color(1, 1, 0.8, 1.0))
	bgrad.add_point(0.3, Color(1, 0.6, 0.1, 0.8))
	bgrad.add_point(0.6, Color(0.5, 0.5, 0.5, 0.5))
	bgrad.set_color(1, Color(0.3, 0.3, 0.3, 0.0))
	var bgtex := GradientTexture1D.new()
	bgtex.gradient = bgrad
	bmat.color_ramp = bgtex
	# Scale curve: flash big then dissipate
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5))
	sc.add_point(Vector2(0.15, 1.0))
	sc.add_point(Vector2(0.5, 0.7))
	sc.add_point(Vector2(1.0, 0.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	bmat.scale_curve = sct
	burst.process_material = bmat
	var bmesh := QuadMesh.new()
	bmesh.size = Vector2(0.3, 0.3)
	bmesh.material = _make_fire_mat(Color(1, 1, 0.8), 3.0)
	burst.draw_pass_1 = bmesh
	parent.add_child(burst)

	var flash := OmniLight3D.new()
	flash.light_color = color
	flash.light_energy = 5.0
	flash.omni_range = 6.0
	flash.position = pos
	parent.add_child(flash)

	var timer := Timer.new()
	timer.wait_time = 1.5
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(func():
		burst.queue_free()
		flash.queue_free()
	)
	burst.add_child(timer)

static func spawn_rocket_explosion(parent: Node3D, pos: Vector3) -> void:
	var burst := GPUParticles3D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 20
	burst.lifetime = 0.6
	burst.fixed_fps = 30
	burst.position = pos
	var bmat := ParticleProcessMaterial.new()
	bmat.direction = Vector3(0, 1, 0)
	bmat.spread = 180.0
	bmat.initial_velocity_min = 3.0
	bmat.initial_velocity_max = 6.0
	bmat.gravity = Vector3(0, -6, 0)
	bmat.scale_min = 0.3
	bmat.scale_max = 1.2
	bmat.damping_min = 1.0
	bmat.damping_max = 2.0
	var bgrad := Gradient.new()
	bgrad.set_color(0, Color(1.0, 0.9, 0.3, 1.0))
	bgrad.add_point(0.3, Color(1.0, 0.4, 0.0, 0.8))
	bgrad.set_color(1, Color(0.4, 0.2, 0.0, 0.0))
	var bgtex := GradientTexture1D.new()
	bgtex.gradient = bgrad
	bmat.color_ramp = bgtex
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.4))
	sc.add_point(Vector2(0.2, 1.0))
	sc.add_point(Vector2(1.0, 0.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	bmat.scale_curve = sct
	burst.process_material = bmat
	var bmesh := QuadMesh.new()
	bmesh.size = Vector2(0.25, 0.25)
	bmesh.material = _make_fire_mat(Color(1.0, 0.5, 0.0), 3.0)
	burst.draw_pass_1 = bmesh
	parent.add_child(burst)

	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.6, 0.1)
	flash.light_energy = 4.0
	flash.omni_range = 4.0
	flash.position = pos
	parent.add_child(flash)

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(func():
		burst.queue_free()
		flash.queue_free()
	)
	burst.add_child(timer)

static func spawn_molotov_explosion(parent: Node3D, pos: Vector3) -> void:
	# Fire burst
	var burst := GPUParticles3D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 0.8
	burst.amount = 24
	burst.lifetime = 0.8
	burst.fixed_fps = 30
	burst.position = pos
	var bmat := ParticleProcessMaterial.new()
	bmat.direction = Vector3(0, 1, 0)
	bmat.spread = 180.0
	bmat.initial_velocity_min = 2.0
	bmat.initial_velocity_max = 5.0
	bmat.gravity = Vector3(0, -4, 0)
	bmat.scale_min = 0.5
	bmat.scale_max = 2.0
	bmat.damping_min = 1.0
	bmat.damping_max = 3.0
	var bgrad := Gradient.new()
	bgrad.set_color(0, Color(1.0, 0.9, 0.2, 1.0))
	bgrad.add_point(0.2, Color(1.0, 0.5, 0.0, 0.9))
	bgrad.add_point(0.5, Color(0.6, 0.3, 0.0, 0.6))
	bgrad.set_color(1, Color(0.2, 0.1, 0.0, 0.0))
	var bgtex := GradientTexture1D.new()
	bgtex.gradient = bgrad
	bmat.color_ramp = bgtex
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.3))
	sc.add_point(Vector2(0.15, 1.0))
	sc.add_point(Vector2(0.6, 0.6))
	sc.add_point(Vector2(1.0, 0.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	bmat.scale_curve = sct
	burst.process_material = bmat
	var bmesh := QuadMesh.new()
	bmesh.size = Vector2(0.3, 0.3)
	bmesh.material = _make_fire_mat(Color(1.0, 0.5, 0.0), 4.0)
	burst.draw_pass_1 = bmesh
	parent.add_child(burst)

	# Smoke cloud (slower, rises)
	var smoke := GPUParticles3D.new()
	smoke.emitting = true
	smoke.one_shot = true
	smoke.explosiveness = 0.5
	smoke.amount = 12
	smoke.lifetime = 1.2
	smoke.fixed_fps = 30
	smoke.position = pos
	var smat := ParticleProcessMaterial.new()
	smat.direction = Vector3(0, 1, 0)
	smat.spread = 60.0
	smat.initial_velocity_min = 1.0
	smat.initial_velocity_max = 3.0
	smat.gravity = Vector3(0, 1.0, 0)
	smat.scale_min = 0.5
	smat.scale_max = 2.0
	smat.damping_min = 2.0
	smat.damping_max = 4.0
	var sgrad := Gradient.new()
	sgrad.set_color(0, Color(0.5, 0.5, 0.5, 0.6))
	sgrad.set_color(1, Color(0.3, 0.3, 0.3, 0.0))
	var sgtex := GradientTexture1D.new()
	sgtex.gradient = sgrad
	smat.color_ramp = sgtex
	var ssc := Curve.new()
	ssc.add_point(Vector2(0.0, 0.5))
	ssc.add_point(Vector2(0.3, 1.0))
	ssc.add_point(Vector2(1.0, 0.8))
	var ssct := CurveTexture.new()
	ssct.curve = ssc
	smat.scale_curve = ssct
	smoke.process_material = smat
	var smesh := QuadMesh.new()
	smesh.size = Vector2(0.4, 0.4)
	smesh.material = _make_smoke_mat(Color(0.4, 0.4, 0.4), 0.5)
	smoke.draw_pass_1 = smesh
	parent.add_child(smoke)

	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.5, 0.0)
	flash.light_energy = 6.0
	flash.omni_range = 5.0
	flash.position = pos
	parent.add_child(flash)

	var timer := Timer.new()
	timer.wait_time = 1.5
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(func():
		burst.queue_free()
		smoke.queue_free()
		flash.queue_free()
	)
	burst.add_child(timer)

static func _auto_free(node: Node, delay: float) -> void:
	var timer := Timer.new()
	timer.wait_time = delay
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(node.queue_free)
	node.add_child(timer)
