// 阴影翻转shader - 适用于ColorRect
// 不需要纹理，直接绘制阴影颜色

shader_type canvas_item;

uniform float fov : hint_range(1, 179) = 90;
uniform bool cull_back = true;
uniform float y_rot : hint_range(-180, 180) = 0.0;
uniform float x_rot : hint_range(-180, 180) = 0.0;
uniform float inset : hint_range(0, 1) = 0.0;
// 阴影颜色和透明度
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.35);
// 根据翻转角度调整阴影透明度（卡片越"高"，阴影越淡）
uniform float lift_factor : hint_range(0, 1) = 0.0;
// ColorRect的尺寸（因为没有纹理，需要手动指定）
uniform vec2 rect_size = vec2(264.0, 345.0);

varying flat vec2 o;
varying vec3 p;

void vertex(){
	float sin_b = sin(y_rot / 180.0 * PI);
	float cos_b = cos(y_rot / 180.0 * PI);
	float sin_c = sin(x_rot / 180.0 * PI);
	float cos_c = cos(x_rot / 180.0 * PI);

	mat3 inv_rot_mat;
	inv_rot_mat[0][0] = cos_b;
	inv_rot_mat[0][1] = 0.0;
	inv_rot_mat[0][2] = -sin_b;

	inv_rot_mat[1][0] = sin_b * sin_c;
	inv_rot_mat[1][1] = cos_c;
	inv_rot_mat[1][2] = cos_b * sin_c;

	inv_rot_mat[2][0] = sin_b * cos_c;
	inv_rot_mat[2][1] = -sin_c;
	inv_rot_mat[2][2] = cos_b * cos_c;

	float t = tan(fov / 360.0 * PI);
	p = inv_rot_mat * vec3((UV - 0.5), 0.5 / t);
	float v = (0.5 / t) + 0.5;
	p.xy *= v * inv_rot_mat[2].z;
	o = v * inv_rot_mat[2].xy;

	// 使用rect_size替代TEXTURE_PIXEL_SIZE
	// (UV - 0.5) 范围是 -0.5 到 0.5
	// 乘以 rect_size 得到像素偏移
	VERTEX += (UV - 0.5) * rect_size * t * (1.0 - inset);
}

void fragment(){
	if (cull_back && p.z <= 0.0) discard;
	vec2 uv = (p.xy / p.z).xy - o;
	
	// 检查是否在有效区域内
	float valid = step(max(abs(uv.x), abs(uv.y)), 0.5);
	
	// 阴影颜色，根据lift_factor调整透明度
	// 当卡片腾空越高，阴影越淡
	float alpha = shadow_color.a * (1.0 - lift_factor * 0.7);
	COLOR = vec4(shadow_color.rgb, alpha * valid);
}
