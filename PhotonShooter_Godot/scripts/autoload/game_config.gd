extends Node
## Photon Shooter Lambda (PSL) - Global Configuration, Palette, Fonts & Sprite Cache

const SCREEN_WIDTH: int = 1920
const SCREEN_HEIGHT: int = 1080
const DEFAULT_LIVES: int = 3

const EVENT_NAME: String = "Charity Day - 11th November"
const EVENT_SUBTITLE: String = "Charity Arcade Tournament - Play To Give, Game For Good!"
const PRIZE_FUND_DESC: String = "Top Scorer wins the Grand Charity Prize Fund!"

# --- Retro Sci-Fi Palette ---
const COLOR_BLACK: Color = Color8(10, 10, 18)
const COLOR_WHITE: Color = Color8(245, 245, 255)
const COLOR_CYAN: Color = Color8(0, 240, 255)
const COLOR_DEEP_CYAN: Color = Color8(0, 150, 200)
const COLOR_MAGENTA: Color = Color8(255, 46, 144)
const COLOR_PURPLE: Color = Color8(147, 51, 234)
const COLOR_AMBER: Color = Color8(255, 179, 0)
const COLOR_GOLD: Color = Color8(255, 215, 0)
const COLOR_NEON_GREEN: Color = Color8(57, 255, 20)
const COLOR_DARK_BLUE: Color = Color8(15, 23, 42)
const COLOR_PANEL_BG: Color = Color8(18, 22, 38, 220)
const COLOR_PANEL_BORDER: Color = Color8(0, 220, 240, 180)
const COLOR_GRAY: Color = Color8(120, 130, 150)
const COLOR_MUTED: Color = Color8(120, 130, 150)
const COLOR_DARK_GRAY: Color = Color8(40, 45, 60)
const COLOR_RED: Color = Color8(255, 60, 60)
const COLOR_GREEN: Color = Color8(57, 255, 20)
const COLOR_BG_DEEP: Color = Color8(10, 10, 18)

# --- Cached Font & Textures ---
var pixel_font: FontFile = null
var asteroid_mesh_cache: Dictionary = {}
var asteroid_normal_tex: Texture2D = null

var tex_menu_bg: Texture2D = null
var tex_menu_nebula_loop: Texture2D = null
var menu_bg_frames: Array[Texture2D] = []
var tex_logo: Texture2D = null

var tex_scout: Texture2D = null
var tex_scout_flash: Texture2D = null
var tex_raider: Texture2D = null
var tex_raider_flash: Texture2D = null
var tex_dreadnought: Texture2D = null
var tex_dreadnought_flash: Texture2D = null
var tex_boss: Texture2D = null
var tex_boss_flash: Texture2D = null

var tex_photon_bolt: Texture2D = null
var tex_photon_flare: Texture2D = null
var tex_enemy_comet_red: Texture2D = null
var tex_enemy_lance_gold: Texture2D = null
var tex_orb_red: Texture2D = null
var tex_orb_gold: Texture2D = null
var tex_orb_magenta: Texture2D = null

# Spritesheet frame dictionaries:
# player_frames[bank_state][throttle_state] -> Array[Texture2D] (4 frames)
var player_frames: Dictionary = {}
var player_flash_frames: Dictionary = {}

# scout_anims[state] -> Array[Texture2D] (4 frames: 'cruise', 'charge', 'fire')
var scout_anims: Dictionary = {}
var scout_flash_anims: Dictionary = {}

# raider_anims[bank_state] -> Array[Texture2D] (4 frames: 'bank_left', 'neutral', 'bank_right')
var raider_anims: Dictionary = {}
var raider_flash_anims: Dictionary = {}

# Control prompt textures
var control_textures: Dictionary = {}

# Cached 3D Player & Enemy Starfighter PackedScenes / GLTFPaths
var player_ship_3d_scene: PackedScene = null
var enemy_3d_scenes: Dictionary = {}
const PLAYER_SHIP_GLB_PATH: String = "res://assets/models/player_ship.glb"
const ENEMY_GLB_PATHS: Dictionary = {
	"scout": "res://assets/models/enemy_scout.glb",
	"raider": "res://assets/models/enemy_raider.glb",
	"dreadnought": "res://assets/models/boss_dreadnought.glb",
	"boss_titan": "res://assets/models/boss_titan.glb",
}

func _ready() -> void:
	_load_fonts()
	_load_textures()
	_build_vfx_textures()
	_load_player_3d_model()
	_load_enemy_3d_models()

func _load_player_3d_model() -> void:
	if ResourceLoader.exists(PLAYER_SHIP_GLB_PATH):
		var res = load(PLAYER_SHIP_GLB_PATH)
		if res is PackedScene:
			player_ship_3d_scene = res

func _load_enemy_3d_models() -> void:
	for k in ENEMY_GLB_PATHS.keys():
		var path: String = ENEMY_GLB_PATHS[k]
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is PackedScene:
				enemy_3d_scenes[k] = res

func _instantiate_glb_with_fallback(cached_scene: PackedScene, res_path: String) -> Node3D:
	if cached_scene != null:
		var inst = cached_scene.instantiate()
		if inst is Node3D:
			return inst
	if FileAccess.file_exists(res_path):
		var gltf_buf := FileAccess.get_file_as_bytes(res_path)
		if not gltf_buf.is_empty():
			var gltf_doc_mem := GLTFDocument.new()
			var gltf_state_mem := GLTFState.new()
			if gltf_doc_mem.append_from_buffer(gltf_buf, res_path.get_base_dir(), gltf_state_mem) == OK:
				var mem_root = gltf_doc_mem.generate_scene(gltf_state_mem)
				if mem_root is Node3D:
					return mem_root
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if not abs_path.is_empty() and FileAccess.file_exists(abs_path):
		var gltf_doc := GLTFDocument.new()
		var gltf_state := GLTFState.new()
		var err := gltf_doc.append_from_file(abs_path, gltf_state)
		if err == OK:
			var root_node = gltf_doc.generate_scene(gltf_state)
			if root_node is Node3D:
				return root_node
	return null

func instantiate_player_ship_3d() -> Node3D:
	return _instantiate_glb_with_fallback(player_ship_3d_scene, PLAYER_SHIP_GLB_PATH)

func instantiate_enemy_ship_3d(enemy_type: String) -> Node3D:
	var key: String = enemy_type
	if key == "boss":
		key = "boss_titan"
	var res_path: String = ENEMY_GLB_PATHS.get(key, ENEMY_GLB_PATHS["scout"])
	var cached: PackedScene = enemy_3d_scenes.get(key, null)
	return _instantiate_glb_with_fallback(cached, res_path)

func _load_fonts() -> void:
	var font_path: String = "res://assets/fonts/PressStart2P.ttf"
	if ResourceLoader.exists(font_path):
		pixel_font = load(font_path) as FontFile
	if pixel_font == null and FileAccess.file_exists(font_path):
		var f := FontFile.new()
		var err := f.load_dynamic_font(font_path)
		if err == OK:
			pixel_font = f

func _load_image_from_res(res_path: String) -> Image:
	if ResourceLoader.exists(res_path):
		var tex := load(res_path) as Texture2D
		if tex != null:
			var tex_img: Image = tex.get_image()
			if tex_img != null:
				if tex_img.is_compressed():
					tex_img.decompress()
				return tex_img
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	var img := Image.new()
	if not abs_path.is_empty() and FileAccess.file_exists(abs_path):
		var err := img.load(abs_path)
		if err == OK:
			return img
	return null

func _make_flash_image(src_img: Image) -> Image:
	var f_img: Image = src_img.duplicate()
	f_img.convert(Image.FORMAT_RGBA8)
	var w: int = f_img.get_width()
	var h: int = f_img.get_height()
	for y in range(h):
		for x in range(w):
			var c: Color = f_img.get_pixel(x, y)
			if c.a > 0.0:
				f_img.set_pixel(x, y, Color(1.0, 1.0, 1.0, c.a))
	return f_img

func _load_tex_and_flash(res_path: String) -> Array[Texture2D]:
	var img: Image = _load_image_from_res(res_path)
	if img == null:
		return [null, null]
	var tex := ImageTexture.create_from_image(img)
	var flash_img: Image = _make_flash_image(img)
	var flash_tex := ImageTexture.create_from_image(flash_img)
	return [tex, flash_tex]

func _load_textures() -> void:
	# Menu BG & Logo
	var bg_img: Image = _load_image_from_res("res://assets/images/menu_bg_1080p.png")
	if bg_img == null:
		bg_img = _load_image_from_res("res://assets/images/menu_bg.png")
	if bg_img:
		tex_menu_bg = ImageTexture.create_from_image(bg_img)

	var neb_img: Image = _load_image_from_res("res://assets/images/menu_nebula_loop.png")
	if neb_img != null:
		tex_menu_nebula_loop = ImageTexture.create_from_image(neb_img)

	menu_bg_frames.clear()
	for i in range(8):
		var f_img: Image = _load_image_from_res("res://assets/images/menu_anim/frame_%d.png" % i)
		if f_img != null:
			menu_bg_frames.append(ImageTexture.create_from_image(f_img))

	var logo_img: Image = _load_image_from_res("res://assets/images/psl_logo.png")
	if logo_img:
		tex_logo = ImageTexture.create_from_image(logo_img)

	# Static ship & boss textures
	var sc_pair := _load_tex_and_flash("res://assets/images/enemy_scout.png")
	tex_scout = sc_pair[0]
	tex_scout_flash = sc_pair[1]

	var rd_pair := _load_tex_and_flash("res://assets/images/enemy_raider.png")
	tex_raider = rd_pair[0]
	tex_raider_flash = rd_pair[1]

	var dr_pair := _load_tex_and_flash("res://assets/images/boss_dreadnought.png")
	tex_dreadnought = dr_pair[0]
	tex_dreadnought_flash = dr_pair[1]

	var bs_pair := _load_tex_and_flash("res://assets/images/boss_titan.png")
	tex_boss = bs_pair[0]
	tex_boss_flash = bs_pair[1]

	# Slice Player Ship Spritesheet (12 cols x 3 rows of 230x120)
	_load_player_spritesheet()
	# Slice Scout Spritesheet (4 cols x 3 rows of 96x56)
	_load_scout_spritesheet()
	# Slice Raider Spritesheet (4 cols x 3 rows of 128x68)
	_load_raider_spritesheet()

	# Load control prompt sprites
	var ctrl_keys: Array[String] = [
		"stick_base", "stick_cap",
		"btn_a_normal", "btn_a_pressed",
		"btn_x_normal", "btn_x_pressed",
		"btn_lt_normal", "btn_lt_pressed"
	]
	for k in ctrl_keys:
		var c_img: Image = _load_image_from_res("res://assets/images/controls/" + k + ".png")
		if c_img:
			control_textures[k] = ImageTexture.create_from_image(c_img)

func _load_player_spritesheet() -> void:
	var sheet_img: Image = _load_image_from_res("res://assets/images/player_ship_spritesheet.png")
	if sheet_img == null:
		return
	var fw: int = 230
	var fh: int = 120
	var bank_rows: Array[String] = ["bank_left", "neutral", "bank_right"]
	var throttles: Array = [["idle", 0], ["cruise", 4], ["boost", 8]]

	for r_idx in range(bank_rows.size()):
		var b_name: String = bank_rows[r_idx]
		player_frames[b_name] = {}
		player_flash_frames[b_name] = {}
		for th_pair in throttles:
			var th_name: String = th_pair[0]
			var c_start: int = th_pair[1]
			var f_list: Array[Texture2D] = []
			var fl_list: Array[Texture2D] = []
			for i in range(4):
				var rect := Rect2i((c_start + i) * fw, r_idx * fh, fw, fh)
				var sub: Image = sheet_img.get_region(rect)
				f_list.append(ImageTexture.create_from_image(sub))
				fl_list.append(ImageTexture.create_from_image(_make_flash_image(sub)))
			player_frames[b_name][th_name] = f_list
			player_flash_frames[b_name][th_name] = fl_list

	player_frames["tilt_up"] = player_frames["bank_left"]
	player_frames["tilt_down"] = player_frames["bank_right"]
	player_flash_frames["tilt_up"] = player_flash_frames["bank_left"]
	player_flash_frames["tilt_down"] = player_flash_frames["bank_right"]

func _load_scout_spritesheet() -> void:
	var sheet_img: Image = _load_image_from_res("res://assets/images/enemy_scout_spritesheet.png")
	if sheet_img == null:
		return
	var fw: int = 96
	var fh: int = 56
	var rows: Array[String] = ["cruise", "charge", "fire"]
	for r_idx in range(rows.size()):
		var r_name: String = rows[r_idx]
		var f_list: Array[Texture2D] = []
		var fl_list: Array[Texture2D] = []
		for c_idx in range(4):
			var rect := Rect2i(c_idx * fw, r_idx * fh, fw, fh)
			var sub: Image = sheet_img.get_region(rect)
			f_list.append(ImageTexture.create_from_image(sub))
			fl_list.append(ImageTexture.create_from_image(_make_flash_image(sub)))
		scout_anims[r_name] = f_list
		scout_flash_anims[r_name] = fl_list

func _load_raider_spritesheet() -> void:
	var sheet_img: Image = _load_image_from_res("res://assets/images/enemy_raider_spritesheet.png")
	if sheet_img == null:
		return
	var fw: int = 128
	var fh: int = 68
	var rows: Array[String] = ["bank_left", "neutral", "bank_right"]
	for r_idx in range(rows.size()):
		var r_name: String = rows[r_idx]
		var f_list: Array[Texture2D] = []
		var fl_list: Array[Texture2D] = []
		for c_idx in range(4):
			var rect := Rect2i(c_idx * fw, r_idx * fh, fw, fh)
			var sub: Image = sheet_img.get_region(rect)
			f_list.append(ImageTexture.create_from_image(sub))
			fl_list.append(ImageTexture.create_from_image(_make_flash_image(sub)))
		raider_anims[r_name] = f_list
		raider_flash_anims[r_name] = fl_list


func _scale_tex(tex: Texture2D, target_size: Vector2i) -> Texture2D:
	if tex == null:
		return null
	var img: Image = tex.get_image().duplicate()
	img.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


func get_texture(key: String) -> Texture2D:
	match key:
		"menu_bg":
			return tex_menu_bg
		"menu_nebula_loop":
			return tex_menu_nebula_loop
		"logo":
			return tex_logo
		"enemy_scout":
			return tex_scout
		"enemy_raider":
			return tex_raider
		"enemy_dreadnought", "boss_dreadnought":
			return tex_dreadnought
		"boss_titan", "boss":
			return tex_boss
		_:
			if control_textures.has(key):
				return control_textures[key]
	return null


func get_scaled_texture(key: String, target_size: Vector2i) -> Texture2D:
	return _scale_tex(get_texture(key), target_size)


func slice_horizontal_sheet(key: String, _cols: int, target_size: Vector2i) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	if key == "ctrl_stick":
		var base_tex: Texture2D = control_textures.get("stick_base", null)
		var cap_tex: Texture2D = control_textures.get("stick_cap", null)
		if base_tex != null and cap_tex != null:
			var base_img: Image = base_tex.get_image()
			var cap_img: Image = cap_tex.get_image()
			base_img.convert(Image.FORMAT_RGBA8)
			cap_img.convert(Image.FORMAT_RGBA8)
			var offsets: Array[Vector2i] = [
				Vector2i(0, 0),
				Vector2i(0, -18),
				Vector2i(0, 18),
				Vector2i(-18, 0),
				Vector2i(18, 0)
			]
			for off in offsets:
				var canvas_img: Image = base_img.duplicate()
				var dst := Vector2i(
					int((canvas_img.get_width() - cap_img.get_width()) * 0.5) + off.x,
					int((canvas_img.get_height() - cap_img.get_height()) * 0.5) + off.y
				)
				canvas_img.blend_rect(cap_img, Rect2i(0, 0, cap_img.get_width(), cap_img.get_height()), dst)
				canvas_img.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
				result.append(ImageTexture.create_from_image(canvas_img))
	elif key == "ctrl_btn_a":
		for k in ["btn_a_normal", "btn_a_pressed"]:
			if control_textures.has(k):
				result.append(_scale_tex(control_textures[k], target_size))
	elif key == "ctrl_btn_x":
		for k in ["btn_x_normal", "btn_x_pressed"]:
			if control_textures.has(k):
				result.append(_scale_tex(control_textures[k], target_size))
	elif key == "ctrl_btn_lt":
		for k in ["btn_lt_normal", "btn_lt_pressed"]:
			if control_textures.has(k):
				result.append(_scale_tex(control_textures[k], target_size))
	return result


func get_player_frames(target_size: Vector2i) -> Dictionary:
	var out_frames: Dictionary = {}
	var out_flash: Dictionary = {}
	for b_key in player_frames.keys():
		out_frames[b_key] = {}
		out_flash[b_key] = {}
		for th_key in player_frames[b_key].keys():
			var scaled_f: Array[Texture2D] = []
			var scaled_fl: Array[Texture2D] = []
			var src_f: Array = player_frames[b_key][th_key]
			var src_fl: Array = player_flash_frames[b_key][th_key]
			for i in range(src_f.size()):
				scaled_f.append(_scale_tex(src_f[i], target_size))
				scaled_fl.append(_scale_tex(src_fl[i], target_size))
			out_frames[b_key][th_key] = scaled_f
			out_flash[b_key][th_key] = scaled_fl
	return {"frames": out_frames, "flash_frames": out_flash}


func get_scout_frames(target_size: Vector2i) -> Dictionary:
	var rows: Array[String] = ["cruise", "charge", "fire"]
	var out_frames: Array = []
	var out_flash: Array = []
	for r_name in rows:
		var r_f: Array[Texture2D] = []
		var r_fl: Array[Texture2D] = []
		var src_f: Array = scout_anims.get(r_name, [])
		var src_fl: Array = scout_flash_anims.get(r_name, [])
		for i in range(src_f.size()):
			r_f.append(_scale_tex(src_f[i], target_size))
			r_fl.append(_scale_tex(src_fl[i], target_size))
		out_frames.append(r_f)
		out_flash.append(r_fl)
	return {"frames": out_frames, "flash_frames": out_flash}


func get_raider_frames(target_size: Vector2i) -> Dictionary:
	var rows: Array[String] = ["bank_left", "neutral", "bank_right"]
	var out_frames: Array = []
	var out_flash: Array = []
	for r_name in rows:
		var r_f: Array[Texture2D] = []
		var r_fl: Array[Texture2D] = []
		var src_f: Array = raider_anims.get(r_name, [])
		var src_fl: Array = raider_flash_anims.get(r_name, [])
		for i in range(src_f.size()):
			r_f.append(_scale_tex(src_f[i], target_size))
			r_fl.append(_scale_tex(src_fl[i], target_size))
		out_frames.append(r_f)
		out_flash.append(r_fl)
	return {"frames": out_frames, "flash_frames": out_flash}

# --- Retro Text Rendering Helpers on any CanvasItem ---
func get_pixel_font() -> Font:
	return pixel_font if pixel_font != null else ThemeDB.fallback_font


func draw_text(
	canvas: CanvasItem,
	text: String,
	x: float,
	y: float,
	size: int = 16,
	color: Color = COLOR_WHITE,
	align: String = "center",
	shadow: bool = true,
	shadow_color: Color = Color(0, 0, 0, 1),
	alpha: float = 1.0
) -> void:
	var font: Font = pixel_font if pixel_font != null else ThemeDB.fallback_font
	var str_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var ascent: float = font.get_ascent(size)
	var pos := Vector2(x, y)

	if align == "center":
		pos.x = x - str_size.x * 0.5
		pos.y = y + ascent * 0.42
	elif align == "left":
		pos.x = x
		pos.y = y + ascent
	elif align == "midleft":
		pos.x = x
		pos.y = y + ascent * 0.42
	elif align == "right":
		pos.x = x - str_size.x
		pos.y = y + ascent * 0.42

	var draw_col := Color(color.r, color.g, color.b, color.a * alpha)
	if shadow:
		var sh_col := Color(shadow_color.r, shadow_color.g, shadow_color.b, shadow_color.a * alpha)
		canvas.draw_string(font, pos + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, sh_col)

	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, draw_col)

func draw_glow_text(
	canvas: CanvasItem,
	text: String,
	x: float,
	y: float,
	size: int = 24,
	color: Color = COLOR_CYAN,
	glow_color: Color = COLOR_MAGENTA,
	align: String = "center",
	pulse_time: float = 0.0
) -> void:
	var glow_offset: float = 1.0 + float(int(abs(sin(pulse_time * 3.0)) * 2.0))
	var offsets: Array[Vector2] = [
		Vector2(-glow_offset, 0),
		Vector2(glow_offset, 0),
		Vector2(0, -glow_offset),
		Vector2(0, glow_offset)
	]
	for off in offsets:
		draw_text(canvas, text, x + off.x, y + off.y, size, glow_color, align, false)
	draw_text(canvas, text, x, y, size, color, align, false)

func format_commas(val: int) -> String:
	var s: String = str(abs(val))
	var out: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = s[i] + out
		count += 1
	return ("-" + out) if val < 0 else out


func draw_glass_panel(
	canvas: CanvasItem,
	rect: Rect2,
	bg_color: Color = Color8(8, 12, 32, 200),
	border_color: Color = COLOR_CYAN,
	accent_color: Color = COLOR_MAGENTA,
	corner_size: float = 16.0,
	border_width: float = 2.0
) -> void:
	canvas.draw_rect(rect, bg_color, true)

	var stripe_col = Color(border_color.r, border_color.g, border_color.b, 0.16)
	canvas.draw_rect(Rect2(rect.position.x + 2, rect.position.y + 2, rect.size.x - 4, 6), stripe_col, true)

	canvas.draw_rect(rect, border_color, false, border_width)

	var c = corner_size
	var x = rect.position.x
	var y = rect.position.y
	var w = rect.size.x
	var h = rect.size.y

	# Top-left bracket
	canvas.draw_line(Vector2(x - 2, y - 2), Vector2(x + c, y - 2), accent_color, 3.0)
	canvas.draw_line(Vector2(x - 2, y - 2), Vector2(x - 2, y + c), accent_color, 3.0)

	# Top-right bracket
	canvas.draw_line(Vector2(x + w - c, y - 2), Vector2(x + w + 2, y - 2), accent_color, 3.0)
	canvas.draw_line(Vector2(x + w + 2, y - 2), Vector2(x + w + 2, y + c), accent_color, 3.0)

	# Bottom-left bracket
	canvas.draw_line(Vector2(x - 2, y + h - c), Vector2(x - 2, y + h + 2), accent_color, 3.0)
	canvas.draw_line(Vector2(x - 2, y + h + 2), Vector2(x + c, y + h + 2), accent_color, 3.0)

	# Bottom-right bracket
	canvas.draw_line(Vector2(x + w - c, y + h + 2), Vector2(x + w + 2, y + h + 2), accent_color, 3.0)
	canvas.draw_line(Vector2(x + w + 2, y + h - c), Vector2(x + w + 2, y + h + 2), accent_color, 3.0)


func draw_control_badge(
	canvas: CanvasItem,
	x: float,
	y: float,
	key_label: String,
	action_label: String,
	color: Color = COLOR_CYAN
) -> float:
	var font = get_pixel_font()
	var key_sz = font.get_string_size(key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var badge_w = key_sz.x + 22.0
	var badge_h = 32.0
	var badge_rect = Rect2(x, y - badge_h * 0.5, badge_w, badge_h)

	canvas.draw_rect(badge_rect, Color8(18, 26, 58), true)
	canvas.draw_rect(badge_rect, color, false, 2.0)

	draw_text(canvas, key_label, x + badge_w * 0.5, y, 14, COLOR_GOLD, "center")
	draw_text(canvas, action_label, x + badge_w + 10.0, y, 14, COLOR_WHITE, "midleft")

	var act_sz = font.get_string_size(action_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	return badge_w + act_sz.x + 38.0


func _build_vfx_textures() -> void:
	# 1. Procedural smooth teardrop Photon Plasma Lance texture (112x44, +X leading right)
	var bw: int = 112
	var bh: int = 44
	var bolt_img := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
	for py in range(bh):
		var v: float = (float(py) + 0.5 - float(bh) * 0.5) / (float(bh) * 0.5)
		var av: float = absf(v)
		for px in range(bw):
			var u: float = (float(px) + 0.5) / float(bw)
			# Asymmetric supersonic teardrop profile: long tapered tail [0.03..0.77], rounded plasma head [0.77..0.93]
			var profile: float = 0.0
			if u >= 0.03 and u < 0.77:
				profile = pow((u - 0.03) / 0.74, 0.68)
			elif u >= 0.77 and u <= 0.94:
				var nu: float = (u - 0.77) / 0.17
				profile = sqrt(maxf(0.0, 1.0 - nu * nu))

			# Outer atmospheric cobalt-cyan Gaussian bloom
			var bloom_u: float = exp(-pow((u - 0.66) / 0.34, 2.0)) * clampf((u - 0.01) * 8.0, 0.0, 1.0) * clampf((0.99 - u) * 14.0, 0.0, 1.0)
			var bloom_sigma: float = 0.24 + 0.30 * profile
			var bloom: float = bloom_u * exp(-pow(av / maxf(bloom_sigma, 0.05), 2.0))

			# Crisp neon-cyan plasma sheath
			var sheath_r: float = maxf(0.001, profile * 0.34)
			var sheath: float = clampf(1.0 - (av - sheath_r * 0.55) / (sheath_r * 0.65), 0.0, 1.0) * step_soft(0.04, 0.12, u) * step_soft(0.95, 0.89, u)

			# Incandescent white-hot inner needle core
			var core_r: float = maxf(0.001, profile * 0.145)
			var core: float = clampf(1.0 - (av - core_r * 0.45) / (core_r * 0.70), 0.0, 1.0) * step_soft(0.18, 0.32, u) * step_soft(0.92, 0.86, u)

			# Anamorphic vertical & horizontal glint at the leading plasma focal head (u = 0.78)
			var dx_head: float = absf(u - 0.78)
			var head_glint: float = exp(-dx_head * 24.0) * exp(-av * 2.6) * 0.75

			# Color synthesis via clean Color.lerp so Blue is ALWAYS >= Green (zero seafoam overshoot!)
			var tail_tint: float = clampf((0.46 - u) / 0.42, 0.0, 1.0)
			var bloom_col := Color(lerpf(0.04, 0.22, tail_tint), lerpf(0.46, 0.26, tail_tint), 1.0, 1.0)
			var sheath_col := Color(0.02, 0.82, 1.0, 1.0)
			var core_col := Color(0.96, 0.99, 1.0, 1.0)
			var final_col: Color = bloom_col.lerp(sheath_col, sheath).lerp(core_col, clampf(maxf(core, head_glint * 0.85), 0.0, 1.0))

			var alpha: float = clampf(maxf(bloom * 0.62, maxf(sheath * 0.90, maxf(core, head_glint * 0.72))), 0.0, 1.0)
			if alpha > 0.004:
				bolt_img.set_pixel(px, py, Color(final_col.r, final_col.g, final_col.b, alpha))
			else:
				bolt_img.set_pixel(px, py, Color(0.0, 0.0, 0.0, 0.0))
	tex_photon_bolt = ImageTexture.create_from_image(bolt_img)

	# 2. Procedural Enemy Crimson-Scarlet Plasma Comet texture (96x48) & Solar-Gold Railgun Lance texture (108x44)
	tex_enemy_comet_red = _create_directional_plasma_tex(
		96,
		48,
		0.68,
		0.40,
		Color(0.78, 0.02, 0.14, 1.0),
		Color(0.95, 0.16, 0.08, 1.0),
		Color(1.0, 0.36, 0.14, 1.0),
		Color(1.0, 0.97, 0.92, 1.0)
	)
	tex_enemy_lance_gold = _create_directional_plasma_tex(
		108,
		44,
		0.74,
		0.32,
		Color(0.88, 0.24, 0.02, 1.0),
		Color(0.96, 0.48, 0.04, 1.0),
		Color(1.0, 0.82, 0.12, 1.0),
		Color(1.0, 0.99, 0.88, 1.0)
	)

	# 3. Procedural 4-point starburst & radial energy orb textures (64x64)
	tex_photon_flare = _create_starburst_orb_tex(
		Color(0.04, 0.56, 1.0, 1.0),
		Color(0.20, 0.86, 1.0, 1.0),
		Color(0.98, 1.0, 1.0, 1.0),
		0.92
	)
	tex_orb_red = _create_starburst_orb_tex(
		Color(0.88, 0.04, 0.16, 1.0),
		Color(1.0, 0.28, 0.16, 1.0),
		Color(1.0, 0.96, 0.94, 1.0),
		0.55
	)
	tex_orb_gold = _create_starburst_orb_tex(
		Color(0.96, 0.34, 0.02, 1.0),
		Color(1.0, 0.82, 0.14, 1.0),
		Color(1.0, 0.99, 0.90, 1.0),
		0.82
	)
	tex_orb_magenta = _create_starburst_orb_tex(
		Color(0.62, 0.04, 0.92, 1.0),
		Color(1.0, 0.20, 0.82, 1.0),
		Color(1.0, 0.96, 1.0, 1.0),
		0.88
	)


func _create_directional_plasma_tex(
	bw: int,
	bh: int,
	head_u: float,
	thickness: float,
	tail_bloom_col: Color,
	head_bloom_col: Color,
	sheath_col: Color,
	core_col: Color
) -> Texture2D:
	var img := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
	var front_span: float = maxf(0.12, 0.94 - head_u)
	for py in range(bh):
		var v: float = (float(py) + 0.5 - float(bh) * 0.5) / (float(bh) * 0.5)
		var av: float = absf(v)
		for px in range(bw):
			var u: float = (float(px) + 0.5) / float(bw)
			var profile: float = 0.0
			if u >= 0.03 and u < head_u:
				profile = pow((u - 0.03) / maxf(0.1, head_u - 0.03), 0.78)
			elif u >= head_u and u <= head_u + front_span:
				var nu: float = (u - head_u) / front_span
				profile = sqrt(maxf(0.0, 1.0 - nu * nu))

			var bloom_u: float = exp(-pow((u - (head_u - 0.08)) / 0.36, 2.0)) * clampf((u - 0.01) * 7.5, 0.0, 1.0) * clampf((0.99 - u) * 13.0, 0.0, 1.0)
			var bloom_sigma: float = 0.26 + 0.34 * profile
			var bloom: float = bloom_u * exp(-pow(av / maxf(bloom_sigma, 0.05), 2.0))

			var sheath_r: float = maxf(0.001, profile * thickness)
			var sheath: float = clampf(1.0 - (av - sheath_r * 0.55) / (sheath_r * 0.65), 0.0, 1.0) * step_soft(0.05, 0.16, u) * step_soft(0.96, head_u + front_span * 0.85, u)

			var core_r: float = maxf(0.001, profile * thickness * 0.46)
			var core: float = clampf(1.0 - (av - core_r * 0.45) / (core_r * 0.70), 0.0, 1.0) * step_soft(0.24, 0.42, u) * step_soft(0.93, head_u + front_span * 0.72, u)

			var dx_head: float = absf(u - head_u)
			var head_glint: float = exp(-dx_head * 20.0) * exp(-av * 2.8) * 0.72

			var tail_tint: float = clampf(((head_u - 0.18) - u) / 0.45, 0.0, 1.0)
			var b_col: Color = head_bloom_col.lerp(tail_bloom_col, tail_tint)
			var f_col: Color = b_col.lerp(sheath_col, sheath).lerp(core_col, clampf(maxf(core, head_glint * 0.82), 0.0, 1.0))

			var alpha: float = clampf(maxf(bloom * 0.70, maxf(sheath * 0.94, maxf(core, head_glint * 0.74))), 0.0, 1.0)
			if alpha > 0.004:
				img.set_pixel(px, py, Color(f_col.r, f_col.g, f_col.b, alpha))
			else:
				img.set_pixel(px, py, Color(0.0, 0.0, 0.0, 0.0))
	return ImageTexture.create_from_image(img)


func _create_starburst_orb_tex(
	outer_col: Color,
	mid_col: Color,
	core_col: Color,
	star_weight: float = 0.85
) -> Texture2D:
	var fw: int = 64
	var fh: int = 64
	var flare_img := Image.create(fw, fh, false, Image.FORMAT_RGBA8)
	for py in range(fh):
		var ny: float = (float(py) + 0.5 - float(fh) * 0.5) / (float(fh) * 0.5)
		var ay: float = absf(ny)
		for px in range(fw):
			var nx: float = (float(px) + 0.5 - float(fw) * 0.5) / (float(fw) * 0.5)
			var ax: float = absf(nx)
			var rad: float = sqrt(nx * nx + ny * ny)
			var radial_edge: float = step_soft(1.0, 0.18, rad)

			var soft_orb: float = exp(-rad * rad * 3.0) * radial_edge
			var h_spike: float = exp(-ay * 10.5) * exp(-ax * 2.0) * radial_edge
			var v_spike: float = exp(-ax * 11.5) * exp(-ay * 2.4) * radial_edge
			var hot_center: float = exp(-rad * rad * 20.0)

			var star: float = clampf(maxf(h_spike, v_spike * 0.88) * star_weight, 0.0, 1.0)
			var f_col: Color = outer_col.lerp(mid_col, clampf(maxf(soft_orb * 0.85, star), 0.0, 1.0)).lerp(core_col, clampf(hot_center, 0.0, 1.0))
			var a_f: float = clampf(maxf(soft_orb * 0.82, maxf(star * 0.92, hot_center)), 0.0, 1.0)
			if a_f > 0.004:
				flare_img.set_pixel(px, py, Color(f_col.r, f_col.g, f_col.b, a_f))
			else:
				flare_img.set_pixel(px, py, Color(0.0, 0.0, 0.0, 0.0))
	return ImageTexture.create_from_image(flare_img)


func step_soft(edge0: float, edge1: float, x: float) -> float:
	var t: float = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func draw_photon_laser_bolt(
	canvas: CanvasItem,
	x: float,
	y: float,
	anim_phase: float = 0.0,
	scale_mult: float = 1.0
) -> void:
	var pulse: float = 1.0 + 0.11 * sin(anim_phase * 42.0)
	var draw_w: float = 92.0 * scale_mult
	var draw_h: float = 34.0 * scale_mult * pulse
	# Position so the hot plasma head (u=0.78) leads at x + 17 and the ion wake trails behind to x - 66
	var rect := Rect2(x - draw_w * 0.72, y - draw_h * 0.5, draw_w, draw_h)

	# Trailing twin sapphire-cyan ion slipstream micro-streaks
	var wake_wave: float = sin(anim_phase * 34.0) * 2.4 * scale_mult
	canvas.draw_line(
		Vector2(x - 60.0 * scale_mult, y - 2.4 * scale_mult + wake_wave * 0.45),
		Vector2(x - 6.0 * scale_mult, y - 1.5 * scale_mult),
		Color(0.14, 0.56, 1.0, 0.46),
		1.8 * scale_mult
	)
	canvas.draw_line(
		Vector2(x - 52.0 * scale_mult, y + 2.4 * scale_mult - wake_wave * 0.45),
		Vector2(x - 4.0 * scale_mult, y + 1.5 * scale_mult),
		Color(0.28, 0.42, 1.0, 0.40),
		1.5 * scale_mult
	)

	if tex_photon_bolt != null:
		canvas.draw_texture_rect(tex_photon_bolt, rect, false, Color(1.0, 1.0, 1.0, 0.98))
	else:
		canvas.draw_rect(Rect2(x - 20.0, y - 4.0, 38.0, 8.0), COLOR_CYAN, true)

	# Razor-sharp incandescent inner plasma filament, nose cross-glint & focal spark
	var nose_x: float = x + 16.5 * scale_mult
	var tail_x: float = x - 24.0 * scale_mult
	canvas.draw_line(
		Vector2(tail_x, y),
		Vector2(nose_x, y),
		Color(0.95, 0.99, 1.0, 0.96),
		2.8 * scale_mult * pulse
	)
	var glint_h: float = 6.5 * scale_mult * pulse
	canvas.draw_line(
		Vector2(nose_x - 3.0 * scale_mult, y - glint_h),
		Vector2(nose_x - 3.0 * scale_mult, y + glint_h),
		Color(0.65, 0.92, 1.0, 0.65),
		1.6 * scale_mult
	)
	canvas.draw_circle(Vector2(nose_x - 2.0 * scale_mult, y), 3.0 * scale_mult * pulse, Color(1.0, 1.0, 1.0, 0.98))


func draw_photon_muzzle_flash(
	canvas: CanvasItem,
	gx: float,
	gy: float,
	g_ratio: float,
	scale_mult: float = 1.0
) -> void:
	var r: float = clampf(g_ratio, 0.0, 1.0)
	if r <= 0.01:
		return
	if tex_photon_flare != null:
		var fw: float = (34.0 + 24.0 * r) * scale_mult
		var fh: float = (26.0 + 18.0 * r) * scale_mult
		canvas.draw_texture_rect(
			tex_photon_flare,
			Rect2(gx - fw * 0.38, gy - fh * 0.5, fw, fh),
			false,
			Color(1.0, 1.0, 1.0, 0.92 * r)
		)
	# Crisp forward plasma muzzle spike
	canvas.draw_line(
		Vector2(gx - 2.0 * scale_mult, gy),
		Vector2(gx + (16.0 + 12.0 * r) * scale_mult, gy),
		Color(0.88, 1.0, 1.0, 0.92 * r),
		2.4 * scale_mult
	)
	canvas.draw_circle(Vector2(gx + 2.0 * scale_mult, gy), 3.4 * scale_mult * r, Color(1.0, 1.0, 1.0, 0.96 * r))


func draw_photon_impact_flash(
	canvas: CanvasItem,
	ix: float,
	iy: float,
	progress: float,
	scale_mult: float = 1.0
) -> void:
	# progress: 0.0 (just hit) -> 1.0 (faded out)
	var p: float = clampf(progress, 0.0, 1.0)
	var inv_p: float = 1.0 - p
	if inv_p <= 0.01:
		return
	if tex_photon_flare != null:
		var sz: float = (48.0 * inv_p + 14.0) * scale_mult
		canvas.draw_texture_rect(
			tex_photon_flare,
			Rect2(ix - sz * 0.5, iy - sz * 0.5, sz, sz),
			false,
			Color(1.0, 1.0, 1.0, 0.94 * inv_p)
		)
	# Radiating plasma slash needles rebounding off the enemy armor
	var slash_angles = [PI - 0.52, PI - 0.18, PI + 0.22, PI + 0.58, -0.45, 0.45]
	for idx in range(slash_angles.size()):
		var ang: float = slash_angles[idx]
		var r0: float = (3.0 + 14.0 * p) * scale_mult
		var r1: float = (13.0 + 24.0 * p - float(idx % 2) * 4.0) * scale_mult
		canvas.draw_line(
			Vector2(ix + cos(ang) * r0, iy + sin(ang) * r0),
			Vector2(ix + cos(ang) * r1, iy + sin(ang) * r1),
			Color(0.65, 0.92, 1.0, 0.88 * inv_p),
			2.0 * scale_mult * inv_p + 0.6
		)


func draw_homing_missile(
	canvas: CanvasItem,
	x: float,
	y: float,
	vx: float,
	vy: float,
	trail: Array,
	age: float = 0.0,
	is_tracking: bool = true,
	scale_mult: float = 1.0
) -> void:
	var pos := Vector2(x, y)
	var spd_sq: float = vx * vx + vy * vy
	var fwd: Vector2 = Vector2(vx, vy).normalized() if spd_sq > 1.0 else Vector2.RIGHT
	var perp := Vector2(-fwd.y, fwd.x)
	var s: float = scale_mult * 1.22
	var nozzle: Vector2 = pos - fwd * (13.0 * s)

	# 1. Volumetric propellant smoke puffs + glowing plasma ribbon contrail anchored strictly at nozzle
	var tail_pts: Array[Vector2] = []
	for raw_pt in trail:
		var v: Vector2 = raw_pt
		if (v - nozzle).dot(fwd) <= 1.0:
			tail_pts.append(v)
	tail_pts.append(nozzle)

	var n_pts: int = tail_pts.size()
	if n_pts >= 2:
		for i in range(n_pts - 1):
			var t_frac: float = float(i + 1) / float(n_pts)
			var pt: Vector2 = tail_pts[i]
			# Expanding warm-indigo propellant smoke puff behind the missile flame
			var smoke_r: float = (10.5 * (1.0 - t_frac * 0.52) + 3.0) * scale_mult
			var smoke_a: float = 0.34 * t_frac * (1.0 - t_frac * 0.28)
			canvas.draw_circle(pt, smoke_r, Color(0.42, 0.28, 0.56, smoke_a))

		for i in range(n_pts - 1):
			var p0: Vector2 = tail_pts[i]
			var p1: Vector2 = tail_pts[i + 1]
			var seg_t: float = float(i + 1) / float(n_pts)
			# Soft crimson-amber glow under-ribbon
			canvas.draw_line(p0, p1, Color(1.0, 0.28, 0.08, 0.26 * seg_t), (5.0 + 7.5 * seg_t) * scale_mult)
			var rib_col: Color = Color(0.96, 0.28, 0.12, 0.22 + 0.62 * seg_t).lerp(
				Color(1.0, 0.86, 0.24, 0.94),
				seg_t * seg_t
			)
			canvas.draw_line(p0, p1, rib_col, (1.8 + 5.2 * seg_t) * scale_mult)
			if seg_t > 0.50:
				canvas.draw_line(p0, p1, Color(1.0, 0.98, 0.88, (seg_t - 0.50) * 1.65), (1.2 + 2.0 * seg_t) * scale_mult)

	# 2. Roaring animated rear afterburner plume seated at the rocket nozzle
	var pulse: float = 1.0 + 0.20 * sin(age * 46.0)
	if tex_orb_gold != null:
		var glow_sz: float = 34.0 * s * pulse
		canvas.draw_texture_rect(
			tex_orb_gold,
			Rect2(nozzle.x - glow_sz * 0.5, nozzle.y - glow_sz * 0.5, glow_sz, glow_sz),
			false,
			Color(1.0, 1.0, 1.0, 0.92)
		)
	var flame_outer := PackedVector2Array([
		nozzle + perp * (4.5 * s),
		nozzle - fwd * (19.0 * s * pulse),
		nozzle - perp * (4.5 * s),
	])
	canvas.draw_colored_polygon(flame_outer, Color(1.0, 0.36, 0.06, 0.95))
	var flame_core := PackedVector2Array([
		nozzle + perp * (2.6 * s),
		nozzle - fwd * (11.5 * s * pulse),
		nozzle - perp * (2.6 * s),
	])
	canvas.draw_colored_polygon(flame_core, Color(1.0, 0.96, 0.80, 0.98))

	# 3. Armored finned Photon Torpedo fuselage (Option C dark ink silhouette + two-tone titanium/gunmetal + gold band)
	var outline_hull := PackedVector2Array([
		pos + fwd * (17.5 * s),
		pos + fwd * (7.5 * s) + perp * (5.6 * s),
		pos - fwd * (5.0 * s) + perp * (5.6 * s),
		pos - fwd * (13.5 * s) + perp * (9.6 * s),
		pos - fwd * (14.5 * s) + perp * (4.8 * s),
		pos - fwd * (14.5 * s) - perp * (4.8 * s),
		pos - fwd * (13.5 * s) - perp * (9.6 * s),
		pos - fwd * (5.0 * s) - perp * (5.6 * s),
		pos + fwd * (7.5 * s) - perp * (5.6 * s),
	])
	canvas.draw_colored_polygon(outline_hull, Color(0.03, 0.03, 0.09, 0.98))

	# Swept gunmetal tail fins
	var fin_l := PackedVector2Array([
		pos - fwd * (5.5 * s) + perp * (3.8 * s),
		pos - fwd * (12.8 * s) + perp * (8.4 * s),
		pos - fwd * (13.2 * s) + perp * (3.8 * s),
	])
	var fin_r := PackedVector2Array([
		pos - fwd * (5.5 * s) - perp * (3.8 * s),
		pos - fwd * (13.2 * s) - perp * (3.8 * s),
		pos - fwd * (12.8 * s) - perp * (8.4 * s),
	])
	canvas.draw_colored_polygon(fin_l, Color(0.22, 0.28, 0.40, 1.0))
	canvas.draw_colored_polygon(fin_r, Color(0.16, 0.21, 0.32, 1.0))

	# Main cylindrical torpedo body (bright silver-titanium dorsal half + slate belly)
	var body_top := PackedVector2Array([
		pos + fwd * (15.5 * s),
		pos + fwd * (7.0 * s) + perp * (4.1 * s),
		pos - fwd * (13.0 * s) + perp * (4.1 * s),
		pos - fwd * (13.0 * s),
	])
	var body_bot := PackedVector2Array([
		pos + fwd * (15.5 * s),
		pos - fwd * (13.0 * s),
		pos - fwd * (13.0 * s) - perp * (4.1 * s),
		pos + fwd * (7.0 * s) - perp * (4.1 * s),
	])
	canvas.draw_colored_polygon(body_top, Color(0.86, 0.93, 1.0, 1.0))
	canvas.draw_colored_polygon(body_bot, Color(0.46, 0.56, 0.72, 1.0))

	# Amber-gold ordnance collar stripe
	var band := PackedVector2Array([
		pos + fwd * (2.6 * s) + perp * (4.1 * s),
		pos - fwd * (2.6 * s) + perp * (4.1 * s),
		pos - fwd * (2.6 * s) - perp * (4.1 * s),
		pos + fwd * (2.6 * s) - perp * (4.1 * s),
	])
	canvas.draw_colored_polygon(band, COLOR_GOLD)

	# 4. Glowing target-lock seeker nose warhead (pulsing neon-magenta when locked, amber when ballistic)
	var nose_tip: Vector2 = pos + fwd * (12.5 * s)
	var warhead_col: Color = Color(1.0, 0.20, 0.70, 1.0) if is_tracking else Color(1.0, 0.62, 0.12, 1.0)
	var warhead_poly := PackedVector2Array([
		pos + fwd * (15.8 * s),
		pos + fwd * (7.2 * s) + perp * (3.9 * s),
		pos + fwd * (7.2 * s) - perp * (3.9 * s),
	])
	canvas.draw_colored_polygon(warhead_poly, warhead_col)
	var seeker_tex: Texture2D = tex_orb_magenta if is_tracking else tex_orb_gold
	if seeker_tex != null:
		var s_pulse: float = (22.0 + 5.5 * sin(age * 28.0)) * s
		canvas.draw_texture_rect(
			seeker_tex,
			Rect2(nose_tip.x - s_pulse * 0.5, nose_tip.y - s_pulse * 0.5, s_pulse, s_pulse),
			false,
			Color(1.0, 1.0, 1.0, 0.90)
		)
	canvas.draw_circle(nose_tip, 2.2 * s, Color(1.0, 1.0, 1.0, 0.98))


func draw_missile_blast(
	canvas: CanvasItem,
	bx: float,
	by: float,
	progress: float,
	scale_mult: float = 1.0
) -> void:
	var p: float = clampf(progress, 0.0, 1.0)
	var inv_p: float = 1.0 - p
	if inv_p <= 0.01:
		return
	var center := Vector2(bx, by)
	if tex_orb_gold != null:
		var sz_g: float = (138.0 * pow(p, 0.42) + 46.0) * scale_mult
		canvas.draw_texture_rect(
			tex_orb_gold,
			Rect2(bx - sz_g * 0.5, by - sz_g * 0.5, sz_g, sz_g),
			false,
			Color(1.0, 1.0, 1.0, 0.96 * inv_p)
		)
	if tex_orb_magenta != null:
		var sz_m: float = (86.0 * inv_p + 26.0) * scale_mult
		canvas.draw_texture_rect(
			tex_orb_magenta,
			Rect2(bx - sz_m * 0.5, by - sz_m * 0.5, sz_m, sz_m),
			false,
			Color(1.0, 1.0, 1.0, 0.88 * inv_p)
		)
	# Blazing incandescent detonation fireball + radiating shrapnel plasma slashes
	canvas.draw_circle(center, (22.0 * inv_p + 5.0) * scale_mult, Color(1.0, 0.78, 0.22, 0.72 * inv_p))
	canvas.draw_circle(center, (14.0 * inv_p + 3.0) * scale_mult, Color(1.0, 0.99, 0.90, 0.96 * inv_p))
	for i in range(10):
		var ang: float = float(i) * (TAU / 10.0) + 0.22
		var r0: float = (8.0 + 26.0 * p) * scale_mult
		var r1: float = (26.0 + 56.0 * p - float(i % 2) * 14.0) * scale_mult
		canvas.draw_line(
			Vector2(bx + cos(ang) * r0, by + sin(ang) * r0),
			Vector2(bx + cos(ang) * r1, by + sin(ang) * r1),
			Color(1.0, 0.90, 0.45, 0.92 * inv_p),
			2.8 * scale_mult * inv_p + 0.8
		)


func _draw_oriented_tex_quad(
	canvas: CanvasItem,
	tex: Texture2D,
	pos: Vector2,
	fwd: Vector2,
	perp: Vector2,
	draw_w: float,
	draw_h: float,
	head_u: float,
	mod_col: Color = Color.WHITE
) -> void:
	var back_edge: Vector2 = pos - fwd * (draw_w * head_u)
	var front_edge: Vector2 = pos + fwd * (draw_w * (1.0 - head_u))
	var half_h: float = draw_h * 0.5
	var pts := PackedVector2Array([
		back_edge - perp * half_h,
		front_edge - perp * half_h,
		front_edge + perp * half_h,
		back_edge + perp * half_h,
	])
	var cols := PackedColorArray([mod_col, mod_col, mod_col, mod_col])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	])
	canvas.draw_polygon(pts, cols, uvs, tex)


func draw_enemy_projectile(
	canvas: CanvasItem,
	x: float,
	y: float,
	vx: float,
	vy: float,
	radius: float,
	col: Color,
	anim_time: float = 0.0
) -> void:
	var pos := Vector2(x, y)
	var spd_sq: float = vx * vx + vy * vy
	var fwd: Vector2 = Vector2(vx, vy).normalized() if spd_sq > 1.0 else Vector2.LEFT
	var perp := Vector2(-fwd.y, fwd.x)
	var pulse: float = 1.0 + 0.10 * sin(anim_time * 26.0 + (x + y) * 0.025)

	# Distinguish the 3 enemy weapon archetypes by their palette color:
	# 1. Solar-Gold Heavy Capital Railgun Lance (Dreadnought & Boss Titan aimed twin-railgun bursts)
	var is_gold: bool = (col.r > 0.85 and col.g > 0.65 and col.b < 0.35)
	# 2. Neon-Magenta Nova Pulsar Star (Boss Titan 14-shot radial nova storm)
	var is_magenta: bool = (col.r > 0.75 and col.b > 0.45 and col.g < 0.35)

	if is_gold:
		# Twin amber-gold ionized slipstream wakes
		canvas.draw_line(
			pos - fwd * (radius * 5.2),
			pos - fwd * (radius * 0.6),
			Color(1.0, 0.58, 0.06, 0.48),
			maxf(1.8, radius * 0.28)
		)
		if tex_enemy_lance_gold != null:
			_draw_oriented_tex_quad(
				canvas,
				tex_enemy_lance_gold,
				pos,
				fwd,
				perp,
				radius * 8.4,
				radius * 4.4 * pulse,
				0.74,
				Color(1.0, 1.0, 1.0, 0.98)
			)
		# Razor-sharp incandescent white-gold lance spine & focal cross-glint
		canvas.draw_line(
			pos - fwd * (radius * 2.1),
			pos + fwd * (radius * 1.65),
			Color(1.0, 0.99, 0.88, 0.98),
			maxf(2.6, radius * 0.48 * pulse)
		)
		var glint_r: float = radius * 0.85 * pulse
		canvas.draw_line(
			pos + fwd * (radius * 0.35) - perp * glint_r,
			pos + fwd * (radius * 0.35) + perp * glint_r,
			Color(1.0, 0.92, 0.55, 0.72),
			maxf(1.5, radius * 0.22)
		)
		canvas.draw_circle(pos + fwd * (radius * 0.35), maxf(2.8, radius * 0.46), Color(1.0, 1.0, 0.95, 1.0))

	elif is_magenta:
		var pulse_m: float = 1.0 + 0.12 * sin(anim_time * 18.0 + (x + y) * 0.02)
		if tex_orb_magenta != null:
			var m_sz: float = radius * 5.6 * pulse_m
			canvas.draw_texture_rect(
				tex_orb_magenta,
				Rect2(pos.x - m_sz * 0.5, pos.y - m_sz * 0.5, m_sz, m_sz),
				false,
				Color(1.0, 1.0, 1.0, 0.94)
			)
		# Dark-violet Option C contrast rim + spinning 4-point neon-magenta pulsar star + inner white core
		var rot: float = anim_time * 7.5 + (x - y) * 0.015
		var d1 := Vector2(cos(rot), sin(rot))
		var d2 := Vector2(-d1.y, d1.x)
		var star_r: float = radius * 1.85 * pulse_m
		var waist_r: float = radius * 0.72
		var star_poly := PackedVector2Array([
			pos + d1 * star_r,
			pos + (d1 + d2).normalized() * waist_r,
			pos + d2 * star_r,
			pos + (-d1 + d2).normalized() * waist_r,
			pos - d1 * star_r,
			pos + (-d1 - d2).normalized() * waist_r,
			pos - d2 * star_r,
			pos + (d1 - d2).normalized() * waist_r,
		])
		canvas.draw_circle(pos, radius + 1.8, Color(0.18, 0.02, 0.30, 0.88))
		canvas.draw_colored_polygon(star_poly, Color(1.0, 0.22, 0.84, 0.98))
		canvas.draw_circle(pos, maxf(3.2, radius * 0.62), Color(1.0, 0.96, 1.0, 1.0))

	else:
		# Crimson-Scarlet Enemy Plasma Comet (Scout, Raider, Dreadnought & Boss Titan fan volleys)
		if tex_enemy_comet_red != null:
			_draw_oriented_tex_quad(
				canvas,
				tex_enemy_comet_red,
				pos,
				fwd,
				perp,
				radius * 7.2,
				radius * 4.8 * pulse,
				0.68,
				Color(1.0, 1.0, 1.0, 0.98)
			)
		# Crisp crimson danger shell + incandescent white-hot fireball core centered on hitbox
		canvas.draw_circle(pos, radius * 0.98, Color(1.0, 0.18, 0.18, 0.95))
		canvas.draw_circle(pos + fwd * (radius * 0.14), maxf(2.8, radius * 0.58 * pulse), Color(1.0, 0.97, 0.92, 1.0))


func draw_score_popup(
	canvas: CanvasItem,
	x: float,
	y: float,
	text: String,
	progress: float,
	style: String = "standard"
) -> void:
	var p: float = clampf(progress, 0.0, 1.0)
	if p >= 1.0:
		return

	# Smooth fade-out over final 32% of lifetime
	var alpha: float = 1.0
	if p > 0.68:
		var ft: float = (p - 0.68) / 0.32
		alpha = 1.0 - ft * ft * (3.0 - 2.0 * ft)
	if alpha <= 0.01:
		return

	# Elastic arcade pop-in scale
	var scale_s: float = 1.0
	if p < 0.09:
		scale_s = lerpf(0.62, 1.22, p / 0.09)
	elif p < 0.22:
		scale_s = lerpf(1.22, 1.0, (p - 0.09) / 0.13)
	elif style in ["capital", "boss"]:
		scale_s = 1.0 + 0.05 * sin(p * 24.0)

	var font_sz: int = 16
	var core_col: Color = Color(1.0, 0.90, 0.24, 1.0)
	var rim_col: Color = Color(0.92, 0.42, 0.04, 1.0)

	match style:
		"raider":
			font_sz = 17
			core_col = Color(1.0, 0.93, 0.34, 1.0)
			rim_col = Color(1.0, 0.34, 0.56, 1.0)
		"dodge":
			font_sz = 17
			core_col = COLOR_CYAN
			rim_col = Color(0.08, 0.42, 0.95, 1.0)
		"capital":
			font_sz = 24
			var pulse_c: float = 0.5 + 0.5 * sin(p * 28.0)
			core_col = COLOR_GOLD.lerp(Color(0.85, 0.99, 1.0, 1.0), pulse_c * 0.65)
			rim_col = COLOR_MAGENTA
		"boss":
			font_sz = 30
			var pulse_b: float = 0.5 + 0.5 * sin(p * 32.0)
			core_col = COLOR_GOLD.lerp(COLOR_CYAN, pulse_b * 0.55)
			rim_col = COLOR_MAGENTA

	# Initial white-hot flash right as enemy explodes
	if p < 0.14:
		core_col = core_col.lerp(Color(1.0, 1.0, 0.96, 1.0), 1.0 - (p / 0.14))

	var font: Font = pixel_font if pixel_font != null else ThemeDB.fallback_font
	var str_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz)
	var ascent: float = font.get_ascent(font_sz)
	var local_pos := Vector2(-str_size.x * 0.5, ascent * 0.42)

	canvas.draw_set_transform(Vector2(x, y), 0.0, Vector2(scale_s, scale_s))

	# Subtle burst halo behind fresh pop-ups
	if p < 0.36:
		var halo_a: float = (1.0 - p / 0.36) * 0.34 * alpha
		var halo_tex: Texture2D = tex_photon_flare if style == "dodge" else tex_orb_gold
		if halo_tex != null:
			var hw: float = str_size.x * 1.35 + 24.0
			var hh: float = float(font_sz) * 2.4 + 14.0
			canvas.draw_texture_rect(
				halo_tex,
				Rect2(-hw * 0.5, -hh * 0.5, hw, hh),
				false,
				Color(1.0, 1.0, 1.0, halo_a)
			)

	# Crisp dark arcade outline + drop shadow so digits stay 100% legible over explosions
	var dark_col := Color(0.02, 0.02, 0.08, 0.96 * alpha)
	canvas.draw_string(font, local_pos + Vector2(3.0, 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, dark_col)
	for off in [
		Vector2(-2.0, 0.0), Vector2(2.0, 0.0), Vector2(0.0, -2.0), Vector2(0.0, 2.0),
		Vector2(-2.0, -2.0), Vector2(2.0, -2.0), Vector2(-2.0, 2.0), Vector2(2.0, 2.0)
	]:
		canvas.draw_string(font, local_pos + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, dark_col)

	# Colored neon rim pass + bright core glyphs
	var rim_draw := Color(rim_col.r, rim_col.g, rim_col.b, 0.78 * alpha)
	for roff in [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0), Vector2(0.0, 1.0)]:
		canvas.draw_string(font, local_pos + roff, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, rim_draw)

	var main_draw := Color(core_col.r, core_col.g, core_col.b, alpha)
	canvas.draw_string(font, local_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, main_draw)

	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_player_shield_hit(
	canvas: CanvasItem,
	cx: float,
	cy: float,
	progress: float,
	hit_angle: float,
	remaining_hp: int = 3
) -> void:
	var p: float = clampf(progress, 0.0, 1.0)
	var inv_p: float = 1.0 - p
	if inv_p <= 0.01:
		return

	var fade: float = pow(inv_p, 1.25)
	var center := Vector2(cx, cy)
	var hit_dir := Vector2(cos(hit_angle), sin(hit_angle))

	# Sleek aerodynamic deflector ellipse fitted around the 3D starfighter (152x86)
	var breath: float = 0.95 + 0.09 * sin(minf(1.0, p * 3.0) * PI * 0.5) + 0.02 * sin(p * 42.0)
	var rx: float = 86.0 * breath
	var ry: float = 50.0 * breath

	var is_critical: bool = (remaining_hp <= 1)
	var col_outer: Color = Color(0.06, 0.58, 1.0, 1.0) if not is_critical else Color(0.84, 0.04, 0.08, 1.0)
	var col_main: Color = Color(0.14, 0.92, 1.0, 1.0) if not is_critical else Color(1.0, 0.15, 0.14, 1.0)
	var col_hot: Color = Color(0.94, 1.0, 1.0, 1.0) if not is_critical else Color(1.0, 0.88, 0.84, 1.0)

	# 1. Smooth per-vertex translucent Fresnel dome fill weighted toward the impact hemisphere
	var segs: int = 36
	var dome_pts := PackedVector2Array()
	var dome_cols := PackedColorArray()
	dome_pts.append(center)
	dome_cols.append(Color(col_outer.r, col_outer.g, col_outer.b, 0.04 * fade))
	for i in range(segs + 1):
		var ang: float = float(i) * TAU / float(segs)
		var u_dir := Vector2(cos(ang), sin(ang))
		var dir_w: float = pow(maxf(0.0, u_dir.dot(hit_dir)), 1.6)
		var v_col: Color = col_outer.lerp(col_main, dir_w)
		v_col.a = (0.09 + 0.28 * dir_w) * fade
		dome_pts.append(center + Vector2(u_dir.x * rx, u_dir.y * ry))
		dome_cols.append(v_col)
	canvas.draw_polygon(dome_pts, dome_cols)

	# 2. Curved hexagonal energy honeycomb facets rippling away from the impact point
	var hex_r: float = 0.23
	var dx_step: float = hex_r * 1.5
	var dy_step: float = hex_r * 1.73205
	var wave_front: float = 0.88 - p * 1.75
	for gx in range(-2, 3):
		for gy in range(-2, 3):
			var hx: float = float(gx) * dx_step
			var hy: float = (float(gy) + (0.5 if abs(gx) % 2 == 1 else 0.0)) * dy_step
			var r_sq: float = hx * hx + hy * hy
			if r_sq > 0.66:
				continue
			var align: float = hx * hit_dir.x + hy * hit_dir.y
			var impact_boost: float = maxf(0.0, align + 0.25) * inv_p
			var ripple_boost: float = exp(-pow((align - wave_front) / 0.28, 2.0)) * 0.95
			var cell_strength: float = clampf(maxf(impact_boost * 0.85, ripple_boost) * fade, 0.0, 1.0)
			if cell_strength <= 0.06:
				continue
			var hex_poly := PackedVector2Array()
			var hex_line := PackedVector2Array()
			for k in range(7):
				var ka: float = float(k % 6) * (TAU / 6.0)
				var vx_n: float = hx + cos(ka) * (hex_r * 0.88)
				var vy_n: float = hy + sin(ka) * (hex_r * 0.88)
				var vr_sq: float = minf(1.0, vx_n * vx_n + vy_n * vy_n)
				# Subtle 3D spherical dome foreshortening
				var dome_scale: float = 1.0 - 0.10 * vr_sq
				var pt := Vector2(cx + vx_n * rx * dome_scale, cy + vy_n * ry * dome_scale)
				if k < 6:
					hex_poly.append(pt)
				hex_line.append(pt)
			var f_c: Color = col_main.lerp(col_hot, cell_strength * 0.55)
			canvas.draw_colored_polygon(hex_poly, Color(f_c.r, f_c.g, f_c.b, 0.13 * cell_strength))
			canvas.draw_polyline(hex_line, Color(f_c.r, f_c.g, f_c.b, 0.72 * cell_strength), 1.5)

	# 3. Double-layered elliptical forcefield rim + propagating dual shock-arcs
	for i in range(segs):
		var a0: float = float(i) * TAU / float(segs)
		var a1: float = float(i + 1) * TAU / float(segs)
		var am: float = 0.5 * (a0 + a1)
		var p0 := Vector2(cx + cos(a0) * rx, cy + sin(a0) * ry)
		var p1 := Vector2(cx + cos(a1) * rx, cy + sin(a1) * ry)
		var ang_diff: float = absf(fmod(am - hit_angle + PI * 3.0, TAU) - PI)
		var rim_dir: float = pow(maxf(0.0, cos(ang_diff)), 1.4)
		var shock_ring: float = exp(-pow((ang_diff - p * 2.35) / 0.30, 2.0)) * inv_p
		var seg_e: float = clampf((0.28 + 0.72 * maxf(rim_dir, shock_ring)) * fade, 0.0, 1.0)
		var glow_c: Color = col_outer.lerp(col_main, maxf(rim_dir, shock_ring))
		canvas.draw_line(p0, p1, Color(glow_c.r, glow_c.g, glow_c.b, 0.42 * seg_e), 6.2 * fade + 1.5)
		var core_c: Color = col_main.lerp(col_hot, maxf(rim_dir * 0.85, shock_ring))
		canvas.draw_line(p0, p1, Color(core_c.r, core_c.g, core_c.b, 0.92 * seg_e), 2.2)

	# 4. Point-of-impact starburst crest & tangential deflection arcs on the struck shield edge
	var crest_pt := Vector2(cx + hit_dir.x * rx * 0.96, cy + hit_dir.y * ry * 0.96)
	var flare_tex: Texture2D = tex_photon_flare if not is_critical else (tex_orb_red if tex_orb_red != null else tex_photon_flare)
	if flare_tex != null:
		var f_sz: float = (74.0 * inv_p + 22.0)
		var f_tint: Color = Color(1.0, 1.0, 1.0, 0.95 * fade) if not is_critical else Color(1.0, 0.30, 0.25, 0.96 * fade)
		canvas.draw_texture_rect(
			flare_tex,
			Rect2(crest_pt.x - f_sz * 0.5, crest_pt.y - f_sz * 0.5, f_sz, f_sz),
			false,
			f_tint
		)
	if is_critical and tex_photon_flare != null:
		var ray_sz: float = (62.0 * inv_p + 18.0)
		canvas.draw_texture_rect(
			tex_photon_flare,
			Rect2(crest_pt.x - ray_sz * 0.5, crest_pt.y - ray_sz * 0.5, ray_sz, ray_sz),
			false,
			Color(1.0, 0.22, 0.18, 0.88 * fade)
		)
	canvas.draw_circle(crest_pt, 7.5 * inv_p + 2.0, Color(col_hot.r, col_hot.g, col_hot.b, 0.96 * fade))
	var tang := Vector2(-hit_dir.y * rx, hit_dir.x * ry).normalized()
	for sgn in [-1.0, 1.0]:
		var d0: Vector2 = crest_pt + tang * (sgn * (4.0 + 18.0 * p))
		var d1: Vector2 = crest_pt + tang * (sgn * (20.0 + 44.0 * p)) - hit_dir * (6.0 * p)
		canvas.draw_line(d0, d1, Color(col_hot.r, col_hot.g, col_hot.b, 0.86 * fade), 2.4 * inv_p + 0.8)


func draw_shield_collapse_wave(canvas: CanvasItem, cx: float, cy: float, progress: float) -> void:
	var p: float = clampf(progress, 0.0, 1.0)
	var inv_p: float = 1.0 - p
	if inv_p <= 0.01:
		return
	var rx: float = 84.0 + 135.0 * pow(p, 0.65)
	var ry: float = 48.0 + 85.0 * pow(p, 0.65)
	var segs: int = 28
	for i in range(segs):
		if (i + int(p * 12.0)) % 3 == 0:
			continue # Shattering broken-ring segments
		var a0: float = float(i) * TAU / float(segs)
		var a1: float = (float(i) + 0.72) * TAU / float(segs)
		var p0 := Vector2(cx + cos(a0) * rx, cy + sin(a0) * ry)
		var p1 := Vector2(cx + cos(a1) * rx, cy + sin(a1) * ry)
		var col: Color = COLOR_CYAN.lerp(COLOR_RED, float(i % 2) * 0.75)
		canvas.draw_line(p0, p1, Color(col.r, col.g, col.b, 0.90 * inv_p), 3.2 * inv_p + 1.0)


func draw_boss_emergency_shield(
	canvas: CanvasItem,
	cx: float,
	cy: float,
	rx: float,
	ry: float,
	anim_time: float,
	remaining_ratio: float,
	hit_flash: float = 0.0,
	hit_angle: float = PI
) -> void:
	var r_rem: float = clampf(remaining_ratio, 0.0, 1.0)
	if r_rem <= 0.001:
		return

	# Snap-in envelope & low-time warning flicker right before shield drops
	var env_alpha: float = 1.0
	if r_rem > 0.92:
		env_alpha = clampf((1.0 - r_rem) / 0.08, 0.25, 1.0)
	elif r_rem < 0.18:
		var flick: float = 0.55 + 0.45 * sin(anim_time * 54.0)
		env_alpha = clampf(r_rem / 0.18, 0.2, 1.0) * flick

	var breath: float = 1.0 + 0.018 * sin(anim_time * 9.5)
	var s_rx: float = rx * breath
	var s_ry: float = ry * breath
	var center := Vector2(cx, cy)

	var col_cyan := Color(0.14, 0.88, 1.0, 1.0)
	var col_violet := Color(0.92, 0.24, 0.96, 1.0)
	var col_hot := Color(0.96, 1.0, 1.0, 1.0)
	var hit_t: float = clampf(hit_flash / 0.24, 0.0, 1.0)
	var hit_dir := Vector2(cos(hit_angle), sin(hit_angle))

	# 1. Translucent Fresnel deflector dome weighted toward the forward (-X) combat hemisphere
	var segs: int = 44
	var dome_pts := PackedVector2Array()
	var dome_cols := PackedColorArray()
	dome_pts.append(center)
	dome_cols.append(Color(0.08, 0.40, 0.85, 0.03 * env_alpha))
	for i in range(segs + 1):
		var ang: float = float(i) * TAU / float(segs)
		var u_dir := Vector2(cos(ang), sin(ang))
		var fwd_w: float = 0.45 + 0.55 * maxf(0.0, -u_dir.x)
		var hit_w: float = pow(maxf(0.0, u_dir.dot(hit_dir)), 2.2) * hit_t
		var v_col: Color = col_violet.lerp(col_cyan, 0.62 + 0.35 * sin(ang * 2.0 + anim_time * 4.0))
		v_col = v_col.lerp(col_hot, hit_w * 0.75)
		v_col.a = (0.07 + 0.12 * fwd_w + 0.24 * hit_w) * env_alpha
		dome_pts.append(center + Vector2(u_dir.x * s_rx, u_dir.y * s_ry))
		dome_cols.append(v_col)
	canvas.draw_polygon(dome_pts, dome_cols)

	# 2. Scrolling hexagonal energy honeycomb lattice across the capital barrier
	var hex_r: float = 0.19
	var dx_step: float = hex_r * 1.5
	var dy_step: float = hex_r * 1.73205
	var wave_x: float = fmod(anim_time * 0.95, 1.8) - 0.9
	for gx in range(-3, 4):
		for gy in range(-2, 3):
			var hx: float = float(gx) * dx_step
			var hy: float = (float(gy) + (0.5 if abs(gx) % 2 == 1 else 0.0)) * dy_step
			var r_sq: float = hx * hx + hy * hy
			if r_sq > 0.76:
				continue
			var pulse_w: float = exp(-pow((hx - wave_x) / 0.34, 2.0)) * 0.65
			var hit_cell: float = exp(-pow(((hx - hit_dir.x * 0.75) * (hx - hit_dir.x * 0.75) + (hy - hit_dir.y * 0.75) * (hy - hit_dir.y * 0.75)) / 0.22, 1.0)) * hit_t
			var cell_e: float = clampf((0.16 + pulse_w + hit_cell * 0.95) * env_alpha, 0.0, 1.0)
			if cell_e <= 0.08:
				continue
			var hex_line := PackedVector2Array()
			for k in range(7):
				var ka: float = float(k % 6) * (TAU / 6.0)
				var vx_n: float = hx + cos(ka) * (hex_r * 0.88)
				var vy_n: float = hy + sin(ka) * (hex_r * 0.88)
				var dome_s: float = 1.0 - 0.09 * minf(1.0, vx_n * vx_n + vy_n * vy_n)
				hex_line.append(Vector2(cx + vx_n * s_rx * dome_s, cy + vy_n * s_ry * dome_s))
			var hc: Color = col_cyan.lerp(col_violet, 0.35 + 0.35 * sin(float(gx + gy) + anim_time * 3.0))
			hc = hc.lerp(col_hot, hit_cell * 0.65)
			canvas.draw_polyline(hex_line, Color(hc.r, hc.g, hc.b, 0.50 * cell_e), 1.4)

	# 3. Double-layered elliptical forcefield rim with racing overload surge nodes
	for i in range(segs):
		var a0: float = float(i) * TAU / float(segs)
		var a1: float = float(i + 1) * TAU / float(segs)
		var am: float = 0.5 * (a0 + a1)
		var p0 := Vector2(cx + cos(a0) * s_rx, cy + sin(a0) * s_ry)
		var p1 := Vector2(cx + cos(a1) * s_rx, cy + sin(a1) * s_ry)
		var surge: float = 0.5 + 0.5 * sin(am * 3.0 - anim_time * 7.5)
		var ang_diff: float = absf(fmod(am - hit_angle + PI * 3.0, TAU) - PI)
		var hit_rim: float = exp(-pow(ang_diff / 0.42, 2.0)) * hit_t
		var seg_e: float = clampf((0.46 + 0.42 * surge + 0.55 * hit_rim) * env_alpha, 0.0, 1.0)
		var glow_c: Color = col_violet.lerp(col_cyan, surge)
		canvas.draw_line(p0, p1, Color(glow_c.r, glow_c.g, glow_c.b, 0.44 * seg_e), 7.0)
		var core_c: Color = col_cyan.lerp(col_hot, 0.45 * surge + 0.55 * hit_rim)
		canvas.draw_line(p0, p1, Color(core_c.r, core_c.g, core_c.b, 0.92 * seg_e), 2.4)

	# 4. Deflected player-shot starburst crest on the struck shield perimeter
	if hit_t > 0.02:
		var crest_pt := Vector2(cx + hit_dir.x * s_rx * 0.97, cy + hit_dir.y * s_ry * 0.97)
		if tex_photon_flare != null:
			var f_sz: float = 68.0 * hit_t + 20.0
			canvas.draw_texture_rect(
				tex_photon_flare,
				Rect2(crest_pt.x - f_sz * 0.5, crest_pt.y - f_sz * 0.5, f_sz, f_sz),
				false,
				Color(1.0, 1.0, 1.0, 0.94 * hit_t * env_alpha)
			)
		canvas.draw_circle(crest_pt, 7.0 * hit_t + 2.0, Color(1.0, 1.0, 1.0, 0.96 * hit_t * env_alpha))


func draw_boss_laser_charge(
	canvas: CanvasItem,
	ox: float,
	oy: float,
	aim_angle: float,
	progress: float,
	anim_time: float = 0.0
) -> void:
	var p: float = clampf(progress, 0.0, 1.0)
	var origin := Vector2(ox, oy)
	var dir := Vector2(cos(aim_angle), sin(aim_angle))
	var locked: bool = (p >= 0.66)

	# 1. Sleek player-targeted laser sightline telegraph (brightens right as trajectory locks)
	var sight_len: float = 1750.0
	var sight_end: Vector2 = origin + dir * sight_len
	if locked:
		var lock_pulse: float = 0.65 + 0.35 * sin(anim_time * 64.0)
		canvas.draw_line(origin, sight_end, Color(1.0, 0.14, 0.44, 0.34 * lock_pulse), 4.2)
		canvas.draw_line(origin, sight_end, Color(1.0, 0.88, 0.95, 0.68 * lock_pulse), 1.6)
	else:
		var track_a: float = lerpf(0.10, 0.30, p / 0.66)
		canvas.draw_line(origin, sight_end, Color(1.0, 0.16, 0.52, track_a), 1.4)

	# 2. Contracting plasma charge ring pulling energy into the cannon muzzle
	var ring_r: float = lerpf(32.0, 5.5, pow(p, 0.82))
	var ring_a: float = clampf(p * 1.4, 0.25, 0.92)
	canvas.draw_arc(origin, ring_r, 0.0, TAU, 24, Color(1.0, 0.24, 0.66, ring_a * 0.85), 2.2)
	if p > 0.25:
		var ring2_r: float = lerpf(22.0, 3.5, clampf((p - 0.25) / 0.75, 0.0, 1.0))
		canvas.draw_arc(origin, ring2_r, 0.0, TAU, 20, Color(1.0, 0.88, 0.45, ring_a * 0.72), 1.6)

	# 3. Swelling incandescent overload core & rotating 4-point charge cross
	var core_scale: float = 0.45 + 0.85 * p
	if tex_orb_magenta != null:
		var g_sz: float = 54.0 * core_scale
		canvas.draw_texture_rect(
			tex_orb_magenta,
			Rect2(ox - g_sz * 0.5, oy - g_sz * 0.5, g_sz, g_sz),
			false,
			Color(1.0, 0.75, 0.92, 0.92)
		)
	var rot: float = anim_time * 12.0 + p * 4.5
	var spoke_len: float = (10.0 + 14.0 * p)
	for k in range(2):
		var sang: float = rot + float(k) * PI * 0.5
		var sd := Vector2(cos(sang), sin(sang)) * spoke_len
		canvas.draw_line(origin - sd, origin + sd, Color(1.0, 0.86, 0.96, 0.86), 2.0)
	canvas.draw_circle(origin, 4.2 + 5.2 * p, Color(1.0, 0.18, 0.48, 0.96))
	canvas.draw_circle(origin, 2.2 + 3.2 * p, Color(1.0, 0.98, 0.98, 1.0))


func draw_boss_targeted_laser(
	canvas: CanvasItem,
	x: float,
	y: float,
	vx: float,
	vy: float,
	anim_time: float = 0.0
) -> void:
	var pos := Vector2(x, y)
	var spd_sq: float = vx * vx + vy * vy
	var fwd: Vector2 = Vector2(vx, vy).normalized() if spd_sq > 1.0 else Vector2.LEFT
	var perp := Vector2(-fwd.y, fwd.x)
	var pulse: float = 1.0 + 0.10 * sin(anim_time * 46.0 + (x + y) * 0.02)

	# 1. Long high-velocity crimson-magenta ionized slipstream wake
	canvas.draw_line(
		pos - fwd * 74.0,
		pos - fwd * 8.0,
		Color(1.0, 0.10, 0.48, 0.44),
		4.2
	)
	for sgn in [-1.0, 1.0]:
		canvas.draw_line(
			pos - fwd * 56.0 + perp * (sgn * 3.4),
			pos - fwd * 4.0 + perp * (sgn * 2.0),
			Color(1.0, 0.34, 0.78, 0.42),
			1.6
		)

	# 2. Oriented glowing plasma lance aura
	if tex_enemy_comet_red != null:
		_draw_oriented_tex_quad(
			canvas,
			tex_enemy_comet_red,
			pos,
			fwd,
			perp,
			96.0,
			30.0 * pulse,
			0.74,
			Color(1.0, 0.78, 0.96, 0.98)
		)

	# 3. High-contrast crimson-magenta beam sheath + razor-sharp white-hot laser core
	var tail_pt: Vector2 = pos - fwd * 30.0
	var nose_pt: Vector2 = pos + fwd * 18.0
	canvas.draw_line(tail_pt, nose_pt, Color(0.24, 0.02, 0.18, 0.85), 9.2)
	canvas.draw_line(tail_pt, nose_pt, Color(1.0, 0.14, 0.46, 0.96), 6.0 * pulse)
	canvas.draw_line(pos - fwd * 22.0, nose_pt, Color(1.0, 0.96, 0.99, 0.99), 2.8 * pulse)

	# 4. Leading focal cross-glint
	var glint_pt: Vector2 = pos + fwd * 12.0
	canvas.draw_line(glint_pt - perp * 7.5 * pulse, glint_pt + perp * 7.5 * pulse, Color(1.0, 0.65, 0.88, 0.76), 1.6)
	canvas.draw_circle(glint_pt, 3.4 * pulse, Color(1.0, 1.0, 1.0, 1.0))


func draw_asteroid_2d_fallback(
	canvas: CanvasItem,
	cx: float,
	cy: float,
	radius: float,
	spin_angle: float,
	variant_idx: int = 0,
	is_flashing: bool = false
) -> void:
	var pts := PackedVector2Array()
	var line_pts := PackedVector2Array()
	var n_verts: int = 12
	for i in range(n_verts):
		var a: float = spin_angle + float(i) * TAU / float(n_verts)
		var jitter: float = 0.86 + 0.16 * sin(float(i) * 2.7 + float(variant_idx) * 1.9) + 0.08 * cos(float(i) * 4.3)
		var pt := Vector2(cx + cos(a) * radius * jitter, cy + sin(a) * radius * jitter)
		pts.append(pt)
		line_pts.append(pt)
	line_pts.append(pts[0])
	var fill_c: Color = Color(0.95, 0.98, 1.0, 1.0) if is_flashing else Color(0.28, 0.27, 0.35, 1.0)
	var rim_c: Color = Color(1.0, 1.0, 1.0, 1.0) if is_flashing else Color(0.56, 0.68, 0.82, 0.92)
	canvas.draw_colored_polygon(pts, fill_c)
	canvas.draw_polyline(line_pts, rim_c, 2.0)


func draw_asteroid_damage_fissures(
	canvas: CanvasItem,
	cx: float,
	cy: float,
	radius: float,
	hp_ratio: float,
	spin_angle: float,
	variant_idx: int = 0
) -> void:
	var dmg: float = clampf((0.75 - hp_ratio) / 0.75, 0.0, 1.0)
	if dmg <= 0.02:
		return
	var branch_count: int = 3 if dmg < 0.52 else 5
	var glow_col := Color(1.0, 0.44, 0.08, 0.58 * dmg)
	var core_col := Color(1.0, 0.92, 0.62, 0.88 * dmg)

	for b in range(branch_count):
		var base_a: float = spin_angle * 0.85 + float(b) * (TAU / float(branch_count)) + float(variant_idx) * 1.15
		var p0 := Vector2(cx + cos(base_a) * radius * 0.08, cy + sin(base_a) * radius * 0.08)
		var mid_a: float = base_a + 0.26 * sin(float(b * 3 + variant_idx))
		var p1 := Vector2(cx + cos(mid_a) * radius * (0.36 + 0.14 * dmg), cy + sin(mid_a) * radius * (0.36 + 0.14 * dmg))
		var tip_a: float = mid_a - 0.22 * cos(float(b * 5 + variant_idx))
		var p2 := Vector2(cx + cos(tip_a) * radius * (0.58 + 0.24 * dmg), cy + sin(tip_a) * radius * (0.58 + 0.24 * dmg))

		canvas.draw_line(p0, p1, glow_col, 4.2 * dmg + 1.2)
		canvas.draw_line(p1, p2, glow_col, 3.0 * dmg + 1.0)
		canvas.draw_line(p0, p1, core_col, 1.7)
		canvas.draw_line(p1, p2, core_col, 1.2)
	if dmg > 0.45:
		canvas.draw_circle(Vector2(cx, cy), 4.0 * dmg, Color(1.0, 0.76, 0.30, 0.68 * dmg))




