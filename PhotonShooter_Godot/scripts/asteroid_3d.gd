extends SubViewport
class_name Asteroid3D
## Real-time 3D procedural cratered basalt asteroid renderer (`SubViewport`).
## Matches the starfighter/enemy 3D lighting pipeline: orthogonal Camera3D, Blue Giant
## directional self-shadowing into 3D craters, cosmic violet nebula bounce fill,
## sun-gated Fresnel rim shader, and dual live OmniLight3D weapon/laser reflections.

const EnemyRimHighlightShader = preload("res://assets/shaders/enemy_rim_highlight.gdshader")

var is_large: bool = true
var variant_index: int = 0

var rock_rig: Node3D = null
var rock_mesh_inst: MeshInstance3D = null
var camera_3d: Camera3D = null
var sun_light: DirectionalLight3D = null
var nebula_fill_light: DirectionalLight3D = null
var weapon_lights_3d: Array[OmniLight3D] = []
var rim_material: ShaderMaterial = null
var surface_material: StandardMaterial3D = null


func _init(p_large: bool = true, p_variant: int = 0, viewport_size: Vector2i = Vector2i(144, 144)) -> void:
	is_large = p_large
	variant_index = p_variant
	size = viewport_size
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.13, 0.30)
	env.ambient_light_energy = 0.24
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	camera_3d = Camera3D.new()
	camera_3d.name = "Camera3D"
	camera_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera_3d.size = 2.55
	camera_3d.position = Vector3(0.0, 0.0, 4.5)
	camera_3d.near = 0.1
	camera_3d.far = 20.0
	add_child(camera_3d)

	var default_ray := Vector3(-0.68, -0.48, -0.36).normalized()

	sun_light = DirectionalLight3D.new()
	sun_light.name = "SunLight"
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun_light.directional_shadow_max_distance = 12.0
	sun_light.shadow_bias = 0.016
	sun_light.shadow_normal_bias = 1.10
	sun_light.shadow_blur = 1.25
	sun_light.light_color = Color(0.84, 0.94, 1.0)
	sun_light.light_energy = 2.15
	add_child(sun_light)
	sun_light.look_at_from_position(-default_ray * 6.0, Vector3.ZERO, Vector3.UP)

	nebula_fill_light = DirectionalLight3D.new()
	nebula_fill_light.name = "NebulaBounceLight"
	nebula_fill_light.light_color = Color(0.42, 0.20, 0.62)
	nebula_fill_light.light_energy = 0.44
	add_child(nebula_fill_light)
	nebula_fill_light.look_at_from_position(
		Vector3(default_ray.x * 4.0, default_ray.y * 3.0 - 2.0, 3.5),
		Vector3.ZERO,
		Vector3.UP
	)

	for i in range(2):
		var wl := OmniLight3D.new()
		wl.name = "WeaponLight%d" % i
		wl.visible = false
		wl.omni_range = 2.7
		wl.omni_attenuation = 1.25
		add_child(wl)
		weapon_lights_3d.append(wl)

	rock_rig = Node3D.new()
	rock_rig.name = "AsteroidRig"
	add_child(rock_rig)

	if EnemyRimHighlightShader != null:
		rim_material = ShaderMaterial.new()
		rim_material.shader = EnemyRimHighlightShader
		rim_material.set_shader_parameter("rim_color", Color(0.48, 0.80, 1.0, 1.0))
		rim_material.set_shader_parameter("rim_power", 3.4)
		rim_material.set_shader_parameter("rim_strength", 0.34)
		rim_material.set_shader_parameter("sun_dir_view", -default_ray)

	surface_material = StandardMaterial3D.new()
	surface_material.vertex_color_use_as_albedo = true
	surface_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	surface_material.roughness = 0.84
	surface_material.metallic = 0.14
	var normal_tex := _get_shared_rock_normal_tex()
	if normal_tex != null:
		surface_material.normal_enabled = true
		surface_material.normal_texture = normal_tex
		surface_material.normal_scale = 1.18
	if rim_material != null:
		surface_material.next_pass = rim_material

	rock_mesh_inst = MeshInstance3D.new()
	rock_mesh_inst.name = "AsteroidMesh"
	rock_mesh_inst.mesh = _get_or_build_asteroid_mesh(is_large, variant_index)
	rock_mesh_inst.material_override = surface_material
	rock_rig.add_child(rock_mesh_inst)


static func _get_shared_rock_normal_tex() -> Texture2D:
	if GameConfig.asteroid_normal_tex != null:
		return GameConfig.asteroid_normal_tex
	var fn := FastNoiseLite.new()
	fn.seed = 40913
	fn.noise_type = FastNoiseLite.TYPE_CELLULAR
	fn.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	fn.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	fn.frequency = 0.072
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = 3

	var sz: int = 96
	var h_img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in range(sz):
		for x in range(sz):
			var h0: float = fn.get_noise_2d(float(x), float(y))
			var hx: float = fn.get_noise_2d(float((x + 1) % sz), float(y))
			var hy: float = fn.get_noise_2d(float(x), float((y + 1) % sz))
			var dx: float = (h0 - hx) * 3.1
			var dy: float = (h0 - hy) * 3.1
			var n := Vector3(dx, dy, 1.0).normalized()
			h_img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))
	GameConfig.asteroid_normal_tex = ImageTexture.create_from_image(h_img)
	return GameConfig.asteroid_normal_tex


static func _get_or_build_asteroid_mesh(large_flag: bool, var_idx: int) -> ArrayMesh:
	var key: String = "%s_%d" % ["L" if large_flag else "S", var_idx % 4]
	if GameConfig.asteroid_mesh_cache.has(key):
		return GameConfig.asteroid_mesh_cache[key]

	var seed_base: int = (18271 if large_flag else 53917) + (var_idx % 4) * 7919
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base

	var noise_lobe := FastNoiseLite.new()
	noise_lobe.seed = seed_base + 5
	noise_lobe.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_lobe.frequency = 0.52

	var noise_macro := FastNoiseLite.new()
	noise_macro.seed = seed_base + 11
	noise_macro.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise_macro.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise_macro.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	noise_macro.frequency = 0.78 if large_flag else 0.96

	var noise_crag := FastNoiseLite.new()
	noise_crag.seed = seed_base + 37
	noise_crag.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_crag.frequency = 1.55
	noise_crag.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise_crag.fractal_octaves = 3

	var craters: Array[Dictionary] = []
	var crater_count: int = 8 if large_flag else 5
	for _c in range(crater_count):
		var c_dir := Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-0.6, 1.0)
		).normalized()
		craters.append({
			"dir": c_dir,
			"rad": rng.randf_range(0.30, 0.54) if large_flag else rng.randf_range(0.34, 0.58),
			"depth": rng.randf_range(0.19, 0.30) if large_flag else rng.randf_range(0.16, 0.25)
		})

	# Sheared cleavage planes give boulders crisp angular asteroid facets instead of round spheres
	var shear_planes: Array[Dictionary] = []
	var plane_count: int = 3 if large_flag else 4
	for _p in range(plane_count):
		var p_dir := Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0)
		).normalized()
		shear_planes.append({
			"dir": p_dir,
			"cut": rng.randf_range(0.74, 0.88)
		})

	var axis_scale := (
		Vector3(
			rng.randf_range(1.06, 1.18),
			rng.randf_range(0.82, 0.94),
			rng.randf_range(0.84, 0.98)
		)
		if large_flag
		else Vector3(
			rng.randf_range(1.10, 1.24),
			rng.randf_range(0.74, 0.88),
			rng.randf_range(0.78, 0.94)
		)
	)

	var t_gold: float = (1.0 + sqrt(5.0)) * 0.5
	var verts: Array[Vector3] = [
		Vector3(-1,  t_gold, 0).normalized(),
		Vector3( 1,  t_gold, 0).normalized(),
		Vector3(-1, -t_gold, 0).normalized(),
		Vector3( 1, -t_gold, 0).normalized(),
		Vector3(0, -1,  t_gold).normalized(),
		Vector3(0,  1,  t_gold).normalized(),
		Vector3(0, -1, -t_gold).normalized(),
		Vector3(0,  1, -t_gold).normalized(),
		Vector3( t_gold, 0, -1).normalized(),
		Vector3( t_gold, 0,  1).normalized(),
		Vector3(-t_gold, 0, -1).normalized(),
		Vector3(-t_gold, 0,  1).normalized(),
	]
	var faces: Array = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]

	var subdiv_levels: int = 3 if large_flag else 2
	for _sub in range(subdiv_levels):
		var mid_cache: Dictionary = {}
		var next_faces: Array = []
		for f in faces:
			var i0: int = f[0]
			var i1: int = f[1]
			var i2: int = f[2]
			var m01: int = _midpoint_idx(i0, i1, verts, mid_cache)
			var m12: int = _midpoint_idx(i1, i2, verts, mid_cache)
			var m20: int = _midpoint_idx(i2, i0, verts, mid_cache)
			next_faces.append([i0, m01, m20])
			next_faces.append([i1, m12, m01])
			next_faces.append([i2, m20, m12])
			next_faces.append([m01, m12, m20])
		faces = next_faces

	# Linear-space dark basalt & oxidized iron-chondrite vertex colors (avoids white clipping under solar light)
	var displaced: Array[Vector3] = []
	var v_colors: Array[Color] = []
	var base_slate := Color(0.072, 0.078, 0.104)
	var warm_ochre := Color(0.148, 0.092, 0.064)
	var deep_crevice := Color(0.020, 0.019, 0.034)
	var ridge_glint := Color(0.175, 0.195, 0.240)

	for u in verts:
		var lobe_v: float = noise_lobe.get_noise_3d(u.x * 1.15, u.y * 1.15, u.z * 1.15)
		var macro_v: float = noise_macro.get_noise_3d(u.x * 1.45, u.y * 1.45, u.z * 1.45)
		var crag_v: float = noise_crag.get_noise_3d(u.x * 1.75, u.y * 1.75, u.z * 1.75)
		var r_disp: float = 0.92 + lobe_v * 0.18 + macro_v * (0.26 if large_flag else 0.32) + crag_v * 0.12

		for sp in shear_planes:
			var proj: float = u.dot(sp["dir"]) * r_disp
			var cut_d: float = float(sp["cut"])
			if proj > cut_d:
				r_disp -= (proj - cut_d) * 0.68

		var crater_delta: float = 0.0
		var crater_dark: float = 0.0
		for cr in craters:
			var ang: float = acos(clampf(u.dot(cr["dir"]), -1.0, 1.0))
			var c_rad: float = float(cr["rad"])
			var c_dep: float = float(cr["depth"])
			if ang < c_rad * 1.30:
				var q: float = ang / c_rad
				if q < 1.0:
					var bowl: float = 1.0 - q * q
					crater_delta -= c_dep * bowl * bowl
					crater_dark = maxf(crater_dark, bowl * 0.78)
				var rim_ring: float = exp(-pow((q - 1.02) / 0.15, 2.0))
				crater_delta += c_dep * 0.42 * rim_ring

		var final_r: float = clampf(r_disp + crater_delta, 0.48, 1.18)
		var pos := Vector3(u.x * axis_scale.x, u.y * axis_scale.y, u.z * axis_scale.z) * final_r
		displaced.append(pos)

		var vein_t: float = clampf(crag_v * 0.65 + 0.46, 0.0, 1.0)
		var col: Color = base_slate.lerp(warm_ochre, vein_t * 0.58)
		if final_r > 0.98:
			col = col.lerp(ridge_glint, clampf((final_r - 0.98) * 3.6, 0.0, 0.70))
		col = col.lerp(deep_crevice, clampf(crater_dark + maxf(0.0, 0.86 - final_r) * 2.4, 0.0, 0.82))
		v_colors.append(col)

	var smooth_normals: Array[Vector3] = []
	smooth_normals.resize(displaced.size())
	for idx in range(smooth_normals.size()):
		smooth_normals[idx] = Vector3.ZERO

	for f in faces:
		var p0: Vector3 = displaced[f[0]]
		var p1: Vector3 = displaced[f[1]]
		var p2: Vector3 = displaced[f[2]]
		var fn_vec: Vector3 = (p0 - p2).cross(p0 - p1)
		smooth_normals[f[0]] += fn_vec
		smooth_normals[f[1]] += fn_vec
		smooth_normals[f[2]] += fn_vec

	for idx in range(smooth_normals.size()):
		var sn: Vector3 = smooth_normals[idx]
		smooth_normals[idx] = sn.normalized() if sn.length_squared() > 0.00001 else verts[idx]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		var i0: int = f[0]
		var i1: int = f[1]
		var i2: int = f[2]
		var p0: Vector3 = displaced[i0]
		var p1: Vector3 = displaced[i1]
		var p2: Vector3 = displaced[i2]
		# Godot 4 front-face winding uses Plane(p0, p1, p2).normal = (p0 - p2).cross(p0 - p1)
		var face_n: Vector3 = (p0 - p2).cross(p0 - p1).normalized()
		var center_dir: Vector3 = (p0 + p1 + p2).normalized()
		var tri_indices: Array = [i0, i1, i2]
		if face_n.dot(center_dir) < 0.0:
			face_n = -face_n
			tri_indices = [i0, i2, i1]

		for ti in tri_indices:
			var v_pos: Vector3 = displaced[ti]
			var sm_n: Vector3 = smooth_normals[ti]
			if sm_n.dot(center_dir) < 0.0:
				sm_n = -sm_n
			# Stronger facet blend (0.62) highlights angular rocky planes and crater rims
			var blended_n: Vector3 = sm_n.lerp(face_n, 0.62).normalized()
			var u_sph: float = 0.5 + atan2(v_pos.z, v_pos.x) / TAU
			var v_sph: float = 0.5 - asin(clampf(v_pos.y / maxf(v_pos.length(), 0.001), -1.0, 1.0)) / PI
			st.set_normal(blended_n)
			st.set_uv(Vector2(u_sph * 2.2, v_sph * 2.2))
			st.set_color(v_colors[ti])
			st.add_vertex(v_pos)

	st.generate_tangents()
	var built_mesh: ArrayMesh = st.commit()
	GameConfig.asteroid_mesh_cache[key] = built_mesh
	return built_mesh


static func _midpoint_idx(a: int, b: int, verts: Array[Vector3], cache: Dictionary) -> int:
	var lo: int = mini(a, b)
	var hi: int = maxi(a, b)
	var k: int = (lo << 16) | hi
	if cache.has(k):
		return int(cache[k])
	var mid: Vector3 = (verts[a] + verts[b]).normalized()
	var idx: int = verts.size()
	verts.append(mid)
	cache[k] = idx
	return idx


func update_tumble(spin_axis: Vector3, spin_angle: float, wobble_angle: float) -> void:
	if rock_rig == null:
		return
	var ax: Vector3 = spin_axis.normalized() if spin_axis.length_squared() > 0.001 else Vector3.UP
	var b := Basis(ax, spin_angle)
	b = b.rotated(Vector3(1.0, 0.25, 0.0).normalized(), sin(wobble_angle) * 0.28)
	rock_rig.basis = b


func update_dynamic_lighting(
	rock_screen_pos: Vector2,
	draw_size: Vector2,
	sun_screen_pos: Vector2,
	nearby_lights: Array = []
) -> void:
	var dx: float = clampf((rock_screen_pos.x - sun_screen_pos.x) / 720.0, -1.6, 1.6)
	var dy: float = clampf(-(rock_screen_pos.y - sun_screen_pos.y) / 480.0, -1.6, 1.6)
	if absf(dx) < 0.08 and absf(dy) < 0.08:
		dy = -0.25
	var ray_dir := Vector3(dx, dy, -0.36).normalized()

	if sun_light != null and sun_light.is_inside_tree():
		var screen_dist: float = rock_screen_pos.distance_to(sun_screen_pos) / 1920.0
		var prox_mult: float = lerpf(1.22, 0.84, clampf(screen_dist, 0.0, 1.0))
		sun_light.light_energy = 2.15 * prox_mult
		sun_light.look_at_from_position(-ray_dir * 6.0, Vector3.ZERO, Vector3.UP)

	if nebula_fill_light != null and nebula_fill_light.is_inside_tree():
		nebula_fill_light.look_at_from_position(
			Vector3(ray_dir.x * 4.0, ray_dir.y * 3.0 - 2.0, 3.5),
			Vector3.ZERO,
			Vector3.UP
		)

	if rim_material != null:
		rim_material.set_shader_parameter("sun_dir_view", -ray_dir)

	var cam_h: float = camera_3d.size if camera_3d != null else 2.55
	var px_to_3d: float = cam_h / maxf(draw_size.y, 1.0)

	for i in range(weapon_lights_3d.size()):
		var omni: OmniLight3D = weapon_lights_3d[i]
		if omni == null:
			continue
		if i < nearby_lights.size():
			var wl: Dictionary = nearby_lights[i]
			var lpos: Vector2 = wl["pos"]
			var rel_px: Vector2 = lpos - rock_screen_pos
			var x_3d: float = clampf(rel_px.x * px_to_3d, -2.0, 2.0)
			var y_3d: float = clampf(-rel_px.y * px_to_3d, -2.0, 2.0)
			var z_3d: float = float(wl.get("z", 0.78))
			var energy: float = float(wl.get("energy", 0.0)) * 1.25
			if energy > 0.03:
				omni.visible = true
				omni.position = Vector3(x_3d, y_3d, z_3d)
				omni.light_color = wl["color"]
				omni.light_energy = energy
				omni.omni_range = float(wl.get("range", 2.6))
			else:
				omni.visible = false
		else:
			omni.visible = false


func has_3d_model() -> bool:
	return rock_mesh_inst != null and rock_mesh_inst.mesh != null
