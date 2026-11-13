shader_type spatial;
// Island terrain painted with scanned ground textures: grass, cliff rock, beach sand and a dirt road.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_d : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_n : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_arm : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_d : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_n : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_arm : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D sand_d : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D sand_n : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D sand_arm : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D road_d : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D road_n : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D road_arm : repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 grass_tint : source_color = vec3(0.5, 0.74, 0.4);
uniform vec3 scorch : source_color = vec3(0.21, 0.18, 0.2);
uniform float normal_strength = 1.1;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = wpos.xz;
	float n_big = texture(noise_tex, p * 0.0035).r;
	float n_mid = texture(noise_tex, p * 0.028).r;
	float n_fine = texture(noise_tex, p * 0.31).r;

	// grass, sampled at two scales so the tiling does not show
	vec2 ug = p * 0.26;
	vec3 gd = mix(texture(grass_d, ug).rgb, texture(grass_d, p * 0.057 + 0.37).rgb, 0.45) * grass_tint;
	gd *= mix(0.72, 1.12, n_mid);
	gd = mix(gd, gd * vec3(1.25, 1.08, 0.7), smoothstep(0.55, 0.75, n_big) * 0.45);
	vec3 gn = texture(grass_n, ug).rgb;
	vec3 ga = texture(grass_arm, ug).rgb;

	// cliff rock, projected from the side so it does not stretch
	vec3 bw = abs(wnrm);
	float bx = bw.x / max(bw.x + bw.z, 0.001);
	vec3 rd = mix(texture(rock_d, wpos.xy * 0.16).rgb, texture(rock_d, wpos.zy * 0.16).rgb, bx);
	rd *= mix(0.8, 1.1, n_mid);
	vec3 rn = texture(rock_n, p * 0.2).rgb;
	vec3 ra = texture(rock_arm, p * 0.2).rgb;

	vec2 us = p * 0.3;
	vec3 sd = texture(sand_d, us).rgb * mix(0.9, 1.08, n_mid);
	vec3 sn = texture(sand_n, us).rgb;
	vec3 sa = texture(sand_arm, us).rgb;

	vec2 ur = p * 0.33;
	vec3 dd = texture(road_d, ur).rgb * mix(0.85, 1.1, n_mid);
	vec3 dn = texture(road_n, ur).rgb;
	vec3 da = texture(road_arm, ur).rgb;

	float slope = smoothstep(0.83, 0.66, wnrm.y + (n_fine - 0.5) * 0.1);
	float beach = smoothstep(2.0, 0.9, wpos.y + (n_fine - 0.5) * 0.9);
	float pth = smoothstep(0.32, 0.62, COLOR.r + (n_fine - 0.5) * 0.35);

	vec3 col = mix(gd, rd, slope);
	vec3 nm = mix(gn, rn, slope);
	vec3 arm = mix(ga, ra, slope);
	col = mix(col, sd, beach);
	nm = mix(nm, sn, beach);
	arm = mix(arm, sa, beach);
	col = mix(col, dd, pth);
	nm = mix(nm, dn, pth);
	arm = mix(arm, da, pth);

	col = mix(col, scorch * mix(0.7, 1.3, n_fine), COLOR.g * 0.85);
	float wet = smoothstep(0.55, 0.05, wpos.y);
	col *= mix(1.0, 0.55, wet);

	ALBEDO = col;
	ROUGHNESS = mix(arm.g, 0.3, wet);
	AO = arm.r;
	AO_LIGHT_AFFECT = 0.4;
	SPECULAR = 0.4;
	vec3 t = nm * 2.0 - 1.0;
	float fade = clamp(1.0 - length(VERTEX) / 140.0, 0.25, 1.0);
	vec3 wn = normalize(wnrm + vec3(t.x, 0.0, -t.y) * normal_strength * fade);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
