shader_type canvas_item;
// Draws a frame of layers (FlashArt.render): the texture has the layers one
// below the other, all of the same size. Layer 0 is the normal image; the
// others mix with the screen behind the graphic by their blend mode, in their
// order, and the normal image goes over them. A BackBufferCopy before the
// node copies the screen behind it (see FrameMaterial).

const int MAX_LAYERS = 9;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform int count = 1;
// The codes of FlashArt (blend_code in flash_art/src/godot_api.rs).
uniform int modes[MAX_LAYERS];
// A colour added to the graphic, as the colour filters of the client do (see tint.gdshader).
uniform vec3 added : source_color;

// The colour of the node (modulate). In fragment(), COLOR is already multiplied by the texture.
varying vec4 node_colour;

void vertex() {
	node_colour = COLOR;
}

float hard_light(float b, float s) {
	return s <= 0.5 ? 2.0 * s * b : 1.0 - 2.0 * (1.0 - s) * (1.0 - b);
}

vec3 blend(int mode, vec3 b, vec3 s) {
	if (mode == 1) return b * s;
	if (mode == 2) return b + s - b * s;
	if (mode == 3) return max(b, s);
	if (mode == 4) return min(b, s);
	if (mode == 5) return abs(b - s);
	if (mode == 6) return min(b + s, vec3(1.0));
	if (mode == 7) return vec3(hard_light(s.r, b.r), hard_light(s.g, b.g), hard_light(s.b, b.b));
	if (mode == 8) return vec3(hard_light(b.r, s.r), hard_light(b.g, s.g), hard_light(b.b, s.b));
	return s;
}

vec4 layer(sampler2D pixels, vec2 uv, vec4 modulate) {
	vec4 c = texture(pixels, uv) * modulate;
	return vec4(min(c.rgb + added * c.a, vec3(1.0)), c.a);
}

void fragment() {
	float height = 1.0 / float(count);
	vec3 back = texture(screen, SCREEN_UV).rgb;
	vec3 result = back;
	float cover = 0.0;
	for (int i = 1; i < count; i++) {
		vec4 part = layer(TEXTURE, UV + vec2(0.0, height * float(i)), node_colour);
		result = mix(result, blend(modes[i], result, part.rgb), part.a);
		cover += part.a * (1.0 - cover);
	}
	vec4 normal = layer(TEXTURE, UV, node_colour);
	result = mix(result, normal.rgb, normal.a);
	cover += normal.a * (1.0 - cover);
	// Drawn with alpha cover over the screen, this gives result.
	COLOR = cover > 0.0 ? vec4(clamp((result - back * (1.0 - cover)) / cover, 0.0, 1.0), cover) : vec4(0.0);
}
