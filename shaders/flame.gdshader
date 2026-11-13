shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, shadows_disabled, depth_draw_never;
// Flame particle: a noise-eroded tongue of fire that thins out and cools from white-yellow to deep red
// as it ages. "upright" flames keep their tip pointing up; the rest tumble (explosions, jets).

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform bool upright = false;
uniform float energy = 1.25;
uniform float rise = 0.9;

varying float life;
varying float seed;

void vertex() {
	life = INSTANCE_CUSTOM.y;
	seed = fract(float(INSTANCE_ID) * 0.61803);
	float ang = upright ? 0.0 : INSTANCE_CUSTOM.x;
	mat4 mat_world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	mat_world = mat_world * mat4(vec4(cos(ang), -sin(ang), 0.0, 0.0), vec4(sin(ang), cos(ang), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = UV;
	float t = 1.0 - uv.y;                       // 0 at the base, 1 at the tip
	// turbulence that scrolls toward the tip, with a sideways wobble that grows with height
	vec2 nuv = uv * vec2(0.55, 0.8) + vec2(seed * 7.3, seed * 3.1 + TIME * rise);
	float n = texture(noise_tex, nuv).r * 0.6 + texture(noise_tex, nuv * 2.4 + 0.37).r * 0.4;
	float wob = (texture(noise_tex, vec2(seed * 5.0, uv.y * 0.6 + TIME * rise * 0.7)).r - 0.5) * 0.35 * t;
	float x = uv.x - 0.5 + wob;
	// tongue shape: wide at the base, pinched to a point
	float halfw = mix(0.36, 0.05, pow(t, 0.8));
	float tongue = (1.0 - abs(x) / halfw) * smoothstep(0.0, 0.12, t) * (1.0 - pow(t, 2.5));
	float puff = 1.0 - length(uv - 0.5) * 2.0;
	float shape = upright ? tongue : mix(puff, tongue, 0.35);
	float v = shape * 1.15 + (n - 0.5) * 1.1 - life * 0.85;
	float a = smoothstep(0.02, 0.16, v) * smoothstep(0.0, 0.07, life);
	// temperature: deep red at the ragged edge, orange body, yellow-white heart
	vec3 col = mix(vec3(0.75, 0.06, 0.01), vec3(1.0, 0.36, 0.03), smoothstep(0.03, 0.3, v));
	col = mix(col, vec3(1.0, 0.72, 0.18), smoothstep(0.3, 0.6, v));
	col = mix(col, vec3(1.0, 0.95, 0.7), smoothstep(0.62, 0.95, v));
	col = mix(col, vec3(0.55, 0.05, 0.0), smoothstep(0.55, 1.0, life) * 0.7);
	ALBEDO = col * energy;
	ALPHA = a * COLOR.a;
}
