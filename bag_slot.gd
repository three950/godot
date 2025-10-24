extends Panel

# 卡槽脚本 - 支持 Drag & Drop 的卡片槽位

var contained_card: Control = null  # 当前槽位中的卡片

func _ready() -> void:
	# 可以在这里添加初始化逻辑
	pass

# 检查槽位是否为空
func is_empty() -> bool:
	return contained_card == null

# 放置卡片到槽位
func place_card(card: Control) -> bool:
	if not is_empty():
		print("警告: 槽位 %s 已有卡片" % name)
		return false
	
	# 保存卡片的全局位置
	var saved_global_position = card.global_position
	
	# 将卡片作为子节点添加到槽位
	var old_parent = card.get_parent()
	if old_parent:
		old_parent.remove_child(card)
	
	add_child(card)
	
	# 设置卡片位置为槽位中心
	card.position = size / 2 - card.size / 2
	
	# 缩放卡片以适应槽位
	var scale_x = size.x / card.size.x * 0.9  # 留10%边距
	var scale_y = size.y / card.size.y * 0.9
	var target_scale = min(scale_x, scale_y)
	card.scale = Vector2(target_scale, target_scale)
	
	# 重新计算中心位置（考虑缩放）
	card.position = size / 2 - card.size * target_scale / 2
	
	contained_card = card
	print("卡片 %s 已放入槽位 %s" % [card.name, name])
	return true

# 从槽位移除卡片
func remove_card() -> Control:
	var card = contained_card
	if card == null:
		return null
	
	# 从槽位中移除
	if card.get_parent() == self:
		remove_child(card)
	
	contained_card = null
	print("卡片 %s 已从槽位 %s 移除" % [card.name, name])
	return card

# ==================== Drag & Drop 系统 ====================

# 判断是否可以接受拖放的数据
func _can_drop_data(_at_position: Vector2, data) -> bool:
	# 只接受字典类型的数据，且包含 card 字段
	if typeof(data) != TYPE_DICTIONARY:
		return false
	
	if not data.has("card"):
		return false
	
	var card = data["card"]
	
	# 检查卡片是否有堆叠的子卡片
	if "stacked_cards" in card and card.stacked_cards.size() > 0:
		return false  # 带有堆叠卡片的卡片不能放入背包槽
	
	# 只有空槽位才能接受卡片
	return is_empty()

# 执行拖放操作
func _drop_data(_at_position: Vector2, data) -> void:
	if typeof(data) != TYPE_DICTIONARY or not data.has("card"):
		return
	
	var card = data["card"]
	
	# 如果卡片在其他卡槽中，先从那个卡槽移除
	if "parent_slot" in card and card.parent_slot != null:
		if card.parent_slot.has_method("remove_card"):
			card.parent_slot.remove_card()
	
	# 如果卡片堆叠在其他卡片上，从堆叠中移除
	if "parent_card" in card and card.parent_card != null:
		if card.parent_card.has_method("remove_from_stack"):
			card.parent_card.remove_from_stack(card)
		card.parent_card = null
	
	# 放置卡片到当前槽位
	if place_card(card):
		# 记录卡片所在的槽位
		card.parent_slot = self
		# 设置卡片状态为固定
		if "cardCurrentState" in card and "cardState" in card:
			card.cardCurrentState = card.cardState.fixed

