const GC = preload("res://game_constants.gd")
const PlayerBuilder = preload("res://player_builder.gd")
const Effects = preload("res://effects.gd")

var ball_node: RigidBody3D
var velocity := Vector3.ZERO
var caught := false
var catch_player := -1
var catch_timer := 0.0
var release_immunity := 0.0
var release_player := -1

var _parent: Node3D
var _game  # reference to main for collision callbacks
var _ball_mat: StandardMaterial3D
var _ball_light: OmniLight3D
var _trail_grad: Gradient
var _trail_mat: StandardMaterial3D

func _init(parent: Node3D, game) -> void:
	_parent = parent
	_game = game

func create() -> void:
	ball_node = RigidBody3D.new()
	ball_node.gravity_scale = 0.0
	ball_node.collision_layer = 2
	ball_node.collision_mask = 4 | 8 | 16 | 32
	ball_node.contact_monitor = true
	ball_node.max_contacts_reported = 4
	ball_node.continuous_cd = true
	ball_node.linear_damp = 0.0
	ball_node.angular_damp = 0.0
	ball_node.freeze = true
	ball_node.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

	var shape := SphereShape3D.new()
	shape.radius = GC.BALL_RADIUS
	var col := CollisionShape3D.new()
	col.shape = shape
	ball_node.add_child(col)

	# Fireball mesh
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = GC.BALL_RADIUS
	sm.height = GC.BALL_RADIUS * 2.0
	mi.mesh = sm
	_ball_mat = StandardMaterial3D.new()
	_ball_mat.emission_enabled = true
	_ball_mat.emission_energy_multiplier = 3.0
	mi.material_override = _ball_mat
	ball_node.add_child(mi)

	# Point light
	_ball_light = OmniLight3D.new()
	_ball_light.light_energy = 2.0
	_ball_light.omni_range = 4.0
	_ball_light.omni_attenuation = 1.5
	ball_node.add_child(_ball_light)

	# Fire trail particles
	var trail := GPUParticles3D.new()
	trail.emitting = true
	trail.amount = 12
	trail.lifetime = 0.2
	trail.fixed_fps = 30
	var tmat := ParticleProcessMaterial.new()
	tmat.direction = Vector3(0, 0, 0)
	tmat.spread = 180.0
	tmat.initial_velocity_min = 0.0
	tmat.initial_velocity_max = 0.2
	tmat.gravity = Vector3(0, 0, 0)
	tmat.scale_min = 0.8
	tmat.scale_max = 1.0
	# Scale curve: full size at spawn, shrink to nothing
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 1.0))
	sc.add_point(Vector2(0.4, 0.5))
	sc.add_point(Vector2(1.0, 0.0))
	var scale_curve := CurveTexture.new()
	scale_curve.curve = sc
	tmat.scale_curve = scale_curve
	_trail_grad = Gradient.new()
	var gtex := GradientTexture1D.new()
	gtex.gradient = _trail_grad
	tmat.color_ramp = gtex
	trail.process_material = tmat
	var tmesh := QuadMesh.new()
	tmesh.size = Vector2(GC.BALL_RADIUS * 0.8, GC.BALL_RADIUS * 0.8)
	_trail_mat = StandardMaterial3D.new()
	_trail_mat.vertex_color_use_as_albedo = true
	_trail_mat.emission_enabled = true
	_trail_mat.emission_energy_multiplier = 2.0
	_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var fire_tex := Effects._get_fire_tex()
	if fire_tex:
		_trail_mat.albedo_texture = fire_tex
	_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tmesh.material = _trail_mat
	trail.draw_pass_1 = tmesh
	ball_node.add_child(trail)

	ball_node.position = Vector3(0, GC.WALL_HEIGHT / 2.0, 0)
	_parent.add_child(ball_node)

func set_color(color: Color) -> void:
	_ball_mat.albedo_color = color
	_ball_mat.emission = color * 0.8
	_ball_light.light_color = color
	_trail_grad.set_color(0, Color(color.r, color.g, color.b, 0.9))
	_trail_grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	_trail_mat.emission = color

func start_round() -> void:
	caught = false
	catch_player = -1
	catch_timer = 0.0
	release_immunity = 0.0
	release_player = -1
	ball_node.position = Vector3(0, GC.WALL_HEIGHT / 2.0, 0)
	var base_angle := (randi() % 4) * PI / 2.0 + PI / 4.0
	var angle := base_angle + (randf() - 0.5) * 0.5
	velocity = Vector3(cos(angle), 0, sin(angle)) * GC.BALL_SPEED
	set_color(Color(1.0, 1.0, 1.0))

func release(players: Array, bricks_destroyed: int) -> void:
	if not caught:
		return
	var speed_mult := 1.0 + bricks_destroyed * 0.015
	var current_speed := GC.BALL_SPEED * speed_mult
	var p: Dictionary = players[catch_player]
	velocity = PlayerBuilder.get_paddle_outward(p) * current_speed
	release_immunity = GC.CATCH_IMMUNITY_TIME
	release_player = catch_player
	players[catch_player]["catch_cooldown"] = GC.CATCH_COOLDOWN
	caught = false
	catch_player = -1
	catch_timer = 0.0

func move(delta: float, bricks_destroyed: int, players: Array) -> void:
	if release_immunity > 0.0:
		release_immunity -= delta

	if caught:
		catch_timer += delta
		if catch_timer >= GC.CATCH_MAX_TIME:
			release(players, bricks_destroyed)
			return
		if catch_player >= 0 and catch_player < players.size():
			var p: Dictionary = players[catch_player]
			var paddle: StaticBody3D = p["paddle"]
			if paddle and is_instance_valid(paddle):
				var outward := PlayerBuilder.get_paddle_outward(p)
				ball_node.position = paddle.position + outward * (GC.BALL_RADIUS + 0.15)
				ball_node.position.y = GC.WALL_HEIGHT / 2.0
		return

	var speed_mult := 1.0 + bricks_destroyed * 0.015
	var current_speed := GC.BALL_SPEED * speed_mult
	var vel := velocity.normalized() * current_speed
	var motion := vel * delta
	var collision := ball_node.move_and_collide(motion)

	if collision:
		var collider := collision.get_collider()
		var normal := collision.get_normal()
		velocity = vel.bounce(normal).normalized() * current_speed

		if collider.has_meta("type"):
			var ctype: String = collider.get_meta("type")
			if ctype == "brick":
				_game.on_brick_hit(collider)
			elif ctype == "paddle":
				_game.on_paddle_hit(collider, collision)
			elif ctype == "king":
				_game.on_king_hit(collider)

		_enforce_min_angle()

	ball_node.position.y = GC.WALL_HEIGHT / 2.0
	velocity.y = 0.0

	# Keep ball in bounds
	var hw := GC.ARENA_W / 2.0 - GC.BALL_RADIUS
	var hh := GC.ARENA_H / 2.0 - GC.BALL_RADIUS
	if ball_node.position.x < -hw:
		ball_node.position.x = -hw
		velocity.x = absf(velocity.x)
		_enforce_min_angle()
	elif ball_node.position.x > hw:
		ball_node.position.x = hw
		velocity.x = -absf(velocity.x)
		_enforce_min_angle()
	if ball_node.position.z < -hh:
		ball_node.position.z = -hh
		velocity.z = absf(velocity.z)
		_enforce_min_angle()
	elif ball_node.position.z > hh:
		ball_node.position.z = hh
		velocity.z = -absf(velocity.z)
		_enforce_min_angle()

func _enforce_min_angle() -> void:
	var spd := velocity.length()
	if spd < 0.01:
		return
	var vx := velocity.x
	var vz := velocity.z
	if absf(vx) < absf(vz) * GC.MIN_ANGLE:
		vx = sign(vx) * absf(vz) * GC.MIN_ANGLE if vx != 0.0 else (1.0 if randf() > 0.5 else -1.0) * absf(vz) * GC.MIN_ANGLE
	if absf(vz) < absf(vx) * GC.MIN_ANGLE:
		vz = sign(vz) * absf(vx) * GC.MIN_ANGLE if vz != 0.0 else (1.0 if randf() > 0.5 else -1.0) * absf(vx) * GC.MIN_ANGLE
	velocity = Vector3(vx, 0, vz).normalized() * spd
