shader_type sky;
// Atmospheric sky: horizon haze, sun disc with glow, and soft layered clouds lit by the sun.

uniform vec3 top_color : source_color = vec3(0.1, 0.3, 0.7);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.87, 0.97);
uniform vec3 bottom_color : source_color = vec3(0.35, 0.55, 0.7);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.8);
uniform vec3 cloud_light : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.55, 0.6, 0.7);
uniform float cloud_cover = 0.5;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

float clouds(vec2 uv) {
	float n = texture(noise_tex, uv).r * 0.5;
	n += texture(noise_tex, uv * 2.3 + 0.37).r * 0.27;
	n += texture(noise_tex, uv * 5.1 + 0.11).r * 0.15;
	n += texture(noise_tex, uv * 11.0 + 0.7).r * 0.08;
	return n;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float t = clamp(dir.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(t, 0.42));
	if (dir.y < 0.0) {
		col = mix(horizon_color, bottom_color, clamp(-dir.y * 6.0, 0.0, 1.0));
	}
	float sd = 0.0;
	if (LIGHT0_ENABLED) {
		sd = max(dot(dir, LIGHT0_DIRECTION), 0.0);
		col += sun_color * pow(sd, 6.0) * 0.18 * LIGHT0_ENERGY * 0.5;
		col += sun_color * pow(sd, 60.0) * 0.5;
	}
	if (dir.y > 0.0) {
		vec2 uv = dir.xz / (dir.y + 0.12) * 0.07 + vec2(TIME * 0.002, TIME * 0.0008);
		float n = clouds(uv);
		float thr = 1.0 - cloud_cover;
		float dens = smoothstep(thr, thr + 0.22, n);
		// light the side facing the sun, shade the thick middle
		float n_sun = clouds(uv + LIGHT0_DIRECTION.xz * 0.012);
		float lit = clamp((n - n_sun) * 9.0 + 0.6, 0.0, 1.0);
		vec3 cc = mix(cloud_shade, cloud_light, lit * (1.0 - dens * 0.45));
		cc += sun_color * pow(sd, 10.0) * (1.0 - dens) * 0.9;
		float horizon_fade = smoothstep(0.0, 0.16, dir.y);
		col = mix(col, cc, dens * horizon_fade);
	}
	if (LIGHT0_ENABLED) {
		col = mix(col, sun_color * 6.0, smoothstep(0.9992, 0.9996, dot(dir, LIGHT0_DIRECTION)) * step(0.0, dir.y));
	}
	COLOR = col;
}
