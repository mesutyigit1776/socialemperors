shader_type canvas_item;
// Adds a colour to a graphic, as the colour filters of the client do.

uniform vec3 added : source_color;

void fragment() {
	// COLOR is the texture times the colour of the node.
	vec4 c = COLOR;
	COLOR = vec4(min(c.rgb + added * c.a, vec3(1.0)), c.a);
}
