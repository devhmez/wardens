shader_type spatial;
// Cel-shaded surface used by characters, props and bending meshes.

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float shade_floor = 0.42;
uniform float rim = 0.35;
uniform vec4 rim_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform float spec = 0.0;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float dissolve = 0.0;

varying vec3 wpos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (dissolve > 0.0) {
		float n = hash(floor(wpos * 14.0));
		if (n < dissolve) {
			discard;
		}
	}
	vec3 base = albedo.rgb * COLOR.rgb;
	ALBEDO = mix(base, flash_color.rgb, clamp(flash, 0.0, 1.0));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float r = smoothstep(0.55, 0.62, fres) * rim;
	EMISSION = emission.rgb * emission_energy + rim_color.rgb * r * 0.35 + flash_color.rgb * flash * 1.5;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = smoothstep(0.0, 0.05, ndl);
	float band2 = smoothstep(0.55, 0.6, ndl);
	float lit = band * mix(0.78, 1.0, band2);
	float sh = smoothstep(0.25, 0.4, ATTENUATION);
	float i = mix(shade_floor * 0.0, 1.0, lit * sh) ;
	DIFFUSE_LIGHT += LIGHT_COLOR * i / PI;
	if (spec > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		float s = smoothstep(0.96, 0.975, dot(NORMAL, h)) * spec * sh;
		SPECULAR_LIGHT += LIGHT_COLOR * s;
	}
}
