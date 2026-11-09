shader_type canvas_item;

// --- Tunable Space Backdrop Uniforms ---
uniform highp float scroll_speed : hint_range(0.0, 2.0, 0.01) = 0.08;
uniform highp float scroll_offset = 0.0;
uniform highp float star_density : hint_range(0.1, 3.0, 0.05) = 1.0;
uniform highp float star_twinkle_speed : hint_range(0.0, 10.0, 0.1) = 3.2;
uniform highp float star_twinkle_amount : hint_range(0.0, 1.0, 0.05) = 0.35;
uniform highp float nebula_intensity : hint_range(0.0, 2.0, 0.05) = 0.72;
uniform highp float nebula_scale : hint_range(0.5, 10.0, 0.1) = 3.0;

uniform vec4 bg_deep_color : source_color = vec4(0.02, 0.024, 0.07, 1.0);
uniform vec4 nebula_tint_primary : source_color = vec4(0.34, 0.06, 0.50, 1.0);
uniform vec4 nebula_tint_secondary : source_color = vec4(0.03, 0.30, 0.48, 1.0);
uniform vec4 star_tint_near : source_color = vec4(0.90, 0.96, 1.0, 1.0);
uniform vec4 star_tint_far : source_color = vec4(0.55, 0.68, 0.96, 1.0);

// --- Distant Blue Giant Sun Uniforms (Sample B) ---
uniform int enable_sun = 1;
uniform highp vec2 sun_uv = vec2(0.78, 0.20);
uniform highp float sun_radius : hint_range(0.005, 0.10, 0.001) = 0.028;
uniform vec4 sun_core_color : source_color = vec4(0.96, 0.99, 1.0, 1.0);
uniform vec4 sun_corona_color : source_color = vec4(0.32, 0.78, 1.0, 1.0);
uniform vec4 sun_scatter_color : source_color = vec4(0.14, 0.48, 0.92, 1.0);
uniform highp float sun_intensity : hint_range(0.0, 3.0, 0.05) = 1.05;

// Fast 2D hash functions (highp to avoid mediump FBM quantization steps)
highp float hash12(highp vec2 p) {
	highp vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

highp vec2 hash22(highp vec2 p) {
	highp vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// Exact 32-bit integer lattice hash (immune to GPU float FMA seam wraparound at lattice edges)
highp float hash12_int(ivec2 p) {
	uvec2 q = uvec2(p) * uvec2(1597334673u, 3812015801u);
	uint n = (q.x ^ q.y) * 1597334673u;
	n = (n ^ (n >> 16u)) * 2246822519u;
	return float(n >> 8u) * (1.0 / 16777216.0);
}

// 2D Value Noise
highp float value_noise(highp vec2 p) {
	ivec2 i = ivec2(floor(p));
	highp vec2 f = fract(p);
	highp vec2 u = f * f * (3.0 - 2.0 * f);

	highp float a = hash12_int(i);
	highp float b = hash12_int(i + ivec2(1, 0));
	highp float c = hash12_int(i + ivec2(0, 1));
	highp float d = hash12_int(i + ivec2(1, 1));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// 4-Octave Fractional Brownian Motion (FBM) with domain rotation
highp float fbm(highp vec2 p) {
	highp float val = 0.0;
	highp float amp = 0.5;
	highp mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < 4; i++) {
		val += amp * value_noise(p);
		p = rot * p * 2.03 + vec2(17.1, 31.7);
		amp *= 0.5;
	}
	return val;
}

// Single parallax starfield layer with slight twinkle
highp float star_layer(highp vec2 uv, highp float grid_scale, highp float threshold, highp float size_scale, highp float seed) {
	highp vec2 p = uv * grid_scale + vec2(seed * 37.0, seed * 19.0);
	highp vec2 id = floor(p);
	highp vec2 gv = fract(p) - 0.5;

	highp float cell_hash = hash12(id + seed * 113.0);
	if (cell_hash > threshold) {
		return 0.0;
	}

	highp vec2 rand_offset = (hash22(id + seed * 53.0) - 0.5) * 0.72;
	highp float dist = length(gv - rand_offset);

	highp float radius = mix(0.035, 0.095, fract(cell_hash * 19.3)) * size_scale;
	highp float star = smoothstep(radius, radius * 0.15, dist);

	// Slight sinusoidal twinkle per star
	highp float phase = cell_hash * 6.2831853;
	highp float twinkle = 1.0 - star_twinkle_amount * (0.5 + 0.5 * sin(TIME * star_twinkle_speed + phase));
	return star * twinkle;
}

void fragment() {
	// Aspect-corrected UV (16:9)
	highp vec2 uv = UV;
	highp float aspect = 1920.0 / 1080.0;
	highp vec2 aspect_uv = vec2(uv.x * aspect, uv.y);

	// Use scroll_offset if driven by script, otherwise TIME * scroll_speed
	highp float t = (abs(scroll_offset) > 0.00001) ? scroll_offset : (TIME * scroll_speed);

	// 1. Drifting Dual-Layer FBM Nebula
	highp vec2 neb_uv1 = aspect_uv * nebula_scale + vec2(t * 0.55, t * 0.04);
	highp float n1 = fbm(neb_uv1);

	highp vec2 neb_uv2 = aspect_uv * (nebula_scale * 1.45) + vec2(t * 0.90, -t * 0.05) + vec2(n1 * 0.55);
	highp float n2 = fbm(neb_uv2);

	// Dust lanes & soft cloud masks
	highp float cloud_primary = smoothstep(0.38, 0.78, n1) * nebula_intensity;
	highp float cloud_secondary = smoothstep(0.44, 0.82, n2) * nebula_intensity * 0.85;
	highp float dust_void = smoothstep(0.25, 0.55, fbm(aspect_uv * (nebula_scale * 0.75) + vec2(t * 0.3, 4.2)));

	vec3 col = bg_deep_color.rgb;
	col = mix(col, nebula_tint_primary.rgb, clamp(cloud_primary * dust_void, 0.0, 1.0));
	col += nebula_tint_secondary.rgb * clamp(cloud_secondary * (0.4 + 0.6 * n1), 0.0, 1.0);

	// 2. Layered Parallax Starfield (3 depth tiers)
	highp float density_clamped = clamp(star_density, 0.05, 4.0);
	highp float thresh_far = clamp(0.085 * density_clamped, 0.0, 0.55);
	highp float thresh_mid = clamp(0.050 * density_clamped, 0.0, 0.45);
	highp float thresh_near = clamp(0.025 * density_clamped, 0.0, 0.35);

	highp float s_far = star_layer(aspect_uv + vec2(t * 0.45, 0.0), 42.0, thresh_far, 0.85, 1.1);
	highp float s_mid = star_layer(aspect_uv + vec2(t * 0.95, 0.0), 26.0, thresh_mid, 1.05, 2.7);
	highp float s_near = star_layer(aspect_uv + vec2(t * 1.65, 0.0), 15.0, thresh_near, 1.30, 4.3);

	// 3. Distant Sapphire-White Blue Giant + Corona + Volumetric Nebula Rim-Scattering
	if (enable_sun == 1) {
		highp vec2 sun_aspect = vec2(sun_uv.x * aspect, sun_uv.y);
		highp vec2 delta = aspect_uv - sun_aspect;
		highp float d = length(delta);

		// Wash out background pinpoint stars inside the bright solar glare
		highp float star_dim = smoothstep(sun_radius * 1.2, sun_radius * 6.5, d);
		col += star_tint_far.rgb * (s_far * 0.65 * star_dim);
		col += mix(star_tint_far.rgb, star_tint_near.rgb, 0.5) * (s_mid * 0.85 * star_dim);
		col += star_tint_near.rgb * (s_near * 1.15 * star_dim);

		// Wide atmospheric sapphire haze + backlit nebula gas scattering
		highp float wide_haze = exp(-d * 2.3) * 0.34 * sun_intensity;
		highp float cloud_rim = smoothstep(0.32, 0.76, n1) * (1.0 - smoothstep(0.72, 0.95, n2));
		highp float neb_scatter = exp(-d * 2.8) * (0.28 + 0.85 * cloud_rim) * sun_intensity;
		col += sun_scatter_color.rgb * (wide_haze + neb_scatter * 0.52);

		// Inner inverse-square corona + stellar diffraction streaks
		highp float corona = (0.0022 / (d * d + 0.0016)) * sun_intensity;
		highp float ray_h = exp(-abs(delta.y) * 95.0) * exp(-abs(delta.x) * 4.2) * 0.42 * sun_intensity;
		highp float ray_diag1 = exp(-abs(delta.x * 0.5 + delta.y * 0.866) * 140.0) * exp(-d * 9.0) * 0.22 * sun_intensity;
		highp float ray_diag2 = exp(-abs(delta.x * 0.5 - delta.y * 0.866) * 140.0) * exp(-d * 9.0) * 0.22 * sun_intensity;
		col += sun_corona_color.rgb * clamp(corona * 0.68 + ray_h + ray_diag1 + ray_diag2, 0.0, 1.8);

		// Crisp limb-darkened stellar photosphere disc
		highp float disc = smoothstep(sun_radius * 1.18, sun_radius * 0.55, d);
		col = mix(col, sun_core_color.rgb, clamp(disc * sun_intensity, 0.0, 1.0));
		col = clamp(col, vec3(0.0), vec3(1.0));
	} else {
		col += star_tint_far.rgb * (s_far * 0.65);
		col += mix(star_tint_far.rgb, star_tint_near.rgb, 0.5) * (s_mid * 0.85);
		col += star_tint_near.rgb * (s_near * 1.15);
	}

	// Subtle 8-bit gradient dithering to eliminate dark-space color banding
	col = clamp(col + (hash12(FRAGCOORD.xy) - 0.5) * (1.35 / 255.0), vec3(0.0), vec3(1.0));
	COLOR = vec4(col, 1.0);
}
