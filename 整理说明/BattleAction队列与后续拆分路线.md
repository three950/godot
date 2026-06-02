# BattleAction 队列与后续拆分路线

## 目标

战斗系统当前最需要解决的不是把普攻拆得很细，而是保证所有会播放动画、扣血、触发效果的战斗行为都经过同一条顺序队列。

核心原则：

```text
单位计时 / 玩家操作 / 反击 / 装备触发 / 被动触发
        -> 生成战斗请求
        -> 进入同一个 ActionQueue
        -> controller 逐个执行
```

这样可以避免反击、装备效果、被动技能直接播放动画，和当前正在执行的攻击动画或伤害结算重叠。

## 当前阶段建议的 helper 职责

### BattleScene3DCombatController

Controller 是战斗上下文和总调度者。

建议保留的职责：

- 维护战斗是否进行中。
- 管理参战双方的单位列表视图。
- 负责单位冷却 Timer 到点后的行动入队。
- 启动和停止 ActionQueue。
- 统一检查单位是否仍然有效、是否仍然存活。
- 在每个 action 执行后检查战斗是否结束。
- 统一发出 `unit_died`、`battle_ended` 等战斗生命周期信号。

不建议继续增加的职责：

- 不要把每种技能效果都写进 controller。
- 不要让 controller 同时塞满装备、状态、被动、特殊规则。
- 不要让 controller 以外的系统直接播放战斗动画或直接结算战斗伤害。

### BattleUnitActionPlanner

Planner 只负责“这个单位轮到行动时准备做什么”。

建议职责：

- 根据单位配置选择技能。
- 根据技能规则选择目标。
- 返回或提供这次行动所需的技能和目标。

不建议职责：

- 不负责全局行动顺序。
- 不负责播放动画。
- 不负责扣血。
- 不负责战斗结束判断。

如果后续逻辑变复杂，可以让 planner 返回一个轻量行动意图：

```text
BattleActionIntent
  user
  skill
  target
```

当前没必要马上加这个类，只要职责上按这个方向收敛即可。

### BattleSkill

Skill 表示“这个技能要做什么”。

当前阶段可以继续让技能调用 controller 提供的窄接口，例如：

```gdscript
await context.perform_basic_attack(user, target)
```

但要注意边界：

- 技能不应该自己直接播放全局战斗动画。
- 技能不应该绕过 controller 直接修改战斗单位状态。
- 技能触发其他攻击时，应该调用 `request_attack()`，让请求进入队列。

长期更理想的方向是：技能不直接执行表现和结算，只负责向队列追加 action。

### ActionQueue

ActionQueue 的职责很简单：

- 保存待执行 action。
- 每次只执行一个 action。
- 当前 action 完成后再执行下一个。
- 战斗停止时清空队列。

当前可以先由 `BattleScene3DCombatController` 内部维护队列，不必马上拆出单独脚本。

当队列逻辑开始变多时，再抽成独立 helper：

```text
CombatActionQueue
  add(action)
  clear()
  is_running()
  drain(context)
```

## 当前阶段推荐的 action 粒度

现在不建议把普攻拆成三四个 action。

推荐先保持粗粒度：

```text
BasicAttackAction
  校验攻击者和目标
  播放近战/远程攻击动画
  扣血
  显示白闪、伤害数字、受击抖动
  上报死亡
```

反击也只需要追加一个同类 action：

```text
queue.add(BasicAttackAction(counter_user, original_attacker))
```

这样已经能解决“反击直接播放动画导致插队”的问题。

## 为什么不要现在拆成 AttackAnimationAction / DamageAction

普攻现在拆成下面这样会显得过度设计：

```text
UseSkillAction
AttackAnimationAction
DamageAction
HitReactionAction
DeathAction
```

这些拆分不是错，但它们适合在系统已经需要复用或插入细节时再做。

当前阶段过早拆分会带来问题：

- 文件和类数量增加。
- 普攻阅读成本变高。
- controller、skill、action 之间跳转变多。
- 还没有足够多的技能类型证明这些拆分必要。

## 后期需要细化时的修改路线

### 第一阶段：统一入队

目标：

- 自动攻击、反击、装备触发、被动攻击全部进入同一个队列。
- `request_attack()` 只负责登记请求，不直接播放动画。
- 自动攻击 Timer 到点后也只是生成队列 action。

建议 action：

```text
TurnAction 或 BasicAttackAction
QueuedSkillAction
```

这一阶段不需要独立伤害事件。

### 第二阶段：抽独立 ActionQueue

触发条件：

- 队列状态越来越多。
- controller 里出现大量队列清理、暂停、插队、延迟执行逻辑。
- 多种系统都需要向队列追加 action。

修改方向：

```text
BattleScene3DCombatController
  持有 CombatActionQueue

CombatActionQueue
  只负责顺序执行
```

Controller 仍然负责战斗生命周期和胜负判断。

### 第三阶段：抽 DamageContext / HitContext

触发条件：

- 出现护盾、减伤、暴击、吸血。
- 出现受击后反击。
- 出现伤害类型，例如物理、魔法、真实伤害。
- 出现死亡替代、濒死触发、格挡。

建议数据：

```text
DamageContext
  source
  target
  base_damage
  actual_damage
  damage_type
  tags
```

这个阶段可以把 `take_damage()` 包成统一伤害结算 helper，但仍然不一定要把表现拆得很细。

### 第四阶段：拆 DamageAction

触发条件：

- 很多技能只造成伤害，不需要普通攻击动画。
- 毒、流血、陷阱、反伤都要复用同一套伤害结算。
- 受击触发需要稳定发生在扣血之后、死亡判断之前或之后。

修改方向：

```text
DamageAction
  计算最终伤害
  扣血
  显示伤害数字
  触发 on_damaged
  判断死亡
```

此时反击可以由 `on_damaged` 监听器追加：

```text
queue.add(BasicAttackAction(counter_user, damage_source))
```

### 第五阶段：拆表现 action

触发条件：

- 不同技能动画越来越多。
- 需要复用飞弹、冲刺、范围特效、持续特效。
- 需要动画和结算之间更精确的时机控制。

修改方向：

```text
AttackAnimationAction
ProjectileAction
HitReactionAction
WaitAction
```

这一步是表现层复杂之后才需要，不是普攻一开始就要做。

## 最小可行结构

短期最推荐的结构是：

```text
BattleScene3DCombatController
  管战斗生命周期
  管队列 drain
  管单位 Timer

BattleUnitActionPlanner
  选技能
  选目标

BattleSkill
  调用 controller 的窄接口

队列 action
  turn
  skill request
```

这个结构能先解决当前问题，同时保留后续拆 `ActionQueue`、`DamageContext`、`DamageAction` 的空间。

## 当前代码维护规则

- 新增反击、装备攻击、被动攻击时，不要直接调用 `skill.execute()`。
- 新增战斗动画时，不要绕过 controller 队列直接播放。
- 新增伤害效果时，先复用现有攻击结算；当伤害类型明显变多，再抽 `DamageContext`。
- 新增 helper 前先确认它是否真的减少复杂度，而不是只把一次普攻拆成更多跳转。
