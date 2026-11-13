shader_type spatial;
// Sea and lake surface: rippled normals, refraction, depth absorption, sky reflection and shore foam.

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 scatter : source_color = vec3(0.02, 0.2, 0.25);
uniform vec3 foam : source_color = vec3(0.92, 0.96, 0.97);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 0.21 + TIME * 0.9) * 0.07 + cos(wpos.z * 0.17 + TIME * 0.7) * 0.07;
}

float scene_depth(vec2 uv, mat4 inv_proj) {
	float depth = texture(depth_tex, uv).r;
	vec4 upos = inv_proj * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return upos.z / upos.w;
}

void fragment() {
	vec2 uv = wpos.xz;
	vec3 n1 = texture(normal_tex, uv * 0.045 + TIME * vec2(0.011, 0.007)).rgb;
	vec3 n2 = texture(normal_tex, uv * 0.13 + TIME * vec2(-0.019, 0.014)).rgb;
	vec3 n3 = texture(normal_tex, uv * 0.47 + TIME * vec2(0.031, -0.036)).rgb;
	vec2 nxy = (n1.xy - 0.5) + (n2.xy - 0.5) * 0.8 + (n3.xy - 0.5) * 0.45;
	NORMAL_MAP = normalize(vec3(nxy, 0.55)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.85;

	float diff = VERTEX.z - scene_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec2 ruv = SCREEN_UV + nxy * 0.05 * clamp(diff * 0.6, 0.0, 1.0);
	float rdiff = VERTEX.z - scene_depth(ruv, INV_PROJECTION_MATRIX);
	if (rdiff < 0.0) {
		ruv = SCREEN_UV;
		rdiff = diff;
	}
	vec3 scene = textureLod(screen_tex, ruv, 0.0).rgb;
	vec3 absorb = exp(-rdiff * vec3(0.55, 0.16, 0.11));
	vec3 under = scene * absorb + scatter * (1.0 - exp(-rdiff * 0.28));

	float nz = texture(noise_tex, uv * 0.09 + TIME * vec2(0.02, 0.013)).r;
	float shore = smoothstep(0.55 + nz * 0.7, 0.0, diff);
	float lace = smoothstep(0.6, 0.7, texture(noise_tex, uv * 0.3 - TIME * vec2(0.03, 0.02)).r) * smoothstep(2.2, 0.3, diff) * 0.5;
	float f = clamp(shore + lace, 0.0, 1.0);

	ALBEDO = foam * f;
	EMISSION = under * (1.0 - f);
	ROUGHNESS = mix(0.04, 0.6, f);
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
