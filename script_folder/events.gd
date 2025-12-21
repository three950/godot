extends Node

signal card_fixed()
signal card_put_in_bag(card:Card)
signal stack_changed(card:Card)

# 背包注册/注销信号
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

@export var spawn_card_info: CardInfo = null
## 根据卡牌资源类型创建对应的卡牌实例
func _create_card_instance() -> Node:
	var instance = spawn_card_info.card_scene.instantiate()
	instance.set_stats(spawn_card_info)
	return instance
