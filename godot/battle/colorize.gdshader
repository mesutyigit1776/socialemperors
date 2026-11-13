shader_type canvas_item;
// The colorize of a ColorMatrixFilter of the client with amount 1: the
// brightness of each pixel in one colour.

uniform vec3 colour : source_color;

void fragment() {
	// COLOR is the texture times the colour of the node.
	float brightness = dot(COLOR.rgb, vec3(0.3086, 0.6094, 0.082));
	COLOR = vec4(colour * brightness, COLOR.a);
}
