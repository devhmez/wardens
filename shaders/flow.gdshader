shader_type spatial;
render_mode cull_disabled, shadows_disabled, unshaded, depth_draw_never;
// Scrolling energy surface: water bodies, tornado funnels, air rings, fire walls.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 color_a : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.9, 1.0, 1.0, 1.0);
uniform vec2 scroll = vec2(0.0, 1.0);
uniform vec2 tiling = vec2(1.0, 1.0);
uniform float cut = 0.45;
uniform float soft = 0.08;
uniform float energy = 1.0;
uniform float alpha = 1.0;
uniform float fade_top = 0.0;
uniform float fade_bottom = 0.0;
uniform float fresnel = 0.0;
uniform float solid = 0.0;
uniform float v_scale = 1.0;
uniform float skew = 0.0;
uniform float v_grad = 0.0;
uniform float v0 = 0.3;
uniform float v1 = 0.6;

void fragment() {
	float v = clamp(UV.y * v_scale, 0.0, 1.0);
	vec2 uv = vec2(UV.x + v * skew, v) * tiling + scroll * TIME;
	float n = texture(noise_tex, uv).r * 0.6 + texture(noise_tex, uv * 2.1 + vec2(0.3, TIME * 0.2)).r * 0.4;
	float m = max(smoothstep(cut, cut + soft, n), solid);
	float hi = smoothstep(cut + 0.16, cut + 0.18, n);
	vec3 col = mix(color_a.rgb, color_b.rgb, hi);
	float a = mix(color_a.a, color_b.a, hi) * m * alpha;
	float g = smoothstep(v0, v1, v) * v_grad;
	col = mix(col, color_b.rgb, g);
	a = clamp(a + g, 0.0, 1.0);
	a *= mix(1.0, smoothstep(0.0, 0.3, v), fade_top);
	a *= mix(1.0, smoothstep(1.0, 0.7, v), fade_bottom);
	if (fresnel > 0.0) {
		float f = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
		a = clamp(a + f * fresnel * alpha, 0.0, 1.0);
		col = mix(col, color_b.rgb, f * fresnel);
	}
	ALBEDO = col * energy;
	ALPHA = clamp(a, 0.0, 1.0);
}
