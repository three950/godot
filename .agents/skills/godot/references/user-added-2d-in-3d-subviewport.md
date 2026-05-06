# [USER-ADDED] 在 3D 场景中呈现 2D tscn（带碰撞）

> 注：本条为用户新增（2026-05-06）。

## 目标
在 `Node3D` 场景里，把一个 2D `.tscn` 渲染到 3D 世界中，同时保留 3D 物理碰撞能力。

## 推荐节点结构
```text
Node3D (容器)
├─ SubViewport
│  └─ 你的2D场景实例（.tscn）
└─ StaticBody3D (用于3D碰撞)
   ├─ CollisionShape3D
   └─ Sprite3D (显示 SubViewport 的画面)
```

## 操作步骤
1. 在 `Node3D` 下创建 `SubViewport`。
2. 将要显示的 2D `.tscn` 作为 `SubViewport` 子节点（实例）挂载。
3. 在同级或合适位置创建 `StaticBody3D`（承载 3D 碰撞）。
4. 在 `StaticBody3D` 下创建 `Sprite3D`，将其 `texture` 指向上面的 `SubViewport` 输出。
5. 给 `StaticBody3D` 配置 `CollisionShape3D` 以满足 3D 物理需求。

## 关键注意点（非常重要）
`Sprite3D` 继承自 `GeometryInstance3D`，需要把默认的 `Material Override` 清空（设为 `null` / 空），否则可能导致视口纹理显示异常或被覆盖。

## 排查顺序
若画面不对，优先检查：
1. `Sprite3D.texture` 是否正确引用 `SubViewport`
2. `Sprite3D` 的 `Material Override` 是否已清空
3. `Sprite3D` 的朝向、缩放、`pixel_size` 是否与场景比例匹配
4. `SubViewport` 尺寸与更新策略是否合理

## 补充说明
2D 场景中的 2D 碰撞不会直接变成 3D 碰撞。通常做法是：
- 渲染层面使用 `SubViewport + Sprite3D`
- 物理层面使用 `StaticBody3D + CollisionShape3D`
