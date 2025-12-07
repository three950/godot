class_name CraftManager
extends Node
@export var craft_pools: Array[CardInfo] = []
var _recipe_map: Dictionary = {}

func _ready() -> void:
	_build_recipe_map()
	Events.stack_changed.connect(_get_array)

func _build_recipe_map() -> void:
	for card_info in craft_pools:
		if card_info is ThingsCard and card_info.has_craft_recipe:
			var material_names: Array[String] = []
			for material in card_info.craft_materials:
				material_names.append(material.name)
			material_names.sort()
			_recipe_map[material_names] = card_info
	print("Recipe Map: ", _recipe_map)

func _get_array(card: Card) -> void:
	var result_down: Array[String] = []
	var result_up: Array[String] = []
	var cards_to_free: Array[Card] = []
	
	# children_card向下遍历
	if card.children_card != null:
		var current = card.children_card
		while current != null:
			result_down.append(current.name)
			cards_to_free.append(current)
			current = current.children_card
	
	# follow_target向上遍历，同时找到最顶层的卡片
	var top_card: Card = card
	if card.follow_target != null:
		var current = card.follow_target
		while current != null:
			result_up.append(current.name)
			cards_to_free.append(current)
			if current.follow_target == null:
				top_card = current
			current = current.follow_target
	
	var result: Array[String] = []
	result.assign(result_up + [card.name] + result_down)
	if result:
		result.sort()
	print(result)
	
	# 查询配方
	if _recipe_map.has(result):
		print("配方匹配成功: ", result, " -> ", _recipe_map[result].name)
		var spawn_position = top_card.global_position		
		# 销毁所有相关卡片
		cards_to_free.append(card)
		for c in cards_to_free:
			c.queue_free()		
		# 生成新卡片
		_spawn_crafted_card(_recipe_map[result], spawn_position)

func _spawn_crafted_card(card_info: CardInfo, spawn_position: Vector2) -> void:
	var instance = card_info.card_scene.instantiate()
	instance.set_stats(card_info)
	
	# 将卡牌添加到Cards分组的根节点
	var cards_group = get_tree().get_first_node_in_group("Cards")
	if cards_group:
		cards_group.add_child(instance)
	instance.global_position = spawn_position
	print("合成卡牌已生成: ", card_info.name, " 位置: ", spawn_position)
