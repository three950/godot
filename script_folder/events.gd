extends Node

signal card_fixed()
signal card_put_in_bag(card:Card)
signal stack_changed(card: Card3D)

# 防具注册/注销信号
signal bag_registered(bag: BagArea)
signal bag_unregistered(bag: BagArea)

# 卡片拖拽信号（用于 BagMover 监听）
signal card_drag_started(card: Card)
signal card_dropped(card: Card)

#场景切换导致的物品资源池更新
signal max_layer_changed(max_layer:int)

#堆叠数组发送改变
signal array_changed()

#食物状态更新
signal food_need_update(amount: int)
signal food_have_update(amount: int)

#战斗系统信号
signal battle_start_requested(character: Character, enemy: Enemy)

# 全局计时暂停状态
signal timers_pause_changed(is_paused: bool)
var timers_paused: bool = false

@export var spawn_card_info: CardInfo = null

func set_timers_paused(is_paused: bool) -> void:
	if timers_paused == is_paused:
		return
	timers_paused = is_paused
	timers_pause_changed.emit(timers_paused)

func toggle_timers_paused() -> void:
	set_timers_paused(not timers_paused)

## 根据卡牌资源类型创建对应的卡牌实例
func _create_card_instance() -> Node:
	var instance = spawn_card_info.card_scene.instantiate()
	instance.set_stats(spawn_card_info)
	return instance
