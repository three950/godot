# 3D 原生多场战斗方案
把 `res://script_folder/battle_manager.gd` 挂入 `res://node_3d.tscn`，由它创建 `res://presentation/battle_scene_3d.tscn` 建立 3D 原生战斗。旧 `res://presentation/battle_scene.tscn` 只作为 2D 表现参考，不再接入 3D 战斗。
**Summary**
- 将旧的单例式 `BattleManager` 重构为“战斗调度器”，它不再直接保存一场战斗的单位、容器和计时器，而是负责创建、登记、合并、移除多个 `BattleScene3D`。
- 新增 `battle_scene_3d.tscn`，每个实例代表一场独立战斗，自己维护参战卡牌、战斗区域、攻击计时、卡牌摆放和结束清理。
- `BattleScene3D` 的检测区域大于卡面摆放区域；只要未参战卡牌接触到该区域，就加入这场战斗。
- 多个 `BattleScene3D` 的区域接触时触发合并。合并采用“保留移动”：保留人数更多的战斗场景，把人数更少的战斗场景中的卡牌迁移进去；人数相同则保留先创建的场景。
- 合并时保留每个单位的下一次攻击时间，避免重置攻击进度。

**Core Structure**
- `node_3d.tscn` 挂载一个 `BattleManager` 节点，脚本仍可使用 `res://script_folder/battle_manager.gd`，但内部逻辑改为 3D 多战斗调度。
- 新增 `res://presentation/battle_scene_3d.tscn`：
  - 根节点为 `Node3D`，脚本为新的 `BattleScene3D`。
  - 包含一个 `BattleArea: Area3D`，负责检测进入战斗范围的 `Card3D` 和其他 `BattleScene3D`。
  - 包含双方卡牌摆放节点，例如 `CharacterSlots` 和 `EnemySlots`。
  - 包含攻击特效挂点，用于 3D 子弹、受击抖动、伤害数字等表现。
- 旧 `presentation/battle_scene.tscn` 保留为 2D 版本参考，不再作为 `node_3d.tscn` 的主战斗场景。

**BattleManager 重构**
- `BattleManager` 只做全局协调：
  - 监听 enemy发出的卡牌接触信号。
  - 创建一个新的 `BattleScene3D`。
  - 记录当前所有活跃 `BattleScene3D`。
  - 监听战斗区域接触信号，当两场战斗区域接触时，执行合并。
  - 当某场战斗结束时，从活跃列表移除。
- 不再使用旧的 `active_battle_scene`、`enemy_container`、`character_container` 单实例字段。
- 不再依赖 `Character` / `Enemy` 这两个 2D Control 类型，而是直接操作 `Card3D`。
- 阵营判断基于 `Card3D.card_info`：
  - `CharacterCard` 进入角色阵营。
  - `EnemyCard` 进入敌人阵营。
- 战斗数值继续复用 `BattleStates`，包括 HP、ATK、DEF、speed。

**BattleScene3D 行为**
- 每个 `BattleScene3D` 独立管理本场战斗：
  - 保存角色卡数组、敌人卡数组。
  - 保存每张卡的攻击计时状态。
  - 控制本场卡牌的锁定、摆放、攻击、受击和结束。
- 卡牌加入战斗时：
  - 设置该 `Card3D` 的当前所属战斗。
  - 关闭拖拽、堆叠等普通场景交互。
  - 按阵营加入对应队列。
  - 按照卡片位置排列双方卡牌站位。
  - 如果战斗已开始，为新单位接入攻击计时。
- 卡牌接触 `BattleArea` 时：
  - 未参战且是 `CharacterCard` / `EnemyCard`，加入该 `BattleScene3D`。
  - 已属于本场战斗，忽略。
  - 已属于其他战斗，不直接抢卡，交给两个 `BattleScene3D` 的区域接触合并流程处理。

**Battle Merge**
- 两个 `BattleScene3D` 的 `BattleArea` 接触后，触发战斗合并。
- 合并保留规则：
  - 保留参战单位总数更多的 `BattleScene3D`。
  - 如果人数相同，保留创建时间更早的 `BattleScene3D`。
  - 另一个场景作为被合并方。
- 合并迁移规则：
  - 被合并方的所有存活卡牌迁移到保留方。
  - 根据两个战斗场景的相对位置决定插入方向：
    - 被合并方在保留方左侧，则迁入卡牌插入保留方对应阵营队列左侧。
    - 被合并方在保留方右侧，则迁入卡牌插入保留方对应阵营队列右侧。
  - 迁移后不重新布局卡牌站位。
  - 被合并方的迁移需等待当前场景中所有动画播放完毕
  - 被合并方停止所有 timer、然后释放场景。

**Attack Timing**
- 攻击计时依赖 `Timer.wait_time`
- 每个单位攻击后，根据 speed 计算攻击间隔，并记录下一次攻击的绝对时间。
- 合并时：，合并时需要短暂暂停，合并后正常继续。
- 这样慢速单位不会因为合并重新等待完整攻击间隔，快速单位也不会因为合并额外获得一次立即攻击。

**3D Battle Presentation**
- 战斗卡牌仍然使用现有 `Card3D`，不再创建旧 2D `Character` / `Enemy` 控件进入 `HBoxContainer`。
- `BattleScene3D` 本身需要像 `Card3D` 一样在 `.tscn` 中有可见 3D 表现，而不是纯逻辑节点：
  - 半透明灰色底面参考旧 `BattleScene` 的 `StyleBoxFlat.bg_color`。
  - 红色半透明边框参考旧 `BattleScene` 的 `StyleBoxFlat.border_color`。
  - 可视底面和边框尺寸跟随参战卡牌数量动态变化。
  - `BattleArea` 尺寸跟随可视区域变化，并额外保留一圈检测 padding。
- 战斗摆放由 `BattleScene3D` 控制：
  - 角色阵营和敌人阵营分别排列在战斗区域两侧。
  - 新加入或合并后统一重新排列。
- 攻击表现改为 3D：
  - 子弹用简单 `Node3D` / `MeshInstance3D` / 粒子节点实现，不再使用旧 `Polygon2D` bullet。
  - 受击反馈作用在 `Card3D` 本体，例如短暂闪白、抖动、抬起。
  - 伤害数字可通过 `SubViewport + MeshInstance3D` 显示在卡面上方。
- HP 更新继续通过资源信号刷新卡面上的 2D SubViewport 内容。

**代码搜索补充信息**
- `Card3D` 的根脚本在 `res://card_3d_scripts/card_3d.gd`，场景是 `res://card_3d.tscn`。
- `Card3D` 已经加入 `Cards3D` group，`BattleManager` 可以在 `_ready()` 中扫描 `get_tree().get_nodes_in_group("Cards3D")`，也可以监听 `SceneTree.node_added` 来连接后续生成的卡牌。
- `Card3D` 没有专门的“战斗开始碰撞信号”。可复用现有堆叠检测信号：
  - `card_label_entered_stack_area(entering_card: Card3D)`
  - 信号由 `CardStackDetectorArea` 检测进入的 `CardLabel` 后发出。
  - 该信号参数是进入检测区的卡，接收端需要通过 `bind(card)` 得到被进入的目标卡。
- 现有 3D 卡牌碰撞层：
  - `CardLabel` 使用 `collision_layer = 2`。
  - `CardStackDetectorArea` 使用 `collision_mask = 2`。
  - `CardPushDetectorArea` 使用 `collision_layer = 16`、`collision_mask = 16`，这是卡牌推挤系统，不应被战斗检测复用。
- `BattleScene3D.BattleArea` 需要能检测卡牌的 `CardLabel` 和其他战斗区域：
  - 建议 `collision_layer = 32`。
  - 建议 `collision_mask = 34`，即检测 layer 2 的卡牌标签和 layer 32 的其他战斗区域。
- 阵营和战斗数值来自 `Card3D.card_info`：
  - `CharacterCard` 定义在 `res://assets/人物与敌人/Character/CharacterCard.gd`。
  - `EnemyCard` 定义在 `res://assets/人物与敌人/Enemy/EnemyCard.gd`。
  - 二者都继承 `BattleStates`，`BattleStates` 定义在 `res://assets/人物与敌人/battle/res_battle_states.gd`。
  - `BattleStates` 内含 `HP`、`MAX_HP`、`ATK`、`DEF`、`speed` 和 `take_damage()`。
- `Card3D` 还有 `battle: BattleState` 字段，`BattleState.Phase` 定义在 `res://base_data/battle_stats.gd`，可在进入/退出战斗时标记 `BATTLE` / `COMMON`。
- 进入战斗时需要锁定普通交互：
  - 保存并关闭 `Card3D.can_stack`。
  - 保存并关闭 `Card3D.ray_interaction_enabled`。
  - 保存并关闭 `Card3D.stack_detector.monitoring/monitorable`。
  - 调用 `detach_from_follow_target()`、`reset_offset()`，避免带着堆叠偏移进入战斗。
- 退出战斗时需要恢复上述交互状态，并把存活卡牌 reparent 回 `BattleScene3D` 的父节点，保持全局位置。
- `Card3D.face_size` 默认是 `Vector2(2.64, 3.45)`，`BattleScene3D` 动态宽高可以用它作为卡面尺寸依据。
- 当前 3D 主场景 `res://node_3d.tscn` 已经有若干 `Card3D` 实例和 `CraftManager`，战斗管理节点应挂在根 `Node3D` 下，和 `CraftManager` 平级。
- 旧 `res://main.tscn` 仍引用 `res://script_folder/battle_manager.gd`，但本方案不再兼容 2D 战斗；如继续打开旧 2D 主场景，需要移除或替换那个节点。
- 本地 Codex 环境可能无法可靠启动 Godot 项目加载校验；最终加载/运行应由开发者在 Godot 中实际执行。

**Important Assumptions**
- `node_3d.tscn` 是这套 3D 战斗系统的目标主场景。
- 一张 `Card3D` 同一时间只能属于一场战斗。
- 战斗区域接触一定合并，不支持两个战斗区域重叠但保持独立。
- 旧 2D 战斗流程不再使用；`BattleManager` 可以直接重构为纯 3D 调度器。
