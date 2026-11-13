shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;
// Inverted-hull ink outline.

uniform vec4 color : source_color = vec4(0.08, 0.06, 0.1, 1.0);
uniform float width = 0.014;
uniform float dissolve = 0.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float w = width * clamp(clip.w * 0.16, 0.6, 3.0);
	VERTEX += NORMAL * w;
}

void fragment() {
	if (dissolve > 0.02) {
		discard;
	}
	ALBEDO = color.rgb;
}
