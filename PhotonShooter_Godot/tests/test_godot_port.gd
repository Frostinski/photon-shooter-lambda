extends SceneTree

var main_node: Node = null
var frame_step: int = 0


func _initialize() -> void:
	print("=== Starting Photon Shooter Lambda Godot 4.7.2 Verification Suite ===")

	var main_packed: PackedScene = load("res://scenes/main.tscn")
	assert(main_packed != null, "Failed to load res://scenes/main.tscn")

	main_node = main_packed.instantiate()
	root.add_child(main_node)


func _process(_delta: float) -> bool:
	frame_step += 1

	if frame_step == 2:
		# 1. Verify GameConfig assets & spritesheets
		var gc = root.get_node("GameConfig")
		assert(gc != null, "GameConfig autoload missing")
		assert(gc.get_pixel_font() != null, "Pixel font failed to load")
		assert(gc.get_texture("logo") != null, "Logo texture failed to load")
		assert(gc.get_texture("menu_bg") != null, "Menu BG texture failed to load")
		assert(gc.get_texture("menu_nebula_loop") != null, "Menu looping nebula texture failed to load")
		assert(gc.menu_bg_frames.size() == 8, "Expected 8 animated menu background frames")

		var player_data = gc.get_player_frames(Vector2i(132, 95))
		assert(player_data["frames"].has("bank_left") and player_data["frames"].has("neutral") and player_data["frames"].has("bank_right"), "Player banking states missing")
		assert(player_data["frames"]["neutral"]["cruise"].size() == 4, "Player cruise frames should have 4 frames")

		var test_3d_ship = gc.instantiate_player_ship_3d()
		assert(test_3d_ship != null and test_3d_ship is Node3D, "Meshy 3D player ship (res://assets/models/player_ship.glb) failed to instantiate")
		test_3d_ship.free()

		for etype in ["scout", "raider", "dreadnought", "boss_titan"]:
			var test_enemy_3d = gc.instantiate_enemy_ship_3d(etype)
			assert(test_enemy_3d != null and test_enemy_3d is Node3D, "Meshy 3D enemy ship (%s) failed to instantiate" % etype)
			test_enemy_3d.free()

		var scout_data = gc.get_scout_frames(Vector2i(88, 70))
		assert(scout_data["frames"].size() == 3 and scout_data["frames"][0].size() == 4, "Scout 4x3 spritesheet slicing failed")

		var raider_data = gc.get_raider_frames(Vector2i(104, 84))
		assert(raider_data["frames"].size() == 3 and raider_data["frames"][0].size() == 4, "Raider 4x3 spritesheet slicing failed")
		print("[PASS] GameConfig textures, fonts, and Player/Scout/Raider spritesheets verified.")

		# 2. Verify SoundManager SFX & Music
		var sm = root.get_node("SoundManager")
		assert(sm != null, "SoundManager autoload missing")
		assert(sm.sfx_streams.size() == 13 and sm.sfx_streams.has("dodge_ready"), "Expected 13 SFX streams including dodge_ready audio prompt")
		print("[PASS] SoundManager 13 SFX streams (including dodge_ready chime) and music player verified.")

		# 3. Verify Splash State -> Menu State transition
		assert(main_node.current_state_name == "SPLASH", "Initial state should be SPLASH")
		var splash = main_node.current_state
		splash.state_update(0.5)
		splash._skip_to_menu()
		assert(main_node.current_state_name == "MENU", "Should transition to MENU after skip")
		print("[PASS] Splash State update, draw, and skip to MENU verified.")

	elif frame_step == 4:
		# 4. Verify Menu State & High Scores State
		var menu = main_node.current_state
		var initial_scroll = menu.nebula_scroll_x
		for _i in range(6):
			menu.state_update(0.1)
		assert(menu.bg_frames.size() == 8, "Menu should have 8 animated foreground ship frames")
		assert(menu.nebula_loop_tex != null and menu.nebula_scroll_x > initial_scroll, "Menu nebula background should scroll left and loop")
		main_node.set_state("HIGH_SCORES")
		var hs = main_node.current_state
		hs.state_update(0.25)
		var hsm = root.get_node("HighScoreManager")
		assert(hsm != null and hsm.DEFAULT_SCORES.is_empty(), "Scoreboard DEFAULT_SCORES must be blank with 0 entries")
		hsm.clear_scores()
		assert(hsm.scores.is_empty() and hsm.get_top_score() == 0, "Cleared scoreboard must have 0 entries and 0 top score")
		hsm.add_score("ACE", 12300)
		assert(hsm.scores.size() == 1 and hsm.get_top_score() == 12300, "Adding a score to blank scoreboard should set #1")
		hsm.clear_scores()
		assert(hsm.scores.is_empty(), "clear_scores() must restore blank scoreboard")
		print("[PASS] Animated Menu State (looping nebula/starfield scroll + subtle enemy light glow) and Blank High Scores State verified.")

	elif frame_step == 6:
		# 5. Verify How To Play Demo State (All 4 steps + launch)
		main_node.set_state("HOW_TO_PLAY")
		var htp = main_node.current_state
		for step_i in range(4):
			htp._advance_step(step_i)
			for _f in range(12):
				htp.state_update(0.1)
		print("[PASS] How To Play 4-step interactive demo verified.")

	elif frame_step == 8:
		# 6. Verify Game State mechanics & .gdshader Space Backdrop
		main_node.set_state("GAME")
		var game = main_node.current_state
		assert(game.player != null, "Player should be initialized in GAME state")
		assert(game.player_3d != null and game.player_3d.has_3d_model(), "PlayerShip3D SubViewport and 3D GLB model should be active in GAME state")
		assert(game.scout_3d != null and game.scout_3d.has_3d_model(), "Scout 3D SubViewport should have 3D GLB model")
		assert(game.raider_3d_neutral != null and game.raider_3d_neutral.has_3d_model(), "Raider 3D SubViewport should have 3D GLB model")
		assert(game.dreadnought_3d != null and game.dreadnought_3d.has_3d_model(), "Dreadnought 3D SubViewport should have 3D GLB model")
		assert(game.boss_3d != null and game.boss_3d.has_3d_model(), "Boss Titan 3D SubViewport should have 3D GLB model")
		game.player_3d.update_ship_pose(0.2, -300.0, "bank_left", "boost", 1.0, false, 0.0)
		assert(game.player_3d.current_roll_deg < 26.0, "PlayerShip3D should roll toward bank_left angle when moving up")
		game.player_3d.update_ship_pose(0.5, 300.0, "bank_right", "boost", 1.5, false, 0.0)
		assert(game.player_3d.current_roll_deg > 26.0, "PlayerShip3D should roll toward bank_right angle when moving down")
		assert(game.backdrop_rect != null and game.backdrop_material != null, "SpaceBackdrop ColorRect and ShaderMaterial should be initialized")
		assert(game.backdrop_material.shader != null, "space_backdrop.gdshader should be compiled and attached")
		assert(absf(float(game.backdrop_material.get_shader_parameter("scroll_speed")) - 0.08) < 0.001, "scroll_speed uniform mismatch")
		assert(absf(float(game.backdrop_material.get_shader_parameter("star_density")) - 1.0) < 0.001, "star_density uniform mismatch")
		assert(int(game.backdrop_material.get_shader_parameter("enable_sun")) == 1, "Blue Giant sun uniform should be enabled on SpaceBackdrop")

		# Verify continuous multi-angle fluid Interceptor banking + dynamic Blue Giant solar tracking + live 3D laser reflections
		var test_raider_vp = game.raider_3d_pool[0]
		assert(game.raider_3d_pool.size() >= 6 and game.scout_3d_pool.size() >= 6, "Per-instance 3D SubViewport pools should be initialized")
		var prev_roll: float = -999.0
		for test_vy in [-120.0, -60.0, -25.0, 0.0, 25.0, 60.0, 120.0]:
			test_raider_vp.reset_pose_for_spawn(test_vy, 120.0)
			test_raider_vp.update_pose(0.1, test_vy, "neutral", 0.0, false, false, 120.0)
			assert(test_raider_vp.current_roll_deg > prev_roll + 2.5, "Interceptor 3D banking must smoothly interpolate across intermediate vy values rather than snapping")
			prev_roll = test_raider_vp.current_roll_deg

		test_raider_vp.update_dynamic_lighting(Vector2(600.0, 750.0), Vector2(164.0, 112.0), Vector2(1500.0, 216.0), [])
		var sun_basis_a: Basis = test_raider_vp.sun_light.global_basis
		assert(not test_raider_vp.weapon_lights_3d[0].visible, "Weapon reflection OmniLight3D should be hidden when no projectiles are nearby")
		test_raider_vp.update_dynamic_lighting(
			Vector2(1750.0, 650.0),
			Vector2(164.0, 112.0),
			Vector2(1500.0, 216.0),
			[{"pos": Vector2(1690.0, 650.0), "color": Color(0.12, 0.90, 1.0), "energy": 2.4, "z": 0.68, "range": 2.65}]
		)
		var sun_basis_b: Basis = test_raider_vp.sun_light.global_basis
		assert(sun_basis_a.z.distance_to(sun_basis_b.z) > 0.25, "SunLight 3D shadow vector must dynamically track ship screen position relative to Blue Giant")
		assert(test_raider_vp.weapon_lights_3d[0].visible and test_raider_vp.weapon_lights_3d[0].light_energy > 2.0, "Nearby Photon Plasma Lance must activate real-time 3D OmniLight3D hull reflection")
		assert(absf(game.player.primary_fire_rate - (0.175 / 1.2)) < 0.0001, "Player laser fire rate (+20%) mismatch")
		assert(absf(game.player.missile_recharge_time - 2.7) < 0.0001, "Player missile recharge time (2.7s) mismatch")
		assert(game.player.max_missile_charges == 3 and game.player.missile_charges == 3, "Player 3-charge missile system mismatch")

		# Test Scout Striker (enter -> hover -> fire 3-shot spread -> retreat) & Raider Sweep (sine wave + checkpoints)
		var scout = game.EnemyShip.new("scout", 1800.0, 500.0, game.enemy_sprites, 1.0, 1.0, 0.0, "spread")
		var scout_bullets: Array = []
		assert(scout.state == "enter" and scout.hp == 20, "Scout should start in enter state with 20 base HP")
		for _s in range(30):
			scout.update(0.05, game.player, scout_bullets, 1)
		assert(scout.state == "hover", "Scout should transition to hover state at target_x (~1440)")
		for _s in range(40):
			scout.update(0.05, game.player, scout_bullets, 1)
		assert(scout.has_fired and scout_bullets.size() == 3, "Scout should charge and fire a single 3-shot spread during hover")
		assert(scout.state == "retreat", "Scout should transition to retreat state after hover_duration")

		# Test Raider banking states & single X-checkpoint firing in GameState
		var raider = game.EnemyShip.new("raider", 1450.0, 500.0, game.enemy_sprites, 1.0)
		assert(raider.hp == 25 and raider.score_value == 300 and raider.fire_checkpoints.size() == 1, "Raider (Interceptor) should have 25 base HP, 300 score_value, and 1 X fire checkpoint")
		raider.amp_y = 140.0
		raider.freq_y = 2.5
		raider.phase = 0.0
		var dummy_bullets: Array = []
		raider.update(0.05, game.player, dummy_bullets, 2)
		assert(raider.bank_state == "bank_right", "Raider moving down should use bank_right")
		raider.phase = PI
		raider.update(0.05, game.player, dummy_bullets, 2)
		assert(raider.bank_state == "bank_left", "Raider moving up should use bank_left")

		# Test smooth zero-jump entrance-to-strafing transition for both Dreadnought Destroyer and Boss Titan
		var test_dread = game.DreadnoughtShip.new(game.enemy_sprites)
		var d_bullets: Array = []
		var prev_dx: float = test_dread.x
		var prev_dy: float = test_dread.y
		var dread_crossed_enter := false
		for _step_d in range(320):
			var was_entering: bool = test_dread.entering
			test_dread.update(0.016, game.player, d_bullets)
			if was_entering and not test_dread.entering:
				dread_crossed_enter = true
				assert(absf(test_dread.y - prev_dy) < 0.01 and absf(test_dread.x - test_dread.target_x) < 0.01, "Dreadnought handoff frame must have 0.00px jump")
			assert(absf(test_dread.y - prev_dy) < 5.0, "Dreadnought Y must never jump when transitioning from entering to strafing")
			assert(absf(test_dread.x - prev_dx) < 6.0, "Dreadnought X must never jump when transitioning from entering to strafing")
			prev_dx = test_dread.x
			prev_dy = test_dread.y
		assert(dread_crossed_enter and absf(test_dread.y - 540.0) > 25.0, "Dreadnought should finish entering and smoothly ramp into vertical strafing")

		var test_titan = game.BossTitan.new(game.enemy_sprites)
		var t_bullets: Array = []
		var prev_tx: float = test_titan.x
		var prev_ty: float = test_titan.y
		var titan_crossed_enter := false
		for _step_t in range(420):
			var was_t_entering: bool = test_titan.entering
			test_titan.update(0.016, game.player, t_bullets)
			if was_t_entering and not test_titan.entering:
				titan_crossed_enter = true
				assert(absf(test_titan.y - prev_ty) < 0.01 and absf(test_titan.x - test_titan.target_x) < 0.01, "Boss Titan handoff frame must have 0.00px jump")
			assert(absf(test_titan.y - prev_ty) < 4.5, "Boss Titan Y must never jump when transitioning from entering to strafing")
			assert(absf(test_titan.x - prev_tx) < 5.5, "Boss Titan X must never jump when transitioning from entering to strafing")
			prev_tx = test_titan.x
			prev_ty = test_titan.y
		assert(titan_crossed_enter and absf(test_titan.y - 540.0) > 20.0, "Boss Titan should finish entering and smoothly ramp into vertical strafing")
		test_titan.x = 1555.0
		test_titan.y = 540.0
		assert(not test_titan.intersects_rect(Rect2(1555.0 - 350.0, 540.0 - 85.0, 28.0, 8.0)), "Empty space above Titan sloped prow must NOT register a hit")
		assert(not test_titan.intersects_rect(Rect2(1555.0 - 250.0, 540.0 - 65.0, 28.0, 8.0)), "Empty space above Titan forward deck must NOT register a hit")
		assert(not test_titan.intersects_rect(Rect2(1555.0 + 40.0, 540.0 - 128.0, 28.0, 8.0)), "Empty space above Titan tallest rear turret must NOT register a hit")
		assert(not test_titan.intersects_rect(Rect2(1555.0 + 280.0, 540.0 - 10.0, 28.0, 8.0)), "Titan rear thruster exhaust plumes must NOT register a hull hit")
		assert(test_titan.intersects_rect(Rect2(1555.0 - 405.0, 540.0 + 74.0, 28.0, 8.0)), "Titan lower shark-prow beak tip must register a hit")
		assert(test_titan.intersects_rect(Rect2(1555.0 - 340.0, 540.0 - 4.0, 28.0, 8.0)), "Titan bridge visor must register a hit")
		assert(test_titan.intersects_rect(Rect2(1555.0 + 30.0, 540.0 - 102.0, 28.0, 8.0)), "Titan tallest rear turret housing must register a hit")

		# Test Dreadnought 50% HP Emergency Shield, Overload Warning, High-Speed Targeted Lasers & +25% Phase 2 Fire Rate
		game.reset_game()
		game.dreadnought = game.DreadnoughtShip.new(game.enemy_sprites)
		game.dreadnought.entering = false
		game.dreadnought.x = 1515.0
		game.dreadnought.y = 540.0
		game.dreadnought.hp = 610
		game._hit_dreadnought(100, Vector2(1320.0, 540.0), true)
		assert(game.dreadnought.hp == 600 and game.dreadnought.is_shielded(), "Destroyer crossing 50% HP must clamp at 600 HP and engage Emergency Shield")
		assert(game.overload_warning_timer > 3.0 and "ENERGY OVERLOAD" in game.overload_warning_text, "Destroyer overload must trigger flashing energy overload warning")
		game._hit_dreadnought(100, Vector2(1300.0, 540.0), true)
		assert(game.dreadnought.hp == 600, "Destroyer must be 100% invulnerable to damage while Emergency Shield is active")
		var d_overload_bullets: Array = []
		game.player.y = 300.0
		for _ds in range(18):
			game.dreadnought.update(0.05, game.player, d_overload_bullets)
		assert(game.dreadnought.charging_lasers.size() == 1, "Destroyer must have 1 active targeting laser during tracking")
		var tracked_ang_1: float = float(game.dreadnought.charging_lasers[0]["aim_angle"])
		game.player.y = 820.0
		for _ds in range(6):
			game.dreadnought.update(0.05, game.player, d_overload_bullets)
		var locked_ang: float = float(game.dreadnought.charging_lasers[0]["aim_angle"])
		assert(absf(locked_ang - tracked_ang_1) > 0.15, "Targeting laser must track player during first 1.0s")
		# Now age is ~1.05s (>= 1.0s track_time): moving the player must NOT move the locked targeting laser
		game.player.y = 200.0
		game.dreadnought.update(0.05, game.player, d_overload_bullets)
		assert(absf(float(game.dreadnought.charging_lasers[0]["aim_angle"]) - locked_ang) < 0.0001, "Targeting laser must lock in place after 1.0s targeting")
		for _ds in range(3):
			game.dreadnought.update(0.05, game.player, d_overload_bullets)
		assert(d_overload_bullets.size() == 1 and game.dreadnought.charging_lasers.is_empty(), "Targeting laser must fire after locking and enter 0.5s gap before reacquiring")
		for _ds in range(9):
			game.dreadnought.update(0.05, game.player, d_overload_bullets)
		assert(game.dreadnought.charging_lasers.is_empty(), "Must maintain 0.5s gap before reacquiring player ship")
		game.dreadnought.update(0.05, game.player, d_overload_bullets)
		assert(game.dreadnought.charging_lasers.size() == 1, "Must reacquire player ship after 0.5s gap")
		for _ds in range(45):
			game.dreadnought.update(0.05, game.player, d_overload_bullets)
		var d_tlasers: int = 0
		for eb_d in d_overload_bullets:
			if String(eb_d.get("kind", "")) == "targeted_laser":
				d_tlasers += 1
				var d_spd: float = Vector2(float(eb_d["vx"]), float(eb_d["vy"])).length()
				assert(absf(d_spd - 1120.0) < 2.0 and float(eb_d["radius"]) >= 11.0, "Destroyer targeted overload lasers must be larger (radius 11.5) while keeping 1120 speed")
		assert(d_tlasers >= 2, "Destroyer must charge (1.0s tracking + lock + 0.5s gap) and fire targeted high-speed lasers during Emergency Shield")
		assert(not game.dreadnought.is_shielded() and game.dreadnought.enraged, "Destroyer Emergency Shield must drop after a few seconds into enraged Phase 2")
		game.dreadnought.attack_timer = 0.01
		game.dreadnought.update(0.02, game.player, d_overload_bullets)
		assert(absf(game.dreadnought.attack_timer - (1.2 / 1.25)) < 0.02, "Destroyer Phase 2 regular firing pattern must run 25% faster (1.2 / 1.25 = 0.96s)")

		# Test Boss Titan 50% HP Emergency Shield, Invulnerability, High-Speed Targeted Lasers & +40% Phase 2 Fire Rate
		game.reset_game()
		game.boss = game.BossTitan.new(game.enemy_sprites)
		game.boss.entering = false
		game.boss.x = 1555.0
		game.boss.y = 540.0
		game.boss.hp = 3020
		game._hit_boss_titan(100, Vector2(1200.0, 540.0), true)
		assert(game.boss.hp == 3000 and game.boss.is_shielded(), "Boss Titan crossing 50% HP must clamp at 3000 HP and engage Emergency Shield")
		assert(game.overload_warning_timer > 3.0, "Boss Titan overload must trigger flashing energy overload warning")
		game._hit_boss_titan(100, Vector2(1200.0, 540.0), true)
		assert(game.boss.hp == 3000, "Boss Titan must be 100% invulnerable to damage while Emergency Shield is active")
		var b_overload_bullets: Array = []
		for _bs in range(105):
			game.boss.update(0.05, game.player, b_overload_bullets)
		var b_tlasers: int = 0
		for eb_b in b_overload_bullets:
			if String(eb_b.get("kind", "")) == "targeted_laser":
				b_tlasers += 1
				var b_spd: float = Vector2(float(eb_b["vx"]), float(eb_b["vy"])).length()
				assert(absf(b_spd - 1220.0) < 2.0 and float(eb_b["radius"]) >= 11.0, "Titan targeted overload lasers must be larger (radius 11.5) while keeping 1220 speed")
		assert(b_tlasers >= 3, "Boss Titan must charge (1.0s tracking + lock + 0.5s gap) and fire multiple targeted high-speed lasers during Emergency Shield")
		assert(not game.boss.is_shielded() and game.boss.enraged, "Boss Titan Emergency Shield must drop into enraged Phase 2")
		game.boss.attack_timer = 0.01
		game.boss.update(0.02, game.player, b_overload_bullets)
		assert(absf(game.boss.attack_timer - (1.1 / 1.40)) < 0.02, "Boss Titan Phase 2 regular firing pattern must run 40% faster (1.1 / 1.40)")

		# Test Minimal HUD, Dodge Recharge Exhaust Colour + Audio Trigger, Floating Fade-Out Shield Bar & Red 3rd-Hit Shield
		game.reset_game()
		game.player.dodge_cooldown = 0.45
		game.player.dodge_timer = 0.0
		for _dc in range(6):
			game.state_update(0.05)
		assert(game.player.dodge_cooldown > 0.0, "Dodge should still be on cooldown mid-recharge")
		assert(game.player_3d.current_exhaust_mid_color.r > 0.85 and game.player_3d.current_exhaust_mid_color.b < 0.30, "Player exhaust must shift to Amber-Orange while dodge is recharging")
		for _dr in range(5):
			game.state_update(0.05)
		assert(game.player.dodge_cooldown == 0.0 and game.player.dodge_ready_flash > 0.0, "Dodge finishing recharge must trigger dodge_ready_flash & audio prompt")
		assert(game.player_3d.current_exhaust_mid_color.b > 0.85 and game.player_3d.current_exhaust_mid_color.r < 0.48, "Player exhaust must shift to Charged Electric Cyan-Blue when dodge recharges")

		# 1st shield hit (4 -> 3 HP): blue shield + floating bar appears & fades out
		game._damage_player(1, Vector2(game.player.x + 60.0, game.player.y))
		assert(game.player.hp == 3 and game.player.shield_bar_timer > 2.0 and game.hud_shield_lost_seg == 2, "1st hit must show floating shield bar with 3rd shield cell discharging")
		var hit1_emitters: Array = game._collect_weapon_light_emitters()
		var hit1_blue := false
		for em1 in hit1_emitters:
			if float(em1["reach"]) == 210.0 and em1["color"].b > 0.90 and em1["color"].r < 0.30:
				hit1_blue = true
		assert(hit1_blue, "1st shield hit must emit blue/cyan shield reflection light")
		for _fade_step in range(46):
			game.state_update(0.05)
		assert(game.player.shield_bar_timer == 0.0, "Floating shield indicator must fade out to 0.0 so it is not permanent")

		# 2nd shield hit (3 -> 2 HP) & 3rd shield hit (2 -> 1 HP: RED critical shield!)
		game._damage_player(1, Vector2(game.player.x + 60.0, game.player.y))
		assert(game.player.hp == 2 and game.hud_shield_lost_seg == 1, "2nd shield hit must leave 1 shield remaining")
		game.player.invuln_timer = 0.0
		game._damage_player(1, Vector2(game.player.x + 60.0, game.player.y))
		assert(game.player.hp == 1 and game.hud_shield_lost_seg == 0 and game.player.shield_bar_timer > 2.0, "3rd shield hit must lose the last shield (seg 0) and float critical indicator")
		var hit3_emitters: Array = game._collect_weapon_light_emitters()
		var hit3_red := false
		for em3 in hit3_emitters:
			if float(em3["reach"]) == 210.0 and em3["color"].r > 0.90 and em3["color"].b < 0.25:
				hit3_red = true
		assert(hit3_red, "3rd shield hit must switch shield reflection emitter to vivid crimson-red")
		game.reset_game()

		# Simulate gameplay frames across phases
		for _i in range(20):
			game.state_update(0.05)

		# Test Dreadnought spawn & Phase 4 retreat
		game.level_time = 73.0
		game.current_phase = 3
		game.spawn_timer = 0.0
		game.state_update(0.05)
		assert(game.dreadnought != null, "Dreadnought should spawn at t >= 72s in Phase 3")
		game.level_time = 90.1
		game.state_update(0.05)
		assert(game.current_phase == 4 and game.dreadnought.retreating, "Dreadnought should retreat when Phase 4 begins")

		# Test Boss spawn, non-frozen defeat chain-explosion sequence, player visibility, and full Victory fly-out
		game.boss_warning_timer = 0.0
		game.state_update(0.05)
		assert(game.boss != null, "Boss Titan should spawn after warning timer expires")
		game.level_time = 100.0 # int(100.0 * 20.0) % 2 == 0 (previously caused 100% invisible player bug!)
		game.player.invuln_timer = 0.8
		game.player_bullets.append({"x": 400.0, "y": 500.0, "vx": 1280.0, "vy": 0.0, "damage": 15, "age": 0.0, "phase": 0.0})
		game._trigger_boss_defeat()
		assert(game.boss_dying == true, "Boss dying sequence should trigger")
		assert(game.player.invuln_timer == 0.0, "Player invuln_timer must clear on boss defeat so player never turns invisible")
		var pre_death_time: float = game.level_time
		var pre_bullet_x: float = float(game.player_bullets[0]["x"])
		game.state_update(0.1)
		assert(game.level_time > pre_death_time, "level_time must continue advancing during boss_dying")
		assert(float(game.player_bullets[0]["x"]) > pre_bullet_x, "In-flight player bullets must not freeze during boss_dying")
		for _bd in range(35):
			game.state_update(0.1)
		assert(not game.boss_dying and game.boss == null and game.victory == true, "Boss dying should transition cleanly into victory after 3.2s")
		for _vc in range(60):
			game.state_update(0.1)
		assert(game.victory_SubPhase == "MODAL" and game.entering_name == true, "Victory sequence should complete centering + blast-off into name entry modal")

		# Test kill Score Pop-ups (+200, +300, +5,000, +10,000) & 4-hit Player Shield Hit / Collapse feedback
		game.reset_game()
		var kill_scout = game.EnemyShip.new("scout", 700.0, 500.0, game.enemy_sprites, 1.0)
		kill_scout.hp = 10
		game.enemies.append(kill_scout)
		game.player_bullets.append({"x": 695.0, "y": 500.0, "vx": 1280.0, "vy": 0.0, "damage": 15, "age": 0.0, "phase": 0.0})
		game.state_update(0.016)
		assert(game.score_popups.size() == 1 and game.score_popups[0]["text"] == "+200" and game.score == 200, "Destroying a Scout must award 200 points and spawn a +200 score pop-up")
		var popup_start_y: float = float(game.score_popups[0]["y"])
		game.state_update(0.10)
		assert(float(game.score_popups[0]["y"]) < popup_start_y, "Score pop-ups must float smoothly upward")

		game.reset_game()
		assert(game.player.max_hp == 4 and game.player.hp == 4, "Player should start with 4/4 HP segments")
		game.enemies.append(game.EnemyShip.new("scout", 1650.0, 400.0, game.enemy_sprites, 1.0))
		var start_enemy_x = game.enemies[0].x
		game._damage_player(1, Vector2(260.0, 510.0))
		assert(game.player != null and game.player.hp == 3 and not game.game_over, "After 1st hit, player should have 3/4 HP")
		assert(game.player.shield_hit_timer > 0.45 and game.hud_shield_lost_seg == 2, "Shield hit must trigger directional deflector bubble & floating shield segment discharge")
		game._damage_player(1, Vector2(260.0, 570.0))
		assert(game.player != null and game.player.hp == 2 and not game.game_over, "After 2nd hit, player should have 2/4 HP")
		game._damage_player(1, Vector2(260.0, 540.0))
		assert(game.player != null and game.player.hp == 1 and not game.game_over, "After 3rd hit, player should have 1/4 HP")
		game._damage_player(1, Vector2(260.0, 540.0))
		assert(game.game_over == true and game.player == null, "On 4th hit, player should be destroyed and Game Over triggered")
		assert(game.shield_collapse_waves.size() == 1, "Lethal 4th hit should trigger expanding shield collapse shatter ring")
		game.state_update(0.1)
		assert(game.enemies[0].x < start_enemy_x, "Background battle should continue moving during Game Over")

		# Test Asteroids: right-to-left flight, tough Large -> 2 Small split, +100 Small score, Enemy pass-through, Player damage, and Phase 1-3 only (never Titan Phase 4)
		game.reset_game()
		game.spawn_timer = 999.0
		game.asteroid_spawn_timer = 999.0
		var large_ast = game.AsteroidHazard.new("large", 900.0, 500.0, -200.0, 0.0, 0)
		assert(large_ast.is_large and large_ast.hp == 180, "Large asteroid should start with tough 180 HP")
		game.asteroids.append(large_ast)
		var pre_ast_x: float = large_ast.x

		# Overlap an enemy Scout directly on top of the Large asteroid -> must NOT collide!
		var pass_scout = game.EnemyShip.new("scout", 900.0, 500.0, game.enemy_sprites, 1.0)
		var scout_start_hp: int = pass_scout.hp
		game.enemies.append(pass_scout)
		game.state_update(0.05)
		assert(large_ast.x < pre_ast_x, "Asteroids must fly right-to-left")
		assert(game.enemies.has(pass_scout) and pass_scout.hp == scout_start_hp, "Asteroids must not collide with or damage enemy ships")
		assert(game.asteroids.has(large_ast) and large_ast.hp == 180, "Enemy ships must not damage or destroy asteroids")
		game.enemies.clear()

		# Hit Large asteroid with 8 laser bolts (120 dmg) -> survives because Large asteroids are tough
		for _b in range(8):
			game.player_bullets.append({"x": large_ast.x - 10.0, "y": large_ast.y, "vx": 1280.0, "vy": 0.0, "damage": 15, "age": 0.0, "phase": 0.0})
		game.state_update(0.016)
		assert(game.asteroids.size() == 1 and large_ast.hp == 60 and game.score == 0, "Large asteroid should survive 120 damage with 60 HP remaining")

		# Finish off Large asteroid (4 more bolts = 60 dmg) -> splits into 2 Small asteroids, 0 points for the split itself
		for _b2 in range(4):
			game.player_bullets.append({"x": large_ast.x - 10.0, "y": large_ast.y, "vx": 1280.0, "vy": 0.0, "damage": 15, "age": 0.0, "phase": 0.0})
		game.state_update(0.016)
		assert(game.asteroids.size() == 2 and game.score == 0, "Destroyed Large asteroid must split into 2 Small asteroids")
		var sm0 = game.asteroids[0]
		var sm1 = game.asteroids[1]
		assert(not sm0.is_large and not sm1.is_large and sm0.hp == 45 and sm1.hp == 45, "Split Small asteroids should have 45 HP (less tough than Large)")
		assert(sm0.vx < 0.0 and sm1.vx < 0.0 and sm0.vy * sm1.vy < 0.0, "Split Small asteroids should continue right-to-left while diverging vertically")

		# Destroy Small asteroid #1 with 3 laser bolts (45 dmg) -> awards +200 points and floating +200 popup
		for _b3 in range(3):
			game.player_bullets.append({"x": sm0.x - 8.0, "y": sm0.y, "vx": 1280.0, "vy": 0.0, "damage": 15, "age": 0.0, "phase": 0.0})
		game.state_update(0.016)
		assert(game.asteroids.size() == 1 and game.score == 200, "Destroying a Small asteroid must award 200 points")
		assert(game.score_popups.size() >= 1 and game.score_popups[-1]["text"] == "+200", "Destroying a Small asteroid must spawn a +200 score popup")

		# Destroy Small asteroid #2 with a homing missile (100 dmg) -> awards another +200 points (total 400)
		game.homing_missiles.append({
			"x": sm1.x - 6.0, "y": sm1.y, "vx": 680.0, "vy": 0.0,
			"speed": 680.0, "damage": 100, "age": 0.0,
			"max_tracking_time": 3.0, "turn_rate": 3.2, "trail": []
		})
		game.state_update(0.016)
		assert(game.asteroids.is_empty() and game.score == 400, "Destroying both Small fragments must yield 400 total points")

		# Test Asteroid <-> Player collision: dodging phases safely; unshielded collision damages player without awarding score
		game.reset_game()
		game.spawn_timer = 999.0
		game.asteroid_spawn_timer = 999.0
		game.player.dodge_timer = 0.18
		var dodge_ast = game.AsteroidHazard.new("small", game.player.x, game.player.y, -220.0, 0.0, 1)
		game.asteroids.append(dodge_ast)
		game.state_update(0.016)
		assert(game.player.hp == 4 and game.asteroids.has(dodge_ast), "Dodging player should phase safely through asteroids")

		game.player.dodge_timer = 0.0
		game.player.invuln_timer = 0.0
		dodge_ast.x = game.player.x
		dodge_ast.y = game.player.y
		game.state_update(0.016)
		assert(game.player.hp == 3 and game.player.shield_hit_timer > 0.0, "Colliding with an asteroid must damage the player ship")
		assert(game.score == 0 and not game.asteroids.has(dodge_ast), "Small asteroid shattering on player shield must not award score")

		# Test Phase 1, 2, 3 spawning & Phase 4 (Titan Boss) exclusion
		for ph_idx in [1, 2, 3]:
			game.reset_game()
			game.current_phase = ph_idx
			game.level_time = float((ph_idx - 1) * 30 + 5)
			game.spawn_timer = 999.0
			game.asteroid_spawn_timer = 0.01
			game.state_update(0.05)
			assert(game.asteroids.size() >= 1, "Asteroids must spawn during Phase %d" % ph_idx)

		# Transition from Phase 3 -> Phase 4 (Titan Boss phase): active asteroids must clear and zero new ones spawn
		game.current_phase = 3
		game.level_time = 89.98
		assert(not game.asteroids.is_empty(), "Precondition: Phase 3 has active asteroids prior to Phase 4 transition")
		game.state_update(0.05)
		assert(game.current_phase == 4 and game.asteroids.is_empty(), "Entering Phase 4 (Titan Boss phase) must clear all asteroids")
		for _p4 in range(20):
			game.asteroid_spawn_timer = 0.0
			game.state_update(0.15)
		assert(game.asteroids.is_empty(), "Zero asteroids may spawn during the Titan boss phase (Phase 4)")

		print("[PASS] Game State combat, weapons, 4-hit segmented health bar, Raider banking, Asteroids (Phases 1-3), Dreadnought, Boss, and Game Over verified.")

	elif frame_step == 10:
		print("=== ALL GODOT 4.7.2 TESTS PASSED 100% ===")
		quit(0)
		return true

	return false
