shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 water_color : source_color = vec4(0.447, 0.612, 0.827, 1.0);
uniform vec4 wave_color : source_color = vec4(0.78, 0.93, 1.0, 1.0);
uniform vec2 inner_half_size = vec2(17.355, 10.68);
uniform float wave_spacing : hint_range(2.0, 16.0, 0.1) = 7.2;
uniform float wave_speed : hint_range(0.0, 2.0, 0.01) = 0.28;
uniform float wave_amplitude : hint_range(0.0, 1.2, 0.01) = 0.32;
uniform float wave_frequency : hint_range(0.1, 3.0, 0.01) = 0.9;
uniform float wave_thickness : hint_range(0.005, 0.2, 0.005) = 0.045;

varying vec2 ocean_pos;

float wave_line(vec2 pos, float offset, float phase_shift) {
	float lane = fract((pos.y + TIME * wave_speed + offset) / wave_spacing);
	float lane_center = (lane - 0.5) * wave_spacing;
	float curve = sin(pos.x * wave_frequency + TIME * 1.2 + phase_shift) * wave_amplitude;
	float distance_to_wave = abs(lane_center - curve);
	float line = 1.0 - smoothstep(wave_thickness, wave_thickness * 3.0, distance_to_wave);
	float appear = smoothstep(0.05, 0.28, lane) * (1.0 - smoothstep(0.72, 0.95, lane));
	return line * appear;
}

void vertex() {
	ocean_pos = VERTEX.xz;
}

void fragment() {
	if (abs(ocean_pos.x) < inner_half_size.x && abs(ocean_pos.y) < inner_half_size.y) {
		discard;
	}

	float waves = 0.0;
	waves += wave_line(ocean_pos, 0.0, 0.0);
	waves += wave_line(ocean_pos * vec2(0.92, 1.0), 1.7, 1.8) * 0.75;
	waves += wave_line(ocean_pos * vec2(1.08, 1.0), 3.1, 3.4) * 0.55;
	waves = clamp(waves, 0.0, 1.0);

	ALBEDO = mix(water_color.rgb, wave_color.rgb, waves);
}
