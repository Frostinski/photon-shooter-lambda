extends Node2D

const SpaceBackdropShader = preload("res://assets/shaders/space_backdrop.gdshader")
const PlayerShip3DScript = preload("res://scripts/player_ship_3d.gd")
const EnemyShip3DScript = preload("res://scripts/enemy_ship_3d.gd")
const Asteroid3DScript = preload("res://scripts/asteroid_3d.gd")

var main_app: Node = null

const ALPHA_GRID: Array = [
	["A", "B", "C", "D", "E", "F", "G"],
	["H", "I", "J", "K", "L", "M", "N"],
	["O", "P", "Q", "R", "S", "T", "U"],
	["V", "W", "X", "Y", "Z", "DEL", "SPC"],
]


class PlayerShip:
	var frames: Dictionary
	var flash_frames: Dictionary
	var x: float = 180.0
	var y: float = GameConfig.SCREEN_HEIGHT * 0.5
	var vx: float = 0.0
	var vy: float = 0.0
	var width: float = 132.0
	var height: float = 95.0
	var speed: float = 580.0

	var max_hp: int = 4
	var hp: int = 4

	var bank_state: String = "neutral"
	var thrust_state: String = "cruise"
	var anim_timer: float = 0.0
	var anim_fps: float = 14.3

	var primary_cooldown: float = 0.0
	var primary_fire_rate: float = 0.175 / 1.2
	var primary_buffer_timer: float = 0.0
	var gun_glow_timer: float = 0.0

	var max_missile_charges: int = 3
	var missile_charges: int = 3
	var missile_recharge_time: float = 2.7
	var missile_recharge_timer: float = 0.0
	var secondary_fire_lock: float = 0.0
	var missile_wing_toggle: int = 1

	var dodge_cooldown: float = 0.0
	var dodge_max_cooldown: float = 1.0
	var dodge_timer: float = 0.0
	var dodge_duration: float = 0.22
	var dodge_vx: float = 0.0
	var dodge_vy: float = 0.0
	var dodge_ready_flash: float = 0.0

	var invuln_timer: float = 0.0
	var shield_hit_timer: float = 0.0
	var shield_hit_duration: float = 0.50
	var shield_hit_angle: float = 0.0
	var shield_bar_timer: float = 0.0
	var shield_bar_duration: float = 2.10
	var afterimages: Array = []

	func _init(p_frames: Dictionary, p_flash_frames: Dictionary) -> void:
		frames = p_frames
		flash_frames = p_flash_frames

	func is_dodging() -> bool:
		return dodge_timer > 0.0

	func is_dodge_ready() -> bool:
		return dodge_cooldown <= 0.0

	func is_invulnerable() -> bool:
		return dodge_timer > 0.0 or invuln_timer > 0.0

	func get_current_frame(use_flash: bool = false) -> Texture2D:
		var source = flash_frames if use_flash else frames
		var state_group: Dictionary = source.get(bank_state, source.get("neutral", {}))
		var frame_list: Array = state_group.get(thrust_state, state_group.get("cruise", []))
		if frame_list.is_empty():
			return null
		var idx = int(anim_timer * anim_fps) % frame_list.size()
		return frame_list[idx]

	func get_hitbox() -> Rect2:
		return Rect2(x - 28.0, y - 18.0, 56.0, 36.0)


class EnemyShip:
	var enemy_type: String
	var x: float
	var y: float
	var base_y: float
	var phase: float
	var time: float = 0.0
	var anim_timer: float = 0.0
	var hit_flash: float = 0.0
	var delay: float = 0.0
	var active: bool = true
	var speed_mult: float = 1.0
	var hp_mult: float = 1.0
	var fire_mode: String = "spread"

	var sprites: Array = []
	var flash_sprites: Array = []
	var tex: Texture2D = null
	var flash_tex: Texture2D = null

	var width: float = 88.0
	var height: float = 70.0
	var hp: int = 20
	var max_hp: int = 20
	var speed_x: float = 380.0
	var amp_y: float = 0.0
	var freq_y: float = 2.0
	var score_value: int = 100
	var fire_timer: float = 0.9
	var fire_rate: float = 1.9

	# Scout Pattern A (Striker: enter -> hover -> retreat)
	var state: String = "enter"
	var target_x: float = 1440.0
	var stop_x: float = 1440.0
	var stopped: bool = false
	var has_stopped: bool = false
	var stop_timer: float = 0.0
	var hover_duration: float = 1.5
	var hover_timer: float = 0.0
	var has_fired: bool = false
	var charge_timer: float = 0.0
	var fire_flash_timer: float = 0.0
	var retreat_dir: String = "up"
	var retreat_vx: float = 0.0
	var retreat_vy: float = 0.0

	# Raider Pattern B (Sweep: continuous sine wave + screen X fire checkpoints)
	var vy: float = 0.0
	var bank_state: String = "neutral"
	var fire_checkpoints: Array = []
	var vp_3d: SubViewport = null

	func _init(
		p_type: String,
		p_x: float,
		p_y: float,
		sprite_data: Dictionary,
		p_speed_mult: float = 1.0,
		p_hp_mult: float = 1.0,
		p_delay: float = 0.0,
		p_fire_mode: String = "spread"
	) -> void:
		enemy_type = p_type
		x = p_x
		y = p_y
		base_y = p_y
		phase = randf_range(0.0, TAU)
		speed_mult = p_speed_mult
		hp_mult = p_hp_mult
		delay = p_delay
		active = (delay <= 0.0)
		fire_mode = p_fire_mode

		if enemy_type == "scout":
			sprites = sprite_data.get("scout_frames", [])
			flash_sprites = sprite_data.get("scout_flash_frames", [])
			width = 88.0
			height = 70.0
			hp = int(round(20.0 * hp_mult))
			max_hp = hp
			speed_x = 380.0 * speed_mult
			score_value = 100
			state = "enter"
			target_x = GameConfig.SCREEN_WIDTH * 0.75 + randf_range(-25.0, 25.0)
			stop_x = target_x
			hover_duration = randf_range(1.2, 1.8)
			stop_timer = hover_duration
			retreat_dir = ["up", "down", "forward"][randi_range(0, 2)]
		else:
			sprites = sprite_data.get("raider_frames", [])
			flash_sprites = sprite_data.get("raider_flash_frames", [])
			tex = sprite_data.get("raider", null)
			flash_tex = sprite_data.get("raider_flash", null)
			width = 104.0
			height = 84.0
			hp = int(round(25.0 * hp_mult))
			max_hp = hp
			speed_x = 340.0 * speed_mult
			amp_y = randf_range(35.0, 75.0)
			freq_y = randf_range(1.8, 2.4)
			score_value = 150
			fire_checkpoints = [
				GameConfig.SCREEN_WIDTH * 0.72 + randf_range(-30.0, 30.0),
				GameConfig.SCREEN_WIDTH * 0.42 + randf_range(-30.0, 30.0),
			]

	func update(dt: float, player_ref: PlayerShip, enemy_bullets: Array, current_phase: int) -> void:
		if delay > 0.0:
			delay -= dt
			if delay <= 0.0:
				active = true
			else:
				return

		time += dt
		anim_timer += dt
		var prev_y = y

		if hit_flash > 0.0:
			hit_flash = maxf(0.0, hit_flash - dt)
		if fire_flash_timer > 0.0:
			fire_flash_timer = maxf(0.0, fire_flash_timer - dt)

		if enemy_type == "scout":
			if state == "enter":
				var dist = x - target_x
				var step_speed = speed_x if dist > 120.0 else maxf(160.0, dist * 3.2)
				x -= step_speed * dt
				if x <= target_x:
					x = target_x
					state = "hover"
					stopped = true
					has_stopped = true
					hover_timer = 0.0
					stop_timer = hover_duration
			elif state == "hover":
				hover_timer += dt
				stop_timer = maxf(0.0, hover_duration - hover_timer)
				x -= 18.0 * dt
				y += sin(time * 4.0 + phase) * 25.0 * dt
				if not has_fired and hover_timer >= hover_duration * 0.42:
					charge_timer += dt
					if charge_timer >= 0.32:
						has_fired = true
						charge_timer = 0.0
						fire_flash_timer = 0.30
						_fire_scout(player_ref, enemy_bullets)
				if hover_timer >= hover_duration:
					state = "retreat"
					stopped = false
					retreat_vx = -460.0 * speed_mult
					if retreat_dir == "up":
						retreat_vy = -230.0 * speed_mult
					elif retreat_dir == "down":
						retreat_vy = 230.0 * speed_mult
					else:
						retreat_vy = 0.0
			elif state == "retreat":
				retreat_vx -= 280.0 * dt
				x += retreat_vx * dt
				y += retreat_vy * dt

			if state != "retreat":
				y = clampf(y, 110.0, GameConfig.SCREEN_HEIGHT - 80.0)
			vy = (y - prev_y) / maxf(dt, 0.001)
		else:
			x -= speed_x * dt
			y = base_y + sin(time * freq_y + phase) * amp_y
			y = clampf(y, 110.0, GameConfig.SCREEN_HEIGHT - 80.0)
			vy = (y - prev_y) / maxf(dt, 0.001)

			if vy < -28.0:
				bank_state = "bank_left"
			elif vy > 28.0:
				bank_state = "bank_right"
			else:
				bank_state = "neutral"

			if not fire_checkpoints.is_empty() and x <= fire_checkpoints[0]:
				fire_checkpoints.pop_front()
				_fire_raider(player_ref, enemy_bullets, current_phase)

	func _fire_scout(player_ref: PlayerShip, enemy_bullets: Array) -> void:
		if x <= 120.0 or x >= GameConfig.SCREEN_WIDTH - 30.0:
			return
		SoundManager.play("enemy_fire")
		if fire_mode == "aimed" and player_ref != null:
			var ang = atan2(player_ref.y - y, player_ref.x - x)
			enemy_bullets.append({
				"x": x - 32.0,
				"y": y,
				"vx": cos(ang) * 520.0,
				"vy": sin(ang) * 520.0,
				"radius": 6.0,
				"color": GameConfig.COLOR_RED
			})
		else:
			for deg in [-14.0, 0.0, 14.0]:
				var ang = PI + deg_to_rad(deg)
				enemy_bullets.append({
					"x": x - 32.0,
					"y": y,
					"vx": cos(ang) * 520.0,
					"vy": sin(ang) * 520.0,
					"radius": 6.0,
					"color": GameConfig.COLOR_RED
				})

	func _fire_raider(player_ref: PlayerShip, enemy_bullets: Array, current_phase: int) -> void:
		if x <= 140.0 or x >= GameConfig.SCREEN_WIDTH - 40.0:
			return
		SoundManager.play("enemy_fire")
		var tx = player_ref.x if player_ref != null else 200.0
		var ty = player_ref.y if player_ref != null else y
		var base_ang = atan2(ty - y, tx - x)
		var spread_degs: Array = [0.0]
		if current_phase >= 3:
			spread_degs = [-16.0, 0.0, 16.0]
		elif current_phase == 2:
			spread_degs = [-10.0, 10.0]

		for deg in spread_degs:
			var ang = base_ang + deg_to_rad(deg)
			enemy_bullets.append({
				"x": x - 40.0,
				"y": y,
				"vx": cos(ang) * 520.0,
				"vy": sin(ang) * 520.0,
				"radius": 7.0,
				"color": GameConfig.COLOR_RED
			})

	func get_hitbox() -> Rect2:
		if enemy_type == "scout":
			return Rect2(x - 32.0, y - 24.0, 64.0, 48.0)
		return Rect2(x - 50.0, y - 34.0, 100.0, 68.0)

	func get_current_texture() -> Texture2D:
		if enemy_type == "scout" and not sprites.is_empty():
			var active_rows = flash_sprites if hit_flash > 0.0 else sprites
			var row_idx: int = 0
			var col_idx: int = 0
			if fire_flash_timer > 0.0:
				row_idx = 2
				col_idx = min(3, int(((0.30 - fire_flash_timer) / 0.30) * 4.0))
			elif charge_timer > 0.0:
				row_idx = 1
				col_idx = min(3, int((charge_timer / 0.32) * 4.0))
			else:
				row_idx = 0
				col_idx = int(anim_timer * 12.5) % 4
			return active_rows[row_idx][col_idx]
		elif enemy_type == "raider" and not sprites.is_empty():
			var active_rows = flash_sprites if hit_flash > 0.0 else sprites
			var row_map = {"bank_left": 0, "neutral": 1, "bank_right": 2}
			var row_idx = row_map.get(bank_state, 1)
			var col_idx = int(anim_timer * 13.3) % 4
			return active_rows[row_idx][col_idx]
		return flash_tex if hit_flash > 0.0 else tex


class DreadnoughtShip:
	var tex: Texture2D
	var flash_tex: Texture2D
	var width: float = 480.0
	var height: float = 228.0
	var x: float = GameConfig.SCREEN_WIDTH + 280.0
	var y: float = GameConfig.SCREEN_HEIGHT * 0.5
	var target_x: float = 1515.0
	var hp: int = 1200
	var max_hp: int = 1200
	var score_value: int = 5000
	var time: float = 0.0
	var strafe_time: float = 0.0
	var vy: float = 0.0
	var hit_flash: float = 0.0
	var entering: bool = true
	var retreating: bool = false
	var retreat_vx: float = -360.0
	var attack_timer: float = 1.4
	var attack_index: int = 0
	var burst_remaining: int = 0
	var burst_timer: float = 0.0
	var burst_angle: float = PI

	# Half-health Emergency Shield & Phase 2 (+25% fire rate + targeted high-speed charge lasers)
	var phase2_triggered: bool = false
	var enraged: bool = false
	var emergency_shield_duration: float = 4.5
	var emergency_shield_timer: float = 0.0
	var shield_hit_flash: float = 0.0
	var shield_hit_angle: float = PI
	var charging_lasers: Array = []
	var overload_shot_timer: float = 0.0
	var overload_shots_remaining: int = 0
	var targeted_laser_timer: float = 2.08
	var laser_hardpoint_idx: int = 0

	func _init(sprite_data: Dictionary) -> void:
		tex = sprite_data.get("dreadnought", null)
		flash_tex = sprite_data.get("dreadnought_flash", null)

	func is_shielded() -> bool:
		return emergency_shield_timer > 0.0 and not retreating

	func get_shield_center() -> Vector2:
		return Vector2(x - 16.0, y)

	func get_shield_radii() -> Vector2:
		return Vector2(248.0, 114.0)

	func intersects_shield(rect: Rect2) -> bool:
		var sc: Vector2 = get_shield_center()
		var sr: Vector2 = get_shield_radii()
		if not Rect2(sc.x - sr.x, sc.y - sr.y, sr.x * 2.0, sr.y * 2.0).intersects(rect):
			return false
		var rc: Vector2 = rect.get_center()
		var nx: float = (rc.x - sc.x) / (sr.x + rect.size.x * 0.5)
		var ny: float = (rc.y - sc.y) / (sr.y + rect.size.y * 0.5)
		return (nx * nx + ny * ny) <= 1.04

	func register_shield_hit(hit_pt: Vector2) -> void:
		var sc: Vector2 = get_shield_center()
		shield_hit_flash = 0.24
		shield_hit_angle = atan2(hit_pt.y - sc.y, hit_pt.x - sc.x)

	func activate_emergency_shield() -> void:
		phase2_triggered = true
		emergency_shield_timer = emergency_shield_duration
		burst_remaining = 0
		charging_lasers.clear()
		overload_shots_remaining = 5
		overload_shot_timer = 0.16

	func _queue_targeted_laser(player_ref: PlayerShip, charge_dur: float = 1.0, beam_spd: float = 1120.0) -> void:
		var hardpoints: Array[Vector2] = [
			Vector2(-218.0, 26.0),
			Vector2(-180.0, 18.0),
			Vector2(-124.0, -34.0),
		]
		var hp_off: Vector2 = hardpoints[laser_hardpoint_idx % hardpoints.size()]
		laser_hardpoint_idx += 1
		var tx: float = player_ref.x if player_ref != null else 200.0
		var ty: float = player_ref.y if player_ref != null else y
		var ang: float = atan2(ty - (y + hp_off.y), tx - (x + hp_off.x))
		charging_lasers.append({
			"offset": hp_off,
			"age": 0.0,
			"charge_time": charge_dur,
			"aim_angle": ang,
			"speed": beam_spd,
		})

	func _update_charging_lasers(dt: float, player_ref: PlayerShip, enemy_bullets: Array) -> void:
		for cl in charging_lasers.duplicate():
			var off: Vector2 = cl["offset"]
			if player_ref != null:
				cl["aim_angle"] = atan2(player_ref.y - (y + off.y), player_ref.x - (x + off.x))
			cl["age"] = float(cl["age"]) + dt
			if float(cl["age"]) >= float(cl["charge_time"]):
				var ang: float = float(cl["aim_angle"])
				var spd: float = float(cl["speed"])
				enemy_bullets.append({
					"kind": "targeted_laser",
					"x": x + off.x,
					"y": y + off.y,
					"vx": cos(ang) * spd,
					"vy": sin(ang) * spd,
					"radius": 11.5,
					"color": Color(1.0, 0.16, 0.50),
				})
				SoundManager.play("boss_fire")
				charging_lasers.erase(cl)

	func trigger_retreat() -> void:
		if not retreating:
			retreating = true
			entering = false
			burst_remaining = 0
			emergency_shield_timer = 0.0
			charging_lasers.clear()
			retreat_vx = -360.0
			SoundManager.play("dodge")

	func update(dt: float, player_ref: PlayerShip, enemy_bullets: Array) -> void:
		time += dt
		var prev_y: float = y
		if hit_flash > 0.0:
			hit_flash = maxf(0.0, hit_flash - dt)
		if shield_hit_flash > 0.0:
			shield_hit_flash = maxf(0.0, shield_hit_flash - dt)

		if retreating:
			retreat_vx = maxf(-1350.0, retreat_vx - 900.0 * dt)
			x += retreat_vx * dt
			y += sin(time * 2.0) * 40.0 * dt
			vy = (y - prev_y) / maxf(dt, 0.001)
			return

		if entering:
			var dist: float = x - target_x
			var step_spd: float = 280.0 if dist > 140.0 else maxf(45.0, dist * 2.2)
			var move_x: float = step_spd * dt
			if dist <= move_x or dist <= 0.5:
				x = target_x
				entering = false
				strafe_time = 0.0
			else:
				x -= move_x
			vy = 0.0
		else:
			strafe_time += dt
			var env_t: float = clampf(strafe_time / 1.15, 0.0, 1.0)
			var strafe_env: float = env_t * env_t * (3.0 - 2.0 * env_t)
			y = GameConfig.SCREEN_HEIGHT * 0.5 + sin(strafe_time * 1.3) * 185.0 * strafe_env
			x = target_x + sin(strafe_time * 0.8) * 32.0 * strafe_env
			vy = (y - prev_y) / maxf(dt, 0.001)

		_update_charging_lasers(dt, player_ref, enemy_bullets)

		# Emergency Shield Overload Barrage (invulnerable while unleashing targeted high-speed lasers)
		if emergency_shield_timer > 0.0:
			emergency_shield_timer = maxf(0.0, emergency_shield_timer - dt)
			if overload_shots_remaining > 0:
				overload_shot_timer -= dt
				if overload_shot_timer <= 0.0:
					overload_shot_timer = 0.72
					overload_shots_remaining -= 1
					_queue_targeted_laser(player_ref, 1.0, 1120.0)
			if emergency_shield_timer <= 0.0:
				enraged = true
				attack_timer = 0.24
				targeted_laser_timer = 1.35
			return

		var fire_mult: float = 1.25 if enraged else 1.0

		if burst_remaining > 0:
			burst_timer -= dt
			if burst_timer <= 0.0:
				burst_timer = 0.07 / fire_mult
				var y_off = -44.0 if burst_remaining % 2 == 0 else 44.0
				burst_remaining -= 1
				enemy_bullets.append({
					"x": x - 165.0,
					"y": y + y_off,
					"vx": cos(burst_angle) * 560.0,
					"vy": sin(burst_angle) * 560.0,
					"radius": 7.0,
					"color": GameConfig.COLOR_GOLD
				})
				SoundManager.play("enemy_fire")

		attack_timer -= dt
		if attack_timer <= 0.0 and not entering:
			attack_timer = 1.2 / fire_mult
			var tx = player_ref.x if player_ref != null else 200.0
			var ty = player_ref.y if player_ref != null else y
			var base_ang = atan2(ty - y, tx - (x - 190.0))

			if attack_index % 2 == 0:
				for deg in [-20.0, 0.0, 20.0]:
					var ang = base_ang + deg_to_rad(deg)
					enemy_bullets.append({
						"x": x - 195.0,
						"y": y,
						"vx": cos(ang) * 520.0,
						"vy": sin(ang) * 520.0,
						"radius": 8.0,
						"color": GameConfig.COLOR_RED
					})
				SoundManager.play("enemy_fire")
			else:
				burst_remaining = 4
				burst_timer = 0.0
				burst_angle = base_ang
			attack_index += 1

		if enraged and not entering:
			targeted_laser_timer -= dt
			if targeted_laser_timer <= 0.0:
				targeted_laser_timer = 2.60 / fire_mult
				_queue_targeted_laser(player_ref, 1.0, 1120.0)

	func get_hitbox() -> Rect2:
		return Rect2(x - 205.0, y - 82.0, 390.0, 164.0)


class BossTitan:
	var tex: Texture2D
	var flash_tex: Texture2D
	var width: float = 920.0
	var height: float = 400.0
	var x: float = GameConfig.SCREEN_WIDTH + 520.0
	var y: float = GameConfig.SCREEN_HEIGHT * 0.5
	var target_x: float = 1555.0
	var hp: int = 6000
	var max_hp: int = 6000
	var score_value: int = 50000
	var time: float = 0.0
	var strafe_time: float = 0.0
	var vy: float = 0.0
	var hit_flash: float = 0.0
	var entering: bool = true
	var attack_timer: float = 1.5
	var attack_pattern: int = 0
	var salvo_remaining: int = 0
	var salvo_timer: float = 0.0
	var salvo_angle: float = PI

	# Half-health Emergency Shield & Phase 2 (+40% fire rate + targeted high-speed charge lasers)
	var phase2_triggered: bool = false
	var enraged: bool = false
	var emergency_shield_duration: float = 5.0
	var emergency_shield_timer: float = 0.0
	var shield_hit_flash: float = 0.0
	var shield_hit_angle: float = PI
	var charging_lasers: Array = []
	var overload_shot_timer: float = 0.0
	var overload_shots_remaining: int = 0
	var targeted_laser_timer: float = 1.85
	var laser_hardpoint_idx: int = 0

	func _init(sprite_data: Dictionary) -> void:
		tex = sprite_data.get("boss", null)
		flash_tex = sprite_data.get("boss_flash", null)

	func is_shielded() -> bool:
		return emergency_shield_timer > 0.0

	func get_shield_center() -> Vector2:
		return Vector2(x - 92.0, y + 6.0)

	func get_shield_radii() -> Vector2:
		return Vector2(408.0, 166.0)

	func intersects_shield(rect: Rect2) -> bool:
		var sc: Vector2 = get_shield_center()
		var sr: Vector2 = get_shield_radii()
		if not Rect2(sc.x - sr.x, sc.y - sr.y, sr.x * 2.0, sr.y * 2.0).intersects(rect):
			return false
		var rc: Vector2 = rect.get_center()
		var nx: float = (rc.x - sc.x) / (sr.x + rect.size.x * 0.5)
		var ny: float = (rc.y - sc.y) / (sr.y + rect.size.y * 0.5)
		return (nx * nx + ny * ny) <= 1.04

	func register_shield_hit(hit_pt: Vector2) -> void:
		var sc: Vector2 = get_shield_center()
		shield_hit_flash = 0.24
		shield_hit_angle = atan2(hit_pt.y - sc.y, hit_pt.x - sc.x)

	func activate_emergency_shield() -> void:
		phase2_triggered = true
		emergency_shield_timer = emergency_shield_duration
		salvo_remaining = 0
		charging_lasers.clear()
		overload_shots_remaining = 7
		overload_shot_timer = 0.16

	func _queue_targeted_laser(player_ref: PlayerShip, charge_dur: float = 1.0, beam_spd: float = 1220.0) -> void:
		var hardpoints: Array[Vector2] = [
			Vector2(-358.0, 12.0),
			Vector2(-236.0, -34.0),
			Vector2(-82.0, 62.0),
			Vector2(-138.0, -56.0),
			Vector2(-46.0, -100.0),
		]
		var hp_off: Vector2 = hardpoints[laser_hardpoint_idx % hardpoints.size()]
		laser_hardpoint_idx += 1
		var tx: float = player_ref.x if player_ref != null else 200.0
		var ty: float = player_ref.y if player_ref != null else y
		var ang: float = atan2(ty - (y + hp_off.y), tx - (x + hp_off.x))
		charging_lasers.append({
			"offset": hp_off,
			"age": 0.0,
			"charge_time": charge_dur,
			"aim_angle": ang,
			"speed": beam_spd,
		})

	func _update_charging_lasers(dt: float, player_ref: PlayerShip, enemy_bullets: Array) -> void:
		for cl in charging_lasers.duplicate():
			var off: Vector2 = cl["offset"]
			if player_ref != null:
				cl["aim_angle"] = atan2(player_ref.y - (y + off.y), player_ref.x - (x + off.x))
			cl["age"] = float(cl["age"]) + dt
			if float(cl["age"]) >= float(cl["charge_time"]):
				var ang: float = float(cl["aim_angle"])
				var spd: float = float(cl["speed"])
				enemy_bullets.append({
					"kind": "targeted_laser",
					"x": x + off.x,
					"y": y + off.y,
					"vx": cos(ang) * spd,
					"vy": sin(ang) * spd,
					"radius": 11.5,
					"color": Color(1.0, 0.16, 0.50),
				})
				SoundManager.play("boss_fire")
				charging_lasers.erase(cl)

	func update(dt: float, player_ref: PlayerShip, enemy_bullets: Array) -> void:
		time += dt
		var prev_y: float = y
		if hit_flash > 0.0:
			hit_flash = maxf(0.0, hit_flash - dt)
		if shield_hit_flash > 0.0:
			shield_hit_flash = maxf(0.0, shield_hit_flash - dt)

		if entering:
			var dist: float = x - target_x
			var step_spd: float = 240.0 if dist > 160.0 else maxf(42.0, dist * 1.8)
			var move_x: float = step_spd * dt
			if dist <= move_x or dist <= 0.5:
				x = target_x
				entering = false
				strafe_time = 0.0
			else:
				x -= move_x
			vy = 0.0
			return

		strafe_time += dt
		var env_t: float = clampf(strafe_time / 1.25, 0.0, 1.0)
		var strafe_env: float = env_t * env_t * (3.0 - 2.0 * env_t)
		y = GameConfig.SCREEN_HEIGHT * 0.5 + sin(strafe_time * 1.0) * 155.0 * strafe_env
		x = target_x + sin(strafe_time * 0.6) * 22.0 * strafe_env
		vy = (y - prev_y) / maxf(dt, 0.001)

		_update_charging_lasers(dt, player_ref, enemy_bullets)

		# Emergency Shield Overload Barrage (invulnerable while unleashing targeted high-speed lasers)
		if emergency_shield_timer > 0.0:
			emergency_shield_timer = maxf(0.0, emergency_shield_timer - dt)
			if overload_shots_remaining > 0:
				overload_shot_timer -= dt
				if overload_shot_timer <= 0.0:
					overload_shot_timer = 0.58
					overload_shots_remaining -= 1
					_queue_targeted_laser(player_ref, 1.0, 1220.0)
			if emergency_shield_timer <= 0.0:
				enraged = true
				attack_timer = 0.22
				targeted_laser_timer = 1.25
			return

		var fire_mult: float = 1.40 if enraged else 1.0

		if salvo_remaining > 0:
			salvo_timer -= dt
			if salvo_timer <= 0.0:
				salvo_timer = 0.055 / fire_mult
				var turret_offsets = [-115.0, -48.0, 42.0, 98.0]
				var y_off = turret_offsets[salvo_remaining % 4]
				salvo_remaining -= 1
				var jitter = deg_to_rad(randf_range(-3.5, 3.5))
				var ang = salvo_angle + jitter
				enemy_bullets.append({
					"x": x - 285.0,
					"y": y + y_off,
					"vx": cos(ang) * 600.0,
					"vy": sin(ang) * 600.0,
					"radius": 8.0,
					"color": GameConfig.COLOR_GOLD
				})
				SoundManager.play("boss_fire")

		attack_timer -= dt
		if attack_timer <= 0.0:
			attack_timer = 1.1 / fire_mult
			var tx = player_ref.x if player_ref != null else 200.0
			var ty = player_ref.y if player_ref != null else y
			var base_ang = atan2(ty - y, tx - (x - 385.0))

			var pat = attack_pattern % 3
			attack_pattern += 1

			if pat == 0:
				SoundManager.play("boss_fire")
				for deg in [-36.0, -24.0, -12.0, 0.0, 12.0, 24.0, 36.0]:
					var ang = base_ang + deg_to_rad(deg)
					enemy_bullets.append({
						"x": x - 395.0,
						"y": y,
						"vx": cos(ang) * 540.0,
						"vy": sin(ang) * 540.0,
						"radius": 9.0,
						"color": GameConfig.COLOR_RED
					})
			elif pat == 1:
				salvo_remaining = 6
				salvo_timer = 0.0
				salvo_angle = base_ang
			else:
				SoundManager.play("boss_fire")
				var count: int = 14
				for i in range(count):
					var ang = (TAU * float(i) / float(count)) + time * 0.4
					enemy_bullets.append({
						"x": x - 160.0,
						"y": y,
						"vx": cos(ang) * 480.0,
						"vy": sin(ang) * 480.0,
						"radius": 8.0,
						"color": GameConfig.COLOR_MAGENTA
					})

		if enraged:
			targeted_laser_timer -= dt
			if targeted_laser_timer <= 0.0:
				targeted_laser_timer = 2.65 / fire_mult
				_queue_targeted_laser(player_ref, 1.0, 1220.0)

	func get_hitbox() -> Rect2:
		return Rect2(x - 412.0, y - 110.0, 662.0, 226.0)

	func get_hitboxes() -> Array[Rect2]:
		return [
			Rect2(x - 412.0, y + 60.0, 30.0, 38.0),    # 1. Lower shark-prow beak tip
			Rect2(x - 386.0, y + 30.0, 30.0, 70.0),    # 2. Lower sloped prow
			Rect2(x - 360.0, y + 4.0, 36.0, 98.0),     # 3. Upper prow & orange visor
			Rect2(x - 328.0, y - 14.0, 64.0, 118.0),   # 4. Curved bridge roof
			Rect2(x - 268.0, y - 20.0, 90.0, 136.0),   # 5. Forward deck & ventral vents
			Rect2(x - 182.0, y - 42.0, 54.0, 158.0),   # 6. Forward Turret 1 dome
			Rect2(x - 132.0, y - 46.0, 60.0, 160.0),   # 7. Midship deck
			Rect2(x - 76.0, y - 68.0, 72.0, 182.0),    # 8. Midship Turret 2 dome
			Rect2(x - 8.0, y - 88.0, 34.0, 202.0),     # 9. Command tower neck
			Rect2(x + 22.0, y - 110.0, 70.0, 224.0),   # 10. Top Turret 3 dome peak
			Rect2(x + 88.0, y - 62.0, 72.0, 178.0),    # 11. Aft saddle behind Turret 3
			Rect2(x + 156.0, y - 84.0, 70.0, 200.0),   # 12. Swept dorsal tail fins & engine pod
			Rect2(x + 222.0, y - 44.0, 28.0, 132.0),   # 13. Rear engine bell cluster
		]

	func find_hit_zone(rect: Rect2) -> Rect2:
		if not get_hitbox().intersects(rect):
			return Rect2()
		for zone in get_hitboxes():
			if zone.intersects(rect):
				return zone
		return Rect2()

	func intersects_rect(rect: Rect2) -> bool:
		return find_hit_zone(rect).size.x > 0.0


class AsteroidHazard:
	var size_type: String = "large"
	var is_large: bool = true
	var x: float = 2010.0
	var y: float = 540.0
	var vx: float = -210.0
	var vy: float = 0.0
	var radius: float = 48.0
	var draw_size: float = 144.0
	var hp: int = 180
	var max_hp: int = 180
	var score_value: int = 0
	var hit_flash: float = 0.0
	var variant_index: int = 0
	var spin_axis: Vector3 = Vector3(0.32, 0.84, 0.44)
	var spin_angle: float = 0.0
	var spin_speed: float = 1.05
	var wobble_angle: float = 0.0
	var wobble_speed: float = 1.75
	var vp_3d: SubViewport = null

	func _init(
		p_size_type: String,
		start_x: float,
		start_y: float,
		vel_x: float,
		vel_y: float,
		p_variant: int = -1
	) -> void:
		size_type = p_size_type
		is_large = p_size_type == "large"
		x = start_x
		y = start_y
		vx = vel_x
		vy = vel_y
		variant_index = (randi() % 4) if p_variant < 0 else (p_variant % 4)
		if is_large:
			radius = 48.0
			draw_size = 144.0
			max_hp = 180
			hp = max_hp
			score_value = 0
			spin_speed = randf_range(0.55, 1.05) * (-1.0 if randf() < 0.5 else 1.0)
			wobble_speed = randf_range(0.90, 1.55)
		else:
			radius = 26.0
			draw_size = 86.0
			max_hp = 45
			hp = max_hp
			score_value = 100
			spin_speed = randf_range(1.35, 2.35) * (-1.0 if randf() < 0.5 else 1.0)
			wobble_speed = randf_range(1.65, 2.55)
		spin_angle = randf_range(0.0, TAU)
		wobble_angle = randf_range(0.0, TAU)
		var ax := Vector3(
			randf_range(-0.85, 0.85),
			randf_range(-1.0, 1.0),
			randf_range(-0.75, 0.75)
		)
		spin_axis = ax.normalized() if ax.length_squared() > 0.02 else Vector3(0.28, 0.92, 0.26).normalized()

	func update(dt: float) -> void:
		x += vx * dt
		y += vy * dt
		if y < 86.0 and vy < 0.0:
			y = 86.0
			vy = absf(vy) * 0.78
		elif y > GameConfig.SCREEN_HEIGHT - 86.0 and vy > 0.0:
			y = GameConfig.SCREEN_HEIGHT - 86.0
			vy = -absf(vy) * 0.78
		spin_angle = fmod(spin_angle + spin_speed * dt, TAU)
		wobble_angle = fmod(wobble_angle + wobble_speed * dt, TAU)
		if hit_flash > 0.0:
			hit_flash = maxf(0.0, hit_flash - dt)

	func intersects_rect(rect: Rect2) -> bool:
		var cx: float = clampf(x, rect.position.x, rect.end.x)
		var cy: float = clampf(y, rect.position.y, rect.end.y)
		var dx: float = x - cx
		var dy: float = y - cy
		return (dx * dx + dy * dy) <= (radius * radius)


var player_frames: Dictionary = {}
var player_flash_frames: Dictionary = {}
var enemy_sprites: Dictionary = {}
var stars: Array = []

# Tunable GPU Shader Backdrop properties
@export var backdrop_scroll_speed: float = 0.08
@export var backdrop_star_density: float = 1.0
@export var backdrop_nebula_intensity: float = 0.72
@export var backdrop_bg_color: Color = Color(0.02, 0.024, 0.07, 1.0)
@export var backdrop_nebula_primary: Color = Color(0.34, 0.06, 0.50, 1.0)
@export var backdrop_nebula_secondary: Color = Color(0.03, 0.30, 0.48, 1.0)
@export var backdrop_star_near: Color = Color(0.90, 0.96, 1.0, 1.0)
@export var backdrop_star_far: Color = Color(0.55, 0.68, 0.96, 1.0)

var backdrop_rect: ColorRect = null
var backdrop_material: ShaderMaterial = null
var backdrop_scroll_offset: float = 0.0
var current_sun_uv: Vector2 = Vector2(0.78, 0.20)
var player_3d: SubViewport = null
var scout_3d: SubViewport = null
var raider_3d_neutral: SubViewport = null
var raider_3d_left: SubViewport = null
var raider_3d_right: SubViewport = null
var scout_3d_pool: Array[SubViewport] = []
var raider_3d_pool: Array[SubViewport] = []
var dreadnought_3d: SubViewport = null
var boss_3d: SubViewport = null
var asteroid_large_3d_pool: Array[SubViewport] = []
var asteroid_small_3d_pool: Array[SubViewport] = []

var player: PlayerShip = null
var score: int = 0
var level_time: float = 0.0
var current_phase: int = 1
var phase_banner_timer: float = 3.0
var phase_banner_text: String = "PHASE 1: OUTER RIM PATROL"

var player_bullets: Array = []
var homing_missiles: Array = []
var enemy_bullets: Array = []
var enemies: Array = []
var asteroids: Array = []
var asteroid_spawn_timer: float = 2.4
var dreadnought: DreadnoughtShip = null
var dreadnought_spawned: bool = false
var boss: BossTitan = null
var boss_spawned: bool = false
var boss_warning_timer: float = 0.0
var overload_warning_timer: float = 0.0
var overload_warning_text: String = "DANGER! ENEMY SHIP ENERGY OVERLOAD DETECTED"

var boss_dying: bool = false
var boss_death_timer: float = 0.0
var boss_explosion_tick: float = 0.0
var boss_death_pos: Vector2 = Vector2(1555.0, 540.0)

var particles: Array = []
var laser_impacts: Array = []
var missile_blasts: Array = []
var score_popups: Array = []
var shield_collapse_waves: Array = []
var hud_shield_flash_timer: float = 0.0
var hud_shield_lost_seg: int = -1
var screen_shake: float = 0.0
var spawn_timer: float = 1.0

var paused: bool = false
var pause_index: int = 0
var pause_options: Array[String] = ["RESUME MISSION", "RESTART MISSION", "RETURN TO MAIN MENU"]
var pause_rects: Array[Rect2] = []

var game_over: bool = false
var victory: bool = false
var end_sequence_timer: float = 0.0
var victory_SubPhase: String = "NONE"
var victory_start_pos: Vector2 = Vector2(200.0, 540.0)

var entering_name: bool = false
var pilot_name: String = ""
var score_saved: bool = false
var end_menu_index: int = 0
var end_menu_rects: Array[Rect2] = []
var end_menu_guard_timer: float = 0.0

var kb_row: int = 0
var kb_col: int = 0
var kb_nav_cooldown: float = 0.0
var kb_key_rects: Array = []
var kb_confirm_rect: Rect2 = Rect2(0, 0, 0, 0)


func _ready() -> void:
	var p_data = GameConfig.get_player_frames(Vector2i(132, 95))
	player_frames = p_data["frames"]
	player_flash_frames = p_data["flash_frames"]

	var scout_data = GameConfig.get_scout_frames(Vector2i(96, 68))
	var raider_data = GameConfig.get_raider_frames(Vector2i(144, 96))
	var raider_tex = GameConfig.get_scaled_texture("enemy_raider", Vector2i(144, 96))
	var dread_tex = GameConfig.get_scaled_texture("enemy_dreadnought", Vector2i(480, 228))
	var boss_tex = GameConfig.get_scaled_texture("boss_titan", Vector2i(920, 400))

	enemy_sprites = {
		"scout_frames": scout_data["frames"],
		"scout_flash_frames": scout_data["flash_frames"],
		"raider_frames": raider_data["frames"],
		"raider_flash_frames": raider_data["flash_frames"],
		"raider": raider_tex,
		"raider_flash": ImageTexture.create_from_image(GameConfig._make_flash_image(raider_tex.get_image())) if raider_tex else null,
		"dreadnought": dread_tex,
		"dreadnought_flash": ImageTexture.create_from_image(GameConfig._make_flash_image(dread_tex.get_image())) if dread_tex else null,
		"boss": boss_tex,
		"boss_flash": ImageTexture.create_from_image(GameConfig._make_flash_image(boss_tex.get_image())) if boss_tex else null,
	}

	var rng = RandomNumberGenerator.new()
	rng.seed = 777777
	for layer in range(3):
		var spd = [45.0, 115.0, 240.0][layer]
		var sz = [1.0, 2.0, 3.0][layer]
		var col = [Color8(90, 100, 150), Color8(150, 180, 230), Color8(220, 240, 255)][layer]
		var count = [50, 35, 18][layer]
		for i in range(count):
			stars.append({
				"x": rng.randf_range(0.0, GameConfig.SCREEN_WIDTH),
				"y": rng.randf_range(0.0, GameConfig.SCREEN_HEIGHT),
				"speed": spd * rng.randf_range(0.85, 1.2),
				"size": sz,
				"color": col
			})

	_setup_shader_backdrop()
	_setup_player_3d()
	_setup_enemy_3d()
	_setup_asteroid_3d()


func _setup_player_3d() -> void:
	if PlayerShip3DScript == null:
		return
	player_3d = PlayerShip3DScript.new(Vector2i(230, 130))
	player_3d.name = "PlayerShip3DViewport"
	add_child(player_3d)


func _setup_enemy_3d() -> void:
	if EnemyShip3DScript == null:
		return
	scout_3d_pool.clear()
	for i in range(6):
		var svp: SubViewport = EnemyShip3DScript.new("scout", Vector2i(136, 100))
		svp.name = "Scout3DViewport" if i == 0 else ("Scout3DViewport_%d" % i)
		add_child(svp)
		scout_3d_pool.append(svp)
	scout_3d = scout_3d_pool[0]

	raider_3d_pool.clear()
	for i in range(6):
		var rvp: SubViewport = EnemyShip3DScript.new("raider", Vector2i(172, 118))
		rvp.name = "Raider3DNeutralViewport" if i == 0 else ("Raider3DViewport_%d" % i)
		add_child(rvp)
		raider_3d_pool.append(rvp)
	raider_3d_neutral = raider_3d_pool[0]
	raider_3d_left = raider_3d_pool[1]
	raider_3d_right = raider_3d_pool[2]

	dreadnought_3d = EnemyShip3DScript.new("dreadnought", Vector2i(520, 250))
	dreadnought_3d.name = "Dreadnought3DViewport"
	add_child(dreadnought_3d)

	boss_3d = EnemyShip3DScript.new("boss_titan", Vector2i(960, 420))
	boss_3d.name = "BossTitan3DViewport"
	add_child(boss_3d)


func _setup_asteroid_3d() -> void:
	if Asteroid3DScript == null:
		return
	asteroid_large_3d_pool.clear()
	for i in range(4):
		var lvp: SubViewport = Asteroid3DScript.new(true, i % 4, Vector2i(144, 144))
		lvp.name = "AsteroidLarge3DViewport_%d" % i
		add_child(lvp)
		asteroid_large_3d_pool.append(lvp)

	asteroid_small_3d_pool.clear()
	for i in range(8):
		var svp: SubViewport = Asteroid3DScript.new(false, i % 4, Vector2i(86, 86))
		svp.name = "AsteroidSmall3DViewport_%d" % i
		add_child(svp)
		asteroid_small_3d_pool.append(svp)


func _acquire_asteroid_vp(is_large: bool, variant_idx: int, used_vps: Dictionary) -> SubViewport:
	if Asteroid3DScript == null:
		return null
	var pool: Array[SubViewport] = asteroid_large_3d_pool if is_large else asteroid_small_3d_pool
	var v_mod: int = variant_idx % 4
	for vp in pool:
		if vp != null and not used_vps.has(vp) and int(vp.variant_index) == v_mod:
			used_vps[vp] = true
			return vp
	for vp in pool:
		if vp != null and not used_vps.has(vp):
			used_vps[vp] = true
			return vp
	var vp_size := Vector2i(144, 144) if is_large else Vector2i(86, 86)
	var extra_vp: SubViewport = Asteroid3DScript.new(is_large, v_mod, vp_size)
	extra_vp.name = "Asteroid%s3DViewport_%d" % ["Large" if is_large else "Small", pool.size()]
	add_child(extra_vp)
	pool.append(extra_vp)
	used_vps[extra_vp] = true
	return extra_vp


func _acquire_enemy_vp(enemy_type: String, used_vps: Dictionary) -> SubViewport:
	if EnemyShip3DScript == null:
		return null
	var pool: Array[SubViewport] = scout_3d_pool if enemy_type == "scout" else raider_3d_pool
	for vp in pool:
		if vp != null and not used_vps.has(vp):
			used_vps[vp] = true
			return vp
	var vp_size := Vector2i(136, 100) if enemy_type == "scout" else Vector2i(172, 118)
	var extra_vp: SubViewport = EnemyShip3DScript.new(enemy_type, vp_size)
	extra_vp.name = "%s3DViewport_%d" % [enemy_type.capitalize(), pool.size()]
	add_child(extra_vp)
	pool.append(extra_vp)
	used_vps[extra_vp] = true
	return extra_vp


func _setup_shader_backdrop() -> void:
	if SpaceBackdropShader == null:
		return
	backdrop_material = ShaderMaterial.new()
	backdrop_material.shader = SpaceBackdropShader
	backdrop_rect = ColorRect.new()
	backdrop_rect.name = "SpaceBackdrop"
	backdrop_rect.position = Vector2(-40.0, -40.0)
	backdrop_rect.size = Vector2(GameConfig.SCREEN_WIDTH + 80.0, GameConfig.SCREEN_HEIGHT + 80.0)
	backdrop_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop_rect.show_behind_parent = true
	backdrop_rect.material = backdrop_material
	add_child(backdrop_rect)
	sync_backdrop_uniforms()


func sync_backdrop_uniforms() -> void:
	if backdrop_material == null:
		return
	backdrop_material.set_shader_parameter("scroll_speed", backdrop_scroll_speed)
	backdrop_material.set_shader_parameter("scroll_offset", backdrop_scroll_offset)
	backdrop_material.set_shader_parameter("star_density", backdrop_star_density)
	backdrop_material.set_shader_parameter("nebula_intensity", backdrop_nebula_intensity)
	backdrop_material.set_shader_parameter("bg_deep_color", backdrop_bg_color)
	backdrop_material.set_shader_parameter("nebula_tint_primary", backdrop_nebula_primary)
	backdrop_material.set_shader_parameter("nebula_tint_secondary", backdrop_nebula_secondary)
	backdrop_material.set_shader_parameter("star_tint_near", backdrop_star_near)
	backdrop_material.set_shader_parameter("star_tint_far", backdrop_star_far)
	backdrop_material.set_shader_parameter("enable_sun", 1)
	backdrop_material.set_shader_parameter("sun_uv", current_sun_uv)
	backdrop_material.set_shader_parameter("sun_radius", 0.028)
	backdrop_material.set_shader_parameter("sun_core_color", Color(0.96, 0.99, 1.0, 1.0))
	backdrop_material.set_shader_parameter("sun_corona_color", Color(0.32, 0.78, 1.0, 1.0))
	backdrop_material.set_shader_parameter("sun_scatter_color", Color(0.14, 0.48, 0.92, 1.0))
	backdrop_material.set_shader_parameter("sun_intensity", 1.05)


func enter(_params: Dictionary = {}) -> void:
	reset_game()


func reset_game() -> void:
	SoundManager.play_music("A286_nebula.wav", true, 0.50, true)
	player = PlayerShip.new(player_frames, player_flash_frames)
	score = 0
	level_time = 0.0
	current_sun_uv = Vector2(0.79, 0.20)
	if backdrop_material != null:
		backdrop_material.set_shader_parameter("sun_uv", current_sun_uv)
	current_phase = 1
	phase_banner_timer = 3.0
	phase_banner_text = "PHASE 1: OUTER RIM PATROL"

	player_bullets.clear()
	homing_missiles.clear()
	enemy_bullets.clear()
	enemies.clear()
	asteroids.clear()
	asteroid_spawn_timer = 2.4
	dreadnought = null
	dreadnought_spawned = false
	boss = null
	boss_spawned = false
	boss_warning_timer = 0.0
	overload_warning_timer = 0.0
	overload_warning_text = "DANGER! ENEMY SHIP ENERGY OVERLOAD DETECTED"

	boss_dying = false
	boss_death_timer = 0.0
	boss_explosion_tick = 0.0
	boss_death_pos = Vector2(1555.0, 540.0)

	particles.clear()
	laser_impacts.clear()
	missile_blasts.clear()
	score_popups.clear()
	shield_collapse_waves.clear()
	hud_shield_flash_timer = 0.0
	hud_shield_lost_seg = -1
	screen_shake = 0.0
	spawn_timer = 1.0
	if dreadnought_3d != null:
		dreadnought_3d.reset_pose_for_spawn(0.0)
	if boss_3d != null:
		boss_3d.reset_pose_for_spawn(0.0)

	paused = false
	pause_index = 0
	pause_rects.clear()

	game_over = false
	victory = false
	end_sequence_timer = 0.0
	victory_SubPhase = "NONE"
	victory_start_pos = Vector2(200.0, 540.0)

	entering_name = false
	pilot_name = ""
	score_saved = false
	end_menu_index = 0
	end_menu_rects.clear()
	end_menu_guard_timer = 0.0

	kb_row = 0
	kb_col = 0
	kb_nav_cooldown = 0.0
	kb_key_rects.clear()
	kb_confirm_rect = Rect2(0, 0, 0, 0)


func _confirm_pilot_score() -> void:
	var final_name = pilot_name.strip_edges()
	if final_name.is_empty():
		final_name = "PILOT"
	HighScoreManager.add_score(final_name, score)
	entering_name = false
	score_saved = true
	end_menu_guard_timer = 0.35
	SoundManager.play("menu_confirm")


func _activate_selected_grid_key() -> void:
	if kb_row == 4:
		_confirm_pilot_score()
		return
	var key_val = ALPHA_GRID[kb_row][kb_col]
	if key_val == "DEL":
		if pilot_name.length() > 0:
			pilot_name = pilot_name.substr(0, pilot_name.length() - 1)
			SoundManager.play("menu_back")
	elif key_val == "SPC":
		if pilot_name.length() < 10:
			pilot_name += " "
			SoundManager.play("menu_move")
	else:
		if pilot_name.length() < 10:
			pilot_name += key_val
			SoundManager.play("menu_move")


func state_input(event: InputEvent) -> void:
	if game_over or victory:
		if entering_name:
			if event is InputEventKey and event.pressed and not event.echo:
				if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
					_confirm_pilot_score()
				elif event.keycode == KEY_BACKSPACE:
					if pilot_name.length() > 0:
						pilot_name = pilot_name.substr(0, pilot_name.length() - 1)
						SoundManager.play("menu_back")
				else:
					var u = event.unicode
					if u >= 32 and u <= 126:
						var ch = String.chr(u).to_upper()
						if "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_".contains(ch) and pilot_name.length() < 10:
							pilot_name += ch
							SoundManager.play("menu_move")
			elif event is InputEventMouseMotion:
				for item in kb_key_rects:
					if item["rect"].has_point(event.position):
						kb_row = item["r"]
						kb_col = item["c"]
				if kb_confirm_rect.has_point(event.position):
					kb_row = 4
			elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				for item in kb_key_rects:
					if item["rect"].has_point(event.position):
						kb_row = item["r"]
						kb_col = item["c"]
						_activate_selected_grid_key()
						return
				if kb_confirm_rect.has_point(event.position):
					kb_row = 4
					_confirm_pilot_score()
		elif score_saved and end_menu_guard_timer <= 0.0:
			if event is InputEventMouseMotion:
				for idx in range(end_menu_rects.size()):
					if end_menu_rects[idx].has_point(event.position):
						end_menu_index = idx
			elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				for idx in range(end_menu_rects.size()):
					if end_menu_rects[idx].has_point(event.position):
						end_menu_index = idx
						_trigger_end_option()
		return

	if paused:
		if event is InputEventMouseMotion:
			for idx in range(pause_rects.size()):
				if pause_rects[idx].has_point(event.position):
					pause_index = idx
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for idx in range(pause_rects.size()):
				if pause_rects[idx].has_point(event.position):
					pause_index = idx
					_trigger_pause_option()


func _trigger_pause_option() -> void:
	SoundManager.play("menu_confirm")
	if pause_index == 0:
		paused = false
		SoundManager.resume_music()
	elif pause_index == 1:
		reset_game()
	elif pause_index == 2:
		main_app.set_state("MENU")


func _trigger_end_option() -> void:
	SoundManager.play("menu_confirm")
	if end_menu_index == 0:
		reset_game()
	else:
		main_app.set_state("MENU")


func _spawn_explosion(x: float, y: float, count: int = 24, base_color: Color = GameConfig.COLOR_GOLD) -> void:
	var cols = [base_color, GameConfig.COLOR_WHITE, GameConfig.COLOR_MAGENTA, GameConfig.COLOR_CYAN]
	for i in range(count):
		var ang = randf_range(0.0, TAU)
		var spd = randf_range(60.0, 380.0)
		var lt = randf_range(0.25, 0.7)
		particles.append({
			"x": x,
			"y": y,
			"vx": cos(ang) * spd,
			"vy": sin(ang) * spd,
			"life": lt,
			"max_life": lt,
			"size": float([3, 4, 5, 7][randi_range(0, 3)]),
			"color": cols[randi_range(0, cols.size() - 1)]
		})


func _spawn_laser_impact(ix: float, iy: float) -> void:
	laser_impacts.append({
		"x": ix,
		"y": iy,
		"age": 0.0,
		"max_age": 0.12,
	})
	var spark_cols = [GameConfig.COLOR_WHITE, GameConfig.COLOR_CYAN, Color(0.28, 0.72, 1.0, 1.0)]
	for _i in range(7):
		var ang = PI + randf_range(-1.15, 1.15)
		var spd = randf_range(140.0, 440.0)
		var lt = randf_range(0.10, 0.24)
		particles.append({
			"x": ix,
			"y": iy,
			"vx": cos(ang) * spd,
			"vy": sin(ang) * spd,
			"life": lt,
			"max_life": lt,
			"size": float([2, 3, 4][randi_range(0, 2)]),
			"color": spark_cols[randi_range(0, spark_cols.size() - 1)]
		})


func _spawn_score_popup(px: float, py: float, points: int, style: String = "standard") -> void:
	if points <= 0:
		return
	var y_nudge: float = -42.0 if style in ["capital", "boss"] else -22.0
	var sx: float = clampf(px, 110.0, GameConfig.SCREEN_WIDTH - 110.0)
	var sy: float = clampf(py + y_nudge, 118.0, GameConfig.SCREEN_HEIGHT - 64.0)
	for existing in score_popups:
		if float(existing["age"]) < 0.28 and absf(float(existing["x"]) - sx) < 78.0 and absf(float(existing["y"]) - sy) < 28.0:
			sy = maxf(112.0, sy - 28.0)

	var max_age: float = 0.95
	var init_vy: float = -88.0
	if style == "capital":
		max_age = 1.35
		init_vy = -72.0
	elif style == "boss":
		max_age = 1.85
		init_vy = -64.0

	score_popups.append({
		"x": sx,
		"y": sy,
		"vy": init_vy,
		"text": "+" + GameConfig.format_commas(points),
		"points": points,
		"age": 0.0,
		"max_age": max_age,
		"style": style,
	})


func _spawn_shield_sparks(cx: float, cy: float, hit_ang: float, is_critical: bool) -> void:
	var hit_dir := Vector2(cos(hit_ang), sin(hit_ang))
	var tang := Vector2(-hit_dir.y * 86.0, hit_dir.x * 50.0).normalized()
	var origin := Vector2(cx + hit_dir.x * 78.0, cy + hit_dir.y * 46.0)
	var cols: Array = (
		[GameConfig.COLOR_CYAN, GameConfig.COLOR_WHITE, Color(0.28, 0.68, 1.0, 1.0)]
		if not is_critical
		else [GameConfig.COLOR_RED, Color(1.0, 0.36, 0.16, 1.0), Color(1.0, 0.88, 0.84, 1.0)]
	)
	for i in range(18):
		var sgn: float = -1.0 if i % 2 == 0 else 1.0
		var spread_v: Vector2 = (tang * sgn * randf_range(0.55, 1.25) + hit_dir * randf_range(-0.15, 0.65)).normalized()
		var spd: float = randf_range(120.0, 390.0)
		var lt: float = randf_range(0.18, 0.42)
		particles.append({
			"x": origin.x + randf_range(-6.0, 6.0),
			"y": origin.y + randf_range(-6.0, 6.0),
			"vx": spread_v.x * spd,
			"vy": spread_v.y * spd,
			"life": lt,
			"max_life": lt,
			"size": float([2, 3, 4, 5][randi_range(0, 3)]),
			"color": cols[randi_range(0, cols.size() - 1)]
		})


func _spawn_dodge_ready_sparks(px: float, py: float) -> void:
	var nozzle_x: float = px - 56.0
	var spark_cols: Array = [GameConfig.COLOR_CYAN, GameConfig.COLOR_WHITE, Color(0.24, 0.76, 1.0, 1.0)]
	for i in range(8):
		var y_off: float = -7.0 if i % 2 == 0 else 7.0
		var ang: float = PI + randf_range(-0.62, 0.62)
		var spd: float = randf_range(120.0, 290.0)
		var lt: float = randf_range(0.12, 0.24)
		particles.append({
			"x": nozzle_x,
			"y": py + y_off,
			"vx": cos(ang) * spd,
			"vy": sin(ang) * spd,
			"life": lt,
			"max_life": lt,
			"size": float([2, 3, 4][randi_range(0, 2)]),
			"color": spark_cols[randi_range(0, spark_cols.size() - 1)]
		})


func _spawn_dreadnought_fleet() -> void:
	dreadnought_spawned = true
	dreadnought = DreadnoughtShip.new(enemy_sprites)
	if dreadnought_3d != null:
		dreadnought_3d.reset_pose_for_spawn(0.0)
	var mid_y = GameConfig.SCREEN_HEIGHT * 0.5
	for i in range(2):
		var y_off = -190.0 if i == 0 else 190.0
		enemies.append(EnemyShip.new(
			"scout",
			GameConfig.SCREEN_WIDTH + 90.0,
			mid_y + y_off,
			enemy_sprites,
			1.30,
			1.70,
			0.35 + i * 0.25,
			"spread"
		))
	for i in range(2):
		var y_off = -260.0 if i == 0 else 260.0
		enemies.append(EnemyShip.new(
			"raider",
			GameConfig.SCREEN_WIDTH + 160.0,
			mid_y + y_off,
			enemy_sprites,
			1.30,
			1.70,
			0.90 + i * 0.30
		))


func _spawn_phase_formation() -> float:
	if current_phase == 1:
		var hp_mult: float = 1.0
		var speed_mult: float = 1.0
		if level_time < 20.0:
			var count = randi_range(2, 3)
			var base_y = randf_range(220.0, GameConfig.SCREEN_HEIGHT - 220.0)
			for i in range(count):
				var y_pos = clampf(base_y + (i - 1) * 110.0, 140.0, GameConfig.SCREEN_HEIGHT - 120.0)
				enemies.append(EnemyShip.new(
					"scout",
					GameConfig.SCREEN_WIDTH + 80.0,
					y_pos,
					enemy_sprites,
					speed_mult,
					hp_mult,
					i * 0.38,
					"spread"
				))
			return 2.3
		else:
			if randf() < 0.65:
				var count = randi_range(2, 3)
				var base_y = randf_range(200.0, GameConfig.SCREEN_HEIGHT - 200.0)
				for i in range(count):
					var y_pos = clampf(base_y + (i - 1) * 90.0, 140.0, GameConfig.SCREEN_HEIGHT - 120.0)
					enemies.append(EnemyShip.new(
						"raider",
						GameConfig.SCREEN_WIDTH + 80.0,
						y_pos,
						enemy_sprites,
						speed_mult,
						hp_mult,
						i * 0.35
					))
			else:
				var count = randi_range(2, 3)
				for i in range(count):
					var y_pos = randf_range(160.0, GameConfig.SCREEN_HEIGHT - 140.0)
					enemies.append(EnemyShip.new(
						"scout",
						GameConfig.SCREEN_WIDTH + 80.0,
						y_pos,
						enemy_sprites,
						speed_mult,
						hp_mult,
						i * 0.35,
						"spread"
					))
			return 2.1
	elif current_phase == 2:
		var hp_mult: float = 1.35
		var speed_mult: float = 1.15
		var count = randi_range(3, 4)
		var base_y = randf_range(220.0, GameConfig.SCREEN_HEIGHT - 220.0)
		for i in range(count):
			var etype = "scout" if randf() < 0.5 else "raider"
			var y_pos = clampf(base_y + (i - 1.5) * 95.0, 140.0, GameConfig.SCREEN_HEIGHT - 120.0)
			enemies.append(EnemyShip.new(
				etype,
				GameConfig.SCREEN_WIDTH + 80.0,
				y_pos,
				enemy_sprites,
				speed_mult,
				hp_mult,
				i * 0.32,
				"spread"
			))
		return 1.85
	elif current_phase == 3:
		var hp_mult: float = 1.70
		var speed_mult: float = 1.30
		if level_time >= 72.0 and not dreadnought_spawned:
			_spawn_dreadnought_fleet()
			return 2.8

		var count = randi_range(3, 5) if dreadnought == null else randi_range(2, 3)
		for i in range(count):
			var etype = "scout" if randf() < 0.5 else "raider"
			var y_pos = randf_range(140.0, GameConfig.SCREEN_HEIGHT - 120.0)
			enemies.append(EnemyShip.new(
				etype,
				GameConfig.SCREEN_WIDTH + 80.0,
				y_pos,
				enemy_sprites,
				speed_mult,
				hp_mult,
				i * 0.28,
				"spread"
			))
		return 1.75 if dreadnought == null else 2.6
	return 2.0


func _spawn_asteroid_debris(cx: float, cy: float, count: int, with_amber_core: bool = true) -> void:
	var rock_cols: Array = [
		Color(0.46, 0.44, 0.54, 1.0),
		Color(0.62, 0.52, 0.44, 1.0),
		Color(0.30, 0.29, 0.38, 1.0),
		Color(0.74, 0.78, 0.88, 1.0),
	]
	if with_amber_core:
		rock_cols.append(GameConfig.COLOR_GOLD)
		rock_cols.append(GameConfig.COLOR_CYAN)
	for _i in range(count):
		var ang: float = randf_range(0.0, TAU)
		var spd: float = randf_range(55.0, 290.0)
		var lt: float = randf_range(0.22, 0.56)
		particles.append({
			"x": cx + randf_range(-10.0, 10.0),
			"y": cy + randf_range(-10.0, 10.0),
			"vx": cos(ang) * spd - 55.0,
			"vy": sin(ang) * spd,
			"life": lt,
			"max_life": lt,
			"size": float([3, 4, 5, 6][randi_range(0, 3)]),
			"color": rock_cols[randi_range(0, rock_cols.size() - 1)]
		})


func _spawn_asteroid_wave() -> float:
	if current_phase >= 4:
		return 99.0
	if asteroids.size() >= 8:
		return 1.8

	var spawn_x: float = GameConfig.SCREEN_WIDTH + 92.0
	var y_main: float = randf_range(145.0, GameConfig.SCREEN_HEIGHT - 145.0)
	var drift_vy: float = randf_range(-34.0, 34.0)

	if current_phase == 1:
		if randf() < 0.72:
			asteroids.append(AsteroidHazard.new("large", spawn_x, y_main, randf_range(-210.0, -170.0), drift_vy))
		else:
			asteroids.append(AsteroidHazard.new("small", spawn_x, y_main, randf_range(-255.0, -205.0), drift_vy * 1.2))
		return randf_range(4.8, 6.2)
	elif current_phase == 2:
		var roll: float = randf()
		if roll < 0.48:
			asteroids.append(AsteroidHazard.new("large", spawn_x, y_main, randf_range(-235.0, -185.0), drift_vy))
		elif roll < 0.80:
			asteroids.append(AsteroidHazard.new("large", spawn_x, y_main, randf_range(-230.0, -185.0), drift_vy))
			var y_escort: float = clampf(y_main + (-150.0 if y_main > 540.0 else 150.0), 130.0, GameConfig.SCREEN_HEIGHT - 130.0)
			asteroids.append(AsteroidHazard.new("small", spawn_x + 125.0, y_escort, randf_range(-265.0, -215.0), -drift_vy))
		else:
			var y_a: float = clampf(y_main - 85.0, 125.0, GameConfig.SCREEN_HEIGHT - 125.0)
			var y_b: float = clampf(y_main + 85.0, 125.0, GameConfig.SCREEN_HEIGHT - 125.0)
			asteroids.append(AsteroidHazard.new("small", spawn_x, y_a, randf_range(-270.0, -220.0), randf_range(-28.0, 18.0)))
			asteroids.append(AsteroidHazard.new("small", spawn_x + 95.0, y_b, randf_range(-270.0, -220.0), randf_range(-18.0, 28.0)))
		return randf_range(3.3, 4.5)
	else:
		if randf() < 0.65:
			asteroids.append(AsteroidHazard.new("large", spawn_x, y_main, randf_range(-245.0, -195.0), drift_vy))
		else:
			asteroids.append(AsteroidHazard.new("small", spawn_x, y_main, randf_range(-280.0, -225.0), drift_vy * 1.25))
		return randf_range(5.2, 6.6) if dreadnought != null else randf_range(4.4, 5.8)


func _damage_asteroid(ast: AsteroidHazard, dmg: int, impact_pt: Vector2, award_points: bool = true) -> void:
	if ast == null or not asteroids.has(ast):
		return
	ast.hp -= dmg
	ast.hit_flash = 0.08
	if ast.hp > 0:
		_spawn_asteroid_debris(impact_pt.x, impact_pt.y, 5, false)
		SoundManager.play("enemy_hit")
		return

	asteroids.erase(ast)
	SoundManager.play("explosion")
	if ast.is_large:
		_spawn_asteroid_debris(ast.x, ast.y, 28, true)
		screen_shake = maxf(screen_shake, 6.5)
		var vx_top: float = clampf(ast.vx * randf_range(1.06, 1.20), -295.0, -195.0)
		var vx_bot: float = clampf(ast.vx * randf_range(1.06, 1.20), -295.0, -195.0)
		var top_y: float = clampf(ast.y - 20.0, 92.0, GameConfig.SCREEN_HEIGHT - 92.0)
		var bot_y: float = clampf(ast.y + 20.0, 92.0, GameConfig.SCREEN_HEIGHT - 92.0)
		var frag_top := AsteroidHazard.new(
			"small",
			ast.x - 6.0,
			top_y,
			vx_top,
			randf_range(-92.0, -54.0),
			(ast.variant_index + 1) % 4
		)
		var frag_bot := AsteroidHazard.new(
			"small",
			ast.x + 6.0,
			bot_y,
			vx_bot,
			randf_range(54.0, 92.0),
			(ast.variant_index + 2) % 4
		)
		asteroids.append(frag_top)
		asteroids.append(frag_bot)
	else:
		_spawn_asteroid_debris(ast.x, ast.y, 18, award_points)
		if award_points and ast.score_value > 0:
			score += ast.score_value
			_spawn_score_popup(ast.x, ast.y, ast.score_value, "standard")


func _clear_asteroids_for_boss_phase() -> void:
	if asteroids.is_empty():
		return
	for ast in asteroids:
		_spawn_asteroid_debris(ast.x, ast.y, 12, false)
	asteroids.clear()


func _find_nearest_target(from_x: float, from_y: float) -> Variant:
	var candidates: Array = []
	for e in enemies:
		if e.active and e.x > from_x - 80.0:
			candidates.append(e)
	if dreadnought != null and not dreadnought.retreating:
		candidates.append(dreadnought)
	if boss != null and not boss_dying:
		candidates.append(boss)
	if candidates.is_empty():
		for ast in asteroids:
			if ast.x > from_x - 40.0:
				candidates.append(ast)

	var best = null
	var best_dist: float = 999999.0
	for c in candidates:
		var d = Vector2(c.x - from_x, c.y - from_y).length()
		if d < best_dist:
			best_dist = d
			best = c
	return best


func _update_end_modals_input(dt: float) -> void:
	if entering_name:
		if kb_nav_cooldown > 0.0:
			kb_nav_cooldown -= dt

		if InputHelper.just_pressed("delete") and kb_nav_cooldown <= 0.0:
			if pilot_name.length() > 0:
				pilot_name = pilot_name.substr(0, pilot_name.length() - 1)
				SoundManager.play("menu_back")
			kb_nav_cooldown = 0.16
			return

		if kb_nav_cooldown <= 0.0:
			if InputHelper.just_pressed("up"):
				kb_row = (kb_row - 1 + 5) % 5
				SoundManager.play("menu_move")
				kb_nav_cooldown = 0.15
			elif InputHelper.just_pressed("down"):
				kb_row = (kb_row + 1) % 5
				SoundManager.play("menu_move")
				kb_nav_cooldown = 0.15
			elif InputHelper.just_pressed("left") and kb_row < 4:
				kb_col = (kb_col - 1 + 7) % 7
				SoundManager.play("menu_move")
				kb_nav_cooldown = 0.14
			elif InputHelper.just_pressed("right") and kb_row < 4:
				kb_col = (kb_col + 1) % 7
				SoundManager.play("menu_move")
				kb_nav_cooldown = 0.14
			elif InputHelper.just_pressed("confirm"):
				_activate_selected_grid_key()
				kb_nav_cooldown = 0.20

	elif score_saved:
		if end_menu_guard_timer > 0.0:
			end_menu_guard_timer -= dt
			return

		if InputHelper.just_pressed("left") or InputHelper.just_pressed("up"):
			end_menu_index = (end_menu_index - 1 + 2) % 2
			SoundManager.play("menu_move")
		elif InputHelper.just_pressed("right") or InputHelper.just_pressed("down"):
			end_menu_index = (end_menu_index + 1) % 2
			SoundManager.play("menu_move")
		elif InputHelper.just_pressed("confirm"):
			_trigger_end_option()


func state_update(dt: float) -> void:
	if InputHelper.just_pressed("pause") and not game_over and not victory and not boss_dying:
		paused = not paused
		SoundManager.play("menu_confirm")
		if paused:
			SoundManager.pause_music()
		else:
			SoundManager.resume_music()
		return

	if paused:
		if InputHelper.just_pressed("up"):
			pause_index = (pause_index - 1 + pause_options.size()) % pause_options.size()
			SoundManager.play("menu_move")
		elif InputHelper.just_pressed("down"):
			pause_index = (pause_index + 1) % pause_options.size()
			SoundManager.play("menu_move")
		elif InputHelper.just_pressed("confirm"):
			_trigger_pause_option()
		return

	# GPU Shader Parallax Starfield, FBM Nebula & Slowly Drifting Sapphire-White Blue Giant
	var star_mult = 2.6 if victory_SubPhase == "BLAST_OFF" else 1.0
	backdrop_scroll_offset += backdrop_scroll_speed * star_mult * dt
	current_sun_uv = Vector2(
		0.79 - clampf(level_time / 145.0, 0.0, 1.0) * 0.06,
		0.20 + sin(level_time * 0.11) * 0.008
	)
	if backdrop_material != null:
		backdrop_material.set_shader_parameter("scroll_offset", backdrop_scroll_offset)
		backdrop_material.set_shader_parameter("sun_uv", current_sun_uv)
	else:
		for s in stars:
			s["x"] -= s["speed"] * star_mult * dt
			if s["x"] < 0.0:
				s["x"] = GameConfig.SCREEN_WIDTH
				s["y"] = randf_range(0.0, GameConfig.SCREEN_HEIGHT)

	# Particles & Laser Impact Flashes
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
		sp["y"] = maxf(104.0, float(sp["y"]) + float(sp["vy"]) * dt)

	for scw in shield_collapse_waves.duplicate():
		scw["age"] += dt
		if scw["age"] >= scw["max_age"]:
			shield_collapse_waves.erase(scw)

	if hud_shield_flash_timer > 0.0:
		hud_shield_flash_timer = maxf(0.0, hud_shield_flash_timer - dt)

	if screen_shake > 0.0:
		screen_shake = maxf(0.0, screen_shake - dt * 25.0)

	# Timeline & Phase Progression (always advances so glow text, strobes & VFX never freeze)
	level_time += dt
	if phase_banner_timer > 0.0:
		phase_banner_timer -= dt
	if boss_warning_timer > 0.0:
		boss_warning_timer -= dt
	if overload_warning_timer > 0.0:
		overload_warning_timer = maxf(0.0, overload_warning_timer - dt)

	if not boss_dying and not victory:
		if level_time >= 30.0 and current_phase == 1:
			current_phase = 2
			phase_banner_text = "PHASE 2: ASTEROID AMBUSH - RAIDERS INBOUND"
			phase_banner_timer = 3.0
			asteroid_spawn_timer = minf(asteroid_spawn_timer, 0.9)
		elif level_time >= 60.0 and current_phase == 2:
			current_phase = 3
			phase_banner_text = "PHASE 3: HEAVY FLEET BLOCKADE"
			phase_banner_timer = 3.0
		elif level_time >= 90.0 and current_phase == 3:
			current_phase = 4
			phase_banner_text = "WARNING: COLOSSAL TITAN DETECTED!"
			phase_banner_timer = 3.5
			boss_warning_timer = 2.8
			overload_warning_timer = 0.0
			_clear_asteroids_for_boss_phase()
			SoundManager.play("boss_warning")
			if dreadnought != null and not dreadnought.retreating:
				dreadnought.trigger_retreat()
	if current_phase >= 4 and not asteroids.is_empty():
		_clear_asteroids_for_boss_phase()

	# BOSS DEATH CHAIN-EXPLOSION SEQUENCE (runs concurrently without freezing player flight or projectiles)
	if boss_dying:
		boss_death_timer -= dt
		boss_explosion_tick -= dt
		if player != null:
			player.invuln_timer = 0.0
		if boss != null:
			boss.x = boss_death_pos.x + randf_range(-7.0, 7.0)
			boss.y = boss_death_pos.y + randf_range(-4.5, 4.5)

		if boss_explosion_tick <= 0.0:
			boss_explosion_tick = 0.14
			var ex = boss_death_pos.x + randf_range(-340.0, 310.0)
			var ey = boss_death_pos.y + randf_range(-145.0, 145.0)
			missile_blasts.append({"x": ex, "y": ey, "age": 0.0, "max_age": 0.24})
			_spawn_explosion(ex, ey, 35, GameConfig.COLOR_GOLD)
			SoundManager.play("explosion")
			screen_shake = 12.0

		if boss_death_timer <= 0.0:
			boss_dying = false
			boss = null
			missile_blasts.append({"x": boss_death_pos.x, "y": boss_death_pos.y, "age": 0.0, "max_age": 0.34})
			_spawn_explosion(boss_death_pos.x, boss_death_pos.y, 130, GameConfig.COLOR_WHITE)
			_spawn_explosion(boss_death_pos.x, boss_death_pos.y, 60, GameConfig.COLOR_GOLD)
			SoundManager.play("explosion")
			screen_shake = 24.0
			victory = true
			victory_SubPhase = "WAIT_2S"
			end_sequence_timer = 2.0

	# VICTORY CINEMATIC SEQUENCE
	if victory:
		if player != null:
			player.invuln_timer = 0.0
			if player.gun_glow_timer > 0.0:
				player.gun_glow_timer = maxf(0.0, player.gun_glow_timer - dt)

		if victory_SubPhase == "WAIT_2S":
			end_sequence_timer -= dt
			if end_sequence_timer <= 0.0 and player != null:
				victory_SubPhase = "CENTERING"
				end_sequence_timer = 0.0
				victory_start_pos = Vector2(player.x, player.y)
				player.dodge_timer = 0.0
				player.bank_state = "neutral"
				player.thrust_state = "cruise"
		elif victory_SubPhase == "CENTERING" and player != null:
			player.anim_timer += dt
			end_sequence_timer += dt
			var prev_y: float = player.y
			var t = minf(1.0, end_sequence_timer / 1.2)
			var smooth_t = t * t * (3.0 - 2.0 * t)
			var target_x = GameConfig.SCREEN_WIDTH * 0.35
			var target_y = GameConfig.SCREEN_HEIGHT * 0.5
			player.x = victory_start_pos.x + (target_x - victory_start_pos.x) * smooth_t
			player.y = victory_start_pos.y + (target_y - victory_start_pos.y) * smooth_t
			player.vy = (player.y - prev_y) / maxf(dt, 0.001)
			if player.vy < -35.0:
				player.bank_state = "bank_left"
			elif player.vy > 35.0:
				player.bank_state = "bank_right"
			else:
				player.bank_state = "neutral"
			player.thrust_state = "cruise"
			if player_3d != null:
				player_3d.update_ship_pose(dt, player.vy, player.bank_state, player.thrust_state, player.anim_timer, false, 0.0)
			for img in player.afterimages.duplicate():
				img["timer"] -= dt
				if img["timer"] <= 0.0:
					player.afterimages.erase(img)
			if t >= 1.0:
				victory_SubPhase = "BLAST_OFF"
				player.bank_state = "neutral"
				player.thrust_state = "boost"
				player.vx = 250.0
				player.vy = 0.0
				SoundManager.play("dodge")
				_spawn_explosion(player.x - 50.0, player.y, 35, GameConfig.COLOR_CYAN)
		elif victory_SubPhase == "BLAST_OFF" and player != null:
			player.anim_timer += dt
			player.vx += 2600.0 * dt
			player.x += player.vx * dt
			player.vy = 0.0
			player.bank_state = "neutral"
			player.thrust_state = "boost"
			if player_3d != null:
				player_3d.update_ship_pose(dt, 0.0, "neutral", "boost", player.anim_timer, false, 0.0, true, 0.0)
			player.afterimages.append({
				"x": player.x,
				"y": player.y,
				"timer": 0.20,
				"bank": "neutral",
				"thrust": "boost"
			})
			for img in player.afterimages.duplicate():
				img["timer"] -= dt
				if img["timer"] <= 0.0:
					player.afterimages.erase(img)

			if player.x > GameConfig.SCREEN_WIDTH + 240.0:
				victory_SubPhase = "MODAL"
				entering_name = true
				kb_row = 0
				kb_col = 0
		elif victory_SubPhase == "MODAL":
			_update_end_modals_input(dt)

	# GAME OVER DELAY & MODAL (background battle continues unpaused)
	if game_over:
		if not entering_name and not score_saved:
			end_sequence_timer -= dt
			if end_sequence_timer <= 0.0:
				entering_name = true
				kb_row = 0
				kb_col = 0
		else:
			_update_end_modals_input(dt)

	# Update Player (active during normal combat, boss death sequence, and the 2s post-kill celebration window)
	if player != null and not game_over and (not victory or victory_SubPhase == "WAIT_2S"):
		var move_vec = InputHelper.get_movement()
		player.anim_timer += dt

		if player.primary_cooldown > 0.0:
			player.primary_cooldown -= dt
		if player.primary_buffer_timer > 0.0:
			player.primary_buffer_timer -= dt
		if player.gun_glow_timer > 0.0:
			player.gun_glow_timer = maxf(0.0, player.gun_glow_timer - dt)
		if player.secondary_fire_lock > 0.0:
			player.secondary_fire_lock -= dt

		if player.missile_charges < player.max_missile_charges:
			player.missile_recharge_timer += dt
			if player.missile_recharge_timer >= player.missile_recharge_time:
				player.missile_recharge_timer -= player.missile_recharge_time
				player.missile_charges += 1
				if player.missile_charges >= player.max_missile_charges:
					player.missile_recharge_timer = 0.0
		else:
			player.missile_recharge_timer = 0.0

		if player.dodge_ready_flash > 0.0:
			player.dodge_ready_flash = maxf(0.0, player.dodge_ready_flash - dt)
		if player.dodge_cooldown > 0.0:
			player.dodge_cooldown = maxf(0.0, player.dodge_cooldown - dt)
			if player.dodge_cooldown <= 0.0:
				player.dodge_ready_flash = 0.32
				SoundManager.play("dodge_ready")
				_spawn_dodge_ready_sparks(player.x, player.y)
		if player.invuln_timer > 0.0:
			player.invuln_timer -= dt
		if player.shield_hit_timer > 0.0:
			player.shield_hit_timer = maxf(0.0, player.shield_hit_timer - dt)
		if player.shield_bar_timer > 0.0:
			player.shield_bar_timer = maxf(0.0, player.shield_bar_timer - dt)

		if InputHelper.just_pressed("dodge") and player.dodge_cooldown <= 0.0 and not player.is_dodging():
			player.dodge_timer = player.dodge_duration
			player.dodge_cooldown = player.dodge_max_cooldown
			player.dodge_ready_flash = 0.0
			var dv = move_vec if move_vec.length() > 0.01 else Vector2(1.0, 0.0)
			player.dodge_vx = dv.x * player.speed * 2.0
			player.dodge_vy = dv.y * player.speed * 2.0
			SoundManager.play("dodge")

		if player.is_dodging():
			player.dodge_timer -= dt
			player.vx = player.dodge_vx
			player.vy = player.dodge_vy
			player.afterimages.append({
				"x": player.x,
				"y": player.y,
				"timer": 0.16,
				"bank": player.bank_state,
				"thrust": "boost"
			})
		else:
			player.vx = move_vec.x * player.speed
			player.vy = move_vec.y * player.speed

		player.x += player.vx * dt
		player.y += player.vy * dt
		player.x = clampf(player.x, 70.0, GameConfig.SCREEN_WIDTH - 70.0)
		player.y = clampf(player.y, 72.0, GameConfig.SCREEN_HEIGHT - 74.0)

		if move_vec.y < -0.2:
			player.bank_state = "bank_left"
		elif move_vec.y > 0.2:
			player.bank_state = "bank_right"
		else:
			player.bank_state = "neutral"

		if player.is_dodging() or move_vec.x > 0.25:
			player.thrust_state = "boost"
		elif move_vec.x < -0.25:
			player.thrust_state = "idle"
		else:
			player.thrust_state = "cruise"

		if player_3d != null:
			var dodge_prog: float = 0.0
			if player.is_dodging():
				dodge_prog = clampf(1.0 - (player.dodge_timer / maxf(player.dodge_duration, 0.001)), 0.0, 1.0)
			player_3d.update_ship_pose(
				dt,
				player.vy,
				player.bank_state,
				player.thrust_state,
				player.anim_timer,
				player.is_dodging(),
				dodge_prog,
				player.is_dodge_ready(),
				player.dodge_ready_flash
			)

		for img in player.afterimages.duplicate():
			img["timer"] -= dt
			if img["timer"] <= 0.0:
				player.afterimages.erase(img)

		# Primary Weapon: Twin Wing-Mounted Photon Plasma Lances
		if not victory and (InputHelper.just_pressed("fire_primary") or InputHelper.is_action_down("fire_primary")):
			player.primary_buffer_timer = 0.12

		if not victory and player.primary_buffer_timer > 0.0 and player.primary_cooldown <= 0.0:
			player.primary_cooldown = player.primary_fire_rate
			player.primary_buffer_timer = 0.0
			player.gun_glow_timer = 0.10
			var spawn_offsets = [Vector2(34.0, -14.5), Vector2(34.0, 14.5)]
			if player.bank_state == "bank_left":
				spawn_offsets = [Vector2(34.0, -18.0), Vector2(34.0, 10.5)]
			elif player.bank_state == "bank_right":
				spawn_offsets = [Vector2(34.0, -10.5), Vector2(34.0, 18.0)]
			for s_idx in range(spawn_offsets.size()):
				var soff: Vector2 = spawn_offsets[s_idx]
				player_bullets.append({
					"x": player.x + soff.x,
					"y": player.y + soff.y,
					"vx": 1280.0,
					"vy": 0.0,
					"damage": 15,
					"age": 0.0,
					"phase": level_time + float(s_idx) * 0.08
				})
			SoundManager.play("primary_fire")

		# Secondary Weapon: Heavy Homing Missiles (3-charge system)
		if not victory and InputHelper.just_pressed("fire_secondary") and player.missile_charges > 0 and player.secondary_fire_lock <= 0.0:
			player.missile_charges -= 1
			player.secondary_fire_lock = 0.18
			var side = player.missile_wing_toggle
			player.missile_wing_toggle *= -1

			var launch_x = player.x + 12.0
			var launch_y = player.y + side * 28.0
			homing_missiles.append({
				"x": launch_x,
				"y": launch_y,
				"vx": 560.0,
				"vy": side * 95.0,
				"speed": 680.0,
				"damage": 100,
				"age": 0.0,
				"max_tracking_time": 3.0,
				"turn_rate": 3.2,
				"trail": []
			})
			_spawn_explosion(launch_x + 10.0, launch_y, 7, GameConfig.COLOR_GOLD)
			SoundManager.play("secondary_fire")

	# Enemy & Asteroid Spawning (Coordinated Phase Formation Director)
	if not boss_dying and not victory:
		if current_phase < 4:
			if current_phase == 3 and level_time >= 72.0 and not dreadnought_spawned:
				_spawn_dreadnought_fleet()
				spawn_timer = maxf(spawn_timer, 2.6)
			spawn_timer -= dt
			if spawn_timer <= 0.0:
				spawn_timer = _spawn_phase_formation()
			asteroid_spawn_timer -= dt
			if asteroid_spawn_timer <= 0.0:
				asteroid_spawn_timer = _spawn_asteroid_wave()
		else:
			if not boss_spawned and boss_warning_timer <= 0.0:
				boss_spawned = true
				boss = BossTitan.new(enemy_sprites)
				if boss_3d != null:
					boss_3d.reset_pose_for_spawn(0.0)

	# Update Player Bullets
	for b in player_bullets.duplicate():
		b["age"] = b.get("age", 0.0) + dt
		b["x"] += b["vx"] * dt
		b["y"] += b["vy"] * dt
		if b["x"] > GameConfig.SCREEN_WIDTH + 60.0:
			player_bullets.erase(b)
			continue

		var b_rect = Rect2(b["x"] - 14.0, b["y"] - 4.0, 28.0, 8.0)
		var hit: bool = false

		for e in enemies.duplicate():
			if not e.active:
				continue
			if b_rect.intersects(e.get_hitbox()):
				e.hp -= b["damage"]
				e.hit_flash = 0.08
				_spawn_laser_impact(b["x"] + 8.0, b["y"])
				hit = true
				if e.hp <= 0:
					score += e.score_value
					_spawn_score_popup(e.x, e.y, e.score_value, "raider" if e.enemy_type == "raider" else "standard")
					_spawn_explosion(e.x, e.y, 26, GameConfig.COLOR_GOLD)
					SoundManager.play("explosion")
					enemies.erase(e)
				else:
					SoundManager.play("enemy_hit")
				break

		if not hit and dreadnought != null and not dreadnought.retreating:
			if dreadnought.is_shielded() and dreadnought.intersects_shield(b_rect):
				var sh_pt := Vector2(b["x"] + 10.0, b["y"])
				_hit_dreadnought(b["damage"], sh_pt, false)
				hit = true
			elif not dreadnought.is_shielded() and b_rect.intersects(dreadnought.get_hitbox()):
				var imp_pt := Vector2(b["x"] + 8.0, b["y"])
				_spawn_laser_impact(imp_pt.x, imp_pt.y)
				_hit_dreadnought(b["damage"], imp_pt, false)
				hit = true

		if not hit and boss != null and not boss_dying:
			if boss.is_shielded() and boss.intersects_shield(b_rect):
				var b_sh_pt := Vector2(b["x"] + 10.0, b["y"])
				_hit_boss_titan(b["damage"], b_sh_pt, false)
				hit = true
			elif not boss.is_shielded():
				var b_zone: Rect2 = boss.find_hit_zone(b_rect)
				if b_zone.size.x > 0.0:
					var imp_x: float = clampf(b["x"] + 8.0, b_zone.position.x + 2.0, b_zone.end.x - 2.0)
					_spawn_laser_impact(imp_x, b["y"])
					_hit_boss_titan(b["damage"], Vector2(imp_x, b["y"]), false)
					hit = true

		if not hit:
			for ast in asteroids.duplicate():
				if ast.intersects_rect(b_rect):
					var a_imp := Vector2(b["x"] + 8.0, b["y"])
					_spawn_laser_impact(a_imp.x, a_imp.y)
					_damage_asteroid(ast, b["damage"], a_imp, true)
					hit = true
					break

		if hit:
			player_bullets.erase(b)

	# Update Homing Missiles
	for m in homing_missiles.duplicate():
		m["age"] += dt
		if m["age"] < m["max_tracking_time"]:
			var target = _find_nearest_target(m["x"], m["y"])
			if target != null:
				var desired_ang = atan2(target.y - m["y"], target.x - m["x"])
				var curr_ang = atan2(m["vy"], m["vx"])
				var diff = fmod(desired_ang - curr_ang + PI, TAU) - PI
				var max_step = m["turn_rate"] * dt
				var new_ang = curr_ang + clampf(diff, -max_step, max_step)
				m["vx"] = cos(new_ang) * m["speed"]
				m["vy"] = sin(new_ang) * m["speed"]

		m["x"] += m["vx"] * dt
		m["y"] += m["vy"] * dt
		m["trail"].append(Vector2(m["x"], m["y"]))
		if m["trail"].size() > 20:
			m["trail"].pop_front()

		if m["x"] > GameConfig.SCREEN_WIDTH + 100.0 or m["x"] < -100.0 or m["y"] < -100.0 or m["y"] > GameConfig.SCREEN_HEIGHT + 100.0:
			homing_missiles.erase(m)
			continue

		var m_rect = Rect2(m["x"] - 12.0, m["y"] - 12.0, 24.0, 24.0)
		var exploded: bool = false

		for e in enemies.duplicate():
			if not e.active:
				continue
			if m_rect.intersects(e.get_hitbox()):
				e.hp -= m["damage"]
				e.hit_flash = 0.1
				exploded = true
				if e.hp <= 0:
					score += e.score_value
					_spawn_score_popup(e.x, e.y, e.score_value, "raider" if e.enemy_type == "raider" else "standard")
					_spawn_explosion(e.x, e.y, 32, GameConfig.COLOR_GOLD)
					enemies.erase(e)
				break

		if not exploded and dreadnought != null and not dreadnought.retreating:
			var hit_d_shield: bool = dreadnought.is_shielded() and dreadnought.intersects_shield(m_rect)
			var hit_d_hull: bool = not dreadnought.is_shielded() and m_rect.intersects(dreadnought.get_hitbox())
			if hit_d_shield or hit_d_hull:
				_hit_dreadnought(m["damage"], Vector2(m["x"], m["y"]), true)
				exploded = true

		if not exploded and boss != null and not boss_dying:
			var hit_b_shield: bool = boss.is_shielded() and boss.intersects_shield(m_rect)
			var hit_b_hull: bool = not boss.is_shielded() and boss.intersects_rect(m_rect)
			if hit_b_shield or hit_b_hull:
				_hit_boss_titan(m["damage"], Vector2(m["x"], m["y"]), true)
				exploded = true

		if not exploded:
			for ast in asteroids.duplicate():
				if ast.intersects_rect(m_rect):
					_damage_asteroid(ast, m["damage"], Vector2(m["x"], m["y"]), true)
					exploded = true
					break

		if exploded:
			missile_blasts.append({"x": m["x"], "y": m["y"], "age": 0.0, "max_age": 0.25})
			_spawn_explosion(m["x"], m["y"], 22, GameConfig.COLOR_GOLD)
			_spawn_explosion(m["x"], m["y"], 10, GameConfig.COLOR_MAGENTA)
			SoundManager.play("explosion")
			homing_missiles.erase(m)

	# Update Asteroids (Phases 1-3 only; damages player ship, does not collide with enemy ships)
	for ast in asteroids.duplicate():
		ast.update(dt)
		if ast.x < -140.0:
			asteroids.erase(ast)
			continue
		if player != null and ast.intersects_rect(player.get_hitbox()):
			if not player.is_invulnerable():
				_damage_player(1, Vector2(ast.x, ast.y))
				if not ast.is_large:
					_spawn_asteroid_debris(ast.x, ast.y, 16, false)
					asteroids.erase(ast)
				else:
					ast.hit_flash = 0.10
					if player != null:
						_spawn_asteroid_debris((ast.x + player.x) * 0.5, (ast.y + player.y) * 0.5, 14, false)
					else:
						_spawn_asteroid_debris(ast.x, ast.y, 14, false)

	# Update Enemies
	for e in enemies.duplicate():
		e.update(dt, player, enemy_bullets, current_phase)
		if not e.active:
			continue
		if e.x < -120.0 or e.y < -140.0 or e.y > GameConfig.SCREEN_HEIGHT + 140.0:
			enemies.erase(e)
			continue
		if player != null and e.get_hitbox().intersects(player.get_hitbox()):
			if not player.is_invulnerable():
				_damage_player(1, Vector2(e.x, e.y))
				e.hp = 0
				_spawn_explosion(e.x, e.y, 24, GameConfig.COLOR_RED)
				enemies.erase(e)
			elif player.is_dodging():
				e.hp -= 40
				if e.hp <= 0:
					score += e.score_value
					_spawn_score_popup(e.x, e.y, e.score_value, "dodge")
					_spawn_explosion(e.x, e.y, 26, GameConfig.COLOR_CYAN)
					SoundManager.play("explosion")
					enemies.erase(e)

	if dreadnought != null:
		var d_was_shielded: bool = dreadnought.is_shielded()
		dreadnought.update(dt, player, enemy_bullets)
		if d_was_shielded and not dreadnought.is_shielded() and not dreadnought.retreating:
			var d_sc: Vector2 = dreadnought.get_shield_center()
			shield_collapse_waves.append({"x": d_sc.x, "y": d_sc.y, "age": 0.0, "max_age": 0.38})
			_spawn_explosion(d_sc.x - 40.0, d_sc.y, 20, GameConfig.COLOR_CYAN)
		if dreadnought.retreating and int(level_time * 30.0) % 2 == 0:
			_spawn_explosion(dreadnought.x + 150.0, dreadnought.y, 3, GameConfig.COLOR_CYAN)
		if dreadnought.x < -380.0:
			dreadnought = null

	if boss != null and not boss_dying:
		var b_was_shielded: bool = boss.is_shielded()
		boss.update(dt, player, enemy_bullets)
		if b_was_shielded and not boss.is_shielded():
			var b_sc: Vector2 = boss.get_shield_center()
			shield_collapse_waves.append({"x": b_sc.x, "y": b_sc.y, "age": 0.0, "max_age": 0.42})
			_spawn_explosion(b_sc.x - 60.0, b_sc.y, 28, GameConfig.COLOR_CYAN)
		var hit_player_boss: bool = false
		if player != null and not player.is_invulnerable():
			hit_player_boss = boss.intersects_shield(player.get_hitbox()) if boss.is_shielded() else boss.intersects_rect(player.get_hitbox())
		if hit_player_boss:
			_damage_player(1, Vector2(player.x + 56.0, player.y))

	# Update Enemy Bullets
	var p_hitbox = player.get_hitbox() if player != null else Rect2(0, 0, 0, 0)
	for eb in enemy_bullets.duplicate():
		eb["x"] += eb["vx"] * dt
		eb["y"] += eb["vy"] * dt
		if eb["x"] < -60.0 or eb["x"] > GameConfig.SCREEN_WIDTH + 60.0 or eb["y"] < -60.0 or eb["y"] > GameConfig.SCREEN_HEIGHT + 60.0:
			enemy_bullets.erase(eb)
			continue

		var r = eb["radius"]
		var eb_rect = Rect2(eb["x"] - r, eb["y"] - r, r * 2.0, r * 2.0)
		if player != null and eb_rect.intersects(p_hitbox):
			if not player.is_invulnerable():
				_damage_player(1, Vector2(float(eb["x"]), float(eb["y"])))
				enemy_bullets.erase(eb)

	# Update per-ship 3D poses, continuous fluid Raider banking, Blue Giant solar shadows & real-time laser hull reflections
	_update_all_3d_ships_and_lighting(dt)


func _collect_weapon_light_emitters() -> Array:
	var emitters: Array = []
	# 1. Player Photon Plasma Lances (vivid electric cyan)
	for b in player_bullets:
		emitters.append({
			"pos": Vector2(float(b["x"]), float(b["y"])),
			"color": Color(0.12, 0.90, 1.0),
			"energy": 2.65,
			"reach": 185.0
		})
	# 2. Player twin barrel muzzle flash & deflector shield impact flare
	if player != null and player.gun_glow_timer > 0.0:
		var mf_ratio: float = clampf(player.gun_glow_timer / 0.10, 0.0, 1.0)
		emitters.append({
			"pos": Vector2(player.x + 34.0, player.y),
			"color": Color(0.20, 0.94, 1.0),
			"energy": 2.15 * mf_ratio,
			"reach": 140.0
		})
	if player != null and player.shield_hit_timer > 0.0:
		var sh_ratio: float = clampf(player.shield_hit_timer / maxf(player.shield_hit_duration, 0.001), 0.0, 1.0)
		var sh_col: Color = Color(0.18, 0.94, 1.0) if player.hp >= 2 else Color(1.0, 0.14, 0.12)
		emitters.append({
			"pos": Vector2(player.x + cos(player.shield_hit_angle) * 62.0, player.y + sin(player.shield_hit_angle) * 38.0),
			"color": sh_col,
			"energy": 3.20 * sh_ratio,
			"reach": 210.0
		})
	# 3. Laser Impact Shock-Rings (bright cyan-white armor rebound)
	for imp in laser_impacts:
		var iprog: float = 1.0 - clampf(float(imp["age"]) / maxf(float(imp["max_age"]), 0.001), 0.0, 1.0)
		if iprog > 0.05:
			emitters.append({
				"pos": Vector2(float(imp["x"]), float(imp["y"])),
				"color": Color(0.38, 0.96, 1.0),
				"energy": 3.10 * iprog,
				"reach": 215.0
			})
	# 4. Homing Photon Torpedoes (warm golden-amber afterburner & seeker flare)
	for m in homing_missiles:
		emitters.append({
			"pos": Vector2(float(m["x"]), float(m["y"])),
			"color": Color(1.0, 0.62, 0.18),
			"energy": 2.60,
			"reach": 220.0
		})
	# 5. Torpedo Detonation Fireballs
	for mb in missile_blasts:
		var mprog: float = 1.0 - clampf(float(mb["age"]) / maxf(float(mb["max_age"]), 0.001), 0.0, 1.0)
		if mprog > 0.05:
			emitters.append({
				"pos": Vector2(float(mb["x"]), float(mb["y"])),
				"color": Color(1.0, 0.72, 0.24),
				"energy": 3.60 * mprog,
				"reach": 320.0
			})
	# 6. Enemy Plasma Comets, Gold Railgun Lances, Magenta Nova Pulsars & Targeted Overload Lasers
	for eb in enemy_bullets:
		var is_tlaser: bool = String(eb.get("kind", "")) == "targeted_laser"
		emitters.append({
			"pos": Vector2(float(eb["x"]), float(eb["y"])),
			"color": eb.get("color", GameConfig.COLOR_RED),
			"energy": 2.45 if is_tlaser else 1.05,
			"reach": 205.0 if is_tlaser else 120.0
		})
	# 7. Capital Ship Targeted Laser Charge-Up Emitters (illuminates 3D Destroyer & Titan armor)
	if dreadnought != null and not dreadnought.retreating:
		for cl in dreadnought.charging_lasers:
			var cp: float = clampf(float(cl["age"]) / maxf(float(cl["charge_time"]), 0.001), 0.0, 1.0)
			var coff: Vector2 = cl["offset"]
			emitters.append({
				"pos": Vector2(dreadnought.x + coff.x, dreadnought.y + coff.y),
				"color": Color(1.0, 0.22, 0.62),
				"energy": 1.1 + 2.2 * cp,
				"reach": 220.0
			})
	if boss != null and not boss_dying:
		for cl in boss.charging_lasers:
			var cp_b: float = clampf(float(cl["age"]) / maxf(float(cl["charge_time"]), 0.001), 0.0, 1.0)
			var coff_b: Vector2 = cl["offset"]
			emitters.append({
				"pos": Vector2(boss.x + coff_b.x, boss.y + coff_b.y),
				"color": Color(1.0, 0.22, 0.62),
				"energy": 1.2 + 2.4 * cp_b,
				"reach": 250.0
			})
	return emitters


func _gather_top_lights_for_ship(
	ship_pos: Vector2,
	half_ext: Vector2,
	is_capital: bool,
	emitters: Array
) -> Array:
	var best0_e: float = 0.0
	var best1_e: float = 0.0
	var best0: Dictionary = {}
	var best1: Dictionary = {}
	var box_w: float = half_ext.x * 0.72
	var box_h: float = half_ext.y * 0.72
	var omni_r: float = 1.40 if is_capital else 1.95

	for em in emitters:
		var epos: Vector2 = em["pos"]
		var dx_b: float = maxf(0.0, absf(epos.x - ship_pos.x) - box_w)
		var dy_b: float = maxf(0.0, absf(epos.y - ship_pos.y) - box_h)
		var reach: float = float(em["reach"])
		if dx_b >= reach or dy_b >= reach:
			continue
		var edge_dist: float = sqrt(dx_b * dx_b + dy_b * dy_b)
		if edge_dist >= reach:
			continue
		var atten: float = 1.0 - (edge_dist / reach)
		var eff_e: float = float(em["energy"]) * atten * atten
		if eff_e <= 0.04:
			continue
		# Avoid stacking two nearly identical overlapping bolts from the same twin volley onto both slots
		if not best0.is_empty() and epos.distance_squared_to(best0["pos"]) < 1400.0:
			if eff_e > best0_e:
				best0_e = eff_e
				best0["pos"] = epos
				best0["color"] = em["color"]
				best0["energy"] = minf(3.3, eff_e * 1.18)
			continue
		if eff_e > best0_e:
			best1_e = best0_e
			best1 = best0
			best0_e = eff_e
			best0 = {"pos": epos, "color": em["color"], "energy": eff_e, "z": 0.60, "range": omni_r}
		elif eff_e > best1_e:
			best1_e = eff_e
			best1 = {"pos": epos, "color": em["color"], "energy": eff_e, "z": 0.60, "range": omni_r}

	var result: Array = []
	if best0_e > 0.04:
		result.append(best0)
	if best1_e > 0.04:
		result.append(best1)
	return result


func _update_all_3d_ships_and_lighting(dt: float) -> void:
	var sun_px := Vector2(
		current_sun_uv.x * GameConfig.SCREEN_WIDTH,
		current_sun_uv.y * GameConfig.SCREEN_HEIGHT
	)
	var emitters: Array = _collect_weapon_light_emitters()

	# 1. Player Starfighter 3D solar shadows & live weapon reflections
	if player_3d != null and player != null:
		var p_pos := Vector2(player.x, player.y)
		var p_lights: Array = _gather_top_lights_for_ship(p_pos, Vector2(76.0, 43.0), false, emitters)
		player_3d.update_dynamic_lighting(p_pos, Vector2(152.0, 86.0), sun_px, p_lights)

	# 2. Per-instance Scout & Raider 3D SubViewport assignment, continuous fluid banking & dynamic lighting
	var used_vps: Dictionary = {}
	for e in enemies:
		if e.active and e.vp_3d != null:
			used_vps[e.vp_3d] = true

	for e in enemies:
		if not e.active:
			continue
		var newly_bound: bool = false
		if e.vp_3d == null:
			e.vp_3d = _acquire_enemy_vp(e.enemy_type, used_vps)
			newly_bound = true
		if e.vp_3d == null:
			continue
		e.vp_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		if e.enemy_type == "raider":
			var full_vy: float = maxf(65.0, e.amp_y * e.freq_y)
			if newly_bound:
				e.vp_3d.reset_pose_for_spawn(e.vy, full_vy)
			e.vp_3d.update_pose(dt, e.vy, e.bank_state, e.anim_timer, false, false, full_vy)
			var r_pos := Vector2(e.x, e.y)
			var r_lights: Array = _gather_top_lights_for_ship(r_pos, Vector2(82.0, 56.0), false, emitters)
			e.vp_3d.update_dynamic_lighting(r_pos, Vector2(164.0, 112.0), sun_px, r_lights)
		else:
			var is_chg: bool = e.charge_timer > 0.0 or e.fire_flash_timer > 0.0
			var is_ret: bool = e.state == "retreat"
			if newly_bound:
				e.vp_3d.reset_pose_for_spawn(e.vy, 140.0)
			e.vp_3d.update_pose(dt, e.vy, "neutral", e.anim_timer, is_chg, is_ret, 140.0)
			var s_pos := Vector2(e.x, e.y)
			var s_lights: Array = _gather_top_lights_for_ship(s_pos, Vector2(52.0, 38.0), false, emitters)
			e.vp_3d.update_dynamic_lighting(s_pos, Vector2(104.0, 76.0), sun_px, s_lights)

	# Pause unused pooled SubViewports (keep index 0 warm so tests/inspections always have an active texture)
	for idx in range(scout_3d_pool.size()):
		var svp: SubViewport = scout_3d_pool[idx]
		if svp != null and not used_vps.has(svp) and idx > 0:
			svp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for idx in range(raider_3d_pool.size()):
		var rvp: SubViewport = raider_3d_pool[idx]
		if rvp != null and not used_vps.has(rvp) and idx > 0:
			rvp.render_target_update_mode = SubViewport.UPDATE_DISABLED

	# 3. Dreadnought Destroyer 3D pose, solar shadows & weapon reflections
	if dreadnought_3d != null:
		if dreadnought != null:
			dreadnought_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			var d_vy: float = 0.0 if (dreadnought.entering or dreadnought.retreating) else dreadnought.vy
			dreadnought_3d.update_pose(dt, d_vy, "neutral", dreadnought.time, dreadnought.burst_remaining > 0, dreadnought.retreating)
			var d_pos := Vector2(dreadnought.x, dreadnought.y)
			var d_lights: Array = _gather_top_lights_for_ship(d_pos, Vector2(260.0, 125.0), true, emitters)
			dreadnought_3d.update_dynamic_lighting(d_pos, Vector2(520.0, 250.0), sun_px, d_lights)

	# 4. Boss Titan Flagship 3D pose, solar shadows & weapon reflections
	if boss_3d != null:
		if boss != null:
			boss_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			var boss_anim_t: float = level_time if boss_dying else boss.time
			var b_vy: float = 0.0 if (boss.entering or boss_dying) else boss.vy
			boss_3d.update_pose(dt, b_vy, "neutral", boss_anim_t, boss.salvo_remaining > 0 and not boss_dying, false)
			var b_pos := Vector2(boss.x, boss.y)
			var b_lights: Array = _gather_top_lights_for_ship(b_pos, Vector2(480.0, 210.0), true, emitters)
			boss_3d.update_dynamic_lighting(b_pos, Vector2(960.0, 420.0), sun_px, b_lights)

	# 5. Per-instance 3D Asteroid tumble, Blue Giant crater shadows & weapon reflections
	var used_ast_vps: Dictionary = {}
	for ast in asteroids:
		if ast.vp_3d != null:
			used_ast_vps[ast.vp_3d] = true

	for ast in asteroids:
		if ast.vp_3d == null:
			ast.vp_3d = _acquire_asteroid_vp(ast.is_large, ast.variant_index, used_ast_vps)
		if ast.vp_3d == null:
			continue
		ast.vp_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		ast.vp_3d.update_tumble(ast.spin_axis, ast.spin_angle, ast.wobble_angle)
		var a_pos := Vector2(ast.x, ast.y)
		var a_half := Vector2(ast.radius, ast.radius)
		var a_lights: Array = _gather_top_lights_for_ship(a_pos, a_half, false, emitters)
		ast.vp_3d.update_dynamic_lighting(a_pos, Vector2(ast.draw_size, ast.draw_size), sun_px, a_lights)

	for idx in range(asteroid_large_3d_pool.size()):
		var lvp: SubViewport = asteroid_large_3d_pool[idx]
		if lvp != null and not used_ast_vps.has(lvp) and idx > 0:
			lvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for idx in range(asteroid_small_3d_pool.size()):
		var svp_a: SubViewport = asteroid_small_3d_pool[idx]
		if svp_a != null and not used_ast_vps.has(svp_a) and idx > 0:
			svp_a.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _damage_player(amount: int = 1, hit_pos: Vector2 = Vector2.INF) -> void:
	if player == null or boss_dying or victory:
		return
	var impact_pt: Vector2 = hit_pos if hit_pos.is_finite() else Vector2(player.x + 44.0, player.y)
	var hit_ang: float = atan2(impact_pt.y - player.y, impact_pt.x - player.x)

	player.hp = max(0, player.hp - amount)
	hud_shield_flash_timer = 0.45
	hud_shield_lost_seg = player.hp - 1
	player.invuln_timer = 1.0
	screen_shake = 12.0
	SoundManager.play("player_hit")

	if player.hp > 0:
		player.shield_hit_timer = player.shield_hit_duration
		player.shield_hit_angle = hit_ang
		player.shield_bar_timer = player.shield_bar_duration
		_spawn_shield_sparks(player.x, player.y, hit_ang, player.hp <= 1)
	elif not game_over:
		var px = player.x
		var py = player.y
		shield_collapse_waves.append({"x": px, "y": py, "age": 0.0, "max_age": 0.45})
		_spawn_explosion(px, py, 95, GameConfig.COLOR_GOLD)
		_spawn_explosion(px, py, 45, GameConfig.COLOR_RED)
		_spawn_explosion(px, py, 28, GameConfig.COLOR_CYAN)
		SoundManager.play("explosion")
		SoundManager.play_music("Game_over.wav", false, 0.70, true)
		player = null
		game_over = true
		end_sequence_timer = 2.0


func _trigger_overload_warning(burst_pos: Vector2) -> void:
	overload_warning_timer = 3.6
	overload_warning_text = "DANGER! ENEMY SHIP ENERGY OVERLOAD DETECTED"
	phase_banner_timer = 0.0
	screen_shake = maxf(screen_shake, 11.0)
	SoundManager.play("boss_warning")
	_spawn_explosion(burst_pos.x, burst_pos.y, 26, GameConfig.COLOR_CYAN)
	_spawn_explosion(burst_pos.x, burst_pos.y, 16, GameConfig.COLOR_MAGENTA)


func _hit_dreadnought(dmg: int, impact_pt: Vector2, is_missile: bool = false) -> void:
	if dreadnought == null or dreadnought.retreating:
		return
	if dreadnought.is_shielded():
		dreadnought.register_shield_hit(impact_pt)
		_spawn_explosion(impact_pt.x, impact_pt.y, 7, GameConfig.COLOR_CYAN)
		SoundManager.play("dodge")
		return

	var half_hp: int = int(dreadnought.max_hp * 0.5)
	if not dreadnought.phase2_triggered and (dreadnought.hp - dmg) <= half_hp:
		dreadnought.hp = half_hp
		dreadnought.hit_flash = 0.10 if is_missile else 0.06
		dreadnought.activate_emergency_shield()
		_trigger_overload_warning(dreadnought.get_shield_center())
		return

	dreadnought.hp -= dmg
	dreadnought.hit_flash = 0.10 if is_missile else 0.06
	if dreadnought.hp <= 0:
		score += dreadnought.score_value
		_spawn_score_popup(dreadnought.x, dreadnought.y, dreadnought.score_value, "capital")
		_spawn_explosion(dreadnought.x, dreadnought.y, 70 if is_missile else 65, GameConfig.COLOR_GOLD)
		if not is_missile:
			SoundManager.play("explosion")
		screen_shake = 15.0 if is_missile else 14.0
		overload_warning_timer = 0.0
		dreadnought = null
	elif not is_missile:
		SoundManager.play("enemy_hit")


func _hit_boss_titan(dmg: int, impact_pt: Vector2, is_missile: bool = false) -> void:
	if boss == null or boss_dying:
		return
	if boss.is_shielded():
		boss.register_shield_hit(impact_pt)
		_spawn_explosion(impact_pt.x, impact_pt.y, 8, GameConfig.COLOR_CYAN)
		SoundManager.play("dodge")
		return

	var half_hp: int = int(boss.max_hp * 0.5)
	if not boss.phase2_triggered and (boss.hp - dmg) <= half_hp:
		boss.hp = half_hp
		boss.hit_flash = 0.09 if is_missile else 0.05
		boss.activate_emergency_shield()
		_trigger_overload_warning(boss.get_shield_center())
		return

	boss.hp -= dmg
	boss.hit_flash = 0.09 if is_missile else 0.05
	if boss.hp <= 0:
		_trigger_boss_defeat()
	elif not is_missile:
		SoundManager.play("enemy_hit")


func _trigger_boss_defeat() -> void:
	if boss != null and not boss_dying and not victory:
		score += boss.score_value
		_spawn_score_popup(boss.x - 60.0, boss.y - 50.0, boss.score_value, "boss")
		boss_death_pos = Vector2(boss.x, boss.y)
		boss.emergency_shield_timer = 0.0
		boss.charging_lasers.clear()
		overload_warning_timer = 0.0
		boss_dying = true
		boss_death_timer = 3.2
		boss_explosion_tick = 0.05
		if player != null:
			player.invuln_timer = 0.0
		enemy_bullets.clear()
		enemies.clear()
		asteroids.clear()
		screen_shake = 20.0
		SoundManager.play("explosion")


func _draw() -> void:
	var ox: float = 0.0
	var oy: float = 0.0
	if screen_shake > 0.0:
		ox = randf_range(-screen_shake, screen_shake)
		oy = randf_range(-screen_shake, screen_shake)

	if backdrop_rect != null:
		backdrop_rect.position = Vector2(-40.0 + ox, -40.0 + oy)

	draw_set_transform(Vector2(ox, oy), 0.0, Vector2.ONE)

	if backdrop_material == null:
		draw_rect(Rect2(-40.0, -40.0, GameConfig.SCREEN_WIDTH + 80.0, GameConfig.SCREEN_HEIGHT + 80.0), Color8(5, 6, 18), true)
		for s in stars:
			draw_rect(Rect2(s["x"], s["y"], s["size"], s["size"]), s["color"], true)

	# Dodge afterimages
	if player != null:
		for img in player.afterimages:
			var f_list: Array = player.frames.get(img["bank"], {}).get(img["thrust"], [])
			if not f_list.is_empty():
				var f_tex: Texture2D = f_list[0]
				var a_ratio = clampf(img["timer"] / 0.20, 0.0, 1.0)
				draw_texture(
					f_tex,
					Vector2(img["x"] - f_tex.get_width() * 0.5, img["y"] - f_tex.get_height() * 0.5),
					Color(0.3, 0.9, 1.0, a_ratio * 0.5)
				)

	# Player bullets (Photon Plasma Lances)
	for b in player_bullets:
		var anim_p: float = float(b.get("phase", 0.0)) + float(b.get("age", 0.0))
		GameConfig.draw_photon_laser_bolt(self, b["x"], b["y"], anim_p, 1.0)

	# Homing missiles (Armored Finned Photon Torpedoes)
	for m in homing_missiles:
		var is_trk: bool = float(m.get("age", 0.0)) < float(m.get("max_tracking_time", 3.0))
		GameConfig.draw_homing_missile(
			self,
			m["x"],
			m["y"],
			m["vx"],
			m["vy"],
			m["trail"],
			float(m.get("age", 0.0)),
			is_trk,
			1.0
		)

	var is_live_display := DisplayServer.get_name() != "headless"

	# Asteroids (Real-Time 3D Cratered Boulders rendered behind spacecraft so enemy ships fly cleanly over them)
	for ast in asteroids:
		var drawn_ast_3d := false
		if is_live_display:
			var avp: SubViewport = ast.vp_3d
			if avp == null:
				var fallback_pool: Array[SubViewport] = asteroid_large_3d_pool if ast.is_large else asteroid_small_3d_pool
				if not fallback_pool.is_empty():
					avp = fallback_pool[0]
			if avp != null and avp.has_3d_model():
				var atex: Texture2D = avp.get_texture()
				if atex != null:
					var mod_a := Color(1.45, 1.52, 1.62, 1.0) if ast.hit_flash > 0.0 else Color.WHITE
					var half_d: float = ast.draw_size * 0.5
					draw_texture_rect(
						atex,
						Rect2(ast.x - half_d, ast.y - half_d, ast.draw_size, ast.draw_size),
						false,
						mod_a
					)
					drawn_ast_3d = true
		if not drawn_ast_3d:
			GameConfig.draw_asteroid_2d_fallback(
				self,
				ast.x,
				ast.y,
				ast.radius,
				ast.spin_angle,
				ast.variant_index,
				ast.hit_flash > 0.0
			)
		var hp_ratio_a: float = float(ast.hp) / float(maxi(1, ast.max_hp))
		if hp_ratio_a < 0.75:
			GameConfig.draw_asteroid_damage_fissures(
				self,
				ast.x,
				ast.y,
				ast.radius,
				hp_ratio_a,
				ast.spin_angle,
				ast.variant_index
			)

	# Enemies (Per-Instance Real-Time 3D SubViewport with Continuous Banking, Solar Shadows & Weapon Bounce)
	for e in enemies:
		if not e.active:
			continue
		var drawn_enemy_3d := false
		if is_live_display:
			var mod_e := Color(2.8, 2.8, 2.8, 1.0) if e.hit_flash > 0.0 else Color.WHITE
			var evp: SubViewport = e.vp_3d
			if evp == null:
				evp = scout_3d if e.enemy_type == "scout" else raider_3d_neutral
			if evp != null and evp.has_3d_model():
				var etex: Texture2D = evp.get_texture()
				if etex != null:
					var draw_rect_e := (
						Rect2(e.x - 52.0, e.y - 38.0, 104.0, 76.0)
						if e.enemy_type == "scout"
						else Rect2(e.x - 82.0, e.y - 56.0, 164.0, 112.0)
					)
					draw_texture_rect(etex, draw_rect_e, false, mod_e)
					drawn_enemy_3d = true
		if not drawn_enemy_3d:
			var tex = e.get_current_texture()
			if tex != null:
				draw_texture(tex, Vector2(e.x - tex.get_width() * 0.5, e.y - tex.get_height() * 0.5))

	# Dreadnought (Destroyer 3D SubViewport with Sprite Fallback)
	if dreadnought != null:
		var drawn_dread_3d := false
		if is_live_display and dreadnought_3d != null and dreadnought_3d.has_3d_model():
			var d_vp_tex: Texture2D = dreadnought_3d.get_texture()
			if d_vp_tex != null:
				var mod_d := Color(2.8, 2.8, 2.8, 1.0) if dreadnought.hit_flash > 0.0 else Color.WHITE
				draw_texture_rect(
					d_vp_tex,
					Rect2(dreadnought.x - 260.0, dreadnought.y - 125.0, 520.0, 250.0),
					false,
					mod_d
				)
				drawn_dread_3d = true
		if not drawn_dread_3d:
			var d_tex = dreadnought.flash_tex if dreadnought.hit_flash > 0.0 else dreadnought.tex
			if d_tex != null:
				draw_texture(d_tex, Vector2(dreadnought.x - d_tex.get_width() * 0.5, dreadnought.y - d_tex.get_height() * 0.5))
		if not dreadnought.retreating:
			for cl in dreadnought.charging_lasers:
				var c_off: Vector2 = cl["offset"]
				var c_prog: float = clampf(float(cl["age"]) / maxf(float(cl["charge_time"]), 0.001), 0.0, 1.0)
				GameConfig.draw_boss_laser_charge(self, dreadnought.x + c_off.x, dreadnought.y + c_off.y, float(cl["aim_angle"]), c_prog, level_time)
			if dreadnought.is_shielded():
				var d_sc: Vector2 = dreadnought.get_shield_center()
				var d_sr: Vector2 = dreadnought.get_shield_radii()
				var d_rem: float = dreadnought.emergency_shield_timer / maxf(dreadnought.emergency_shield_duration, 0.001)
				GameConfig.draw_boss_emergency_shield(self, d_sc.x, d_sc.y, d_sr.x, d_sr.y, level_time, d_rem, dreadnought.shield_hit_flash, dreadnought.shield_hit_angle)
			var bar_w: float = 280.0
			var bar_h: float = 10.0
			var bx = dreadnought.x - bar_w * 0.5 - 20.0
			var by = dreadnought.y - 132.0
			draw_rect(Rect2(bx, by, bar_w, bar_h), Color8(30, 10, 25), true)
			var fill_w = bar_w * maxf(0.0, float(dreadnought.hp) / float(dreadnought.max_hp))
			var d_bar_col: Color = GameConfig.COLOR_CYAN if dreadnought.is_shielded() else GameConfig.COLOR_GOLD
			draw_rect(Rect2(bx, by, fill_w, bar_h), d_bar_col, true)
			draw_rect(Rect2(bx, by, bar_w, bar_h), GameConfig.COLOR_CYAN if dreadnought.is_shielded() else GameConfig.COLOR_WHITE, false, 2.0)

	# Boss Titan (Final Ship 3D SubViewport with Sprite Fallback)
	if boss != null:
		var drawn_boss_3d := false
		if is_live_display and boss_3d != null and boss_3d.has_3d_model():
			var b_vp_tex: Texture2D = boss_3d.get_texture()
			if b_vp_tex != null:
				var is_flashing := boss.hit_flash > 0.0 or (boss_dying and int(level_time * 24.0) % 2 == 0)
				var mod_b := Color(2.8, 2.8, 2.8, 1.0) if is_flashing else Color.WHITE
				draw_texture_rect(
					b_vp_tex,
					Rect2(boss.x - 480.0, boss.y - 210.0, 960.0, 420.0),
					false,
					mod_b
				)
				drawn_boss_3d = true
		if not drawn_boss_3d:
			var b_tex = boss.flash_tex if (boss.hit_flash > 0.0 or (boss_dying and int(level_time * 24.0) % 2 == 0)) else boss.tex
			if b_tex != null:
				draw_texture(b_tex, Vector2(boss.x - b_tex.get_width() * 0.5, boss.y - b_tex.get_height() * 0.5))
		if not boss_dying:
			for cl in boss.charging_lasers:
				var bc_off: Vector2 = cl["offset"]
				var bc_prog: float = clampf(float(cl["age"]) / maxf(float(cl["charge_time"]), 0.001), 0.0, 1.0)
				GameConfig.draw_boss_laser_charge(self, boss.x + bc_off.x, boss.y + bc_off.y, float(cl["aim_angle"]), bc_prog, level_time)
			if boss.is_shielded():
				var b_sc: Vector2 = boss.get_shield_center()
				var b_sr: Vector2 = boss.get_shield_radii()
				var b_rem: float = boss.emergency_shield_timer / maxf(boss.emergency_shield_duration, 0.001)
				GameConfig.draw_boss_emergency_shield(self, b_sc.x, b_sc.y, b_sr.x, b_sr.y, level_time, b_rem, boss.shield_hit_flash, boss.shield_hit_angle)

	# Player Ship & Energy Deflector Shield Impact Bubble
	if player != null:
		var show_player = true
		if player.invuln_timer > 0.0 and player.shield_hit_timer <= 0.24 and not player.is_dodging() and not boss_dying and not victory:
			if int(level_time * 20.0) % 2 == 0:
				show_player = false

		if show_player:
			var drawn_3d: bool = false
			if player_3d != null and player_3d.has_3d_model() and DisplayServer.get_name() != "headless":
				var vp_tex: Texture2D = player_3d.get_texture()
				if vp_tex != null:
					var mod_col := Color.WHITE
					if player.is_dodging():
						mod_col = Color(1.6, 1.8, 2.0, 1.0)
					elif player.shield_hit_timer > 0.36:
						mod_col = Color(1.30, 1.68, 1.95, 1.0) if player.hp >= 2 else Color(1.95, 1.18, 1.15, 1.0)
					var draw_w: float = 152.0
					var draw_h: float = 86.0
					draw_texture_rect(
						vp_tex,
						Rect2(player.x - draw_w * 0.5, player.y - draw_h * 0.5, draw_w, draw_h),
						false,
						mod_col
					)
					drawn_3d = true
			if not drawn_3d:
				var p_tex = player.get_current_frame(player.is_dodging() or player.shield_hit_timer > 0.36)
				if p_tex != null:
					draw_texture(p_tex, Vector2(player.x - p_tex.get_width() * 0.5, player.y - p_tex.get_height() * 0.5))

			# Charged dodge exhaust nozzle flare (visible when dodge is ready; absent during amber cooldown)
			if (player.is_dodge_ready() or player.dodge_ready_flash > 0.0) and not player.is_dodging() and GameConfig.tex_photon_flare != null:
				var fl_boost: float = clampf(player.dodge_ready_flash / 0.32, 0.0, 1.0)
				var noz_x: float = player.x - 46.0
				var noz_y: float = player.y + 2.0
				var fl_sz: float = 24.0 + 22.0 * fl_boost + 2.5 * sin(level_time * 18.0)
				var fl_alpha: float = 0.48 + 0.48 * fl_boost
				draw_texture_rect(
					GameConfig.tex_photon_flare,
					Rect2(noz_x - fl_sz * 0.5, noz_y - fl_sz * 0.5, fl_sz, fl_sz),
					false,
					Color(0.25, 0.96, 1.0, fl_alpha)
				)

			if player.gun_glow_timer > 0.0:
				var g_ratio = clampf(player.gun_glow_timer / 0.10, 0.0, 1.0)
				var gun_offsets = [Vector2(24.0, -14.5), Vector2(24.0, 14.5)]
				if player.bank_state == "bank_left":
					gun_offsets = [Vector2(24.0, -18.0), Vector2(24.0, 10.5)]
				elif player.bank_state == "bank_right":
					gun_offsets = [Vector2(24.0, -10.5), Vector2(24.0, 18.0)]
				for goff in gun_offsets:
					GameConfig.draw_photon_muzzle_flash(self, player.x + goff.x, player.y + goff.y, g_ratio, 1.0)

			if not victory and not boss_dying:
				_draw_player_missile_indicator()

		if player.shield_hit_timer > 0.0:
			var sh_prog: float = 1.0 - clampf(player.shield_hit_timer / maxf(player.shield_hit_duration, 0.001), 0.0, 1.0)
			GameConfig.draw_player_shield_hit(self, player.x, player.y, sh_prog, player.shield_hit_angle, player.hp)

		if player.shield_bar_timer > 0.0 and not victory and not boss_dying:
			_draw_player_floating_shield_bar()

	for scw in shield_collapse_waves:
		var scw_prog: float = float(scw["age"]) / maxf(float(scw["max_age"]), 0.001)
		GameConfig.draw_shield_collapse_wave(self, scw["x"], scw["y"], scw_prog)

	# Laser Impact Shock-Rings & Torpedo Detonation Shockwaves
	for imp in laser_impacts:
		var prog: float = float(imp["age"]) / maxf(float(imp["max_age"]), 0.001)
		GameConfig.draw_photon_impact_flash(self, imp["x"], imp["y"], prog, 1.0)

	for mb in missile_blasts:
		var m_prog: float = float(mb["age"]) / maxf(float(mb["max_age"]), 0.001)
		GameConfig.draw_missile_blast(self, mb["x"], mb["y"], m_prog, 1.0)

	# Enemy Bullets (Crimson Plasma Comets, Gold Railgun Lances, Magenta Nova Pulsars & High-Speed Targeted Overload Lasers)
	for eb in enemy_bullets:
		if String(eb.get("kind", "")) == "targeted_laser":
			GameConfig.draw_boss_targeted_laser(
				self,
				eb["x"],
				eb["y"],
				float(eb.get("vx", -1120.0)),
				float(eb.get("vy", 0.0)),
				level_time
			)
		else:
			GameConfig.draw_enemy_projectile(
				self,
				eb["x"],
				eb["y"],
				float(eb.get("vx", -520.0)),
				float(eb.get("vy", 0.0)),
				float(eb["radius"]),
				eb.get("color", GameConfig.COLOR_RED),
				level_time
			)

	# Particles
	for p in particles:
		draw_rect(Rect2(p["x"], p["y"], p["size"], p["size"]), p["color"], true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Floating Arcade Kill Score Pop-Ups
	for sp in score_popups:
		var sp_prog: float = float(sp["age"]) / maxf(float(sp["max_age"]), 0.001)
		GameConfig.draw_score_popup(self, float(sp["x"]), float(sp["y"]), String(sp["text"]), sp_prog, String(sp["style"]))

	# HUD & Overlays
	_draw_hud()

	if paused:
		_draw_pause_overlay()
	elif game_over or victory:
		if entering_name or score_saved:
			_draw_end_overlay()
		else:
			_draw_cinematic_banner()


func _draw_player_floating_shield_bar() -> void:
	if player == null or player.shield_bar_timer <= 0.0:
		return

	var fade_a: float = (
		1.0
		if player.shield_bar_timer >= 0.75
		else pow(clampf(player.shield_bar_timer / 0.75, 0.0, 1.0), 1.35)
	)
	if fade_a <= 0.01:
		return

	var elapsed: float = maxf(0.0, player.shield_bar_duration - player.shield_bar_timer)
	var lift_y: float = 5.0 * (1.0 - exp(-10.0 * elapsed))

	var pod_w: float = 78.0
	var pod_h: float = 16.0
	var pod_x: float = player.x - pod_w * 0.5
	var pod_y: float = maxf(10.0, player.y - 68.0 - lift_y)

	var is_critical: bool = (player.hp <= 1)
	var crit_pulse: float = 0.78 + 0.22 * sin(level_time * 18.0)

	var bg_col := Color(0.03, 0.05, 0.12, 0.78 * fade_a)
	var border_col: Color = (
		Color(0.06, 0.84, 1.0, 0.86 * fade_a)
		if not is_critical
		else Color(1.0, 0.16, 0.18, 0.94 * crit_pulse * fade_a)
	)
	draw_rect(Rect2(pod_x, pod_y, pod_w, pod_h), bg_col, true)
	draw_rect(Rect2(pod_x, pod_y, pod_w, pod_h), border_col, false, 1.2)

	var max_shields: int = maxi(1, player.max_hp - 1) # 3 absorbable shield hits before bare hull
	var shields_left: int = maxi(0, player.hp - 1)
	var slot_w: float = 20.0
	var slot_h: float = 8.0
	var gap: float = 4.0
	var start_x: float = pod_x + 5.0
	var slot_y: float = pod_y + 4.0

	for i in range(max_shields):
		var sx: float = start_x + float(i) * (slot_w + gap)
		var slot_rect := Rect2(sx, slot_y, slot_w, slot_h)

		if i < shields_left:
			draw_rect(slot_rect, Color(0.08, 0.88, 1.0, fade_a), true)
			draw_rect(Rect2(sx + 2.0, slot_y + 1.5, slot_w - 4.0, 2.5), Color(0.92, 1.0, 1.0, 0.88 * fade_a), true)
			draw_rect(slot_rect, Color(0.75, 0.98, 1.0, fade_a), false, 1.0)
		else:
			var empty_bg: Color = (
				Color(0.08, 0.09, 0.18, 0.82 * fade_a)
				if not is_critical
				else Color(0.28, 0.04, 0.06, 0.86 * crit_pulse * fade_a)
			)
			var empty_rim: Color = (
				Color(0.25, 0.34, 0.50, 0.80 * fade_a)
				if not is_critical
				else Color(0.95, 0.18, 0.20, 0.85 * crit_pulse * fade_a)
			)
			draw_rect(slot_rect, empty_bg, true)
			draw_rect(slot_rect, empty_rim, false, 1.0)

			if i == hud_shield_lost_seg and hud_shield_flash_timer > 0.0:
				var f_t: float = clampf(hud_shield_flash_timer / 0.45, 0.0, 1.0)
				var flash_c: Color = (
					Color(0.14, 0.92, 1.0, 1.0).lerp(Color(1.0, 1.0, 1.0, 1.0), f_t * 0.65)
					if not is_critical
					else Color(1.0, 0.12, 0.14, 1.0).lerp(Color(1.0, 0.90, 0.86, 1.0), f_t * 0.55)
				)
				flash_c.a = f_t * 0.92 * fade_a
				draw_rect(slot_rect, flash_c, true)
				var exp_pad: float = (1.0 - f_t) * 4.5
				var burst_rim: Color = (
					Color(0.85, 0.98, 1.0, f_t * 0.90 * fade_a)
					if not is_critical
					else Color(1.0, 0.25, 0.22, f_t * 0.95 * fade_a)
				)
				draw_rect(
					Rect2(sx - exp_pad, slot_y - exp_pad, slot_w + exp_pad * 2.0, slot_h + exp_pad * 2.0),
					burst_rim,
					false,
					1.5
				)


func _draw_player_missile_indicator() -> void:
	if player == null:
		return
	var pod_w: float = 78.0
	var pod_h: float = 18.0
	var pod_x: float = player.x - pod_w * 0.5
	var pod_y: float = player.y + 52.0

	draw_rect(Rect2(pod_x, pod_y, pod_w, pod_h), Color8(8, 12, 30, 185), true)
	draw_rect(Rect2(pod_x, pod_y, pod_w, pod_h), Color8(0, 190, 235, 200), false, 1.0)

	var slot_w: float = 20.0
	var slot_h: float = 10.0
	var gap: float = 4.0
	var start_x: float = pod_x + 5.0
	var slot_y: float = pod_y + 4.0

	for i in range(player.max_missile_charges):
		var sx = start_x + i * (slot_w + gap)
		var slot_rect = Rect2(sx, slot_y, slot_w, slot_h)

		if i < player.missile_charges:
			draw_rect(slot_rect, GameConfig.COLOR_GOLD, true)
			draw_rect(Rect2(sx + 2.0, slot_y + 2.0, slot_w - 4.0, 3.0), GameConfig.COLOR_WHITE, true)
			draw_rect(slot_rect, GameConfig.COLOR_WHITE, false, 1.0)
		elif i == player.missile_charges:
			draw_rect(slot_rect, Color8(25, 30, 55), true)
			var ratio = clampf(player.missile_recharge_timer / player.missile_recharge_time, 0.0, 1.0)
			var fill_w = slot_w * ratio
			if fill_w > 0.0:
				draw_rect(Rect2(sx, slot_y, fill_w, slot_h), GameConfig.COLOR_CYAN, true)
			draw_rect(slot_rect, GameConfig.COLOR_CYAN, false, 1.0)
		else:
			draw_rect(slot_rect, Color8(18, 22, 42), true)
			draw_rect(slot_rect, Color8(60, 75, 110), false, 1.0)


func _draw_cinematic_banner() -> void:
	var cx = GameConfig.SCREEN_WIDTH * 0.5
	if game_over:
		GameConfig.draw_glow_text(
			self,
			"SHIP DESTROYED",
			cx,
			GameConfig.SCREEN_HEIGHT * 0.5 - 30.0,
			46,
			GameConfig.COLOR_RED,
			Color8(120, 0, 0),
			"center",
			level_time
		)
	elif victory:
		GameConfig.draw_glow_text(
			self,
			"TITAN OBLITERATED - AREA SECURED!",
			cx,
			190.0,
			34,
			GameConfig.COLOR_GOLD,
			Color8(140, 60, 0),
			"center",
			level_time
		)


func _draw_hud() -> void:
	# Minimal Top-Right Score Box (no full-width top HUD bar)
	var score_digits: String = "%07d" % score
	var font: Font = GameConfig.get_pixel_font()
	var digits_w: float = font.get_string_size(score_digits, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	var box_w: float = maxf(182.0, digits_w + 30.0)
	var box_h: float = 38.0
	var box_x: float = GameConfig.SCREEN_WIDTH - box_w - 22.0
	var box_y: float = 18.0
	var score_box := Rect2(box_x, box_y, box_w, box_h)

	draw_rect(score_box, Color(0.03, 0.05, 0.13, 0.68), true)
	draw_rect(score_box, Color(0.08, 0.82, 0.98, 0.52), false, 1.5)
	# Minimal corner ticks
	var tk: float = 5.0
	var tick_col := Color(1.0, 0.84, 0.18, 0.82)
	draw_line(Vector2(box_x, box_y), Vector2(box_x + tk, box_y), tick_col, 2.0)
	draw_line(Vector2(box_x, box_y), Vector2(box_x, box_y + tk), tick_col, 2.0)
	draw_line(Vector2(box_x + box_w - tk, box_y + box_h), Vector2(box_x + box_w, box_y + box_h), tick_col, 2.0)
	draw_line(Vector2(box_x + box_w, box_y + box_h - tk), Vector2(box_x + box_w, box_y + box_h), tick_col, 2.0)

	GameConfig.draw_text(
		self,
		score_digits,
		box_x + box_w * 0.5,
		box_y + box_h * 0.5,
		19,
		GameConfig.COLOR_GOLD,
		"center"
	)

	# Boss HP Bar (centered cleanly near top-center with generous margin from the minimal score box)
	var boss_bar_shown: bool = (boss != null and not boss_dying)
	if boss_bar_shown:
		var cx = GameConfig.SCREEN_WIDTH * 0.5
		var b_w: float = 680.0
		var b_h: float = 20.0
		var bx = cx - b_w * 0.5
		var by = 36.0
		var b_shielded: bool = boss.is_shielded()
		var b_title: String = "OMEGA TITAN DREADNOUGHT - EMERGENCY SHIELD ACTIVE" if b_shielded else "OMEGA TITAN DREADNOUGHT"
		var b_title_col: Color = GameConfig.COLOR_CYAN if b_shielded else GameConfig.COLOR_RED
		GameConfig.draw_text(self, b_title, cx, by - 12.0, 15, b_title_col, "center")
		draw_rect(Rect2(bx, by, b_w, b_h), Color8(35, 10, 20, 215), true)
		var fill = b_w * maxf(0.0, float(boss.hp) / float(boss.max_hp))
		var b_fill_col: Color = GameConfig.COLOR_CYAN.lerp(GameConfig.COLOR_MAGENTA, 0.35 + 0.35 * sin(level_time * 12.0)) if b_shielded else GameConfig.COLOR_RED
		draw_rect(Rect2(bx, by, fill, b_h), b_fill_col, true)
		draw_rect(Rect2(bx, by, b_w, b_h), GameConfig.COLOR_CYAN if b_shielded else GameConfig.COLOR_GOLD, false, 2.0)

	# Emergency Shield Energy Overload Flashing Warning Alert
	var alert_top_y: float = 78.0 if boss_bar_shown else 54.0
	if overload_warning_timer > 0.0:
		var cx_w: float = GameConfig.SCREEN_WIDTH * 0.5
		var strobe: float = 0.5 + 0.5 * sin(level_time * 22.0)
		var fade_env: float = clampf(overload_warning_timer / 0.45, 0.0, 1.0)
		var alert_a: float = (0.42 + 0.58 * strobe) * fade_env
		var banner_w: float = 980.0
		var banner_h: float = 54.0
		var banner_rect := Rect2(cx_w - banner_w * 0.5, alert_top_y, banner_w, banner_h)
		draw_rect(banner_rect, Color(0.14, 0.02, 0.08, 0.80 * fade_env), true)
		var border_c: Color = GameConfig.COLOR_RED.lerp(GameConfig.COLOR_GOLD, strobe * 0.55)
		border_c.a = alert_a
		draw_rect(banner_rect, border_c, false, 2.5)
		draw_line(
			Vector2(banner_rect.position.x + 18.0, banner_rect.position.y + 6.0),
			Vector2(banner_rect.end.x - 18.0, banner_rect.position.y + 6.0),
			Color(1.0, 0.85, 0.25, 0.65 * alert_a),
			1.5
		)
		draw_line(
			Vector2(banner_rect.position.x + 18.0, banner_rect.end.y - 6.0),
			Vector2(banner_rect.end.x - 18.0, banner_rect.end.y - 6.0),
			Color(1.0, 0.85, 0.25, 0.65 * alert_a),
			1.5
		)
		if strobe > 0.22:
			var txt_col: Color = GameConfig.COLOR_RED.lerp(GameConfig.COLOR_GOLD, strobe * 0.72)
			GameConfig.draw_glow_text(
				self,
				overload_warning_text,
				cx_w,
				alert_top_y + banner_h * 0.5,
				22,
				txt_col,
				Color8(120, 10, 35),
				"center",
				level_time
			)
		if strobe > 0.48:
			draw_rect(
				Rect2(0.0, 0.0, GameConfig.SCREEN_WIDTH, GameConfig.SCREEN_HEIGHT),
				Color(1.0, 0.12, 0.32, 0.55 * fade_env),
				false,
				6.0
			)
	elif phase_banner_timer > 0.0:
		var cx = GameConfig.SCREEN_WIDTH * 0.5
		var col = GameConfig.COLOR_RED if current_phase == 4 else GameConfig.COLOR_GOLD
		GameConfig.draw_glow_text(self, phase_banner_text, cx, alert_top_y + 26.0, 28, col, Color8(90, 20, 60), "center", level_time)

	if boss_warning_timer > 0.0 and int(level_time * 6.0) % 2 == 0:
		draw_rect(Rect2(0.0, 0.0, GameConfig.SCREEN_WIDTH, GameConfig.SCREEN_HEIGHT), Color8(255, 20, 60), false, 8.0)


func _draw_pause_overlay() -> void:
	draw_rect(Rect2(0.0, 0.0, GameConfig.SCREEN_WIDTH, GameConfig.SCREEN_HEIGHT), Color8(4, 6, 18, 195), true)
	var cx = GameConfig.SCREEN_WIDTH * 0.5
	var cy = GameConfig.SCREEN_HEIGHT * 0.5

	var panel_rect = Rect2(cx - 320.0, cy - 210.0, 640.0, 420.0)
	GameConfig.draw_glass_panel(self, panel_rect, Color8(12, 16, 44, 240), GameConfig.COLOR_CYAN, GameConfig.COLOR_GOLD, 20.0, 3.0)
	GameConfig.draw_glow_text(self, "MISSION PAUSED", cx, cy - 140.0, 32, GameConfig.COLOR_GOLD, Color8(130, 50, 0), "center", level_time)

	pause_rects.clear()
	for idx in range(pause_options.size()):
		var label = pause_options[idx]
		var r = Rect2(cx - 230.0, cy - 55.0 + idx * 78.0, 460.0, 58.0)
		pause_rects.append(r)
		var is_sel = (idx == pause_index)
		draw_rect(r, Color8(36, 22, 82) if is_sel else Color8(16, 22, 52), true)
		draw_rect(r, GameConfig.COLOR_GOLD if is_sel else GameConfig.COLOR_CYAN, false, 3.0 if is_sel else 2.0)
		GameConfig.draw_text(self, label, cx, r.position.y + r.size.y * 0.5, 18, GameConfig.COLOR_WHITE if is_sel else GameConfig.COLOR_MUTED, "center")


func _draw_end_overlay() -> void:
	var overlay_alpha = 145 if game_over else 210
	draw_rect(Rect2(0.0, 0.0, GameConfig.SCREEN_WIDTH, GameConfig.SCREEN_HEIGHT), Color8(4, 6, 18, overlay_alpha), true)
	var cx = GameConfig.SCREEN_WIDTH * 0.5
	var cy = GameConfig.SCREEN_HEIGHT * 0.5

	var panel_rect = Rect2(cx - 460.0, cy - 350.0, 920.0, 700.0)
	var border_col = GameConfig.COLOR_GOLD if victory else GameConfig.COLOR_RED
	GameConfig.draw_glass_panel(self, panel_rect, Color8(10, 14, 38, 235), border_col, GameConfig.COLOR_CYAN, 24.0, 3.0)

	var title = "MISSION ACCOMPLISHED!" if victory else "MISSION FAILED"
	var title_col = GameConfig.COLOR_GOLD if victory else GameConfig.COLOR_RED
	GameConfig.draw_glow_text(self, title, cx, cy - 280.0, 38, title_col, Color8(80, 10, 30), "center", level_time)

	var sub = "CHARITY DAY - 11TH NOVEMBER - TITAN DEFEATED" if victory else "YOUR SHIP WAS LOST IN THE NEBULA"
	GameConfig.draw_text(self, sub, cx, cy - 228.0, 16, GameConfig.COLOR_CYAN, "center")
	GameConfig.draw_text(self, "FINAL SCORE: %s" % GameConfig.format_commas(score), cx, cy - 178.0, 28, GameConfig.COLOR_WHITE, "center")

	if entering_name:
		GameConfig.draw_text(self, "ENTER PILOT CALLSIGN:", cx, cy - 125.0, 16, GameConfig.COLOR_GOLD, "center")

		var box_rect = Rect2(cx - 220.0, cy - 95.0, 440.0, 56.0)
		draw_rect(box_rect, Color8(18, 24, 58), true)
		draw_rect(box_rect, GameConfig.COLOR_CYAN, false, 3.0)
		var cursor = "_" if int(level_time * 3.0) % 2 == 0 else " "
		GameConfig.draw_text(self, pilot_name + cursor, cx, box_rect.position.y + box_rect.size.y * 0.5, 26, GameConfig.COLOR_GOLD, "center")

		kb_key_rects.clear()
		var key_w: float = 88.0
		var key_h: float = 48.0
		var gap_x: float = 12.0
		var gap_y: float = 10.0
		var grid_w: float = 7.0 * key_w + 6.0 * gap_x
		var start_x: float = cx - grid_w * 0.5
		var start_y: float = cy - 20.0

		for r_idx in range(ALPHA_GRID.size()):
			var row = ALPHA_GRID[r_idx]
			for c_idx in range(row.size()):
				var key_label = row[c_idx]
				var kx = start_x + c_idx * (key_w + gap_x)
				var ky = start_y + r_idx * (key_h + gap_y)
				var krect = Rect2(kx, ky, key_w, key_h)
				kb_key_rects.append({"rect": krect, "r": r_idx, "c": c_idx, "key": key_label})

				var is_sel = (kb_row == r_idx and kb_col == c_idx)
				var bg_c = Color8(48, 28, 105) if is_sel else Color8(18, 24, 56)
				if key_label == "DEL":
					bg_c = Color8(95, 25, 45) if is_sel else Color8(45, 16, 30)
				draw_rect(krect, bg_c, true)
				draw_rect(krect, GameConfig.COLOR_GOLD if is_sel else GameConfig.COLOR_CYAN, false, 3.0 if is_sel else 1.0)

				var font_sz = 16 if key_label.length() > 1 else 20
				var txt_col = GameConfig.COLOR_GOLD if is_sel else GameConfig.COLOR_WHITE
				GameConfig.draw_text(self, key_label, krect.position.x + krect.size.x * 0.5, krect.position.y + krect.size.y * 0.5, font_sz, txt_col, "center")

		kb_confirm_rect = Rect2(cx - 220.0, start_y + 4.0 * (key_h + gap_y) + 6.0, 440.0, 52.0)
		var is_conf_sel = (kb_row == 4)
		draw_rect(kb_confirm_rect, Color8(24, 88, 56) if is_conf_sel else Color8(16, 48, 36), true)
		draw_rect(kb_confirm_rect, GameConfig.COLOR_GOLD if is_conf_sel else GameConfig.COLOR_GREEN, false, 3.0 if is_conf_sel else 2.0)
		GameConfig.draw_text(
			self,
			"CONFIRM CALLSIGN",
			cx,
			kb_confirm_rect.position.y + kb_confirm_rect.size.y * 0.5,
			20,
			GameConfig.COLOR_GOLD if is_conf_sel else GameConfig.COLOR_WHITE,
			"center"
		)
	else:
		GameConfig.draw_text(self, "SCORE RECORDED FOR PILOT '%s'!" % pilot_name, cx, cy - 60.0, 20, GameConfig.COLOR_GREEN, "center")
		end_menu_rects.clear()
		var opts = ["PLAY AGAIN" if victory else "RESTART MISSION", "RETURN TO MENU"]
		for idx in range(opts.size()):
			var label = opts[idx]
			var r = Rect2(cx - 350.0 + idx * 370.0, cy + 80.0, 330.0, 66.0)
			end_menu_rects.append(r)
			var is_sel = (idx == end_menu_index)
			draw_rect(r, Color8(36, 22, 82) if is_sel else Color8(16, 22, 52), true)
			draw_rect(r, GameConfig.COLOR_GOLD if is_sel else GameConfig.COLOR_CYAN, false, 3.0 if is_sel else 2.0)
			GameConfig.draw_text(self, label, r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5, 18, GameConfig.COLOR_WHITE if is_sel else GameConfig.COLOR_MUTED, "center")
