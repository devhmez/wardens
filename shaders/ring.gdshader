shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_add, depth_draw_never;
// Expanding shockwave ring drawn on a flat quad.

uniform vec4 color : source_color = vec4(1.0);
uniform float thickness = 0.2;
uniform float fade = 1.0;
uniform float fill = 0.0;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = smoothstep(1.0 - thickness, 1.0 - thickness * 0.4, d) * smoothstep(1.0, 0.97, d);
	a += fill * smoothstep(1.0, 0.0, d) * step(d, 1.0);
	ALBEDO = color.rgb;
	ALPHA = clamp(a, 0.0, 1.0) * fade * color.a;
}
