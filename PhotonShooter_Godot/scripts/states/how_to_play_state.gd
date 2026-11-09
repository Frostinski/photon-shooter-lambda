extends Node2D

const PlayerShip3DScript = preload("res://scripts/player_ship_3d.gd")
const EnemyShip3DScript = preload("res://scripts/enemy_ship_3d.gd")
const SpaceBackdropShader = preload("res://assets/shaders/space_backdrop.gdshader")

const ARENA_CENTER_Y: float = 430.0
const SHIP_DRAW_W: float = 188.0
const SHIP_DRAW_H: float = 102.0

var main_app: Node = null
var player_3d: SubViewport = null
var demo_scout_3d: SubViewport = null
var demo_raider_3d: SubViewport = null

var backdrop_rect: ColorRect = null
var backdrop_material: ShaderMaterial = null
var backdrop_scroll_offset: float = 0.0

var ship_frames: Dictionary = {}
var scout_tex: Texture2D = null
var raider_tex: Texture2D = null
var stars: Array = []

var step: int = 0
var step_timer: float = 0.0
var total_time: float = 0.0
var skipped: bool = false

var ship_x: float = 380.0
var ship_y: float = ARENA_CENTER_Y
var ship_vx: float = 0.0
var ship_vy: float = 0.0
var ship_bank: String = "neutral"
var ship_thrust: String = "cruise"
var gun_glow_timer: float = 0.0
var dodge_active: bool = false
var dodge_afterimages: Array = []

var stick_offset: Vector2 = Vector2.ZERO
var btn_a_pressed: bool = false
var btn_x_pressed: bool = false
var btn_lt_pressed: bool = false

var lasers: Array = []
var missiles: Array = []
var enemy_bullets: Array = []
var dummy_target: Dictionary = {}
var particles: Array = []
var laser_impacts: Array = []
var missile_blasts: Array = []
var score_popups: Array = []

var step1_shots_fired: int = 0
var step2_missile_fired: bool = false
var step3_bullet_spawned: bool = false
var step3_dodge_triggered: bool = false
var step3_dodge_recharged: bool = false
var demo_dodge_ready_flash: float = 0.0


func _ready() -> void:
	_setup_shader_backdrop()

	var ship_data = GameConfig.get_player_frames(Vector2i(int(SHIP_DRAW_W), int(SHIP_DRAW_H)))
	ship_frames = ship_data["frames"]

	if PlayerShip3DScript != null:
		player_3d = PlayerShip3DScript.new(Vector2i(230, 124))
		player_3d.name = "DemoShip3DViewport"
		add_child(player_3d)

	if EnemyShip3DScript != null:
		demo_scout_3d = EnemyShip3DScript.new("scout", Vector2i(136, 100))
		demo_scout_3d.name = "DemoScout3DViewport"
		add_child(demo_scout_3d)
		demo_raider_3d = EnemyShip3DScript.new("raider", Vector2i(172, 118))
		demo_raider_3d.name = "DemoRaider3DViewport"
		add_child(demo_raider_3d)

	scout_tex = GameConfig.get_scaled_texture("enemy_scout", Vector2i(96, 68))
	raider_tex = GameConfig.get_scaled_texture("enemy_raider", Vector2i(144, 96))

	var rng = RandomNumberGenerator.new()
	rng.seed = 202699
	for layer in range(3):
		var spd = [50.0, 130.0, 260.0][layer]
		var sz = [1.0, 2.0, 3.0][layer]
		var col = [Color8(80, 95, 150), Color8(140, 175, 230), Color8(215, 240, 255)][layer]
		var count = [40, 26, 12][layer]
		for i in range(count):
			stars.append({
				"x": rng.randf_range(0.0, GameConfig.SCREEN_WIDTH),
				"y": rng.randf_range(0.0, GameConfig.SCREEN_HEIGHT),
				"speed": spd * rng.randf_range(0.85, 1.2),
				"size": sz,
				"color": col
			})


func _setup_shader_backdrop() -> void:
	if SpaceBackdropShader == null:
		return
	backdrop_material = ShaderMaterial.new()
	backdrop_material.shader = SpaceBackdropShader
	backdrop_material.set_shader_parameter("scroll_speed", 0.06)
	backdrop_material.set_shader_parameter("scroll_offset", 0.0)
	backdrop_material.set_shader_parameter("star_density", 0.90)
	backdrop_material.set_shader_parameter("nebula_intensity", 0.72)
	backdrop_material.set_shader_parameter("enable_sun", 1)
	backdrop_material.set_shader_parameter("sun_uv", Vector2(0.78, 0.20))
	backdrop_material.set_shader_parameter("sun_radius", 0.028)
	backdrop_material.set_shader_parameter("sun_intensity", 1.05)
	backdrop_rect = ColorRect.new()
	backdrop_rect.name = "DemoSpaceBackdrop"
	backdrop_rect.position = Vector2.ZERO
	backdrop_rect.size = Vector2(GameConfig.SCREEN_WIDTH, GameConfig.SCREEN_HEIGHT)
	backdrop_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop_rect.show_behind_parent = true
	backdrop_rect.material = backdrop_material
	add_child(backdrop_rect)


func enter(_params: Dictionary = {}) -> void:
	step = 0
	step_timer = 0.0
	total_time = 0.0
	skipped = false

	ship_x = 380.0
	ship_y = ARENA_CENTER_Y
	ship_vx = 0.0
	ship_vy = 0.0
	ship_bank = "neutral"
	ship_thrust = "cruise"
	gun_glow_timer = 0.0
	dodge_active = false
	dodge_afterimages.clear()

	stick_offset = Vector2.ZERO
	btn_a_pressed = false
	btn_x_pressed = false
	btn_lt_pressed = false

	lasers.clear()
	missiles.clear()
	enemy_bullets.clear()
	dummy_target.clear()
	particles.clear()
	laser_impacts.clear()
	missile_blasts.clear()
	score_popups.clear()

	step1_shots_fired = 0
	step2_missile_fired = false
	step3_bullet_spawned = false
	step3_dodge_triggered = false


func state_input(event: InputEvent) -> void:
	if total_time <= 0.30:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_skip_to_game()
	elif event is InputEventMouseButton and event.pressed:
		_skip_to_game()
	elif event is InputEventJoypadButton and event.pressed:
		_skip_to_game()


func _skip_to_game() -> void:
	if not skipped:
		skipped = true
		SoundManager.play("menu_confirm")
		main_app.set_state("GAME")


func _advance_step(next_step: int) -> void:
	step = next_step
	step_timer = 0.0
	stick_offset = Vector2.ZERO
	btn_a_pressed = false
	btn_x_pressed = false
	btn_lt_pressed = false
	dodge_active = false

	if next_step == 1:
		dummy_target = {
			"x": 1980.0,
			"y": ARENA_CENTER_Y,
			"target_x": 1380.0,
			"hp": 45,
			"max_hp": 45,
			"flash": 0.0,
			"type": "scout",
			"alive": true
		}
		step1_shots_fired = 0
	elif next_step == 2:
		dummy_target = {
			"x": 1980.0,
			"y": ARENA_CENTER_Y - 25.0,
			"target_x": 1400.0,
			"hp": 90,
			"max_hp": 90,
			"flash": 0.0,
			"type": "raider",
			"alive": true
		}
		step2_missile_fired = false
	elif next_step == 3:
		dummy_target.clear()
		enemy_bullets.clear()
		step3_bullet_spawned = false
		step3_dodge_triggered = false
		step3_dodge_recharged = false
		demo_dodge_ready_flash = 0.0


func _spawn_explosion(x: float, y: float, count: int = 22, base_color: Color = GameConfig.COLOR_CYAN) -> void:
	var cols = [base_color, GameConfig.COLOR_GOLD, GameConfig.COLOR_WHITE, GameConfig.COLOR_MAGENTA]
	for i in range(count):
		var ang = randf_range(0.0, TAU)
		var spd = randf_range(60.0, 320.0)
		var lt = randf_range(0.22, 0.48)
		particles.append({
			"x": x,
			"y": y,
			"vx": cos(ang) * spd,
			"vy": sin(ang) * spd,
			"life": lt,
			"max_life": lt,
			"size": float([3, 4, 5][randi_range(0, 2)]),
			"color": cols[randi_range(0, cols.size() - 1)]
		})


func state_update(dt: float) -> void:
	total_time += dt
	step_timer += dt
	if gun_glow_timer > 0.0:
		gun_glow_timer = maxf(0.0, gun_glow_timer - dt)
	if demo_dodge_ready_flash > 0.0:
		demo_dodge_ready_flash = maxf(0.0, demo_dodge_ready_flash - dt)

	var scroll_mult: float = 2.4 if step == 4 else 1.0
	backdrop_scroll_offset += 0.06 * scroll_mult * dt
	if backdrop_material != null:
		backdrop_material.set_shader_parameter("scroll_offset", backdrop_scroll_offset)
	else:
		for s in stars:
			s["x"] -= s["speed"] * scroll_mult * dt
			if s["x"] < 0.0:
				s["x"] = GameConfig.SCREEN_WIDTH
				s["y"] = randf_range(0.0, GameConfig.SCREEN_HEIGHT)

	var prev_x = ship_x
	var prev_y = ship_y

	# STEP 0: FLIGHT MOVEMENT (2.4s)
	if step == 0:
		var t = step_timer
		var target_x = 380.0
		var target_y = ARENA_CENTER_Y
		var desired_stick := Vector2.ZERO
		if t < 0.25:
			desired_stick = Vector2.ZERO
		elif t < 0.85:
			desired_stick = Vector2(0.0, -1.0)
			target_y = ARENA_CENTER_Y - 125.0
		elif t < 1.45:
			desired_stick = Vector2(0.0, 1.0)
			target_y = ARENA_CENTER_Y + 125.0
		elif t < 2.00:
			desired_stick = Vector2(1.0, -0.35).normalized()
			target_x = 610.0
			target_y = ARENA_CENTER_Y
		else:
			desired_stick = Vector2(-0.7, 0.0)
			target_x = 380.0
			target_y = ARENA_CENTER_Y

		stick_offset = stick_offset.lerp(desired_stick, minf(1.0, dt * 12.0))
		ship_x += (target_x - ship_x) * minf(1.0, dt * 7.5)
		ship_y += (target_y - ship_y) * minf(1.0, dt * 7.5)

		if t >= 2.4:
			_advance_step(1)

	# STEP 1: PRIMARY LASERS (2.4s)
	elif step == 1:
		var t = step_timer
		ship_x += (380.0 - ship_x) * minf(1.0, dt * 7.0)
		ship_y += (ARENA_CENTER_Y - ship_y) * minf(1.0, dt * 7.0)

		if not dummy_target.is_empty() and dummy_target.get("alive", false):
			dummy_target["x"] += (dummy_target["target_x"] - dummy_target["x"]) * minf(1.0, dt * 6.5)
			if dummy_target["flash"] > 0.0:
				dummy_target["flash"] -= dt

		if t >= 0.40 and t <= 1.95:
			var cycle = fmod(t - 0.40, 0.26)
			btn_a_pressed = cycle < 0.14
			var expected_shots = int((t - 0.40) / 0.26) + 1
			if step1_shots_fired < expected_shots and step1_shots_fired < 6:
				step1_shots_fired += 1
				gun_glow_timer = 0.10
				SoundManager.play("primary_fire")
				lasers.append({"x": ship_x + 42.0, "y": ship_y - 16.0, "vx": 1380.0, "age": 0.0, "phase": total_time})
				lasers.append({"x": ship_x + 42.0, "y": ship_y + 16.0, "vx": 1380.0, "age": 0.0, "phase": total_time + 0.08})
		else:
			btn_a_pressed = false

		if t >= 2.4:
			_advance_step(2)

	# STEP 2: HOMING MISSILES (2.5s)
	elif step == 2:
		var t = step_timer
		ship_x += (380.0 - ship_x) * minf(1.0, dt * 7.0)
		ship_y += (ARENA_CENTER_Y - ship_y) * minf(1.0, dt * 7.0)

		if not dummy_target.is_empty() and dummy_target.get("alive", false):
			dummy_target["x"] += (dummy_target["target_x"] - dummy_target["x"]) * minf(1.0, dt * 6.5)
			dummy_target["y"] = (ARENA_CENTER_Y - 20.0) + sin(t * 3.8) * 75.0
			if dummy_target["flash"] > 0.0:
				dummy_target["flash"] -= dt

		if t >= 0.55 and t <= 1.10:
			btn_x_pressed = true
			if not step2_missile_fired:
				step2_missile_fired = true
				SoundManager.play("secondary_fire")
				missiles.append({
					"x": ship_x + 24.0,
					"y": ship_y + 26.0,
					"vx": 460.0,
					"vy": 115.0,
					"speed": 840.0,
					"age": 0.0,
					"trail": []
				})
		else:
			btn_x_pressed = false

		if t >= 2.5:
			_advance_step(3)

	# STEP 3: PHASE BARREL ROLL DODGE (2.4s)
	elif step == 3:
		var t = step_timer
		if not step3_bullet_spawned and t >= 0.20:
			step3_bullet_spawned = true
			SoundManager.play("enemy_fire")
			enemy_bullets.append({"x": 1620.0, "y": ARENA_CENTER_Y, "vx": -920.0, "vy": 0.0, "radius": 13.0, "color": GameConfig.COLOR_GOLD})
			enemy_bullets.append({"x": 1700.0, "y": ARENA_CENTER_Y - 44.0, "vx": -920.0, "vy": 0.0, "radius": 10.5, "color": GameConfig.COLOR_RED})
			enemy_bullets.append({"x": 1700.0, "y": ARENA_CENTER_Y + 44.0, "vx": -920.0, "vy": 0.0, "radius": 10.5, "color": GameConfig.COLOR_RED})

		if t < 1.00:
			ship_x += (420.0 - ship_x) * minf(1.0, dt * 6.0)
			ship_y += (ARENA_CENTER_Y - ship_y) * minf(1.0, dt * 6.0)
			btn_lt_pressed = false
			dodge_active = false
		elif t < 1.50:
			btn_lt_pressed = true
			dodge_active = true
			if not step3_dodge_triggered:
				step3_dodge_triggered = true
				SoundManager.play("dodge")
			ship_x += 780.0 * dt
			ship_y -= 65.0 * dt
			dodge_afterimages.append({"x": ship_x, "y": ship_y, "timer": 0.18})
		else:
			btn_lt_pressed = false
			dodge_active = false
			if t >= 2.05 and not step3_dodge_recharged:
				step3_dodge_recharged = true
				demo_dodge_ready_flash = 0.32
				SoundManager.play("dodge_ready")
			ship_x += (560.0 - ship_x) * minf(1.0, dt * 5.0)
			ship_y += (ARENA_CENTER_Y - ship_y) * minf(1.0, dt * 5.0)

		if t >= 2.4:
			_advance_step(4)

	# STEP 4: WARP LAUNCH INTO MISSION (0.65s)
	elif step == 4:
		ship_x += 2100.0 * dt
		dodge_afterimages.append({"x": ship_x, "y": ship_y, "timer": 0.16})
		if step_timer >= 0.65:
			main_app.set_state("GAME")
			return

	# Banking & thrust state
	ship_vx = (ship_x - prev_x) / maxf(dt, 0.001)
	ship_vy = (ship_y - prev_y) / maxf(dt, 0.001)

	if ship_vy < -35.0:
		ship_bank = "bank_left"
	elif ship_vy > 35.0:
		ship_bank = "bank_right"
	else:
		ship_bank = "neutral"

	if dodge_active or ship_vx > 90.0 or step == 4:
		ship_thrust = "boost"
	elif ship_vx < -40.0:
		ship_thrust = "idle"
	else:
		ship_thrust = "cruise"

	if player_3d != null:
		var dodge_prog: float = 0.0
		var demo_dodge_ready: bool = true
		if step == 3:
			if dodge_active:
				dodge_prog = clampf((step_timer - 1.00) / 0.50, 0.0, 1.0)
			elif step_timer >= 1.50 and step_timer < 2.05:
				demo_dodge_ready = false
		player_3d.update_ship_pose(dt, ship_vy, ship_bank, ship_thrust, total_time, dodge_active, dodge_prog, demo_dodge_ready, demo_dodge_ready_flash)

	if demo_scout_3d != null:
		demo_scout_3d.update_pose(dt, 0.0, "neutral", total_time, false, false)
	if demo_raider_3d != null:
		demo_raider_3d.update_pose(dt, cos(step_timer * 3.8) * 285.0, "neutral", total_time, false, false, 260.0)

	# Update lasers
	for l in lasers.duplicate():
		l["age"] = l.get("age", 0.0) + dt
		l["x"] += l["vx"] * dt
		if not dummy_target.is_empty() and dummy_target.get("alive", false):
			if absf(l["x"] - dummy_target["x"]) < 55.0 and absf(l["y"] - dummy_target["y"]) < 48.0:
				dummy_target["hp"] -= 9
				dummy_target["flash"] = 0.08
				laser_impacts.append({"x": l["x"] + 8.0, "y": l["y"], "age": 0.0, "max_age": 0.12})
				_spawn_explosion(l["x"], l["y"], 6, GameConfig.COLOR_CYAN)
				lasers.erase(l)
				if dummy_target["hp"] <= 0:
					dummy_target["alive"] = false
					SoundManager.play("explosion")
					_spawn_explosion(dummy_target["x"], dummy_target["y"], 28, GameConfig.COLOR_GOLD)
					score_popups.append({
						"x": float(dummy_target["x"]),
						"y": float(dummy_target["y"]) - 24.0,
						"vy": -86.0,
						"text": "+100",
						"age": 0.0,
						"max_age": 0.90,
						"style": "standard"
					})
				else:
					SoundManager.play("enemy_hit")
				continue
		if l["x"] > GameConfig.SCREEN_WIDTH + 60.0:
			lasers.erase(l)

	# Update missiles
	for m in missiles.duplicate():
		m["age"] = float(m.get("age", 0.0)) + dt
		if not dummy_target.is_empty() and dummy_target.get("alive", false):
			var desired = atan2(dummy_target["y"] - m["y"], dummy_target["x"] - m["x"])
			var curr = atan2(m["vy"], m["vx"])
			var diff = fmod(desired - curr + PI, TAU) - PI
			var new_ang = curr + clampf(diff, -6.2 * dt, 6.2 * dt)
			m["vx"] = cos(new_ang) * m["speed"]
			m["vy"] = sin(new_ang) * m["speed"]

		m["x"] += m["vx"] * dt
		m["y"] += m["vy"] * dt
		m["trail"].append(Vector2(m["x"], m["y"]))
		if m["trail"].size() > 20:
			m["trail"].pop_front()

		if not dummy_target.is_empty() and dummy_target.get("alive", false):
			if Vector2(m["x"] - dummy_target["x"], m["y"] - dummy_target["y"]).length() < 64.0:
				dummy_target["hp"] = 0
				dummy_target["alive"] = false
				SoundManager.play("explosion")
				missile_blasts.append({"x": m["x"], "y": m["y"], "age": 0.0, "max_age": 0.26})
				_spawn_explosion(dummy_target["x"], dummy_target["y"], 36, GameConfig.COLOR_GOLD)
				_spawn_explosion(dummy_target["x"], dummy_target["y"], 12, GameConfig.COLOR_MAGENTA)
				score_popups.append({
					"x": float(dummy_target["x"]),
					"y": float(dummy_target["y"]) - 24.0,
					"vy": -86.0,
					"text": "+150",
					"age": 0.0,
					"max_age": 0.95,
					"style": "raider"
				})
				missiles.erase(m)
				continue

		if m["x"] > GameConfig.SCREEN_WIDTH + 100.0:
			missiles.erase(m)

	# Update enemy bullets
	for b in enemy_bullets.duplicate():
		b["x"] += b["vx"] * dt
		b["y"] += b["vy"] * dt
		if b["x"] < -80.0:
			enemy_bullets.erase(b)

	# Update dodge afterimages
	for img in dodge_afterimages.duplicate():
		img["timer"] -= dt
		if img["timer"] <= 0.0:
			dodge_afterimages.erase(img)

	# Update particles & impact flashes
	for p in particles.duplicate():
		p["x"] += p["vx"] * dt
		p["y"] += p["vy"] * dt
		p["life"] -= dt
		if p["life"] <= 0.0:
			particles.erase(p)

	for imp in laser_impacts.duplicate():
		imp["age"] += dt
		if imp["age"] >= imp["max_age"]:
			laser_impacts.erase(imp)

	for mb in missile_blasts.duplicate():
		mb["age"] += dt
		if mb["age"] >= mb["max_age"]:
			missile_blasts.erase(mb)

	for sp in score_popups.duplicate():
		sp["age"] += dt
		if sp["age"] >= sp["max_age"]:
			score_popups.erase(sp)
			continue
		sp["vy"] = lerpf(float(sp["vy"]), -20.0, 1.0 - exp(-5.0 * dt))
		sp["y"] = float(sp["y"]) + float(sp["vy"]) * dt

	_update_demo_3d_lighting()


func _update_demo_3d_lighting() -> void:
	var sun_px := Vector2(0.78 * GameConfig.SCREEN_WIDTH, 0.20 * GameConfig.SCREEN_HEIGHT)
	var emitters: Array = []
	for l in lasers:
		emitters.append({"pos": Vector2(float(l["x"]), float(l["y"])), "color": Color(0.12, 0.90, 1.0), "energy": 2.65, "reach": 185.0})
	if gun_glow_timer > 0.0:
		emitters.append({"pos": Vector2(ship_x + 42.0, ship_y), "color": Color(0.20, 0.94, 1.0), "energy": 2.15 * clampf(gun_glow_timer / 0.10, 0.0, 1.0), "reach": 145.0})
	for imp in laser_impacts:
		var ip: float = 1.0 - clampf(float(imp["age"]) / maxf(float(imp["max_age"]), 0.001), 0.0, 1.0)
		if ip > 0.05:
			emitters.append({"pos": Vector2(float(imp["x"]), float(imp["y"])), "color": Color(0.38, 0.96, 1.0), "energy": 3.10 * ip, "reach": 215.0})
	for m in missiles:
		emitters.append({"pos": Vector2(float(m["x"]), float(m["y"])), "color": Color(1.0, 0.62, 0.18), "energy": 2.60, "reach": 220.0})
	for mb in missile_blasts:
		var mp: float = 1.0 - clampf(float(mb["age"]) / maxf(float(mb["max_age"]), 0.001), 0.0, 1.0)
		if mp > 0.05:
			emitters.append({"pos": Vector2(float(mb["x"]), float(mb["y"])), "color": Color(1.0, 0.72, 0.24), "energy": 3.60 * mp, "reach": 310.0})
	for eb in enemy_bullets:
		emitters.append({"pos": Vector2(float(eb["x"]), float(eb["y"])), "color": eb.get("color", GameConfig.COLOR_RED), "energy": 1.05, "reach": 120.0})

	if player_3d != null:
		var p_pos := Vector2(ship_x, ship_y)
		player_3d.update_dynamic_lighting(p_pos, Vector2(SHIP_DRAW_W, SHIP_DRAW_H), sun_px, _pick_demo_lights(p_pos, Vector2(94.0, 51.0), emitters))

	if not dummy_target.is_empty() and dummy_target.get("alive", false):
		var t_pos := Vector2(float(dummy_target["x"]), float(dummy_target["y"]))
		if dummy_target.get("type", "") == "scout" and demo_scout_3d != null:
			demo_scout_3d.update_dynamic_lighting(t_pos, Vector2(122.0, 88.0), sun_px, _pick_demo_lights(t_pos, Vector2(61.0, 44.0), emitters))
		elif dummy_target.get("type", "") == "raider" and demo_raider_3d != null:
			demo_raider_3d.update_dynamic_lighting(t_pos, Vector2(184.0, 126.0), sun_px, _pick_demo_lights(t_pos, Vector2(92.0, 63.0), emitters))


func _pick_demo_lights(ship_pos: Vector2, half_ext: Vector2, emitters: Array) -> Array:
	var best0_e: float = 0.0
	var best1_e: float = 0.0
	var best0: Dictionary = {}
	var best1: Dictionary = {}
	for em in emitters:
		var epos: Vector2 = em["pos"]
		var dx_b: float = maxf(0.0, absf(epos.x - ship_pos.x) - half_ext.x * 0.72)
		var dy_b: float = maxf(0.0, absf(epos.y - ship_pos.y) - half_ext.y * 0.72)
		var reach: float = float(em["reach"])
		var edge_dist: float = sqrt(dx_b * dx_b + dy_b * dy_b)
		if edge_dist >= reach:
			continue
		var atten: float = 1.0 - (edge_dist / reach)
		var eff_e: float = float(em["energy"]) * atten * atten
		if eff_e <= 0.04:
			continue
		if not best0.is_empty() and epos.distance_squared_to(best0["pos"]) < 1400.0:
			if eff_e > best0_e:
				best0_e = eff_e
				best0["pos"] = epos
				best0["energy"] = minf(3.3, eff_e * 1.18)
			continue
		if eff_e > best0_e:
			best1_e = best0_e
			best1 = best0
			best0_e = eff_e
			best0 = {"pos": epos, "color": em["color"], "energy": eff_e, "z": 0.60, "range": 1.95}
		elif eff_e > best1_e:
			best1_e = eff_e
			best1 = {"pos": epos, "color": em["color"], "energy": eff_e, "z": 0.60, "range": 1.95}
	var out: Array = []
	if best0_e > 0.04:
		out.append(best0)
	if best1_e > 0.04:
		out.append(best1)
	return out


func _draw() -> void:
	if backdrop_material == null:
		draw_rect(Rect2(0.0, 0.0, GameConfig.SCREEN_WIDTH, GameConfig.SCREEN_HEIGHT), Color8(6, 7, 20), true)
		for s in stars:
			draw_rect(Rect2(s["x"], s["y"], s["size"], s["size"]), s["color"], true)

	var cx: float = GameConfig.SCREEN_WIDTH * 0.5
	var is_live_display: bool = DisplayServer.get_name() != "headless"

	# 1. Clean Minimal Top Header
	GameConfig.draw_glow_text(
		self,
		"HOW TO PLAY",
		cx,
		54.0,
		26,
		GameConfig.COLOR_GOLD,
		Color8(140, 55, 0),
		"center",
		total_time
	)
	draw_line(Vector2(cx - 180.0, 84.0), Vector2(cx + 180.0, 84.0), Color(0.0, 0.94, 1.0, 0.55), 2.0)

	# 2. Player Ship & Clean 3D Phase Afterimages
	var frame_list: Array = ship_frames.get(ship_bank, {}).get(ship_thrust, [])
	var frame_idx: int = int(total_time * 14.0) % maxi(1, frame_list.size())
	var fallback_ship_tex: Texture2D = frame_list[frame_idx] if not frame_list.is_empty() else null
	var vp_tex: Texture2D = null
	if is_live_display and player_3d != null and player_3d.has_3d_model():
		vp_tex = player_3d.get_texture()

	for img in dodge_afterimages:
		var a_ratio: float = clampf(img["timer"] / 0.18, 0.0, 1.0)
		var ghost_col := Color(0.20, 0.90, 1.0, a_ratio * 0.36)
		var gx: float = img["x"] - SHIP_DRAW_W * 0.5
		var gy: float = img["y"] - SHIP_DRAW_H * 0.5
		if vp_tex != null:
			draw_texture_rect(vp_tex, Rect2(gx, gy, SHIP_DRAW_W, SHIP_DRAW_H), false, ghost_col)
		elif fallback_ship_tex != null:
			draw_texture(fallback_ship_tex, Vector2(gx, gy), ghost_col)

	# Subtle Phase-Shield Aura during Barrel Roll Dodge (no overlapping text clutter)
	if dodge_active:
		if GameConfig.tex_photon_flare != null:
			draw_texture_rect(
				GameConfig.tex_photon_flare,
				Rect2(ship_x - 105.0, ship_y - 68.0, 210.0, 136.0),
				false,
				Color(0.25, 0.95, 1.0, 0.42)
			)
		var shield_r: float = 58.0 + sin(total_time * 28.0) * 3.0
		draw_arc(Vector2(ship_x + 4.0, ship_y), shield_r, -1.15, 1.15, 24, Color(0.2, 0.95, 1.0, 0.85), 2.5)
		draw_arc(Vector2(ship_x + 4.0, ship_y), shield_r, PI - 1.15, PI + 1.15, 24, Color(0.2, 0.95, 1.0, 0.55), 2.0)

	if vp_tex != null:
		var mod_col := Color(1.45, 1.75, 2.0, 1.0) if dodge_active else Color.WHITE
		draw_texture_rect(
			vp_tex,
			Rect2(ship_x - SHIP_DRAW_W * 0.5, ship_y - SHIP_DRAW_H * 0.5, SHIP_DRAW_W, SHIP_DRAW_H),
			false,
			mod_col
		)
	elif fallback_ship_tex != null:
		draw_texture(fallback_ship_tex, Vector2(ship_x - SHIP_DRAW_W * 0.5, ship_y - SHIP_DRAW_H * 0.5))

	if gun_glow_timer > 0.0:
		var g_ratio = clampf(gun_glow_timer / 0.10, 0.0, 1.0)
		var gun_offsets = [Vector2(28.0, -16.0), Vector2(28.0, 16.0)]
		if ship_bank == "bank_left":
			gun_offsets = [Vector2(28.0, -20.0), Vector2(28.0, 12.0)]
		elif ship_bank == "bank_right":
			gun_offsets = [Vector2(28.0, -12.0), Vector2(28.0, 20.0)]
		for goff in gun_offsets:
			GameConfig.draw_photon_muzzle_flash(self, ship_x + goff.x, ship_y + goff.y, g_ratio, 1.06)

	# 3. Target Enemy Ship (clean 3D ship + slim minimal HP bar, no noisy text labels)
	if not dummy_target.is_empty() and dummy_target.get("alive", false):
		var tx: float = dummy_target["x"]
		var ty: float = dummy_target["y"]
		var drawn_target_3d := false
		if is_live_display:
			var mod_t := Color(2.8, 2.8, 2.8, 1.0) if dummy_target.get("flash", 0.0) > 0.0 else Color.WHITE
			if dummy_target["type"] == "scout" and demo_scout_3d != null and demo_scout_3d.has_3d_model():
				var stex: Texture2D = demo_scout_3d.get_texture()
				if stex != null:
					draw_texture_rect(stex, Rect2(tx - 54.0, ty - 40.0, 108.0, 80.0), false, mod_t)
					drawn_target_3d = true
			elif dummy_target["type"] == "raider" and demo_raider_3d != null and demo_raider_3d.has_3d_model():
				var rtex: Texture2D = demo_raider_3d.get_texture()
				if rtex != null:
					draw_texture_rect(rtex, Rect2(tx - 82.0, ty - 56.0, 164.0, 112.0), false, mod_t)
					drawn_target_3d = true
		if not drawn_target_3d:
			var tex = scout_tex if dummy_target["type"] == "scout" else raider_tex
			if tex != null:
				draw_texture(tex, Vector2(tx - tex.get_width() * 0.5, ty - tex.get_height() * 0.5))

		var bar_w: float = 68.0
		var bar_h: float = 5.0
		var bar_y: float = ty - (54.0 if dummy_target["type"] == "scout" else 64.0)
		var hp_ratio: float = clampf(float(dummy_target["hp"]) / maxf(1.0, float(dummy_target["max_hp"])), 0.0, 1.0)
		draw_rect(Rect2(tx - bar_w * 0.5, bar_y, bar_w, bar_h), Color(0.05, 0.06, 0.14, 0.85), true)
		draw_rect(Rect2(tx - bar_w * 0.5, bar_y, bar_w * hp_ratio, bar_h), GameConfig.COLOR_RED, true)
		draw_rect(Rect2(tx - bar_w * 0.5, bar_y, bar_w, bar_h), Color(1.0, 1.0, 1.0, 0.45), false, 1.0)

	# 4. Live Projectiles & VFX
	for l in lasers:
		var anim_p: float = float(l.get("phase", 0.0)) + float(l.get("age", 0.0))
		GameConfig.draw_photon_laser_bolt(self, l["x"], l["y"], anim_p, 1.04)

	for imp in laser_impacts:
		var prog: float = float(imp["age"]) / maxf(float(imp["max_age"]), 0.001)
		GameConfig.draw_photon_impact_flash(self, imp["x"], imp["y"], prog, 1.04)

	for mb in missile_blasts:
		var m_prog: float = float(mb["age"]) / maxf(float(mb["max_age"]), 0.001)
		GameConfig.draw_missile_blast(self, mb["x"], mb["y"], m_prog, 1.08)

	for m in missiles:
		GameConfig.draw_homing_missile(
			self,
			m["x"],
			m["y"],
			m["vx"],
			m["vy"],
			m["trail"],
			float(m.get("age", 0.0)),
			true,
			1.05
		)

	for b in enemy_bullets:
		GameConfig.draw_enemy_projectile(
			self,
			b["x"],
			b["y"],
			float(b.get("vx", -920.0)),
			float(b.get("vy", 0.0)),
			float(b["radius"]),
			b.get("color", GameConfig.COLOR_RED),
			total_time
		)

	for p in particles:
		draw_rect(Rect2(p["x"], p["y"], p["size"], p["size"]), p["color"], true)

	for sp in score_popups:
		var sp_prog: float = float(sp["age"]) / maxf(float(sp["max_age"]), 0.001)
		GameConfig.draw_score_popup(self, float(sp["x"]), float(sp["y"]), String(sp["text"]), sp_prog, String(sp["style"]))

	# 5. Clean 4-Card At-A-Glance Controls Strip
	_draw_controls_strip()

	# 6. Smooth Pulsing Launch Prompt
	var prompt_alpha: float = 0.80 + 0.20 * sin(total_time * 3.8)
	GameConfig.draw_text(
		self,
		"PRESS ANY BUTTON OR KEY TO START",
		cx,
		GameConfig.SCREEN_HEIGHT - 42.0,
		14,
		GameConfig.COLOR_GOLD,
		"center",
		true,
		Color(0.0, 0.0, 0.0, prompt_alpha),
		prompt_alpha
	)


func _draw_controls_strip() -> void:
	var card_w: float = 392.0
	var card_h: float = 178.0
	var gap: float = 24.0
	var total_w: float = card_w * 4.0 + gap * 3.0
	var start_x: float = (GameConfig.SCREEN_WIDTH - total_w) * 0.5
	var card_y: float = GameConfig.SCREEN_HEIGHT - 254.0

	var cards = [
		{"title": "MOVE", "pad": "LEFT STICK / D-PAD", "kb": "WASD / ARROWS"},
		{"title": "LASERS", "pad": "HOLD [A] BUTTON", "kb": "J / Z / LEFT CLICK"},
		{"title": "MISSILES", "pad": "PRESS [X] BUTTON", "kb": "K / X / RIGHT CLICK"},
		{"title": "DODGE", "pad": "PRESS [LT / LB]", "kb": "SPACE / SHIFT"},
	]

	for i in range(4):
		var card_x: float = start_x + float(i) * (card_w + gap)
		var card_rect := Rect2(card_x, card_y, card_w, card_h)
		var is_active: bool = (step == i)

		var bg_col := Color8(14, 24, 56, 232) if is_active else Color8(8, 12, 28, 200)
		var border_col := GameConfig.COLOR_CYAN if is_active else Color8(48, 70, 115, 175)
		var corner_col := GameConfig.COLOR_GOLD if is_active else Color8(70, 95, 145, 160)
		var border_w: float = 2.5 if is_active else 1.5

		GameConfig.draw_glass_panel(self, card_rect, bg_col, border_col, corner_col, 14.0, border_w)

		var ccx: float = card_x + card_w * 0.5
		var title_col: Color = GameConfig.COLOR_GOLD if is_active else Color8(185, 205, 235)
		GameConfig.draw_text(self, cards[i]["title"], ccx, card_y + 26.0, 16, title_col, "center")

		# Crisp vector arcade input icon centered in the card
		var icon_cy: float = card_y + 82.0
		_draw_card_input_icon(i, ccx, icon_cy, is_active)

		var pad_col: Color = GameConfig.COLOR_WHITE if is_active else Color8(165, 185, 215)
		var kb_col: Color = GameConfig.COLOR_CYAN if is_active else Color8(110, 130, 165)
		GameConfig.draw_text(self, cards[i]["pad"], ccx, card_y + 134.0, 12, pad_col, "center")
		GameConfig.draw_text(self, cards[i]["kb"], ccx, card_y + 156.0, 10, kb_col, "center")


func _draw_card_input_icon(card_idx: int, icx: float, icy: float, is_active: bool) -> void:
	var center := Vector2(icx, icy)
	if card_idx == 0:
		# Clean Vector Analog Stick + Cardinal Ticks
		var ring_col: Color = GameConfig.COLOR_CYAN if is_active else Color8(85, 115, 165)
		draw_circle(center, 25.0, Color8(10, 16, 36))
		draw_arc(center, 25.0, 0.0, TAU, 36, ring_col, 2.0)
		for dir_v in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
			draw_line(center + dir_v * 18.0, center + dir_v * 23.0, Color(ring_col.r, ring_col.g, ring_col.b, 0.55), 1.5)
		var cap_pos: Vector2 = center + (stick_offset * 9.5 if is_active else Vector2.ZERO)
		draw_circle(cap_pos, 11.0, GameConfig.COLOR_GOLD if (is_active and stick_offset.length() > 0.15) else ring_col)
		draw_circle(cap_pos, 6.0, GameConfig.COLOR_WHITE)

	elif card_idx == 1:
		# Clean Vector [A] Arcade Button
		var pressed: bool = is_active and btn_a_pressed
		var rim_col: Color = GameConfig.COLOR_GREEN if is_active else Color8(80, 145, 120)
		var fill_col: Color = Color(0.12, 0.72, 0.36, 0.95) if pressed else Color8(12, 28, 24)
		var r_btn: float = 21.0 if pressed else 23.0
		draw_circle(center, r_btn, fill_col)
		draw_arc(center, r_btn, 0.0, TAU, 36, rim_col, 2.5 if is_active else 1.8)
		GameConfig.draw_text(self, "A", icx + 1.0, icy + 1.0, 16, GameConfig.COLOR_WHITE if pressed else rim_col, "center", false)

	elif card_idx == 2:
		# Clean Vector [X] Arcade Button
		var pressed: bool = is_active and btn_x_pressed
		var rim_col: Color = GameConfig.COLOR_CYAN if is_active else Color8(85, 125, 175)
		var fill_col: Color = Color(0.0, 0.65, 0.95, 0.95) if pressed else Color8(12, 22, 42)
		var r_btn: float = 21.0 if pressed else 23.0
		draw_circle(center, r_btn, fill_col)
		draw_arc(center, r_btn, 0.0, TAU, 36, GameConfig.COLOR_GOLD if pressed else rim_col, 2.5 if is_active else 1.8)
		GameConfig.draw_text(self, "X", icx + 1.0, icy + 1.0, 16, GameConfig.COLOR_WHITE if pressed else rim_col, "center", false)

	else:
		# Clean Vector [LT] Shoulder Trigger Badge
		var pressed: bool = is_active and btn_lt_pressed
		var bw: float = 62.0
		var bh: float = 36.0 if pressed else 40.0
		var b_rect := Rect2(icx - bw * 0.5, icy - bh * 0.5, bw, bh)
		var fill_col: Color = Color(0.0, 0.68, 0.95, 0.92) if pressed else Color8(12, 20, 40, 240)
		var rim_col: Color = GameConfig.COLOR_CYAN if is_active else Color8(85, 115, 165)
		GameConfig.draw_glass_panel(self, b_rect, fill_col, rim_col, GameConfig.COLOR_GOLD if pressed else rim_col, 7.0, 2.2 if is_active else 1.6)
		GameConfig.draw_text(self, "LT", icx + 1.0, icy + 1.0, 14, GameConfig.COLOR_WHITE if pressed else rim_col, "center", false)
