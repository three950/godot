extends Panel
class_name BagSlot
signal show_card(card_data:CharacterCard)
@onready var owner_character: Character = _find_owner_character()

func _find_owner_character() -> Character:
	var node: Node = self
	while node:
		if node is Character:
			return node as Character
		node = node.get_parent()
	return null
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

## 获取槽位中的卡片（如果有）
func get_card() -> Card:
	for child in get_children():
		if child is Card:
			return child
	return null

## 检查槽位是否为空
func is_empty() -> bool:
	return get_card() == null

## 将卡片放入槽位（统一处理位置和缩放）
func place_card(card: Card) -> void:
	# 1. 先从原父节点移除（如果有）
	var old_parent = card.get_parent()
	if old_parent:
		old_parent.remove_child(card)

	# 2. 添加到槽位
	add_child(card)
	# 3. 如果这是一个有“添加特性”的物品卡，把特性加到角色身上
	var card_info := card.get_card_resource()
	if card_info is ItemCard:
		var item_card := card_info as ItemCard
		if item_card.添加特性 != "":
			owner_character.character.特性.append(item_card.添加特性)
			print("【BagSlot】添加特性：", owner_character.character.特性)
	var card_size = card.size
	# 计算缩放比例，取较小值以确保卡片完全在槽位内
	var scale_ratio = min(size.x / card_size.x, size.y / card_size.y)
	card.scale = Vector2(scale_ratio, scale_ratio)
	
	# 4. 设置位置（居中对齐，使用局部坐标）
	card.position = (size - card.size * card.scale) / 2.0
	
	print("【BagSlot】卡片 %s 放入槽位，缩放: %.2f" % [card.name, scale_ratio])

## 移除槽位中的卡片并返回
func remove_card() -> Card:
	var card = get_card()
	if card:
		remove_child(card)
		if card.添加特性:
			for feat in card.添加特性:
				owner_character.character.特性.remove_at(feat)
			print("【BagSlot】移除特性：", owner_character.character.特性)
	return card

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
	# 使用统一的 place_card 方法
	place_card(card)
	print("生成卡片")
