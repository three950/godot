shader_type canvas_item;
render_mode unshaded;

uniform vec4 drop_shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);
uniform float shadow_rotation : hint_range(0.0, 360.0) = 0.0;
uniform vec2 rotation_pivot = vec2(0.5, 0.5);

// 基于屏幕位置的偏移变化控制
uniform bool use_position_based_offset = true;
uniform vec2 offset_variation_x = vec2(0.0, 0.1); // X方向偏移强度 (x=右侧往左偏移强度, y=左侧往右偏移强度) - 中心偏移为0
uniform vec2 offset_variation_y = vec2(0.0, 0.1); // Y方向偏移强度 (x=下方往上偏移强度, y=上方往下偏移强度) - 中心偏移为0
uniform vec2 offset_gradient_direction = vec2(1.0, 1.0); // 偏移渐变方向 (1.0 = 从左到右/从上到下, -1.0 = 反向)

uniform float shadow_blur_strength : hint_range(0.0, 20.0) = 2.0;
uniform int shadow_blur_samples : hint_range(3, 8, 1) = 4;
uniform float _blur_scale_factor = 1.0;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear_mipmap;

vec2 rotate_uv(vec2 uv, float angle, vec2 aspect_correction) {
    uv -= rotation_pivot;
    uv *= aspect_correction; // Correct aspect ratio before rotation
    float s = sin(angle);
    float c = cos(angle);
    vec2 rotated = vec2(
        uv.x * c - uv.y * s,
        uv.x * s + uv.y * c
    );
    rotated /= aspect_correction; // Restore original proportions
    return rotated + rotation_pivot;
}

vec4 get_rotated_shadow(vec2 uv, float rotation, vec2 aspect) {
    vec2 corrected_uv = rotate_uv(uv, rotation, aspect);
    return texture(SCREEN_TEXTURE, corrected_uv);
}

vec4 apply_shadow_blur(vec2 uv, vec2 pixel_size, vec2 offset, float rotation, vec2 aspect) {
    float samples = float(pow(2.0, float(shadow_blur_samples)));
	float scaled_blur_strength = shadow_blur_strength * _blur_scale_factor;
    float layer_increment = scaled_blur_strength / samples;
    float angle_increment = TAU / samples;

    // Base rotated shadow
    vec4 shadow_base = get_rotated_shadow(uv - offset, rotation, aspect);
    vec4 color = vec4(drop_shadow_color.rgb, drop_shadow_color.a * shadow_base.a);

    if (scaled_blur_strength <= 0.0) return color;

    // Blur with aspect-corrected rotation
    for (float d = layer_increment; d <= scaled_blur_strength; d += layer_increment) {
        vec4 layer_color = vec4(0.0);
        for (float t = 0.0; t < TAU; t += angle_increment) {
            vec2 sample_uv = uv - offset + vec2(cos(t), sin(t)) * d * pixel_size;
            vec4 sample = get_rotated_shadow(sample_uv, rotation, aspect);
            layer_color += vec4(drop_shadow_color.rgb, drop_shadow_color.a * sample.a);
        }
        layer_color /= samples;
        float weight = 1.0 - sqrt(d / scaled_blur_strength);
        color = mix(color, layer_color, weight);
    }

    return color;
}

void fragment() {
    vec2 pixel_size = SCREEN_PIXEL_SIZE;
    vec2 uv = SCREEN_UV;
    float rotation = radians(shadow_rotation);
    
    // 根据屏幕位置计算动态偏移
    vec2 offset;
    if (use_position_based_offset) {
        // 将UV坐标映射到渐变方向 (-1.0 到 1.0)，中心为0
        vec2 gradient_uv = (uv - 0.5) * 2.0 * offset_gradient_direction;
        
        // 计算X方向的偏移（基于屏幕X位置）
        // 使用距离中心的距离作为强度，中心偏移为0
        // 左侧（gradient_uv.x < 0）：阴影往右偏移（正值）
        // 右侧（gradient_uv.x > 0）：阴影往左偏移（负值）
        float x_distance = abs(gradient_uv.x); // 距离中心的距离 0.0-1.0
        float dynamic_offset_x;
        if (gradient_uv.x < 0.0) {
            // 左侧：往右偏移（正值）
            dynamic_offset_x = offset_variation_x.y * x_distance;
        } else {
            // 右侧：往左偏移（负值）
            dynamic_offset_x = -offset_variation_x.x * x_distance;
        }
        
        // 计算Y方向的偏移（基于屏幕Y位置）
        // 使用距离中心的距离作为强度，中心偏移为0
        // 上方（gradient_uv.y < 0）：阴影往下偏移（正值）
        // 下方（gradient_uv.y > 0）：阴影往上偏移（负值）
        float y_distance = abs(gradient_uv.y); // 距离中心的距离 0.0-1.0
        float dynamic_offset_y;
        if (gradient_uv.y < 0.0) {
            // 上方：往下偏移（正值）
            dynamic_offset_y = offset_variation_y.y * y_distance;
        } else {
            // 下方：往上偏移（负值）
            dynamic_offset_y = -offset_variation_y.x * y_distance;
        }
        
        offset = vec2(dynamic_offset_x, dynamic_offset_y);
    } else {
        // 不使用基于位置的偏移，偏移为0
        offset = vec2(0.0, 0.0);
    }

    // Calculate aspect ratio correction (width/height, height/width)
    vec2 aspect = vec2(1.0, SCREEN_PIXEL_SIZE.x/SCREEN_PIXEL_SIZE.y);

    vec4 original = texture(SCREEN_TEXTURE, uv);
    vec4 shadow = apply_shadow_blur(uv, pixel_size, offset, rotation, aspect);

    COLOR = mix(shadow, original, original.a);
}