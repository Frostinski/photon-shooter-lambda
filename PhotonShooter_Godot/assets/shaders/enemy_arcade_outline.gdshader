shader_type spatial;
render_mode unshaded, cull_front, skip_vertex_transform;

uniform vec4 outline_color : source_color = vec4(0.02, 0.02, 0.07, 1.0);
uniform float outline_width : hint_range(0.0, 0.08) = 0.020;
uniform float depth_bias : hint_range(0.0, 2.0) = 0.55;

void vertex() {
	vec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 view_nrm = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 dir2d = view_nrm.xy;
	float len2d = length(dir2d);
	if (len2d > 0.0005) {
		view_pos.xy += (dir2d / len2d) * outline_width;
	}
	// Push back-facing outline shell behind the front hull in orthographic view space
	// so ONLY the outer silhouette passes depth test (zero interior crease lines!).
	view_pos.z -= depth_bias;
	VERTEX = view_pos;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
