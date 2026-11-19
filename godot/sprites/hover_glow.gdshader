shader_type canvas_item;
// The white glow around an item under the mouse: GlowFilter(white, alpha 1,
// blur 3 x 3, strength 50, quality 3) of the client. The quad grows by pad
// texture pixels at each side, so that the glow can go outside the graphic.
// The glow is the alpha of the graphic, blurred three times with a box of 3
// screen pixels (the kernel 1 3 6 7 6 3 1 / 27), times the strength. The
// graphic itself is not drawn.

uniform float pad = 4.0;  // Texture pixels.
uniform float step_size = 1.0;  // Texture pixels in one screen pixel.
uniform float strength = 50.0;

varying vec2 grown_uv;

void vertex() {
	vec2 side = UV * 2.0 - 1.0;
	VERTEX += side * pad;
	grown_uv = UV + side * pad * TEXTURE_PIXEL_SIZE;
}

float alpha_at(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(tex, uv).a;
}

void fragment() {
	const float weights[7] = float[](1.0, 3.0, 6.0, 7.0, 6.0, 3.0, 1.0);
	float sum = 0.0;
	for (int x = 0; x < 7; x++) {
		for (int y = 0; y < 7; y++) {
			vec2 offset = vec2(float(x - 3), float(y - 3)) * step_size * TEXTURE_PIXEL_SIZE;
			sum += weights[x] * weights[y] * alpha_at(TEXTURE, grown_uv + offset);
		}
	}
	COLOR = vec4(1.0, 1.0, 1.0, clamp(sum / 729.0 * strength, 0.0, 1.0));
}
