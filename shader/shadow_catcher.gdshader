shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

// 阴影接收器着色器 - 只显示阴影，其他部分透明

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.6);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.7;

varying vec3 world_vertex;

void vertex() {
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// 白色基础，让阴影计算正确
	ALBEDO = vec3(1.0);
	// 完全透明，只让阴影显示
	ALPHA = 0.0;
}

void light() {
	// ATTENUATION 在有阴影的地方会变小
	// 1.0 - ATTENUATION = 阴影强度
	float shadow = 1.0 - ATTENUATION;
	
	// 只在阴影区域显示颜色
	if (shadow > 0.01) {
		DIFFUSE_LIGHT += shadow_color.rgb * shadow * shadow_strength;
		ALPHA = shadow * shadow_color.a * shadow_strength;
	}
}

