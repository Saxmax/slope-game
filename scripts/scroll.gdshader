shader_type canvas_item;

uniform float scrollY = 0.0;

void vertex() {
	UV.y += scrollY;
}