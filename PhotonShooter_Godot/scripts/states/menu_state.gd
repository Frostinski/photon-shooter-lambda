extends Node2D

var main_app: Node = null

var options: Array = [
	{"label": "START NEW GAME", "action": "START"},
	{"label": "VIEW HIGH SCORES", "action": "SCORES"},
	{"label": "QUIT", "action": "QUIT"},
]
var selected_index: int = 0
var time: float = 0.0
var nav_cooldown: float = 0.0
var button_rects: Array[Rect2] = []

var transitioning: bool = false
var transition_timer: float = 0.0
var fade_duration: float = 2.0
var black_hold_duration: float = 1.0

var bg_tex: Texture2D = null
var nebula_loop_tex: Texture2D = null
var bg_frames: Array[Texture2D] = []
var logo_smooth: Texture2D = null

var nebula_scroll_x: float = 0.0
var nebula_scroll_speed: float = 42.0
var parallax_stars: Array = []


func _ready() -> void:
	bg_tex = GameConfig.get_texture("menu_bg")
	nebula_loop_tex = GameConfig.get_texture("menu_nebula_loop")
	bg_frames = GameConfig.menu_bg_frames

	var raw_logo: Texture2D = GameConfig.get_texture("logo")
	if raw_logo != null:
		var img = raw_logo.get_image()
		var target_w: int = 560
		var ratio = float(target_w) / float(img.get_width())
		var target_h = int(img.get_height() * ratio)
		var scaled = img.duplicate()
		scaled.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)
		logo_smooth = ImageTexture.create_from_image(scaled)

	var rng = RandomNumberGenerator.new()
	rng.seed = 20261027
	var cols = [Color8(190, 225, 255), Color8(255, 200, 245), Color8(255, 255, 255)]
	for i in range(60):
		parallax_stars.append({
			"x": rng.randf_range(0.0, GameConfig.SCREEN_WIDTH),
			"y": rng.randf_range(0.0, GameConfig.SCREEN_HEIGHT),
			"speed": rng.randf_range(18.0, 68.0),
			"size": [1.0, 2.0, 3.0][rng.randi_range(0, 2)],
			"color": cols[rng.randi_range(0, cols.size() - 1)],
			"alpha": rng.randf_range(0.35, 0.90)
		})


func enter(_params: Dictionary = {}) -> void:
	time = 0.0
	nav_cooldown = 0.2
	transitioning = false
	transition_timer = 0.0
	SoundManager.play_music("menu.wav", true, 0.55)


func state_input(event: InputEvent) -> void:
	if transitioning:
		return

	if event is InputEventMouseMotion:
		for idx in range(button_rects.size()):
			if button_rects[idx].has_point(event.position):
				if selected_index != idx:
					selected_index = idx
					SoundManager.play("menu_move")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for idx in range(button_rects.size()):
			if button_rects[idx].has_point(event.position):
				selected_index = idx
				_trigger_option()


func state_update(dt: float) -> void:
	time += dt
	if nav_cooldown > 0.0:
		nav_cooldown -= dt

	# Slowly move the nebula & starfield background to the left, looping back on the right
	nebula_scroll_x = fmod(nebula_scroll_x + nebula_scroll_speed * dt, GameConfig.SCREEN_WIDTH)

	for s in parallax_stars:
		s["x"] -= s["speed"] * dt
		if s["x"] < 0.0:
			s["x"] += GameConfig.SCREEN_WIDTH
			s["y"] = randf_range(0.0, GameConfig.SCREEN_HEIGHT)

	if transitioning:
		transition_timer += dt
		if transition_timer >= (fade_duration + black_hold_duration):
			main_app.set_state("HOW_TO_PLAY")
		return

	if nav_cooldown <= 0.0:
		if InputHelper.just_pressed("up"):
			selected_index = (selected_index - 1 + options.size()) % options.size()
			SoundManager.play("menu_move")
			nav_cooldown = 0.16
		elif InputHelper.just_pressed("down"):
			selected_index = (selected_index + 1) % options.size()
			SoundManager.play("menu_move")
			nav_cooldown = 0.16
		elif InputHelper.just_pressed("confirm"):
			_trigger_option()
			nav_cooldown = 0.25


func _trigger_option() -> void:
	var action = options[selected_index]["action"]
	SoundManager.play("menu_confirm")
	if action == "START":
		transitioning = true
		transition_timer = 0.0
		SoundManager.fadeout_music(int(fade_duration * 1000.0))
	elif action == "SCORES":
		main_app.set_state("HIGH_SCORES")
	elif action == "QUIT":
		get_tree().quit()


func _draw() -> void:
	# 1. Slowly scrolling & seamlessly looping Nebula and Starfield Background
	if nebula_loop_tex != null:
		var x1: float = -nebula_scroll_x
		var x2: float = GameConfig.SCREEN_WIDTH - nebula_scroll_x
		draw_texture_rect(
			nebula_loop_tex,
			Rect2(x1, 0.0, GameConfig.SCREEN_WIDTH, GameConfig.SCREEN_HEIGHT),
			false
		)
		draw_texture_rect(
			nebula_loop_tex,
			Rect2(x2, 0.0, GameConfig.SCREEN_WIDTH, GameConfig.SCREEN_HEIGHT),
			false
		)
	else:
		draw_rect(Rect2(0.0, 0.0, GameConfig.SCREEN_WIDTH, GameConfig.SCREEN_HEIGHT), GameConfig.COLOR_BG_DEEP, true)

	for s in parallax_stars:
		var c: Color = s["color"]
		draw_rect(Rect2(s["x"], s["y"], s["size"], s["size"]), Color(c.r, c.g, c.b, s["alpha"]), true)

	# 2. Foreground Ships Layer (no sway, subtle enemy ship light glow across 8 frames)
	var active_ships: Texture2D = bg_tex
	if not bg_frames.is_empty():
		var f_idx = int(time * 8.0) % bg_frames.size()
		active_ships = bg_frames[f_idx]

	if active_ships != null:
		draw_texture_rect(
			active_ships,
			Rect2(0.0, 0.0, GameConfig.SCREEN_WIDTH, GameConfig.SCREEN_HEIGHT),
			false
		)

	# 3. Top Charity Event Banner Bar
	var banner_h: float = 56.0
	draw_rect(Rect2(0.0, 0.0, GameConfig.SCREEN_WIDTH, banner_h), Color8(8, 12, 24, 230), true)
	draw_line(Vector2(0.0, banner_h), Vector2(GameConfig.SCREEN_WIDTH, banner_h), GameConfig.COLOR_CYAN, 2.0)
	GameConfig.draw_text(
		self,
		"★ %s ★   %s" % [GameConfig.EVENT_NAME.to_upper(), GameConfig.PRIZE_FUND_DESC],
		GameConfig.SCREEN_WIDTH * 0.5,
		banner_h * 0.5,
		15,
		GameConfig.COLOR_GOLD,
		"center"
	)

	# 4. Floating Title Image in Top-Left of Screen
	var float_y = sin(time * 2.2) * 5.0
	if logo_smooth != null:
		var lx: float = 65.0
		var ly: float = 76.0 + float_y
		draw_texture(logo_smooth, Vector2(lx, ly))

	# 5. Menu Selection Options in Bottom-Left (left-justified, borderless)
	var menu_x: float = 85.0
	var start_y: float = 765.0
	var spacing: float = 62.0
	var hit_w: float = 440.0
	var hit_h: float = 48.0

	button_rects.clear()
	for idx in range(options.size()):
		var opt = options[idx]
		var item_y = start_y + idx * spacing
		var rect = Rect2(menu_x, item_y - hit_h * 0.5, hit_w, hit_h)
		button_rects.append(rect)

		var is_selected = (idx == selected_index)
		if is_selected:
			var arrow_offset = sin(time * 8.0) * 4.0
			GameConfig.draw_text(
				self,
				"►",
				menu_x + arrow_offset,
				item_y,
				22,
				GameConfig.COLOR_GOLD,
				"midleft"
			)
			GameConfig.draw_glow_text(
				self,
				opt["label"],
				menu_x + 38.0,
				item_y,
				22,
				GameConfig.COLOR_GOLD,
				GameConfig.COLOR_MAGENTA,
				"midleft",
				time
			)
		else:
			GameConfig.draw_text(
				self,
				opt["label"],
				menu_x + 38.0,
				item_y,
				20,
				Color8(230, 240, 255),
				"midleft"
			)

	if transitioning:
		var fade_ratio = clampf(transition_timer / fade_duration, 0.0, 1.0)
		draw_rect(
			Rect2(0.0, 0.0, GameConfig.SCREEN_WIDTH, GameConfig.SCREEN_HEIGHT),
			Color(0.0, 0.0, 0.0, fade_ratio),
			true
		)
