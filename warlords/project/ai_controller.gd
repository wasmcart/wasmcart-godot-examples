const GC = preload("res://game_constants.gd")
const PlayerBuilder = preload("res://player_builder.gd")
const BallController = preload("res://ball_controller.gd")

static func move_toward_ball(p: Dictionary, delta: float, ball_pos: Vector3, ball_vel: Vector3, active_items: Array) -> void:
	var bx: float = ball_pos.x
	var bz: float = ball_pos.z
	var ex: float = p["elbow_x"]
	var ez: float = p["elbow_z"]
	var dx: int = p["dir_x"]
	var dz: int = p["dir_z"]
	var cx: float = p["corner_x"]
	var cz: float = p["corner_z"]

	var ball_in_quadrant := (bx - cx) * dx <= 0.0 or (bz - cz) * dz <= 0.0
	var heading_toward := ball_vel.x * (-dx) > 0.0 or ball_vel.z * (-dz) > 0.0

	if not ball_in_quadrant and not heading_toward:
		# Look for powerup items to intercept
		var intercept_pos := Vector3.ZERO
		var found_item := false
		for item in active_items:
			if not is_instance_valid(item):
				continue
			if item.get_meta("target_player") == p["index"]:
				intercept_pos = item.position
				found_item = true
				break
		if found_item:
			var ix: float = intercept_pos.x
			var iz: float = intercept_pos.z
			var irx: float = (ix - ex) * dx
			var irz: float = (iz - ez) * dz
			var target_t: float
			if irx <= 0.0 and irz <= 0.0:
				target_t = 0.5
			elif irx <= 0.0:
				target_t = 0.0
			elif irz <= 0.0:
				target_t = 1.0
			else:
				var iangle: float = atan2(irz, irx)
				target_t = 1.0 - iangle / (PI / 2.0)
			_move_toward(p, target_t, 3.0, delta)
		else:
			_move_toward(p, 0.5, 1.5, delta)
		return

	# Track ball position
	var rx: float = (bx - ex) * dx
	var rz: float = (bz - ez) * dz
	var target_t: float
	if rx <= 0.0 and rz <= 0.0:
		target_t = 0.5
	elif rx <= 0.0:
		target_t = 0.0
	elif rz <= 0.0:
		target_t = 1.0
	else:
		var angle: float = atan2(rz, rx)
		target_t = 1.0 - angle / (PI / 2.0)

	_move_toward(p, target_t, 2.5, delta)

static func release_ball(ai_index: int, players: Array, ball: BallController, bricks_destroyed: int) -> void:
	if not ball.caught:
		return
	var speed_mult := 1.0 + bricks_destroyed * 0.015
	var current_speed := GC.BALL_SPEED * speed_mult
	var enemies := []
	for j in range(4):
		if j != ai_index and players[j]["alive"] and players[j]["king"] and is_instance_valid(players[j]["king"]):
			enemies.append(j)
	if enemies.size() > 0:
		var target_idx: int = enemies[randi() % enemies.size()]
		var king_pos: Vector3 = players[target_idx]["king"].position
		var aim_dir: Vector3 = (king_pos - ball.ball_node.position)
		aim_dir.y = 0.0
		ball.velocity = aim_dir.normalized() * current_speed
	else:
		ball.velocity = PlayerBuilder.get_paddle_outward(players[ai_index]) * current_speed
	ball.release_immunity = GC.CATCH_IMMUNITY_TIME
	ball.release_player = ball.catch_player
	players[ball.catch_player]["catch_cooldown"] = GC.CATCH_COOLDOWN
	ball.caught = false
	ball.catch_player = -1
	ball.catch_timer = 0.0

static func _move_toward(p: Dictionary, target_t: float, speed: float, delta: float) -> void:
	var diff: float = target_t - p["paddle_t"]
	var step: float = speed * delta
	if absf(diff) < step:
		p["paddle_t"] = target_t
	else:
		p["paddle_t"] += sign(diff) * step
	p["paddle_t"] = clampf(p["paddle_t"], 0.0, 1.0)
