extends Panel
class_name BagSlot
signal show_card(card_data:CharacterCard)
func _ready() -> void:
	show_card.connect(show_owned_card)
## 获取卡槽的中心全局位置（用于卡片对齐）
func get_center_global_position() -> Vector2:
	return global_position + size / 2.0

## 检测某个全局坐标是否在卡槽内
func contains_global_point(point: Vector2) -> bool:
	var rect = Rect2(global_position, size)
	return rect.has_point(point)

## 获取卡槽的尺寸（用于计算缩放）
func get_slot_size() -> Vector2:
	return size
func show_owned_card(card_data:CharacterCard) -> void:
	if not card_data:
		push_error("没有卡片数据")
		return
	if not card_data.card_scene:
		push_error("卡片数据中没有场景")
		return
	var card = card_data.card_scene.instantiate()
	if card.has_method("set_character_stats"):
		card.set_character_stats(card_data)
	add_child(card)
	print("生成卡片")
