shader_type spatial;
// Skinned characters: textured PBR with recolouring, hit flash, frost, dissolve,
// and an optional mask that keeps only the head (and hands) of a body worn under an outfit.

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_orm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform bool has_albedo = true;
uniform bool has_normal = false;
uniform bool has_orm = false;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness = 0.8;
uniform float metallic = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_amount = 0.0;
uniform float alpha_cut = 0.0;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float dissolve = 0.0;
uniform float frost = 0.0;
uniform int mask_mode = 0;      // 0 everything, 1 head and neck, 2 head, neck and hands

varying float keep;
varying vec3 opos;

void vertex() {
	opos = VERTEX;
	keep = 1.0;
	if (mask_mode > 0) {
		float w = 0.0;
		for (int i = 0; i < 4; i++) {
			uint b = BONE_INDICES[i];
			bool head = (b == 5u || b == 6u);
			bool hand = (b >= 10u && b <= 30u) || (b >= 34u && b <= 54u);
			if (head || (mask_mode == 2 && hand)) {
				w += BONE_WEIGHTS[i];
			}
		}
		keep = w;
	}
}

void fragment() {
	if (keep < 0.5) {
		discard;
	}
	vec4 t = has_albedo ? texture(tex_albedo, UV) : vec4(1.0);
	if (alpha_cut > 0.0 && t.a < alpha_cut) {
		discard;
	}
	float d = 1.0;
	if (dissolve > 0.0) {
		d = texture(noise_tex, opos.xy * 0.9 + opos.z * 0.6).r;
		if (d < dissolve * 1.1 - 0.05) {
			discard;
		}
	}
	vec3 base = t.rgb;
	float lum = dot(base, vec3(0.3, 0.59, 0.11));
	vec3 recol = tint.rgb * pow(lum, 0.72) * 1.55;
	base = mix(base, recol, tint_amount);
	base *= albedo.rgb;
	vec3 icy = vec3(0.62, 0.84, 1.0);
	base = mix(base, icy, frost * 0.75);
	ALBEDO = mix(base, flash_color.rgb, clamp(flash, 0.0, 1.0));
	float r = roughness;
	float m = metallic;
	if (has_orm) {
		vec3 orm = texture(tex_orm, UV).rgb;
		r = orm.g * roughness;
		m = orm.b * metallic;
		AO = orm.r;
	}
	ROUGHNESS = clamp(mix(r, 0.12, frost), 0.04, 1.0);
	METALLIC = m;
	SPECULAR = 0.5;
	if (has_normal) {
		NORMAL_MAP = texture(tex_normal, UV).rgb;
	}
	float edge = dissolve > 0.0 ? smoothstep(dissolve * 1.1 + 0.06, dissolve * 1.1 - 0.05, d) : 0.0;
	EMISSION = emission.rgb * emission_energy + flash_color.rgb * flash * 1.2 + icy * frost * 0.12 + vec3(0.8, 0.35, 1.0) * edge * 3.0;
}
