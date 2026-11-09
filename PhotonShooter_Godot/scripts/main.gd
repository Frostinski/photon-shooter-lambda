extends Node2D

const SplashStateScript = preload("res://scripts/states/splash_state.gd")
const MenuStateScript = preload("res://scripts/states/menu_state.gd")
const HighScoresStateScript = preload("res://scripts/states/high_scores_state.gd")
const HowToPlayStateScript = preload("res://scripts/states/how_to_play_state.gd")
const GameStateScript = preload("res://scripts/states/game_state.gd")

var states: Dictionary = {}
var current_state_name: String = ""
var current_state: Node2D = null


func _ready() -> void:
	if not OS.has_feature("editor") and DisplayServer.get_name() != "headless":
		var usable: Rect2i = DisplayServer.screen_get_usable_rect()
		if usable.size.x > 0 and (usable.size.x <= 1960 or usable.size.y <= 1120):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

	states["SPLASH"] = SplashStateScript.new()
	states["MENU"] = MenuStateScript.new()
	states["HIGH_SCORES"] = HighScoresStateScript.new()
	states["HOW_TO_PLAY"] = HowToPlayStateScript.new()
	states["GAME"] = GameStateScript.new()

	for key in states.keys():
		var st: Node2D = states[key]
		st.name = key
		st.set("main_app", self)
		st.visible = false
		st.set_process(false)
		st.set_process_input(false)
		add_child(st)

	set_state("SPLASH")


func _process(delta: float) -> void:
	var dt = minf(delta, 0.05)
	InputHelper.update_inputs()
	if current_state != null and current_state.has_method("state_update"):
		current_state.state_update(dt)
		current_state.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var is_f11: bool = event.keycode == KEY_F11
		var is_alt_enter: bool = event.alt_pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)
		if is_f11 or is_alt_enter:
			var cur_mode: int = DisplayServer.window_get_mode()
			if cur_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or cur_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()
			return
	if current_state != null and current_state.has_method("state_input"):
		current_state.state_input(event)


func set_state(state_name: String, params: Dictionary = {}) -> void:
	if current_state != null:
		current_state.visible = false
		current_state.set_process(false)
		current_state.set_process_input(false)

	current_state_name = state_name
	current_state = states.get(state_name, null)
	if current_state != null:
		current_state.visible = true
		current_state.set_process(true)
		current_state.set_process_input(true)
		if current_state.has_method("enter"):
			current_state.enter(params)
		current_state.queue_redraw()
