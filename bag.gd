extends Panel

# 背包面板脚本

@export var is_visible_on_start: bool = false  # 启动时是否可见

func _ready() -> void:
	visible = is_visible_on_start
	
	# 可以在这里添加更多初始化逻辑
	print("背包面板 %s 初始化完成" % name)

# 切换背包的显示/隐藏
func toggle_visibility() -> void:
	visible = !visible
	print("背包面板 %s: %s" % [name, "显示" if visible else "隐藏"])

# 显示背包
func show_bag() -> void:
	visible = true
	print("背包面板 %s 已显示" % name)

# 隐藏背包
func hide_bag() -> void:
	visible = false
	print("背包面板 %s 已隐藏" % name)

# 获取所有卡槽
func get_all_slots() -> Array[Control]:
	var slots: Array[Control] = []
	
	# 获取左侧槽位
	var left_slots = get_node_or_null("HBoxContainer/LeftSlots")
	if left_slots:
		for child in left_slots.get_children():
			if child.is_class("Panel") and child.has_method("is_empty"):
				slots.append(child)
	
	# 获取右侧槽位
	var right_slots = get_node_or_null("HBoxContainer/RightSlots")
	if right_slots:
		for child in right_slots.get_children():
			if child.is_class("Panel") and child.has_method("is_empty"):
				slots.append(child)
	
	return slots

# 获取所有空卡槽
func get_empty_slots() -> Array[Control]:
	var empty_slots: Array[Control] = []
	var all_slots = get_all_slots()
	
	for slot in all_slots:
		if slot.is_empty():
			empty_slots.append(slot)
	
	return empty_slots

# 获取背包中所有卡片
func get_all_cards() -> Array[Control]:
	var cards: Array[Control] = []
	var all_slots = get_all_slots()
	
	for slot in all_slots:
		if not slot.is_empty() and slot.contained_card != null:
			cards.append(slot.contained_card)
	
	return cards

# 检查背包是否已满
func is_full() -> bool:
	return get_empty_slots().is_empty()

# 背包被隐藏/销毁时的处理
# 注意：使用 Drag & Drop 系统后，拖拽中的卡片不会被删除
# 因为卡片数据是通过 get_drag_data 传递的，真正的卡片移动发生在 drop_data 中
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		print("背包面板 %s 即将被删除" % name)
		# 由于使用了内建 Drag & Drop 系统，拖拽中的卡片不会受影响

