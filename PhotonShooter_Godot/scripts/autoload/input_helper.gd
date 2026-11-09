extends Node

const DEADZONE: float = 0.25

var _prev_actions: Dictionary = {}
var _curr_actions: Dictionary = {}

const ACTIONS: Array[String] = [
	"up", "down", "left", "right",
	"fire_primary", "fire_secondary", "dodge",
	"confirm", "back", "delete", "pause"
]


func _ready() -> void:
	for a in ACTIONS:
		_prev_actions[a] = false
		_curr_actions[a] = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			var mode = DisplayServer.window_get_mode()
			if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func update_inputs() -> void:
	for a in ACTIONS:
		_prev_actions[a] = _curr_actions.get(a, false)
		_curr_actions[a] = _poll_action(a)


func get_movement() -> Vector2:
	var dx: float = 0.0
	var dy: float = 0.0

	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		dx -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		dx += 1.0
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		dy -= 1.0
	if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		dy += 1.0

	for pad_id in Input.get_connected_joypads():
		var ax = Input.get_joy_axis(pad_id, JOY_AXIS_LEFT_X)
		var ay = Input.get_joy_axis(pad_id, JOY_AXIS_LEFT_Y)
		if absf(ax) > DEADZONE:
			dx += ax
		if absf(ay) > DEADZONE:
			dy += ay

		if Input.is_joy_button_pressed(pad_id, JOY_BUTTON_DPAD_LEFT):
			dx -= 1.0
		if Input.is_joy_button_pressed(pad_id, JOY_BUTTON_DPAD_RIGHT):
			dx += 1.0
		if Input.is_joy_button_pressed(pad_id, JOY_BUTTON_DPAD_UP):
			dy -= 1.0
		if Input.is_joy_button_pressed(pad_id, JOY_BUTTON_DPAD_DOWN):
			dy += 1.0

	var v = Vector2(dx, dy)
	if v.length() > 1.0:
		v = v.normalized()
	return v


func _poll_action(action: String) -> bool:
	var pads = Input.get_connected_joypads()

	match action:
		"up":
			if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
				return true
			for p in pads:
				if Input.is_joy_button_pressed(p, JOY_BUTTON_DPAD_UP) or Input.get_joy_axis(p, JOY_AXIS_LEFT_Y) < -0.55:
					return true
		"down":
			if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
				return true
			for p in pads:
				if Input.is_joy_button_pressed(p, JOY_BUTTON_DPAD_DOWN) or Input.get_joy_axis(p, JOY_AXIS_LEFT_Y) > 0.55:
					return true
		"left":
			if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
				return true
			for p in pads:
				if Input.is_joy_button_pressed(p, JOY_BUTTON_DPAD_LEFT) or Input.get_joy_axis(p, JOY_AXIS_LEFT_X) < -0.55:
					return true
		"right":
			if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
				return true
			for p in pads:
				if Input.is_joy_button_pressed(p, JOY_BUTTON_DPAD_RIGHT) or Input.get_joy_axis(p, JOY_AXIS_LEFT_X) > 0.55:
					return true
		"fire_primary":
			if Input.is_physical_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_Z) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				return true
			for p in pads:
				if Input.is_joy_button_pressed(p, JOY_BUTTON_A) or Input.is_joy_button_pressed(p, JOY_BUTTON_RIGHT_SHOULDER):
					return true
				if Input.get_joy_axis(p, JOY_AXIS_TRIGGER_RIGHT) > 0.35:
					return true
		"fire_secondary":
			if Input.is_physical_key_pressed(KEY_K) or Input.is_physical_key_pressed(KEY_X) or Input.is_physical_key_pressed(KEY_CTRL) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				return true
			for p in pads:
				if Input.is_joy_button_pressed(p, JOY_BUTTON_X) or Input.is_joy_button_pressed(p, JOY_BUTTON_B):
					return true
		"dodge":
			if Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_C):
				return true
			for p in pads:
				if Input.is_joy_button_pressed(p, JOY_BUTTON_LEFT_SHOULDER) or Input.is_joy_button_pressed(p, JOY_BUTTON_LEFT_STICK):
					return true
				if Input.get_joy_axis(p, JOY_AXIS_TRIGGER_LEFT) > 0.35:
					return true
		"confirm":
			if Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_KP_ENTER) or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_Z):
				return true
			for p in pads:
				if Input.is_joy_button_pressed(p, JOY_BUTTON_A) or Input.is_joy_button_pressed(p, JOY_BUTTON_START):
					return true
		"back":
			if Input.is_physical_key_pressed(KEY_ESCAPE) or Input.is_physical_key_pressed(KEY_BACKSPACE):
				return true
			for p in pads:
				if Input.is_joy_button_pressed(p, JOY_BUTTON_B) or Input.is_joy_button_pressed(p, JOY_BUTTON_BACK):
					return true
		"delete":
			if Input.is_physical_key_pressed(KEY_BACKSPACE) or Input.is_physical_key_pressed(KEY_DELETE):
				return true
			for p in pads:
				if Input.is_joy_button_pressed(p, JOY_BUTTON_X) or Input.is_joy_button_pressed(p, JOY_BUTTON_B):
					return true
		"pause":
			if Input.is_physical_key_pressed(KEY_ESCAPE) or Input.is_physical_key_pressed(KEY_P):
				return true
			for p in pads:
				if Input.is_joy_button_pressed(p, JOY_BUTTON_START):
					return true

	return false


func is_action_down(action: String) -> bool:
	return _curr_actions.get(action, false)


func just_pressed(action: String) -> bool:
	return _curr_actions.get(action, false) and not _prev_actions.get(action, false)
