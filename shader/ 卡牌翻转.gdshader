// Hey this is Hei! This shader "fakes" a 3D-camera perspective on CanvasItems.
// License: MIT
// 合并了阴影效果

shader_type canvas_item;

// Camera FOV
uniform float fov : hint_range(1, 179) = 90;
uniform bool cull_back = true;
uniform float y_rot : hint_range(-180, 180) = 0.0;
uniform float x_rot : hint_range(-180, 180) = 0.0;
// At 0, the image retains its size when unrotated.
// At 1, the image is resized so that it can do a full
// rotation without clipping inside its rect.
uniform float inset : hint_range(0, 1) = 0.0;
// Consider changing this to a uniform and changing it from code

// 卡背颜色（当cull_back为false时生效）
uniform vec4 back_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// 阴影参数
uniform bool shadow_enabled = true;
uniform float shadow_offset_x : hint_range(-10.0, 10.0) = 2.0;
uniform float shadow_offset_y : hint_range(-10.0, 10.0) = 2.0;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.4);

varying flat vec2 o;
varying flat vec2 o_shadow;
varying vec3 p;
varying vec3 p_shadow;

// Creates rotation matrix
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
	float v = (0.5 / t) + 0.5;
	
	// 卡片的3D变换
	p = inv_rot_mat * vec3((UV - 0.5), 0.5 / t);
	p.xy *= v * inv_rot_mat[2].z;
	o = v * inv_rot_mat[2].xy;
	
	// 阴影的3D变换（以偏移后的位置为中心）
	vec2 shadow_offset = vec2(shadow_offset_x, shadow_offset_y) * 0.05;
	p_shadow = inv_rot_mat * vec3((UV - 0.5 + shadow_offset), 0.5 / t);
	p_shadow.xy *= v * inv_rot_mat[2].z;
	o_shadow = v * inv_rot_mat[2].xy;

	VERTEX += (UV - 0.5) / TEXTURE_PIXEL_SIZE * t * (1.0 - inset);
}

void fragment(){
	bool is_back = p.z <= 0.0;
	
	if (is_back) {
		// 卡片背面
		if (cull_back) {
			discard;
		} else {
			vec2 uv = (p.xy / -p.z).xy + o;
			
			// 先绘制阴影（使用阴影专用的变换坐标）
			vec4 final_color = vec4(0.0);
			if (shadow_enabled) {
				vec2 shadow_uv = (p_shadow.xy / -p_shadow.z).xy + o_shadow;
				if (max(abs(shadow_uv.x), abs(shadow_uv.y)) <= 0.5) {
					vec4 tex = texture(TEXTURE, shadow_uv + 0.5);
					final_color = vec4(shadow_color.rgb, tex.a * shadow_color.a);
				}
			}
			
			// 再绘制卡背
			if (max(abs(uv.x), abs(uv.y)) <= 0.5) {
				final_color = mix(final_color, back_color, back_color.a);
			}
			
			COLOR = final_color;
		}
	} else {
		// 卡片正面
		vec2 uv = (p.xy / p.z).xy - o;
		
		// 先绘制阴影（使用阴影专用的变换坐标）
		vec4 final_color = vec4(0.0);
		if (shadow_enabled) {
			vec2 shadow_uv = (p_shadow.xy / p_shadow.z).xy - o_shadow;
			if (max(abs(shadow_uv.x), abs(shadow_uv.y)) <= 0.5) {
				vec4 tex = texture(TEXTURE, shadow_uv + 0.5);
				final_color = vec4(shadow_color.rgb, tex.a * shadow_color.a);
			}
		}
		
		// 再绘制正面纹理
		if (max(abs(uv.x), abs(uv.y)) <= 0.5) {
			vec4 tex_color = texture(TEXTURE, uv + 0.5);
			final_color = mix(final_color, tex_color, tex_color.a);
		}
		
		COLOR = final_color;
	}
}
