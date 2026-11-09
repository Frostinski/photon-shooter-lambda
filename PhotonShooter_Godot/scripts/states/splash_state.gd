extends Node2D

var main_app: Node = null

var timer: float = 0.0
var fade_in_duration: float = 1.5
var hold_duration: float = 4.0
var fade_out_duration: float = 1.5
var total_duration: float = 7.0
var skipped: bool = false

var stars: Array = []


func _ready() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 20261012
	for i in range(90):
		stars.append({
			"x": rng.randf_range(0.0, GameConfig.SCREEN_WIDTH),
			"y": rng.randf_range(0.0, GameConfig.SCREEN_HEIGHT),
			"speed": rng.randf_range(12.0, 55.0),
			"size": [1.0, 2.0, 3.0][rng.randi_range(0, 2)],
			"phase": rng.randf_range(0.0, TAU)
		})


func enter(_params: Dictionary = {}) -> void:
	timer = 0.0
	skipped = false
	SoundManager.play_music("menu.wav", true, 0.55)


func state_input(event: InputEvent) -> void:
	if timer <= 0.3:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_skip_to_menu()
	elif event is InputEventMouseButton and event.pressed:
		_skip_to_menu()
	elif event is InputEventJoypadButton and event.pressed:
		_skip_to_menu()


func _skip_to_menu() -> void:
	if not skipped:
		skipped = true
		SoundManager.play("menu_confirm")
		main_app.set_state("MENU")


func state_update(dt: float) -> void:
	timer += dt

	for s in stars:
		s["x"] -= s["speed"] * dt
		if s["x"] < 0.0:
			s["x"] = GameConfig.SCREEN_WIDTH
			s["y"] = randf_range(0.0, GameConfig.SCREEN_HEIGHT)

	if timer >= total_duration:
		main_app.set_state("MENU")


func _get_alpha() -> float:
	if timer < fade_in_duration:
		return clampf(timer / fade_in_duration, 0.0, 1.0)
	elif timer < fade_in_duration + hold_duration:
		return 1.0
	else:
		var rem = total_duration - timer
		return clampf(rem / fade_out_duration, 0.0, 1.0)


func _draw() -> void:
	# Deep cosmic vertical gradient background
	var bands: int = 54
	var band_h: float = GameConfig.SCREEN_HEIGHT / float(bands)
	for i in range(bands):
		var ratio = float(i) / float(bands)
		var r = int(4.0 + ratio * 14.0)
		var g = int(4.0 + ratio * 8.0)
		var b = int(16.0 + ratio * 38.0)
		draw_rect(Rect2(0.0, i * band_h, GameConfig.SCREEN_WIDTH, band_h + 1.0), Color8(r, g, b), true)

	# Twinkling stars
	for s in stars:
		var twinkle = 0.5 + 0.5 * sin(timer * 3.0 + s["phase"])
		var c_val = int(130.0 + 125.0 * twinkle)
		draw_rect(
			Rect2(s["x"], s["y"], s["size"], s["size"]),
			Color8(c_val, c_val, min(255, c_val + 30)),
			true
		)

	var cx = GameConfig.SCREEN_WIDTH * 0.5
	var cy = GameConfig.SCREEN_HEIGHT * 0.5 - 30.0
	var pulse = 0.5 + 0.5 * sin(timer * 2.5)

	var card_rect = Rect2(cx - 520.0, cy - 230.0, 1040.0, 480.0)
	GameConfig.draw_glass_panel(
		self,
		card_rect,
		Color8(10, 14, 36, 220),
		GameConfig.COLOR_CYAN,
		GameConfig.COLOR_GOLD,
		24.0,
		3.0
	)

	# Decorative top emblem / star crest
	var star_y = card_rect.position.y + 68.0
	draw_line(Vector2(cx - 320.0, star_y), Vector2(cx - 60.0, star_y), GameConfig.COLOR_GOLD, 2.0)
	draw_line(Vector2(cx + 60.0, star_y), Vector2(cx + 320.0, star_y), GameConfig.COLOR_GOLD, 2.0)

	var diamond = PackedVector2Array([
		Vector2(cx, star_y - 18.0),
		Vector2(cx + 18.0, star_y),
		Vector2(cx, star_y + 18.0),
		Vector2(cx - 18.0, star_y)
	])
	draw_colored_polygon(diamond, GameConfig.COLOR_GOLD)
	draw_polyline(diamond + PackedVector2Array([diamond[0]]), GameConfig.COLOR_WHITE, 2.0)

	# Main Event Headline
	GameConfig.draw_glow_text(
		self,
		"CHARITY DAY",
		cx,
		cy - 85.0,
		48,
		GameConfig.COLOR_GOLD,
		Color8(180, 90, 0),
		"center",
		timer
	)

	GameConfig.draw_glow_text(
		self,
		"11TH NOVEMBER",
		cx,
		cy - 15.0,
		30,
		GameConfig.COLOR_CYAN,
		Color8(0, 100, 160),
		"center",
		timer
	)

	draw_line(Vector2(cx - 380.0, cy + 40.0), Vector2(cx + 380.0, cy + 40.0), GameConfig.COLOR_MAGENTA, 2.0)

	GameConfig.draw_text(
		self,
		"PROUDLY PRESENTS",
		cx,
		cy + 95.0,
		20,
		GameConfig.COLOR_WHITE,
		"center"
	)

	var sub_col = Color8(int(180.0 + 70.0 * pulse), 235, 255)
	GameConfig.draw_text(
		self,
		"AN ARCADE EXPERIENCE FOR CHARITY",
		cx,
		cy + 150.0,
		22,
		sub_col,
		"center"
	)

	if int(timer * 2.0) % 2 == 0:
		GameConfig.draw_text(
			self,
			"PRESS ANY BUTTON OR KEY TO SKIP",
			cx,
			GameConfig.SCREEN_HEIGHT - 70.0,
			16,
			GameConfig.COLOR_MUTED,
			"center"
		)

	var alpha = _get_alpha()
	if alpha < 1.0:
		draw_rect(
			Rect2(0.0, 0.0, GameConfig.SCREEN_WIDTH, GameConfig.SCREEN_HEIGHT),
			Color(0.0, 0.0, 0.0, 1.0 - alpha),
			true
		)
