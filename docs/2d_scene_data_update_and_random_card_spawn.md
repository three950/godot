# 2D 场景数据更新与随机卡牌生成调研

## 范围

本文调研 `main.tscn`、`base_data/` 以及 2D 卡牌场景相关脚本，说明当前项目里 2D 场景如何绑定数据、如何刷新显示、以及深度场景卡和小场景卡如何随机生成新卡牌。

注意：项目里部分中文资源路径在终端输出中存在编码显示异常，本文优先使用稳定的脚本路径、资源类名和函数名描述调用链，不依赖具体中文资源名。

## 主场景装配

`main.tscn` 是当前 2D 玩法的主场景，根节点是 `Node2D`。关键节点如下：

| 节点 | 来源/脚本 | 作用 |
| --- | --- | --- |
| `UI_Layer` | `presentation/ui_layer.tscn` + `presentation/ui_stats_manager.gd` | 读取 `base_data/game_stats.tres`，显示食物、金币、层数、天数进度，并播放 BGM |
| `BagMover` | `script_folder/bag_mover.gd` | 通过全局 `Events` 监听拖拽开始/放下，处理卡牌放入背包槽位 |
| `CraftManager` | `script_folder/card_craft_manager.gd` | 监听堆叠变化，按配方识别合成并生成合成结果卡 |
| `BattleManager` | `script_folder/battle_manager.gd` | 监听战斗开始请求，准备战斗场景 |
| 人物/敌人/物品/装备/资源卡 | 各自的 `.tscn` + `.tres` | 初始放在场景里的 2D 卡牌实例 |
| `1000m`、`500m` | `assets/AbyssLayer/Scene.tscn` + `assets/AbyssLayer/Scene.gd` | 深度场景卡；`main.tscn` 给它们设置 `scene` 和全局 `cardpool` |
| 小场景节点 | `assets/小场景/Small_Scene.tscn` + `assets/小场景/Small_Scene.gd` | 小场景卡；`main.tscn` 只设置 `scene`，生成池从 `scene.card_pool` 读取 |

深度场景卡和小场景卡的差异很关键：

| 类型 | 生成池来源 | 生成逻辑 |
| --- | --- | --- |
| 深度场景卡 `Scene` | `main.tscn` 节点上导出的 `cardpool: CardPool` | 先按权重随机类型，再从全局池里按类型随机一张 |
| 小场景卡 `Small_Scene` | `scene: SceneCardPool` 资源里的 `card_pool` | 直接 `scene.card_pool.pick_random()` |

## `base_data/` 数据职责

`base_data/` 当前主要包含三类基础数据：

| 文件 | 类名 | 职责 |
| --- | --- | --- |
| `base_data/CardInfo.gd` | `CardInfo` | 所有卡牌数据的基础资源，包含 `name`、`portrait`、`text`、是否可堆叠、`type` 枚举 |
| `base_data/card_pool/CardPool.gd` | `CardPool` | 全局卡池资源，保存 `Array[CardInfo]`，提供随机类型和按类型抽卡 |
| `base_data/card_pool/card_pool.tres` | `CardPool` 资源 | 实际卡池数据，引用大量物品、资源、装备、小场景、敌人等 `.tres` |
| `base_data/game_stats.gd` / `.tres` | `GameStats` | 全局游戏状态：时间、天数、金币、食物需求/拥有量、当前层、最大层 |
| `base_data/battle_stats.gd` / `.tres` | `BattleState` | 当前是否处于普通/战斗阶段的状态资源 |

`CardInfo.type` 是随机生成的核心筛选字段。`CardPool.get_cards_by_type(type)` 会从 `card_pool` 里过滤出匹配 `type` 的卡，再 `pick_random()` 返回其中一张。

## 卡牌资源到场景实例的通用模式

项目里大多数卡牌数据资源都继承自 `CardInfo`，并额外导出 `card_scene: PackedScene`：

| 数据类 | 继承 | 典型场景 |
| --- | --- | --- |
| `CharacterCard` | `BattleStates -> CardInfo` | `assets/人物与敌人/Character/character.tscn` |
| `EnemyCard` | `BattleStates -> CardInfo` | `assets/人物与敌人/Enemy/enemy.tscn` |
| `ItemCard` | `ThingsCard -> CardInfo` | `assets/物品/道具/item.tscn` |
| `ResourceCard` | `ThingsCard -> CardInfo` | `assets/物品/资源/recource.tscn` |
| `EquipmentCard` | `ThingsCard -> CardInfo` | `assets/物品/装备/Equitment.tscn` |
| `RemainsCard` | `ThingsCard -> CardInfo` | `assets/物品/遗物/remains.tscn` |
| `SceneCard` | `CardInfo` | `assets/AbyssLayer/Scene.tscn` |
| `SceneCardPool` | `SceneCard` | `assets/小场景/Small_Scene.tscn` |

生成卡牌时不会用 `match type` 手动选择场景，而是统一走：

```gdscript
var instance = spawn_card_info.card_scene.instantiate()
instance.set_stats(spawn_card_info)
```

所以新增可生成卡牌时，关键条件是：

1. 数据资源必须继承 `CardInfo` 或其子类。
2. 数据资源的 `type` 要正确。
3. 数据资源要设置可实例化的 `card_scene`。
4. 实例化出的场景脚本要实现 `set_stats(...)`，用于接收对应资源并刷新显示。

## 数据更新机制

### 1. 卡牌显示刷新

基础卡牌脚本是 `assets/card.gd`，它提供通用显示更新：

```gdscript
func _update_card_display() -> void:
	var resource = get_card_resource()
	if resource == null:
		return
	name = resource.name
	cardname = resource.name
	if card_label:
		card_label.text = resource.name
	if card_texture:
		card_texture.texture = resource.portrait
```

子类通过重写 `get_card_resource()` 告诉父类当前卡牌使用哪个数据资源：

| 脚本 | 数据入口 | 刷新内容 |
| --- | --- | --- |
| `assets/物品/things.gd` | `get_things_resource()` | 调用 `_update_card_display()`，再刷新价值 `value` |
| `assets/物品/道具/item.gd` | `item: ItemCard` | `set_stats()` 后刷新物品显示 |
| `assets/物品/资源/recource.gd` | `recource: ResourceCard` | 刷新资源显示和营养值 |
| `assets/人物与敌人/battle_card.gd` | `get_battle_resource()` | 刷新名称、图像、HP/ATK/DEF |
| `assets/AbyssLayer/Scene.gd` | `scene: SceneCard` | 刷新场景卡名称和图像 |

典型流程：

```text
外部设置 card_resource
-> set_stats(resource)
-> 保存到导出变量
-> 如果节点 ready，则调用具体 _update_xxx_display()
-> 具体脚本调用 Card._update_card_display()
-> 更新 name/cardname/Label/TextureRect
```

### 2. 游戏状态 UI 刷新

`GameStats` 是一个 `Resource`，属性 setter 里调用 `emit_changed()`：

```gdscript
func set_coins(value: int) -> void:
	coins = value
	emit_changed()
```

`presentation/ui_stats_manager.gd` 在 `_ready()` 中连接：

```gdscript
game_stats.changed.connect(_update_stats)
Events.food_need_update.connect(_on_food_need_update)
Events.food_have_update.connect(_on_food_have_update)
```

因此 UI 更新链路是：

```text
角色/资源/系统发出 Events.food_need_update 或 Events.food_have_update
-> UIStatsManager 修改 game_stats.food_need / food_have
-> GameStats setter 调用 emit_changed()
-> UIStatsManager._update_stats()
-> 刷新食物、金币、层数、天数 Label
```

时间推进也在 `ui_stats_manager.gd` 的 `_process(delta)` 中完成：

```text
elapsed_time += delta
progress_bar.value = elapsed_time
elapsed_time >= game_stats.time * 60
-> elapsed_time = 0
-> game_stats.days += 1
-> GameStats.changed
-> UI 刷新天数
```

### 3. 战斗属性刷新

战斗数据基类是 `assets/人物与敌人/battle/res_battle_states.gd` 的 `BattleStates`，它继承 `CardInfo`，并定义 `stats_changed` 信号。`HP`、`MAX_HP`、`ATK`、`DEF`、`speed` 的 setter 会发出 `stats_changed`。

`BattleCard` / `Enemy` / `Character` 会连接这个信号到 `update_stats()`，刷新属性标签。也就是说战斗属性不是走 `Resource.changed`，而是走自定义 `stats_changed`。

## 堆叠触发机制

所有普通 2D 卡牌都基于 `assets/card.gd`，核心堆叠字段和信号是：

| 字段/信号 | 作用 |
| --- | --- |
| `overlapping_cards` | 当前拖拽/下落卡牌检测到可堆叠的目标卡 |
| `follow_target` | 当前卡牌堆在谁上面 |
| `children_card` | 当前卡牌上面堆了谁 |
| `stack_state` | 当前堆叠状态标记 |
| `stacking_on_you(children)` | 有卡堆到自己身上 |
| `stop_stacking_on_you()` | 上方卡离开 |
| `array_changed()` | 当前堆叠结构变化 |
| `Events.stack_changed(card)` | 全局堆叠变化，合成系统监听它 |

拖拽结束后，`assets/card-states/card_falling.gd` 会从 `overlapping_cards` 里找最近的可堆叠目标，然后调用 `stack_on_card(target_card)`：

```text
拖拽卡牌释放
-> CardFalling.enter()
-> find_closest_card()
-> stack_on_card(target_card)
-> 当前卡 follow_target = target_card
-> target_card.stacking_on_you.emit(card)
-> target_card.bestacked_on_me(card)
```

`Card.bestacked_on_me()` 会：

1. 设置 `children_card`。
2. 禁用当前底卡的堆叠检测区域。
3. 发出 `array_changed()`。
4. 发出全局 `Events.stack_changed(self)`。

深度场景卡 `Scene` 重写了 `bestacked_on_me()`，在父类逻辑之后启动或更新生成计时。

## 深度场景随机卡牌生成

深度场景卡脚本是 `assets/AbyssLayer/Scene.gd`。

### 触发条件

当角色卡堆叠到深度场景卡上时触发。代码意图是在 `_on_stack_detector_area_entered()` 中只允许 `CardInfo.CardType.人物` 类型进入深度场景卡的堆叠候选列表。

触发后：

```text
人物卡堆到 Scene 上
-> Scene.bestacked_on_me(children)
-> _update_signal_connections()
-> _start_timing()
```

### 计时速度

`Scene._calculate_average_speed()` 会收集堆叠链上的所有人物卡，读取它们资源里的 `speed`，计算平均速度：

```text
average_speed = 所有人物 speed 总和 / 有效人物数
duration = 100.0 / average_speed
```

如果没有有效速度，则返回 `1.0`，生成耗时就是 `100` 秒。

### 进度条

`Scene._start_timing()` 会连接 `CardProgressBar.progress_completed`，并调用：

```gdscript
card_progress_bar.start(duration)
```

`presentation/card_progress_bar.gd` 每帧累加 `_elapsed_time`，达到 `_total_time` 时：

```gdscript
_stop()
progress_completed.emit()
```

这会回调到 `Scene._on_spawn_timer_completed()`。

### 抽卡逻辑

深度场景卡完成计时后：

```gdscript
var type = cardpool.get_random_type_in_abyss()
spawn_card_info = cardpool.get_cards_by_type(type)
_spawn_card()
```

`CardPool.get_random_type_in_abyss()` 使用权重数组随机类型：

| 类型含义 | 当前权重 |
| --- | --- |
| 敌人 | `1` |
| 小场景 | `3` |
| 道具 | `2` |
| 武器/装备 | `2` |
| 资源 | `2` |
| 深度 | `1` |
| 事件 | `0` |

之后 `CardPool.get_cards_by_type(type)` 从 `card_pool` 中筛选同类型卡牌，再 `pick_random()`。

### 实例化和发射动画

`Scene._spawn_card()` 会：

1. 调用 `_create_card_instance()` 实例化 `spawn_card_info.card_scene`。
2. `instance.set_stats(spawn_card_info)` 注入数据并刷新显示。
3. 找到第一个 `Cards` 分组节点。
4. 把实例加进去。
5. 先把卡放在场景卡当前位置。
6. 调用 `card_instance.shooter.play_card_shooter(spawn_position)`，把它发射到 `global_position + spawn_offset`。

默认 `spawn_offset` 是 `Vector2(0, 360)`，即在当前场景卡下方生成。

生成完成后，如果仍然有角色卡堆在场景卡上，就重新 `_start_timing()`，继续生成下一张；否则 `_cancel_timing()`。

## 小场景随机卡牌生成

小场景脚本 `assets/小场景/Small_Scene.gd` 继承 `Scene`，复用堆叠、进度条、实例化和发射逻辑，但重写了两个点。

### 速度计算不同

小场景不使用人物资源里的 `speed` 平均值，而是：

```text
每张人物卡基础速度 = 20
总速度 = 所有人物卡的基础速度 * 场景速度倍率后累加
duration = 100.0 / 总速度
```

如果 `scene is SceneCardPool`，会调用 `scene.speed_change(character_features)` 取得倍率。

`assets/小场景/scene_card_pool/scene_card_pool.gd` 当前逻辑是：

```gdscript
if features.has(需要的参数):
	return 2
return 1
```

也就是角色拥有小场景要求的特性时，速度翻倍。

### 抽卡逻辑不同

小场景完成计时时，不走 `CardPool.get_random_type_in_abyss()`，而是直接从当前小场景资源自己的 `card_pool` 里随机：

```gdscript
spawn_card_info = scene.card_pool.pick_random()
_spawn_card()
```

例如不同小场景 `.tres` 会维护不同的 `card_pool`，所以它们产出的卡牌列表是各自独立的。

## 合成生成卡牌

虽然不是场景随机生成，但 2D 卡牌生成还有一条重要路径：`script_folder/card_craft_manager.gd`。

流程：

```text
Card.bestacked_on_me() / stop_stacking_on_me()
-> Events.stack_changed(card)
-> CraftManager._get_array(card)
-> 收集堆叠链上所有 cardname
-> 排序后匹配 _recipe_map
-> 如果匹配且有合成时间，启动 CardProgressBar
-> 完成后 queue_free() 材料卡
-> card_info.card_scene.instantiate()
-> instance.set_stats(card_info)
-> 添加到 Cards 分组
```

合成配方来源于 `main.tscn` 中 `CraftManager.craft_pools` 导出的资源数组。`_build_recipe_map()` 只会读取 `ThingsCard` 且 `has_craft_recipe == true` 的资源。

## 关键时序图

```text
玩家拖动人物卡到深度场景卡上
-> Area2D 记录 overlapping_cards
-> 松开鼠标进入 CardFalling
-> 找到最近可堆叠目标
-> stack_on_card(Scene)
-> Scene.bestacked_on_me(character)
-> 启动 CardProgressBar
-> progress_completed
-> CardPool 按权重随机类型
-> CardPool 按类型随机 CardInfo
-> spawn_card_info.card_scene.instantiate()
-> set_stats(spawn_card_info)
-> add_child 到 Cards 分组
-> Shooter 播放发射到 spawn_offset
-> 如果人物仍堆叠，继续下一轮计时
```

## 当前实现里的注意事项

1. 深度场景卡的 `SceneCard.card_pool` 资源字段当前不是主要生成来源；`Scene.gd` 实际使用节点上导出的 `cardpool: CardPool`。小场景才使用 `scene.card_pool`。
2. `CardPool.get_cards_by_type()` 当前是同类型内纯随机，稀有度常量已经定义但未参与筛选或权重。
3. `CardPool.get_random_type_in_abyss()` 可能抽到某个类型，但 `card_pool.tres` 中没有该类型卡时，`get_cards_by_type()` 会返回 `null`；随后 `_create_card_instance()` 访问 `spawn_card_info.card_scene` 会报错。当前没有 null 保护。
4. 事件类型权重当前是 `0`，因此深度场景不会随机出事件卡。
5. `Scene._start_timing()` 每次启动都会连接一次 `progress_completed` 的 one-shot 回调；正常完成会自动断开，但如果计时被取消，旧连接是否残留需要结合 Godot 信号行为进一步验证。
6. 终端里部分 `.gd` 文件的中文注释显示为乱码，且有些注释和代码在输出中看起来像同一行。实际 Godot 能否解析应以编辑器/运行结果为准；本文按代码意图和可见调用链描述。

## 新增随机可生成卡牌的最小步骤

1. 创建或复用一个继承 `CardInfo` 的 `.tres` 资源。
2. 设置 `name`、`portrait`、`type`。
3. 设置该资源类的 `card_scene`。
4. 确保目标场景脚本有 `set_stats(resource)` 并会刷新显示。
5. 如果要进深度场景全局池，把资源加入 `base_data/card_pool/card_pool.tres` 的 `card_pool`。
6. 如果只属于某个小场景，把资源加入对应 `SceneCardPool` 资源的 `card_pool`。
7. 如果要影响深度场景出现概率，修改 `CardPool.gd` 的类型权重。
