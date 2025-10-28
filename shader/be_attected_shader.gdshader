shader_type canvas_item;

// 水滴区域参数
uniform int droplet_count : hint_range(1, 20) = 3; // 水滴数量
uniform float min_radius : hint_range(0.02, 0.2) = 0.05; // 最小半径
uniform float max_radius : hint_range(0.05, 0.4) = 0.15; // 最大半径
uniform float edge_smoothness : hint_range(0.001, 0.1) = 0.03; // 边缘平滑度
uniform float random_seed : hint_range(0.0, 100.0) = 1.3; // 随机种子（改变可重新生成布局）
uniform float center_bias : hint_range(0.0, 1.0) = 0.44; // 中心聚集度（0=完全随机，1=集中在中心）

// 不规则效果参数
uniform float ellipse_variation : hint_range(0.0, 0.8) = 0.4; // 椭圆变化程度（0=圆形，1=可能很扁）
uniform float edge_distortion : hint_range(0.0, 0.5) = 0.15; // 边缘扰动强度（制造凹凸效果）
uniform float distortion_frequency : hint_range(1.0, 4.0) = 2.5; // 边缘扰动频率

// 水滴效果参数（来自 water.tres）
uniform vec4 water_color : source_color = vec4(0.4, 0.6, 0.8, 0.21960784); // 水滴颜色
uniform vec4 wet_color : source_color = vec4(0.1764706, 0.25882354, 0.25882354, 0.40392157); // 湿润高光颜色
uniform float wetting_degree : hint_range(0.3, 0.7) = 0.7; // 湿润程度
uniform float noise_scale : hint_range(1.0, 100.0) = 100.0; // 噪声缩放
uniform float noise_detail : hint_range(1.0, 10.0) = 10.0; // 噪声细节层数

// 伪随机函数
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

vec2 random2(vec2 st) {
    st = vec2(dot(st, vec2(127.1, 311.7)), dot(st, vec2(269.5, 183.3)));
    return fract(sin(st) * 43758.5453123);
}

vec2 random_centered(vec2 seed, float bias) {
    vec2 random_pos = random2(seed);
    vec2 center = vec2(0.5);
    return mix(random_pos, center + (random_pos - center) * (1.0 - bias), bias);
}

vec2 fade(vec2 t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float perlin_noise(vec2 P) {
    vec2 Pi = floor(P);
    vec2 Pf = fract(P);

    vec2 grad00 = random2(Pi) * 2.0 - 1.0;
    vec2 grad10 = random2(Pi + vec2(1.0, 0.0)) * 2.0 - 1.0;
    vec2 grad01 = random2(Pi + vec2(0.0, 1.0)) * 2.0 - 1.0;
    vec2 grad11 = random2(Pi + vec2(1.0, 1.0)) * 2.0 - 1.0;

    float n00 = dot(grad00, Pf);
    float n10 = dot(grad10, Pf - vec2(1.0, 0.0));
    float n01 = dot(grad01, Pf - vec2(0.0, 1.0));
    float n11 = dot(grad11, Pf - vec2(1.0, 1.0));

    vec2 fade_xy = fade(Pf);
    return mix(mix(n00, n10, fade_xy.x), mix(n01, n11, fade_xy.x), fade_xy.y);
}

float fbm(vec2 p, float octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for(float i = 0.0; i < octaves; i++) {
        value += amplitude * perlin_noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

float draw_droplet(vec2 uv, vec2 center, float radius, float smoothness, vec2 ellipse_ratio, float seed) {
    vec2 offset = (uv - center) / ellipse_ratio;
    float dist = length(offset);
    float angle = atan(offset.y, offset.x);

    float distortion = sin(angle * distortion_frequency + seed * 10.0) *
                       cos(angle * distortion_frequency * 0.7 + seed * 15.0) *
                       edge_distortion;

    float distorted_radius = radius * (1.0 + distortion);
    return 1.0 - smoothstep(distorted_radius - smoothness, distorted_radius + smoothness, dist);
}

void fragment() {
    vec2 uv = UV;
    vec4 original_color = texture(TEXTURE, uv);

    // Aspect ratio correction
    float aspect_ratio = (1.0 / TEXTURE_PIXEL_SIZE).x / (1.0 / TEXTURE_PIXEL_SIZE).y;
    vec2 corrected_uv = vec2(uv.x * aspect_ratio, uv.y);
    vec2 center_correction = vec2(aspect_ratio, 1.0);

    // Generate droplet mask
    float droplet_mask = 0.0;
    for(int i = 0; i < droplet_count; i++) {
        float seed = float(i) + random_seed;
        vec2 droplet_pos = random_centered(vec2(seed, 0.0), center_bias) * center_correction;
        float radius = mix(min_radius, max_radius, random(vec2(seed, 4.0)));

        vec2 ellipse_ratio = vec2(
            1.0 + (random(vec2(seed, 5.0)) - 0.5) * 2.0 * ellipse_variation,
            1.0 + (random(vec2(seed, 6.0)) - 0.5) * 2.0 * ellipse_variation
        );

        float droplet = draw_droplet(corrected_uv, droplet_pos, radius, edge_smoothness, ellipse_ratio, seed);
        droplet_mask = max(droplet_mask, droplet);
    }

    // Apply water effect with color fade based on wetting_degree
    // 在 0.6-0.7 范围内渐变，0.6 以下保持完整颜色
    float color_fade = clamp((0.7 - wetting_degree) / 0.1, 0.0, 1.0);
    vec4 faded_water_color = mix(vec4(water_color.rgb, 0.0), water_color, color_fade);

    float noise_value = (fbm(uv * noise_scale, noise_detail) + 1.0) * 0.5;
    float wet_pattern = step(wetting_degree, noise_value);
    vec4 wet_effect = mix(faded_water_color, wet_color, wet_pattern);
    vec4 blended = mix(original_color, wet_effect, wet_effect.a);

    // Final blend with mask
    COLOR = vec4(
        mix(original_color.rgb, blended.rgb, droplet_mask),
        mix(original_color.a, blended.a, droplet_mask)
    );
}
