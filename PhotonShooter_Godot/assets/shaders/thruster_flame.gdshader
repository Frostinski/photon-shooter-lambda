shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 core_color : source_color = vec4(1.0, 0.98, 0.85, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.65, 0.06, 1.0);
uniform vec4 edge_color : source_color = vec4(0.95, 0.20, 0.01, 1.0);
uniform float flame_speed : hint_range(1.0, 30.0) = 14.0;
uniform float turbulence_strength : hint_range(0.0, 1.5) = 0.55;
uniform float intensity : hint_range(0.1, 4.0) = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * value_noise(p);
		p = p * 2.12 + vec2(7.3, 13.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	// UV.y is 0.0 at the nozzle base and 1.0 at the flame tip
	float tail_factor = clamp(UV.y, 0.0, 1.0);
	float flutter = (value_noise(vec2(UV.x * 6.0, UV.y * 4.0 - TIME * flame_speed)) - 0.5) * 2.0;
	VERTEX.yz += NORMAL.yz * flutter * 0.022 * tail_factor * turbulence_strength;
}

void fragment() {
	// UV.y = 0 at nozzle port, 1 at flame tip
	float axial = clamp(UV.y, 0.0, 1.0);
	float fresnel = pow(clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 1.35);

	vec2 n_uv = vec2(UV.x * 5.0, axial * 3.5 - TIME * (flame_speed * 0.35));
	float n = fbm(n_uv);
	float n_fine = value_noise(n_uv * 2.6 + vec2(0.0, -TIME * flame_speed * 0.6));

	// Smooth fade-in inside the exhaust port and turbulent fade-out toward the flame tip
	float nozzle_fade = smoothstep(0.0, 0.14, axial);
	float tail_fade = pow(clamp(1.0 - axial, 0.0, 1.0), 1.15);

	// Subtle Mach shock diamonds near the nozzle
	float shock = 0.85 + 0.25 * cos(axial * 26.0 - TIME * 12.0) * (1.0 - axial);

	float heat = fresnel * tail_fade * nozzle_fade * mix(0.65, 1.35, n * 0.7 + n_fine * 0.3) * shock;
	heat = clamp(heat, 0.0, 1.0);

	vec3 col = mix(edge_color.rgb, mid_color.rgb, smoothstep(0.15, 0.58, heat));
	col = mix(col, core_color.rgb, smoothstep(0.58, 0.90, heat));

	float alpha = smoothstep(0.08, 0.45, heat) * intensity;
	ALBEDO = col * intensity;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
