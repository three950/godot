extends Panel
class_name BagSlot

# 信号：当卡片被放入卡槽
signal card_placed(card: Control)
# 信号：当卡片被移出卡槽
signal card_removed(card: Control)

# 卡槽状态
var stored_card: Control = null  # 当前存储的卡片

# 数据联动
var slot_field_name: String = ""  # 对应 CharacterData 中的字段名（left/right/bag1-bag6）
var bag_panel: Control = null  # 所属的背包面板引用

func _ready() -> void:
	# 确保可以接收鼠标事件
	mouse_filter = Control.MOUSE_FILTER_STOP

# 判断卡槽是否为空
func is_empty() -> bool:
	return stored_card == null

# 将卡片放入卡槽
func place_card(card: Control) -> bool:
	# 如果卡槽已有卡片，不能接收
	if not is_empty():
		return false
	
	# 检查卡片是否有堆叠的子卡片，不允许带有堆叠的卡片放入背包
	if "stacked_cards" in card and card.stacked_cards.size() > 0:
		print("【卡槽】警告：不允许带有堆叠卡片的卡片放入背包槽")
		return false
	
	# 【修复】如果卡片还没有设置 original_parent，现在设置它
	# 这样当卡片被拖出时，可以正确地返回到原始父节点
	if "original_parent" in card and card.original_parent == null:
		card.original_parent = card.get_parent()
	
	# 保存卡片的原始父节点
	var old_parent = card.get_parent()
	if old_parent:
		old_parent.remove_child(card)
	
	# 将卡片添加到卡槽
	add_child(card)
	stored_card = card
	
	# 【等比缩放】计算缩放比例以适应卡槽
	var card_size = card.size
	var slot_size = size
	
	# 计算宽度和高度的缩放比例，取较小值以确保卡片完全适应
	var scale_x = slot_size.x / card_size.x if card_size.x > 0 else 1.0
	var scale_y = slot_size.y / card_size.y if card_size.y > 0 else 1.0
	var scale_factor = min(scale_x, scale_y)
	
	# 应用等比缩放
	card.scale = Vector2(scale_factor, scale_factor)
	
	# 计算居中位置（考虑缩放后的实际大小）
	var scaled_card_size = card_size * scale_factor
	card.position = (slot_size - scaled_card_size) / 2.0
	
	# 【关键修复】设置卡片的 z_index，确保比背景的 ColorRect 高
	# 卡槽下的 ColorRect 默认 z_index 是 0，所以卡片设置为 1
	card.z_index = 1
	
	# 确保卡片在场景树中排在 ColorRect 之后（后添加的节点会在上层渲染）
	move_child(card, -1)
	
	# 如果卡片有状态，设置为固定状态
	if "cardCurrentState" in card:
		card.cardCurrentState = card.cardState.fixed
	
	# 发射信号
	card_placed.emit(card)
	
	# 更新 CharacterData
	update_character_data()
	
	print("【卡槽】卡片已放入，z_index=%d, 节点索引=%d" % [card.z_index, card.get_index()])
	
	return true

# 从卡槽移除卡片
func remove_card() -> Control:
	if is_empty():
		return null
	
	var card = stored_card
	stored_card = null
	
	# 清除卡片中的卡槽引用（如果卡片有这个属性）
	if "parent_slot" in card:
		card.parent_slot = null
	
	# 从卡槽移除卡片节点
	if card.get_parent() == self:
		remove_child(card)
	
	# 发射信号
	card_removed.emit(card)
	
	# 更新 CharacterData（清空字段）
	update_character_data()
	
	print("【卡槽】卡片已移除")
	
	return card

# 获取卡槽中的卡片
func get_card() -> Control:
	return stored_card

# 更新角色数据
func update_character_data() -> void:
	# 检查是否有背包面板引用
	if bag_panel == null:
		return
	
	# 检查背包面板是否有当前角色数据
	if not "current_character" in bag_panel or bag_panel.current_character == null:
		return
	
	# 检查是否设置了字段名
	if slot_field_name == "":
		return
	
	var character: CharacterData = bag_panel.current_character
	
	# 获取卡片名称
	var card_name: String = ""
	if not is_empty():
		card_name = _get_card_name(stored_card)
	
	# 更新对应字段
	if slot_field_name in character:
		character.set(slot_field_name, card_name)
		print("【卡槽】已更新角色数据 %s.%s = '%s'" % [character.character_name, slot_field_name, card_name])
	else:
		push_warning("【卡槽】角色数据中没有字段: %s" % slot_field_name)

# 获取卡片名称
func _get_card_name(card: Control) -> String:
	if card == null:
		return ""
	
	# 尝试多种方式获取卡片名称
	
	# 1. 尝试从自定义属性获取
	if "card_name" in card and card.card_name != "":
		return card.card_name
	
	# 2. 尝试从主 Label 获取（路径可能不同）
	var label_paths = [
		"Control/ColorRect/Label",  # 标准路径
		"ColorRect/Label",
		"Label",
		"VBoxContainer/Label",
		"Control/Label"
	]
	
	for path in label_paths:
		var label = card.get_node_or_null(path)
		if label and "text" in label and label.text != "":
			return label.text
	
	# 3. 尝试递归查找第一个 Label 节点
	var first_label = _find_first_label(card)
	if first_label and first_label.text != "":
		return first_label.text
	
	# 4. 如果都失败了，返回节点名称作为后备
	return card.name

# 递归查找第一个 Label 节点
func _find_first_label(node: Node) -> Label:
	if node is Label:
		return node
	
	for child in node.get_children():
		var result = _find_first_label(child)
		if result:
			return result
	
	return null
