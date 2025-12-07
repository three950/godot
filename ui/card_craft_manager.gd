class_name CraftManager
extends Node

func _ready() -> void:
	Events.stack_changed.connect(_get_array)

func _get_array(card: Card) -> Array[String]:
	var result_down: Array[String] = []
	var result_up: Array[String] = []
	#children_card向下遍历
	if card.children_card != null:
		var current = card.children_card
		while current != null:
			result_down.append(current.name)
			current = current.children_card
	#follow_target向上遍历
	if card.follow_target != null:
		var current = card.follow_target
		while current != null:
			result_up.append(current.name)
			current = current.follow_target
	# 基准card只添加一次
	var result: Array[String] = []
	result.assign(result_up + [card.name] + result_down)
	if result:
		result.sort()
	print(result)
	return result
