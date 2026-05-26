# BattleScene3D 战斗配置与技能资源重构说明

## 一、目标

当前战斗行为保持不变：单位仍会按 `ATK / speed / attack_type` 自动攻击，保留攻击队列、远程子弹、近战冲刺、白闪、伤害数字、受击抖动、`unit_died`、`battle_ended` 和全局暂停。

本次结构调整的目标是把职责拆清楚：

- `CombatController` 负责速度调度、攻击队列、统一演出和结算。
- `BattleUnitActionPlanner` 负责单位轮到行动时选择技能、选择目标，并向 controller 请求执行。
- `BattleSkill` 是单位可持有的技能资源，不是“默认普攻接口”。
- 普攻只是技能数组里的默认项，当前先用 `DefaultAttackSkill` 复刻现有普攻逻辑。
- `BiologyCard` 不塞行为树逻辑，只挂战斗配置 `BattleCombatProfile`。

## 二、推荐目录与核心资源

```text
presentation/battle_scene/combat/
  battle_combat_profile.gd      # 每个生物的战斗配置 Resource
  battle_skill.gd               # 技能 Resource 基类
  default_attack_skill.gd       # 当前普攻技能，复刻现有攻击逻辑
  battle_unit_action_planner.gd # 单个 Card3D 轮到行动时的技能与目标决策模块
```

`BiologyCard.gd` 只增加配置入口：

```gdscript
@export var combat_profile: BattleCombatProfile
```

## 三、BattleCombatProfile 定位

`BattleCombatProfile` 表示“这个单位默认如何参与战斗”，不是行为树本体。

```gdscript
class_name BattleCombatProfile
extends Resource

enum Faction { CHARACTER, ENEMY, NEUTRAL }
enum Stance { AGGRESSIVE, PASSIVE, DEFENSIVE, OTHER }

@export var faction: Faction = Faction.ENEMY
@export var stance: Stance = Stance.AGGRESSIVE
@export var skills: Array[BattleSkill] = []
@export var behavior_tree: Resource = null # 先预留，不接入
```

说明：

- `Faction` 用于战斗分边和战斗开启判断。
- 战斗开启核心判断是 `CHARACTER` 与“非 CHARACTER”。
- `ENEMY` 的触发逻辑保持现有行为。
- `NEUTRAL` 只在角色主动堆叠到中立生物时触发战斗，普通碰撞不触发。
- `NEUTRAL` 进入战斗后不创建主动攻击运行时，不会主动攻击。
- `Stance` 不参与战斗结算，只用于战斗前的自主行为。
- `Stance` 只对非 character 单位有意义：
  - `AGGRESSIVE`：主动接近 character。
  - `PASSIVE`：不会主动寻找目标。
  - `DEFENSIVE`：在对应区域范围内，对非同类表现为 aggressive，否则表现为 passive。
  - `OTHER`：保留给特殊自主逻辑。
- `skills` 表示单位持有的技能资源列表。
- `default_skill` 是当前默认使用的技能，通常指向普攻；后续可改成技能优先级、条件技能或行为树选择。

## 四、BattleSkill 定位

`BattleSkill` 是“可被单位持有和执行的技能资源”。普攻、装备赋予的特殊攻击、治疗、毒刺、远程射击、召唤、格挡、抹杀等都应是技能资源或由技能资源组合出来。

```gdscript
class_name BattleSkill
extends Resource

func get_cooldown(user: Card3D, context) -> float:
	return 1.0

func can_use(user: Card3D, context) -> bool:
	return true

func choose_target(user: Card3D, context) -> Card3D:
	return null

func execute(user: Card3D, target: Card3D, context) -> void:
	pass
```

当前阶段只实现 `DefaultAttackSkill`：

- `get_cooldown()` 复刻现有 `BASE_ATTACK_INTERVAL - speed / 50.0`，并保留最小间隔。
- `choose_target()` 迁移现有 `_get_attack_target()` 逻辑，按角色/非角色的biology阵营选择第一个存活目标。
- `execute()` 不直接播放动画和扣血，而是调用 controller 的公共执行方法，例如 `request_attack(user, skill, target)` 或 `perform_basic_attack(attacker, target, damage, attack_type)`。
- 每次攻击前仍重新读取 `attack_type`，保证角色换武器后下一次攻击立刻生效。
- 装备对 character 的影响分三类：
  - 攻击形式：贴图、特效、攻击类型，每次 controller 执行攻击时读取。
  - 数值：装备/卸下时更新角色属性。
  - 特殊效果：buff、debuff、特殊攻击、格挡、召唤等，装备/卸下时更新可用技能或技能效果。
- buff/debuff 后续建议单独做 Resource，并由全局计时系统管理，不局限于战斗。

## 五、CombatController 与 BattleUnitActionPlanner 分工

`BattleScene3DCombatController` 保留为战斗上下文和执行器，但不再把目标选择和技能选择写死在自己内部。

Controller 负责：

- 持有 characters / non_characters 的只读视图。
- 根据单位速度和当前技能冷却计算谁该行动。
- 维护攻击队列，串行执行攻击表现和结算。
- 在入队前、出队执行前、动画结算前都检查攻击者和目标是否仍然存活有效。
- 新增 `request_attack(user, skill, target)`，由 `BattleUnitActionPlanner` 请求 controller 串行执行。
- 保留子弹、近战冲刺、白闪、伤害数字、受击抖动。
- 保留 `unit_died(unit)` 和 `battle_ended()`。
- 保留全局暂停处理，所有攻击冷却 Timer、等待 Timer、Tween 都必须响应 `Events.timers_pause_changed(is_paused)`。
- 合并或结束时停止攻击队列、Timer、Tween，并清理 Effects 下的战斗表现节点。
- 战斗结束判断改成“角色 / 非角色的biology”任一方存活数为 0。

`BattleUnitActionPlanner` 负责：

- 绑定单个进入战斗的 `Card3D`。
- 读取该单位的 `combat_profile`。
- 当前先使用 `default_skill`；后续可按 `skills` 优先级、条件或行为树选择技能。
- 当 controller 通知该单位行动时：
  - 检查单位是否有效、是否存活、是否 neutral。
  - 选择可用技能。
  - 调用技能 `choose_target()`。
  - 找到目标后调用 controller 的 `request_attack(user, skill, target)`。
- `BattleUnitActionPlanner` 不独立决定全局出手顺序，不让动画请求脱离 controller 队列，避免单位已死亡但旧动画仍排队播放。

## 六、战斗开启与分边规则

`BattleManager._are_opponents()` 从 `CharacterCard vs EnemyCard` 改为基于 `combat_profile.faction` 判断。

规则：

- 一方是 `Faction.CHARACTER`，另一方是非 `Faction.CHARACTER`，才可能触发战斗。
- `ENEMY` 与 character 的触发行为保持现有逻辑。
- `NEUTRAL` 与 character 只有在 character 主动堆叠到 neutral 时触发战斗，普通碰撞不触发。
- 非 character 之间不触发战斗。
- character 之间不触发战斗。
- 进入战斗后，`Faction.CHARACTER` 放入角色侧，`Faction.ENEMY` 和 `Faction.NEUTRAL` 放入非角色的biology侧。
- neutral 不主动创建 `BattleUnitActionPlanner`，因此不会攻击，但可以被攻击、死亡、计入非角色的biology侧存活数。

卡牌相关逻辑需要继续考虑堆叠：

- 判断战斗接触、拆出战斗卡、推出非战斗卡时，不能只看堆顶。
- 涉及 `children_card` 的堆叠链时，要确保子卡里的 biology 卡不会被跳过。

## 七、关键修改顺序

1. 新增 `BattleCombatProfile`、`BattleSkill`、`DefaultAttackSkill`、`BattleUnitActionPlanner`。
2. `BiologyCard` 增加 `combat_profile`；为空时运行时生成默认 profile。
3. `BattleScene3D` 的 `characters / enemies` 概念调整为“角色侧 / 非角色的biology侧”，命名可后续统一，但结束判断必须按 faction。
4. `BattleScene3DCombatController` 不再直接写死目标选择；它负责速度调度，并为可行动单位创建/调用 `BattleUnitActionPlanner`。
5. `_get_attack_target()` 迁移到 `DefaultAttackSkill.choose_target()`。
6. `_perform_attack()` 拆成 controller 的公共执行方法，供技能调用；当前普攻仍复刻现有 `ATK / attack_type` 行为。
7. 新增 `request_attack(user, skill, target)`，所有技能攻击都通过 controller 队列串行执行。
8. `BattleManager._are_opponents()` 改为基于 `combat_profile.faction`。
9. 战斗结束判断改为“角色侧 / 非角色的biology侧某边清零”。

## 八、最终结构效果

当前默认所有可战斗单位仍会自动战斗，表现和数值逻辑不变。

后续扩展时：

- 行为树可挂到 `BattleCombatProfile.behavior_tree`。
- 技能可做成 `.tres`，例如 `毒刺普攻.tres`、`远程射击.tres`、`治疗.tres`。
- 装备可以更新角色数值、攻击形式和技能列表。
- Controller 只负责统一调度、演出、结算和死亡/结束信号，不关心具体 AI。
- UnitRuntime 只负责“轮到这个单位时，它准备用什么技能、打谁”。
- BattleSkill 只表达技能行为，不负责全局战斗生命周期。
