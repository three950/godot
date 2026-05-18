# 3D 原生多场战斗方案

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
  - 监听 3D 卡牌堆叠或接触变化。
  - 当发现未参战的 `CharacterCard` 与 `EnemyCard` 满足开战条件时，创建一个新的 `BattleScene3D`。
  - 记录当前所有活跃 `BattleScene3D`。
  - 当两场战斗区域接触时，执行合并。
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
  - 关闭拖拽、堆叠、合成检测等普通场景交互。
  - 按阵营加入对应队列。
  - 重新计算本场双方卡牌站位。
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
  - 迁移后重新布局保留方的卡牌站位。
  - 被合并方停止所有 timer、清理临时特效，然后释放场景。
- 合并期间已结算的伤害保留；未完成的子弹飞行、伤害数字、临时 tween 可以直接清理，不做回滚。

**Attack Timing**
- 攻击计时不要只依赖 `Timer.wait_time`，需要记录每个单位的“下一次攻击时间”。
- 每个单位攻击后，根据 speed 计算攻击间隔，并记录下一次攻击的绝对时间。
- 合并时：
  - 收集每个单位当前剩余攻击时间。
  - 迁入保留方后，用剩余时间恢复该单位的下一次攻击。
  - 如果剩余时间已经小于等于 0，则下一帧允许攻击。
- 这样慢速单位不会因为合并重新等待完整攻击间隔，快速单位也不会因为合并额外获得一次立即攻击。

**3D Battle Presentation**
- 战斗卡牌仍然使用现有 `Card3D`，不再创建旧 2D `Character` / `Enemy` 控件进入 `HBoxContainer`。
- 战斗摆放由 `BattleScene3D` 控制：
  - 角色阵营和敌人阵营分别排列在战斗区域两侧。
  - 新加入或合并后统一重新排列。
- 攻击表现改为 3D：
  - 子弹用简单 `Node3D` / `MeshInstance3D` / 粒子节点实现，不再使用旧 `Polygon2D` bullet。
  - 受击反馈作用在 `Card3D` 本体，例如短暂闪白、抖动、抬起。
  - 伤害数字可通过 `SubViewport + MeshInstance3D` 显示在卡面上方。
- HP 更新继续通过资源信号刷新卡面上的 2D SubViewport 内容。

**Important Assumptions**
- `node_3d.tscn` 是这套 3D 战斗系统的目标主场景。
- 一张 `Card3D` 同一时间只能属于一场战斗。
- 战斗区域接触一定合并，不支持两个战斗区域重叠但保持独立。
- 首版合并只处理两个战斗场景；如果多个战斗区域连锁接触，由 `BattleManager` 逐个合并直到没有重叠战斗。
- 旧 2D 战斗流程可以暂时保留，但不会继续承担 3D 场景里的战斗逻辑。
