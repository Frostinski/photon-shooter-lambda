shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform vec4 rim_color : source_color = vec4(0.68, 0.92, 1.0, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 3.3;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.56;
// Unit direction from ship toward the distant sun in camera View Space
uniform vec3 sun_dir_view = vec3(0.60, 0.50, 0.32);

void fragment() {
	// NORMAL and VIEW are both in View Space in Godot spatial fragment shaders.
	// Gate the grazing Fresnel rim strictly to surfaces facing toward the sun so shadowed sides sink naturally into space.
	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float sun_align = smoothstep(-0.08, 0.68, dot(normalize(NORMAL), normalize(sun_dir_view)));
	float rim = pow(1.0 - ndotv, rim_power) * rim_strength * sun_align;
	ALBEDO = rim_color.rgb * rim;
	ALPHA = 1.0;
}
