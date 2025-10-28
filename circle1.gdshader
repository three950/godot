shader_type canvas_item;

// 参数设置
uniform int droplet_count : hint_range(1, 20) = 3; // 水滴数量
uniform float min_radius : hint_range(0.02, 0.2) = 0.05; // 最小半径
uniform float max_radius : hint_range(0.05, 0.4) = 0.15; // 最大半径
uniform float edge_smoothness : hint_range(0.001, 0.1) = 0.03; // 边缘平滑度
uniform float random_seed : hint_range(0.0, 100.0) = 1.0; // 随机种子（改变可重新生成布局）

// 颜色控制 - 用于区分不同水滴
uniform bool use_color_variation = true; // 是否使用颜色区分
uniform vec4 base_color : source_color = vec4(0.4, 0.6, 0.8, 0.5); // 基础颜色
uniform float color_variation : hint_range(0.0, 1.0) = 0.3; // 颜色变化幅度

// 伪随机函数
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

// 生成2D随机向量
vec2 random2(vec2 st) {
    st = vec2(dot(st,vec2(127.1,311.7)),
              dot(st,vec2(269.5,183.3)));
    return fract(sin(st)*43758.5453123);
}

// 生成随机颜色（基于基础色的变化）
vec3 random_color(float seed) {
    if (!use_color_variation) {
        return base_color.rgb;
    }
    
    float r = base_color.r + (random(vec2(seed, 1.0)) - 0.5) * color_variation;
    float g = base_color.g + (random(vec2(seed, 2.0)) - 0.5) * color_variation;
    float b = base_color.b + (random(vec2(seed, 3.0)) - 0.5) * color_variation;
    
    return vec3(clamp(r, 0.0, 1.0), clamp(g, 0.0, 1.0), clamp(b, 0.0, 1.0));
}

// 绘制单个圆形/水滴
float draw_circle(vec2 uv, vec2 center, float radius, float smoothness) {
    float dist = distance(uv, center);
    return 1.0 - smoothstep(radius - smoothness, radius + smoothness, dist);
}

void fragment() {
    vec2 uv = UV;
    vec3 final_color = vec3(0.0);
    float total_alpha = 0.0;
    
    // 绘制多个静态水滴
    for(int i = 0; i < droplet_count; i++) {
        float seed = float(i) + random_seed;
        
        // 生成水滴的随机位置（静态）
        vec2 droplet_pos = random2(vec2(seed, 0.0));
        
        // 生成随机半径
        float radius = mix(min_radius, max_radius, random(vec2(seed, 4.0)));
        
        // 绘制水滴
        float droplet_mask = draw_circle(uv, droplet_pos, radius, edge_smoothness);
        
        // 生成该水滴的颜色
        vec3 droplet_color = random_color(seed);
        
        // 叠加效果
        final_color += droplet_color * droplet_mask;
        total_alpha += droplet_mask * base_color.a;
    }
    
    // 限制alpha值
    total_alpha = clamp(total_alpha, 0.0, 1.0);
    
    // 输出最终颜色
    COLOR = vec4(final_color, total_alpha);
}
