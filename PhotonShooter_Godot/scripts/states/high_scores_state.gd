extends Node2D

var main_app: Node = null
var time: float = 0.0
var back_rect: Rect2 = Rect2(0, 0, 0, 0)
var bg_tex: Texture2D = null


func _ready() -> void:
	bg_tex = GameConfig.get_texture("menu_bg")


func enter(_params: Dictionary = {}) -> void:
	time = 0.0
	HighScoreManager.load_scores()


func state_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if back_rect.has_point(event.position):
			SoundManager.play("menu_back")
			main_app.set_state("MENU")


func state_update(dt: float) -> void:
	time += dt
	if InputHelper.just_pressed("back") or InputHelper.just_pressed("confirm"):
		if time > 0.2:
			SoundManager.play("menu_back")
			main_app.set_state("MENU")


func _draw() -> void:
	if bg_tex != null:
		draw_texture_rect(bg_tex, Rect2(0.0, 0.0, GameConfig.SCREEN_WIDTH, GameConfig.SCREEN_HEIGHT), false)
	draw_rect(Rect2(0.0, 0.0, GameConfig.SCREEN_WIDTH, GameConfig.SCREEN_HEIGHT), Color8(6, 8, 22, 185), true)

	var cx = GameConfig.SCREEN_WIDTH * 0.5

	GameConfig.draw_glow_text(
		self,
		"HALL OF PILOTS - HIGH SCORES",
		cx,
		95.0,
		36,
		GameConfig.COLOR_GOLD,
		Color8(160, 70, 0),
		"center",
		time
	)
	GameConfig.draw_text(
		self,
		"CHARITY DAY - 11TH NOVEMBER TOURNAMENT LEADERBOARD",
		cx,
		148.0,
		18,
		GameConfig.COLOR_CYAN,
		"center"
	)

	var board_w: float = 1040.0
	var board_h: float = 680.0
	var board_x: float = cx - board_w * 0.5
	var board_y: float = 195.0
	var board_rect = Rect2(board_x, board_y, board_w, board_h)

	GameConfig.draw_glass_panel(
		self,
		board_rect,
		Color8(10, 14, 36, 230),
		GameConfig.COLOR_CYAN,
		GameConfig.COLOR_GOLD,
		22.0,
		3.0
	)

	var header_y = board_y + 52.0
	GameConfig.draw_text(self, "RANK", board_x + 110.0, header_y, 20, GameConfig.COLOR_MAGENTA, "center")
	GameConfig.draw_text(self, "PILOT", board_x + 360.0, header_y, 20, GameConfig.COLOR_MAGENTA, "center")
	GameConfig.draw_text(self, "SCORE", board_x + 650.0, header_y, 20, GameConfig.COLOR_MAGENTA, "center")
	GameConfig.draw_text(self, "DATE", board_x + 900.0, header_y, 20, GameConfig.COLOR_MAGENTA, "center")

	draw_line(
		Vector2(board_x + 50.0, header_y + 28.0),
		Vector2(board_x + board_w - 50.0, header_y + 28.0),
		GameConfig.COLOR_CYAN,
		2.0
	)

	var scores = HighScoreManager.scores
	var start_y = header_y + 72.0
	var row_h = 64.0

	if scores.is_empty():
		GameConfig.draw_text(
			self,
			"NO SCORES RECORDED YET",
			cx,
			board_y + board_h * 0.50,
			22,
			GameConfig.COLOR_CYAN,
			"center"
		)
		GameConfig.draw_text(
			self,
			"LAUNCH A MISSION TO CLAIM THE #1 SPOT",
			cx,
			board_y + board_h * 0.58,
			15,
			GameConfig.COLOR_MUTED,
			"center"
		)

	var max_rows = min(8, scores.size())
	for idx in range(max_rows):
		var entry = scores[idx]
		var ry = start_y + idx * row_h

		if idx % 2 == 0:
			draw_rect(
				Rect2(board_x + 40.0, ry - 26.0, board_w - 80.0, 52.0),
				Color8(20, 28, 65, 130),
				true
			)

		var row_color: Color
		if idx == 0:
			row_color = GameConfig.COLOR_GOLD
			var pulse_w = int(4.0 * sin(time * 5.0))
			draw_rect(
				Rect2(board_x + 38.0 - pulse_w, ry - 28.0, board_w - 76.0 + pulse_w * 2.0, 56.0),
				GameConfig.COLOR_GOLD,
				false,
				2.0
			)
		elif idx == 1:
			row_color = Color8(210, 225, 245)
		elif idx == 2:
			row_color = Color8(235, 165, 100)
		else:
			row_color = GameConfig.COLOR_WHITE

		var rank_str = "#%d" % (idx + 1)
		GameConfig.draw_text(self, rank_str, board_x + 110.0, ry, 22, row_color, "center")
		GameConfig.draw_text(self, str(entry.get("name", "ACE")), board_x + 360.0, ry, 22, row_color, "center")
		GameConfig.draw_text(self, GameConfig.format_commas(int(entry.get("score", 0))), board_x + 650.0, ry, 22, row_color, "center")
		GameConfig.draw_text(self, str(entry.get("date", "2026-10-12")), board_x + 900.0, ry, 18, GameConfig.COLOR_MUTED, "center")

	var btn_w: float = 420.0
	var btn_h: float = 58.0
	back_rect = Rect2(cx - btn_w * 0.5, 920.0, btn_w, btn_h)
	draw_rect(back_rect, Color8(24, 18, 58, 230), true)
	draw_rect(back_rect, GameConfig.COLOR_GOLD, false, 2.0)
	GameConfig.draw_text(
		self,
		"◄ RETURN TO MAIN MENU",
		cx,
		back_rect.position.y + btn_h * 0.5,
		18,
		GameConfig.COLOR_GOLD,
		"center"
	)
