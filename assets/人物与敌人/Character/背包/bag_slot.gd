extends Panel
class_name BagSlot
signal show_card(card_data:ThingsCard)
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
## apply_effects = true 时会应用物品特性 / 装备效果；false 时只做视觉摆放
func place_card(card: Card, apply_effects: bool = true) -> void:
	# 1. 先从原父节点移除（如果有）
	var old_parent = card.get_parent()
	if old_parent:
		print("哎呀移出啦, 原父节点: ", old_parent)
		# 这里只负责从原父节点移除，不在这里做卸下装备逻辑
		# 卸下装备的属性变更统一由 BagMover 在拖拽开始 / 交换时调用 remove_card 处理
		old_parent.remove_child(card)

	# 2. 添加到槽位
	add_child(card)
	# 3. 按需应用物品特性 / 装备效果
	if apply_effects:
		var card_info := card.get_card_resource()
		if card_info is ThingsCard and owner_character and owner_character.character:
			if card_info.添加特性 != "":
				owner_character.character.特性.append(card_info.添加特性)
				print("【BagSlot】添加特性：", owner_character.character.特性)
		# 3.1 如果是装备卡，并且力量满足需求，则应用装备效果
		if card_info is EquipmentCard and owner_character and owner_character.character:
			var equip_card := card_info as EquipmentCard
			if equip_card.need_power < owner_character.character.POW:
				match equip_card.equip_type:
					EquipmentCard.EquipType.攻击:
						owner_character.character.ATK += equip_card.equip_effect
					EquipmentCard.EquipType.防御:
						owner_character.character.DEF += equip_card.equip_effect
	var card_size = card.size
	# 计算缩放比例，取较小值以确保卡片完全在槽位内
	var scale_ratio = min(size.x / card_size.x, size.y / card_size.y)
	card.scale = Vector2(scale_ratio, scale_ratio)
	
	# 4. 设置位置（居中对齐，使用局部坐标）
	card.position = (size - card.size * card.scale) / 2.0
	
	# 5. 装备槽内容变动后，同步 CharacterCard 的单件武器/防具，并刷新角色卡 UI/Viewport。
	_notify_bag_equipment_changed()
	
	print("【BagSlot】卡片 %s 放入槽位，缩放: %.2f" % [card.name, scale_ratio])

## 移除槽位中的卡片并返回
func remove_card() -> Card:
	var card = get_card()
	if card:
		remove_child(card)
		# 移除卡片添加的特性 / 装备效果
		_remove_card_effects(card)
		_notify_bag_equipment_changed()
	return card

## 仅移除当前槽位中卡片的效果，不移除节点（用于拖拽开始时预先扣除属性）
func unequip_only() -> void:
	var card = get_card()
	if card:
		_remove_card_effects(card)

## 内部工具函数：根据卡片信息移除对应效果
func _remove_card_effects(card: Card) -> void:
	if owner_character == null or owner_character.character == null:
		return

	var card_info := card.get_card_resource()
	if card_info is ThingsCard:
		if card_info.添加特性 != "":
			owner_character.character.特性.erase(card_info.添加特性)
			print("【BagSlot】移除特性：", owner_character.character.特性)
	if card_info is EquipmentCard:
		var equip_card := card_info as EquipmentCard
		match equip_card.equip_type:
			0:
				owner_character.character.ATK -= equip_card.equip_effect
			1:
				owner_character.character.DEF -= equip_card.equip_effect

func _notify_bag_equipment_changed() -> void:
	# BagSlot 被包在多层容器里，所以向父级一路查找 BagArea，而不是写死节点路径。
	var node: Node = self
	while node != null:
		if node is BagArea:
			(node as BagArea).sync_character_equipment_from_slots()
			return
		node = node.get_parent()

func show_owned_card(card_data:ThingsCard) -> void:
	if not card_data:
		push_error("没有卡片数据")
		return
	if not card_data.card_scene:
		push_error("卡片数据中没有场景")
		return
	var card = card_data.card_scene.instantiate()
	if card.has_method("set_stats"):
		card.set_stats(card_data)
	# 使用统一的 place_card 方法，但初次加载防具时只做摆放，不重复应用特性 / 装备效果
	place_card(card, false)
	print("生成卡片")

## 设置高亮状态（拖拽时显示白色边框）
func set_highlight(enabled: bool) -> void:
	var color_rect = get_node("ColorRect")
	if color_rect:
		color_rect.visible = enabled
		if enabled:
			color_rect.color = Color(1.0, 1.0, 1.0, 0.5)  # 白色半透明
