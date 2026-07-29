extends Node3D

const GC = preload("res://game_constants.gd")
const AudioManager = preload("res://audio_manager.gd")
const ArenaBuilder = preload("res://arena_builder.gd")
const BallController = preload("res://ball_controller.gd")
const PowerupManager = preload("res://powerup_manager.gd")
const PlayerBuilder = preload("res://player_builder.gd")
const AIController = preload("res://ai_controller.gd")
const Effects = preload("res://effects.gd")

var state := GC.GameState.PLAYING
var players := []
var human_players := {}
var time := 0.0
var bricks_destroyed := 0
var last_hit_player := -1
var round_timer := 0.0
var round_winner := -1

var audio: AudioManager
var ball: BallController
var powerups: PowerupManager
var t_wall_a_end: float
var t_corner_end: float

func _ready() -> void:
	var bounds := PlayerBuilder.compute_path_boundaries()
	t_wall_a_end = bounds[0]
	t_corner_end = bounds[1]

	audio = AudioManager.new()
	add_child(audio)
	ArenaBuilder.setup(self)

	ball = BallController.new(self, self)
	ball.create()
	powerups = PowerupManager.new(self, audio, self)

	_make_players()
	powerups.place_dots(players)
	_start_round()

func _make_players() -> void:
	for i in range(4):
		var p := PlayerBuilder.create_player(i)
		PlayerBuilder.build_all(self, p)
		PlayerBuilder.update_paddle_position(p, t_wall_a_end, t_corner_end)
		players.append(p)

func _start_round() -> void:
	state = GC.GameState.PLAYING
	bricks_destroyed = 0
	last_hit_player = -1
	ball.start_round()
	for p in players:
		p["alive"] = true
		p["paddle_t"] = 0.5

# --- Game Loop ---

func _physics_process(delta: float) -> void:
	if state != GC.GameState.PLAYING:
		return
	time += delta
	_process_input(delta)
	_process_ai(delta)
	ball.move(delta, bricks_destroyed, players)
	powerups.process_items(delta, players)
	powerups.process_rockets(delta, players)
	powerups.process_molotovs(delta, players)

func _process_input(delta: float) -> void:
	for i in range(4):
		if not players[i]["alive"]:
			continue
		var prefix := "p%d_" % (i + 1)
		var move := Input.get_action_strength(prefix + "right") - Input.get_action_strength(prefix + "left")
		var vert := Input.get_action_strength(prefix + "down") - Input.get_action_strength(prefix + "up")
		if absf(move) > 0.1 or absf(vert) > 0.1 or Input.is_action_just_pressed(prefix + "action") or Input.is_action_just_pressed(prefix + "fire"):
			human_players[i] = true
		if not human_players.has(i):
			continue
		move = clampf(move, -1.0, 1.0)
		players[i]["paddle_t"] = clampf(players[i]["paddle_t"] + move * 2.0 * delta, 0.0, 1.0)
		PlayerBuilder.update_paddle_position(players[i], t_wall_a_end, t_corner_end)
		if ball.caught and ball.catch_player == i:
			if not Input.is_action_pressed(prefix + "action"):
				ball.release(players, bricks_destroyed)
		if Input.is_action_just_pressed(prefix + "fire"):
			powerups.fire_rocket(i, players)

func _process_ai(delta: float) -> void:
	for i in range(4):
		if not players[i]["alive"]:
			continue
		if human_players.has(i):
			continue
		AIController.move_toward_ball(players[i], delta, ball.ball_node.position, ball.velocity, powerups.active_items)
		PlayerBuilder.update_paddle_position(players[i], t_wall_a_end, t_corner_end)
		if ball.caught and ball.catch_player == i and ball.catch_timer > 0.5:
			AIController.release_ball(i, players, ball, bricks_destroyed)
		if players[i]["rockets"] > 0 and randf() < 0.01:
			powerups.fire_rocket(i, players)

# --- Collision Callbacks ---

func on_brick_hit(brick: StaticBody3D) -> void:
	var hp: int = brick.get_meta("hp") - 1
	var pi: int = brick.get_meta("player_index")
	if hp <= 0:
		Effects.spawn_brick_particles(self, brick.position, GC.PLAYER_COLORS[pi])
		audio.play_explosion()
		if brick.has_meta("has_powerup") and brick.get_meta("has_powerup"):
			powerups.spawn_item(brick.position, brick.get_meta("powerup_type"), last_hit_player, pi, players)
		players[pi]["bricks"].erase(brick)
		brick.queue_free()
		bricks_destroyed += 1
	else:
		brick.set_meta("hp", hp)
		var mi := brick.get_child(1) as MeshInstance3D
		if mi and mi.material_override:
			var mat: StandardMaterial3D = mi.material_override
			var max_hp: int = brick.get_meta("max_hp")
			var brightness := 0.3 + 0.7 * (float(hp) / float(max_hp))
			mat.albedo_color = GC.PLAYER_COLORS[pi] * brightness

func on_paddle_hit(paddle: Node3D, collision: KinematicCollision3D) -> void:
	audio.play_sound(audio.snd_paddle)
	var pi: int = paddle.get_meta("player_index")
	last_hit_player = pi
	ball.set_color(GC.PLAYER_COLORS[pi])
	var can_catch := false
	if ball.release_immunity <= 0.0 or ball.release_player != pi:
		if players[pi]["catch_cooldown"] <= 0.0 and not players[pi]["paddle_on_fire"]:
			if human_players.has(pi):
				var prefix := "p%d_" % (pi + 1)
				can_catch = Input.is_action_pressed(prefix + "action")
			else:
				can_catch = true
	if can_catch:
		ball.caught = true
		ball.catch_player = pi
		ball.catch_timer = 0.0
		ball.velocity = ball.velocity.normalized()
		return
	ball.velocity = ball.velocity.rotated(Vector3.UP, (randf() - 0.5) * 0.3)
	ball.velocity *= 1.05

func on_king_hit(king: StaticBody3D) -> void:
	var pi: int = king.get_meta("player_index")
	players[pi]["alive"] = false
	audio.play_sound(audio.snd_scream)
	Effects.spawn_king_explosion(self, king.position, GC.PLAYER_COLORS[pi])
	king.queue_free()
	players[pi]["king"] = null
	for brick in players[pi]["bricks"]:
		if is_instance_valid(brick):
			brick.queue_free()
	players[pi]["bricks"].clear()
	if players[pi]["paddle"]:
		players[pi]["paddle"].queue_free()
		players[pi]["paddle"] = null
	var alive_count := 0
	var last_alive := -1
	for i in range(4):
		if players[i]["alive"]:
			alive_count += 1
			last_alive = i
	if alive_count <= 1:
		_round_over(last_alive)

# --- Round Management ---

func _round_over(winner: int) -> void:
	state = GC.GameState.ROUND_END
	round_winner = winner
	round_timer = 3.0
	ball.velocity = Vector3.ZERO
	ball.ball_node.position = Vector3(0, GC.WALL_HEIGHT / 2.0, 0)

func _process(delta: float) -> void:
	if state == GC.GameState.ROUND_END:
		round_timer -= delta
		if round_timer <= 0.0:
			_reset_round()

	for p in players:
		if p["catch_cooldown"] > 0.0:
			p["catch_cooldown"] -= delta
		# Catch bar visual
		var bar: MeshInstance3D = p["catch_bar"]
		if bar and is_instance_valid(bar):
			var bar_mat: StandardMaterial3D = p["catch_bar_mat"]
			if p["catch_cooldown"] <= 0.0:
				bar.scale.x = 1.0
				bar.visible = p["alive"]
				if bar_mat:
					bar_mat.albedo_color = Color(1.0, 1.0, 1.0)
					bar_mat.emission = Color(1.0, 1.0, 1.0)
					bar_mat.emission_energy_multiplier = 1.5
			else:
				var progress: float = 1.0 - (p["catch_cooldown"] / GC.CATCH_COOLDOWN)
				bar.scale.x = progress
				bar.visible = p["alive"]
				if bar_mat:
					bar_mat.albedo_color = Color(0.4, 0.4, 0.4)
					bar_mat.emission = Color(0.3, 0.3, 0.3)
					bar_mat.emission_energy_multiplier = 0.5
		# Paddle fire timer
		if p["paddle_on_fire"]:
			p["fire_timer"] -= delta
			if p["fire_timer"] <= 0.0:
				p["paddle_on_fire"] = false
				p["fire_timer"] = 0.0
				var fp: GPUParticles3D = p["fire_particles"]
				if fp and is_instance_valid(fp):
					fp.queue_free()
				p["fire_particles"] = null
		# Powerup timer
		if p["powerup_timer"] > 0.0:
			p["powerup_timer"] -= delta
			if p["powerup_timer"] <= 0.0:
				p["paddle_scale"] = 1.0
				PlayerBuilder.update_paddle_mesh(p)
		# King faces the ball + gentle bob
		var king: StaticBody3D = p["king"]
		if king and is_instance_valid(king) and king.is_inside_tree():
			var pivot := king.get_node_or_null("KingPivot")
			if pivot:
				pivot.position.y = sin(time * 2.0 + p["index"] * 1.5) * 0.04
			var ball_pos := ball.ball_node.position
			var look_target := Vector3(ball_pos.x, king.position.y, ball_pos.z)
			var dist_to_ball := (look_target - king.position).length()
			if dist_to_ball > 0.1:
				king.look_at(look_target, Vector3.UP)

func _reset_round() -> void:
	for p in players:
		if p["king"] and is_instance_valid(p["king"]):
			p["king"].queue_free()
		for brick in p["bricks"]:
			if is_instance_valid(brick):
				brick.queue_free()
		p["bricks"].clear()
		if p["paddle"] and is_instance_valid(p["paddle"]):
			p["paddle"].queue_free()
	players.clear()
	powerups.clear()

	_make_players()
	powerups.place_dots(players)
	_start_round()
