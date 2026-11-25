shader_type canvas_item;
// The shader of FlashFilters: a CanvasGroup draws its children into a buffer,
// and this shader draws the buffer with the _brightness of Tweener (a
// ColorTransform that adds round(brightness × 100) of 255 to red, green and
// blue) and a GlowFilter of Flash (quality 1) behind it.
//
// The glow is the alpha of the group, averaged over a square of blur × blur
// screen pixels (one box blur pass), times the strength, times the alpha of
// the filter. The square has at most SAMPLES × SAMPLES samples, so a large
// blur takes samples some pixels apart.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 glow_color : source_color = vec4(1.0);
uniform float glow_alpha = 0.0;
uniform float blur = 0.0;  // Screen pixels.
uniform float strength = 2.0;
uniform float brightness = 0.0;

const int SAMPLES = 11;

vec4 unpremultiplied(vec4 c) {
	return c.a > 0.0001 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}

void fragment() {
	vec4 c = unpremultiplied(textureLod(screen_texture, SCREEN_UV, 0.0));
	c.rgb = min(c.rgb + vec3(round(brightness * 100.0) / 255.0), vec3(1.0));
	float glow = 0.0;
	if (glow_alpha > 0.0 && blur > 0.5) {
		int count = min(SAMPLES, int(ceil(blur)));
		float step_pixels = blur / float(count);
		float sum = 0.0;
		for (int x = 0; x < count; x++) {
			for (int y = 0; y < count; y++) {
				vec2 offset = (vec2(float(x), float(y)) - float(count - 1) / 2.0) * step_pixels * SCREEN_PIXEL_SIZE;
				sum += textureLod(screen_texture, SCREEN_UV + offset, 0.0).a;
			}
		}
		glow = clamp(sum / float(count * count) * strength, 0.0, 1.0) * min(glow_alpha, 1.0);
	}
	float alpha = c.a + glow * (1.0 - c.a);
	vec3 colour = alpha > 0.0001 ? (c.rgb * c.a + glow_color.rgb * glow * (1.0 - c.a)) / alpha : vec3(0.0);
	COLOR *= vec4(colour, alpha);
}
