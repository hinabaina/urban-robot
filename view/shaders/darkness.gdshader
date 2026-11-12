// Темнота шахты: чем глубже, тем темнее; свет вычитается кругами с пиксельной «лесенкой». Владелец: B.
shader_type canvas_item;

uniform float surface_y = 192.0;
uniform float ramp_px = 320.0;            // за сколько пикселей глубины темнота доходит до предела
uniform float near_dark = 0.30;           // сразу под землёй
uniform float max_dark = 0.88;            // на дне карты
uniform vec4 lights[24];                  // x, y, радиус, сила
uniform int light_count = 0;
uniform vec4 tint : source_color = vec4(0.02, 0.02, 0.07, 1.0);

varying vec2 world_pos;

void vertex() {
	world_pos = VERTEX;                   // узел стоит в начале координат мира
}

void fragment() {
	vec2 p = floor(world_pos);            // пиксель мира: края света ступеньками, как в пиксель-арте
	float depth = p.y - surface_y;
	float dark = 0.0;
	if (depth > 0.0) {
		dark = mix(near_dark, max_dark, clamp(depth / ramp_px, 0.0, 1.0)) * clamp(depth / 16.0, 0.0, 1.0);
		float lit = 0.0;
		for (int i = 0; i < light_count; i++) {
			vec4 l = lights[i];
			float d = distance(p, l.xy);
			lit = max(lit, l.w * (1.0 - smoothstep(l.z * 0.3, l.z, d)));
		}
		dark *= 1.0 - lit;
		dark = floor(dark * 7.0 + 0.5) / 7.0;
	}
	COLOR = vec4(tint.rgb, dark);
}
