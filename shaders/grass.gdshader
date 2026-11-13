shader_type spatial;
render_mode cull_disabled;
// Wind-swept grass blades drawn through MultiMesh, lit softly with light shining through the tips.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 base_a : source_color = vec3(0.14, 0.26, 0.07);
uniform vec3 base_b : source_color = vec3(0.22, 0.36, 0.1);
uniform vec3 tip_a : source_color = vec3(0.4, 0.58, 0.2);
uniform vec3 tip_b : source_color = vec3(0.56, 0.56, 0.24);
uniform vec3 player_pos = vec3(0.0, -100.0, 0.0);

varying float h;
varying vec3 wp;
varying float rnd;

void vertex() {
	h = UV.y;
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	wp = root;
	rnd = fract(sin(dot(root.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float w = texture(noise_tex, root.xz * 0.02 + vec2(TIME * 0.06, TIME * 0.035)).r - 0.5;
	float gust = sin(TIME * 1.7 + root.x * 0.15 + root.z * 0.11) * 0.5 + 0.5;
	vec3 push = vec3(w * 1.1 + gust * 0.25, 0.0, w * 0.7);
	vec2 d = root.xz - player_pos.xz;
	float near = smoothstep(1.6, 0.2, length(d)) * step(abs(root.y - player_pos.y), 2.0);
	push.xz += normalize(d + vec2(0.001)) * near * 1.2;
	vec3 local_push = push * mat3(MODEL_MATRIX);
	VERTEX += local_push * h * h * 0.5;
	VERTEX.y -= near * h * 0.3;
	NORMAL = normalize(vec3(local_push.x * 0.6, 1.0, local_push.z * 0.6));
}

void fragment() {
	float n1 = texture(noise_tex, wp.xz * 0.028).r;
	float n2 = texture(noise_tex, wp.xz * 0.0035).r;
	vec3 base = mix(base_a, base_b, smoothstep(0.3, 0.7, n1));
	vec3 tip = mix(tip_a, tip_b, clamp(smoothstep(0.5, 0.75, n2) * 0.7 + (rnd - 0.5) * 0.5, 0.0, 1.0));
	ALBEDO = mix(base, tip, h * h) * mix(0.8, 1.12, rnd);
	ROUGHNESS = 0.78;
	SPECULAR = 0.25;
	AO = mix(0.6, 1.0, h);
	BACKLIGHT = tip * h * 0.55;
}
