shader_type spatial;
// Physically based surface with procedural micro-detail (no texture files needed).
// Used by characters, props and solid bending meshes.

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float roughness = 0.85;
uniform float metallic = 0.0;
uniform float bump = 0.006;          // height of surface detail in metres
uniform float detail_scale = 6.0;    // detail repeats per metre
uniform float mottling = 0.18;       // colour variation
uniform float backlight = 0.0;       // light passing through thin things (leaves)
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float dissolve = 0.0;
uniform float frost = 0.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool use_tex = false;
uniform float tex_scale = 0.4;
uniform float tex_gain = 1.8;

varying vec3 opos;
varying vec3 onrm;

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
}

float tri(vec3 p, vec3 w) {
	return texture(noise_tex, p.yz).r * w.x + texture(noise_tex, p.xz).r * w.y + texture(noise_tex, p.xy).r * w.z;
}

void fragment() {
	vec3 w = pow(abs(normalize(onrm)), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 p = opos * detail_scale * 0.12;
	float h = tri(p, w) * 0.6 + tri(p * 3.7 + 0.31, w) * 0.4;
	if (dissolve > 0.0) {
		float d = tri(opos * 0.9 + 0.5, w);
		if (d < dissolve * 1.1 - 0.05) {
			discard;
		}
	}
	vec3 base = albedo.rgb * COLOR.rgb * mix(1.0 - mottling, 1.0 + mottling * 0.5, h);
	if (use_tex) {
		vec3 q = opos * tex_scale;
		vec3 tx = texture(tex_albedo, q.zy).rgb * w.x + texture(tex_albedo, q.xz).rgb * w.y + texture(tex_albedo, q.xy).rgb * w.z;
		base = tx * albedo.rgb * COLOR.rgb * tex_gain;
		h = mix(h, dot(tx, vec3(0.333)), 0.85);
	}
	vec3 icy = vec3(0.62, 0.84, 1.0);
	base = mix(base, icy, frost * 0.75);
	ALBEDO = mix(base, flash_color.rgb, clamp(flash, 0.0, 1.0));
	ROUGHNESS = clamp(mix(roughness + (h - 0.5) * 0.22, 0.12, frost), 0.03, 1.0);
	METALLIC = metallic;
	SPECULAR = 0.5;
	BACKLIGHT = base * backlight;
	// bump from the height field, without needing tangents
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhdx = dFdx(h);
	float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	NORMAL = normalize(abs(det) * NORMAL - bump * grad);
	float edge = 0.0;
	if (dissolve > 0.0) {
		float d2 = tri(opos * 0.9 + 0.5, w);
		edge = smoothstep(dissolve * 1.1 + 0.06, dissolve * 1.1 - 0.05, d2);
	}
	EMISSION = emission.rgb * emission_energy + flash_color.rgb * flash * 1.2 + icy * frost * 0.12 + vec3(0.8, 0.35, 1.0) * edge * 3.0;
}
