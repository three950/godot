extends Control

# 信号：当有卡片堆叠到此卡片上时触发
signal card_stacked_on(stacked_card: Control)

enum cardState{fixed, dragging, bestacked}
enum cardType{normal, selling, architecture}  # 卡片类型
@export var cardCurrentState = cardState.fixed
@export var card_type: cardType = cardType.normal  # 默认为普通类型
@export var follow_target: Label
@export var snap_distance: float = 80.0  # 吸附检测的最大距离
@export var stack_offset: Vector2 = Vector2(0, 15)  # 堆叠时的视觉偏移（Y轴留出label高度）
@export var can_accept_stack: bool = true  # 是否允许其他卡片堆叠在上面
@export var accept_value_only: bool = false  # 若为真，仅接受带有 value 属性的卡片

# 堆叠关系
var stacked_cards: Array[Control] = []  # 堆叠在这张卡片上的其他卡片
var parent_card: Control = null  # 如果这张卡片堆叠在其他卡片上，这是父卡片
var original_position: Vector2 = Vector2.ZERO  # 开始拖拽时的原始位置
var drag_offset_in_stack: Vector2 = Vector2.ZERO  # 在堆叠中的偏移量

# 卡槽相关
var parent_slot: Control = null  # 如果卡片在卡槽中，这是父卡槽
var original_scale: Vector2 = Vector2.ONE  # 记录原始缩放，从卡槽拿出时恢复
var original_parent: Node = null  # 记录从卡槽拿出前的父节点

const DRAG_TEMP_Z := 100

func _ready() -> void:
	original_position = position

func _process(delta: float) -> void:
	match cardCurrentState:
		cardState.dragging:
			# 旧的手动拖拽逻辑已弃用
			# 现在由 Godot 内建 Drag & Drop 系统处理
			pass
		cardState.fixed:
			pass
		cardState.bestacked:
			# 如果堆叠在其他卡片上，跟随父卡片的位置
			if parent_card != null:
				position = parent_card.position + drag_offset_in_stack

# ==================== Godot 内建 Drag & Drop 系统 ====================

# 开始拖拽时调用，返回拖拽数据
func _get_drag_data(_at_position: Vector2):
	# architecture 类型不能拖拽
	if card_type == cardType.architecture:
		return null
	
	# 准备拖拽数据
	var drag_data = {
		"card": self,
		"source_position": global_position,
		"source_slot": parent_slot,
		"source_parent_card": parent_card
	}
	
	# 创建拖拽预览
	var preview = create_drag_preview()
	set_drag_preview(preview)
	
	# 从原位置移除（但不删除节点）
	if parent_slot != null:
		# 如果在卡槽中，只清除卡槽的引用，不移除节点
		parent_slot.contained_card = null
		parent_slot = null
	
	if parent_card != null:
		# 如果堆叠在其他卡片上，从堆叠中移除
		parent_card.remove_from_stack(self)
		parent_card = null
	
	# 记录原始位置
	original_position = global_position
	
	print("开始拖拽卡片: %s" % name)
	return drag_data

# 创建拖拽预览
func create_drag_preview() -> Control:
	var preview = Control.new()
	
	# 创建卡片的视觉副本
	var preview_panel = Panel.new()
	preview_panel.custom_minimum_size = size
	preview_panel.modulate = Color(1, 1, 1, 0.7)  # 半透明效果
	
	# 如果卡片有纹理或背景色，可以复制过来
	# 这里简化处理，只创建一个半透明的面板
	preview.add_child(preview_panel)
	
	# 可以添加更多视觉元素，比如卡片名称等
	if has_node("Label"):
		var label_copy = Label.new()
		var original_label = get_node("Label")
		label_copy.text = original_label.text
		label_copy.position = original_label.position
		preview_panel.add_child(label_copy)
	
	return preview

# 判断是否可以将数据拖放到此卡片上（用于堆叠）
func _can_drop_data(_at_position: Vector2, data) -> bool:
	# 只接受字典类型的数据
	if typeof(data) != TYPE_DICTIONARY:
		return false
	
	if not data.has("card"):
		return false
	
	var dragged_card = data["card"]
	
	# 不能堆叠到自己身上
	if dragged_card == self:
		return false
	
	# 不能堆叠到已经堆叠在自己身上的卡片
	if is_card_in_stack(dragged_card):
		return false
	
	# selling 类型不能作为堆叠目标
	if card_type == cardType.selling:
		return false
	
	# 检查是否允许堆叠
	if not can_accept_stack:
		return false
	
	# 如果只接受带 value 的卡片
	if accept_value_only and not ("value" in dragged_card):
		return false
	
	# 拖拽的卡片如果是 selling 或 architecture 类型，不能被堆叠
	if "card_type" in dragged_card:
		if dragged_card.card_type == cardType.selling or dragged_card.card_type == cardType.architecture:
			return false
	
	return true

# 执行拖放操作（堆叠）
func _drop_data(_at_position: Vector2, data) -> void:
	if typeof(data) != TYPE_DICTIONARY or not data.has("card"):
		return
	
	var dragged_card = data["card"]
	
	# 堆叠到当前卡片上
	stack_card_on_self(dragged_card)
	
	print("卡片 %s 被拖放到 %s 上" % [dragged_card.name, name])

# 将拖拽的卡片堆叠到自己身上
func stack_card_on_self(dragged_card: Control) -> void:
	# 确保卡片在同一个父节点下
	if dragged_card.get_parent() != get_parent():
		var saved_global_pos = dragged_card.global_position
		var old_parent = dragged_card.get_parent()
		var target_parent = get_parent()
		
		if old_parent and target_parent:
			old_parent.remove_child(dragged_card)
			target_parent.add_child(dragged_card)
			dragged_card.global_position = saved_global_pos
	
	# 设置堆叠关系
	dragged_card.parent_card = self
	dragged_card.cardCurrentState = cardState.bestacked
	
	# 计算堆叠偏移量
	var stack_index = get_total_stack_size()
	dragged_card.drag_offset_in_stack = stack_offset * (stack_index + 1)
	
	# 添加到堆叠列表
	add_to_stack(dragged_card)
	
	# 设置位置和层级
	dragged_card.position = position + dragged_card.drag_offset_in_stack
	dragged_card.z_index = z_index + stack_index + 1
	
	# 更新子卡片
	dragged_card.update_stacked_cards()
	
	# 调整场景树顺序
	dragged_card.adjust_scene_tree_order()

# ==================== 旧的按钮拖拽系统（已弃用，保留作为备用）====================

func _on_button_button_down() -> void:
	# 这个方法现在不再用于拖拽
	# 拖拽由 _get_drag_data 处理
	pass

func _on_button_button_up() -> void:
	# 这个方法现在不再用于拖拽
	# 拖拽由 Drag & Drop 系统处理
	# 保留用于其他按钮交互（如点击选择等）
	pass

# 查找最近的可堆叠卡片
func find_closest_card() -> Control:
	var cards = get_tree().get_nodes_in_group("Cards")
	var closest_card: Control = null
	var snap_distance_sq: float = snap_distance * snap_distance
	var closest_distance_sq: float = snap_distance_sq
	
	for card in cards:
		if card == self or card == parent_card:
			continue
		
		# 如果目标卡片堆叠在当前卡片上，跳过（避免循环堆叠）
		if is_card_in_stack(card):
			continue
		
		# 如果目标卡片是 selling 类型，不能堆叠在上面
		# 检查目标卡片是否有 card_type 属性
		if "card_type" in card:
			if card.card_type == cardType.selling:
				continue
		
		# 检查目标卡片是否允许堆叠
		if "can_accept_stack" in card and not card.can_accept_stack:
			continue
		# 如果目标卡片只接受带 value 的卡片
		if "accept_value_only" in card and card.accept_value_only:
			# 拖拽的卡必须有 value 属性
			if not ("value" in self):
				continue
		
		var dist_sq = global_position.distance_squared_to(card.global_position)
		if dist_sq < closest_distance_sq:
			closest_distance_sq = dist_sq
			closest_card = card
	
	return closest_card

# 堆叠到目标卡片上
func stack_on_card(target_card: Control) -> void:
	# selling 类型不能被堆叠
	# architecture 类型理论上不会进入拖拽状态（在 button_down 中已阻止），但这里做防御性检查
	if card_type == cardType.selling or card_type == cardType.architecture:
		cardCurrentState = cardState.fixed
		return
	
	# 确保当前卡片和目标卡片在同一个父节点下
	if get_parent() != target_card.get_parent():
		var saved_global_pos = global_position
		var old_parent = get_parent()
		var target_parent = target_card.get_parent()
		
		if old_parent and target_parent:
			old_parent.remove_child(self)
			target_parent.add_child(self)
			global_position = saved_global_pos
			print("卡片 %s 移动到与 %s 相同的父节点" % [name, target_card.name])
	
	parent_card = target_card
	cardCurrentState = cardState.bestacked
	
	# 计算堆叠偏移量（基于目标卡片整条堆叠链的总数量）
	var stack_index = target_card.get_total_stack_size()
	drag_offset_in_stack = stack_offset * (stack_index + 1)
	
	# 添加到目标卡片的堆叠列表
	target_card.add_to_stack(self)
	
	# 设置位置
	position = target_card.position + drag_offset_in_stack
	
	# 设置层级，堆叠的卡片层级更高
	z_index = target_card.z_index + stack_index + 1
	
	# 对被拖动卡片内部的子卡片递归刷新位置与层级
	update_stacked_cards()
	
	# 关键：调整场景树顺序，确保子卡片在父卡片后面，优先接收输入
	adjust_scene_tree_order()
	
	print("卡片 %s 堆叠到 %s 上" % [name, target_card.name])

# 添加卡片到堆叠
func add_to_stack(card: Control) -> void:
	# selling 类型不允许其他卡片堆叠在上面
	if card_type == cardType.selling:
		print("警告: %s 类型的卡片不允许堆叠其他卡片" % cardType.keys()[card_type])
		return
	
	# 检查是否允许堆叠
	if "can_accept_stack" in self and not can_accept_stack:
		print("警告: %s 卡片不允许堆叠其他卡片" % name)
		return
	# 若仅接受带 value 的卡片
	if accept_value_only and not ("value" in card):
		print("警告: %s 只接受带 value 的卡片堆叠" % name)
		return
	
	if card not in stacked_cards:
		stacked_cards.append(card)
		print("  堆叠数量: %d" % stacked_cards.size())
		# 发射堆叠信号
		card_stacked_on.emit(card)

# 从堆叠中移除卡片
func remove_from_stack(card: Control) -> void:
	if card in stacked_cards:
		stacked_cards.erase(card)
		card.parent_card = null  # 断开父引用
		print("卡片 %s 从 %s 上移除，剩余: %d" % [card.name, name, stacked_cards.size()])
		
		# 重新排列剩余堆叠的卡片
		rearrange_stacked_cards()

# 重新排列堆叠的卡片
func rearrange_stacked_cards() -> void:
	for i in range(stacked_cards.size()):
		var card = stacked_cards[i]
		card.drag_offset_in_stack = stack_offset * (i + 1)
		card.position = position + card.drag_offset_in_stack
		card.z_index = z_index + i + 1
		# 调整场景树顺序
		if card.has_method("adjust_scene_tree_order"):
			card.adjust_scene_tree_order()

# 检查指定卡片是否在当前卡片的堆叠中
func is_card_in_stack(card: Control) -> bool:
	if card in stacked_cards:
		return true
	
	# 递归检查堆叠中的卡片
	for stacked_card in stacked_cards:
		if stacked_card.has_method("is_card_in_stack") and stacked_card.is_card_in_stack(card):
			return true
	
	return false

# 统一更新堆叠卡片的 z_index 与 position
func update_stacked_cards() -> void:
	for i in range(stacked_cards.size()):
		var card = stacked_cards[i]
		card.z_index = z_index + i + 1
		card.position = position + card.drag_offset_in_stack
		if card.has_method("update_stacked_cards"):
			card.update_stacked_cards()

# 兼容旧函数名，内部调用新实现
func update_stacked_cards_z_index() -> void:
	update_stacked_cards()

func update_stacked_cards_position() -> void:
	update_stacked_cards()

# 调整场景树顺序，确保堆叠顺序正确
func adjust_scene_tree_order() -> void:
	var parent_node = get_parent()
	if parent_node == null:
		return
	
	# 如果有父卡片，将自己移到父卡片后面
	if parent_card != null:
		var parent_index = parent_card.get_index()
		# 找到父卡片堆叠中最后一张卡片的位置
		var last_child_index = parent_index
		for child_card in parent_card.stacked_cards:
			var child_index = child_card.get_index()
			if child_index > last_child_index:
				last_child_index = child_index
		
		# 将当前卡片移到最后一张子卡片后面
		parent_node.move_child(self, last_child_index + 1)
	
	# 递归调整自己的子卡片顺序
	for child_card in stacked_cards:
		if child_card.has_method("adjust_scene_tree_order"):
			child_card.adjust_scene_tree_order()

# 将所有堆叠的子卡片移到场景树末尾
func move_stacked_cards_to_end() -> void:
	var parent_node = get_parent()
	if parent_node == null:
		return
	
	# 按顺序将每张子卡片移到末尾
	for child_card in stacked_cards:
		parent_node.move_child(child_card, -1)
		# 递归移动子卡片的子卡片
		if child_card.has_method("move_stacked_cards_to_end"):
			child_card.move_stacked_cards_to_end()

# 递归获取当前卡片堆叠链（不含自身）的总数量
func get_total_stack_size() -> int:
	var total := 0
	for child in stacked_cards:
		total += 1
		if child.has_method("get_total_stack_size"):
			total += child.get_total_stack_size()
	return total

# 检测卡片是否在商店区域之外
func is_outside_shop_area() -> bool:
	# 尝试找到 ShopArea 节点
	var shop_area = get_tree().get_first_node_in_group("ShopArea")
	if shop_area == null:
		# 如果找不到 ShopArea 节点，尝试通过路径查找
		var root = get_tree().root
		shop_area = root.find_child("ShopArea", true, false)
	
	if shop_area == null:
		print("警告: 找不到 ShopArea 节点")
		return true  # 找不到商店区域，默认认为在外面
	
	# 获取卡片的全局矩形
	var card_rect = Rect2(global_position, size)
	
	# 获取商店区域的全局矩形
	var shop_rect = Rect2(shop_area.global_position, shop_area.size)
	
	# 检测是否有交集（如果没有交集，说明卡片在商店区域外）
	return not card_rect.intersects(shop_rect)

# 将卡片从 slot 移动到主场景中
func move_to_main_scene() -> void:
	var old_parent = get_parent()
	if old_parent == null:
		return
	
	# 先获取场景树引用（必须在 remove_child 之前）
	var tree = get_tree()
	if tree == null or tree.root == null:
		push_error("无法获取场景树")
		return
	
	# 保存当前的全局位置
	var saved_global_position = global_position
	
	# 尝试找到 CardManager 节点（人物卡片的父节点）
	var card_manager = tree.root.find_child("CardManager", true, false)
	var target_parent = card_manager
	# 从当前父节点移除
	old_parent.remove_child(self)
	
	# 添加到目标父节点
	target_parent.add_child(self)
	
	# 恢复全局位置（转换为新父节点下的相对位置）
	global_position = saved_global_position
	
	# 确保 z_index 合适，不会被遮挡
	z_index = 0
	
	print("卡片 %s 已从 %s 移动到 %s" % [name, old_parent.name, target_parent.name])

# 尝试购买卡片（扣除金币）
func try_purchase() -> bool:
	# 获取卡片的价值
	if not ("value" in self):
		print("警告: 卡片 %s 没有 value 属性，无法购买" % name)
		return false
	
	var card_value = self.value
	
	# 查找 ShopManager
	var shop_manager = get_tree().get_first_node_in_group("ShopManager")
	if shop_manager == null:
		# 如果找不到，通过路径查找
		var root = get_tree().root
		shop_manager = root.find_child("ShopManager", true, false)
	
	if shop_manager == null:
		print("警告: 找不到 ShopManager 节点")
		return false
	
	# 检查金币是否足够
	if shop_manager.coins < card_value:
		print("金币不足：需要 %d，当前 %d" % [card_value, shop_manager.coins])
		return false
	
	# 扣除金币
	shop_manager.coins -= card_value
	shop_manager.update_coin_display()
	print("购买成功：花费 %d 金币，剩余 %d 金币" % [card_value, shop_manager.coins])
	
	return true

# ==================== 卡槽相关方法 ====================

# 查找最近的空卡槽
func find_closest_slot() -> Control:
	# 获取所有背包面板
	var bag_panels = get_tree().get_nodes_in_group("BagPanel")
	if bag_panels.is_empty():
		return null
	
	var closest_slot: Control = null
	var snap_distance_sq: float = snap_distance * snap_distance
	var closest_distance_sq: float = snap_distance_sq
	
	for bag_panel in bag_panels:
		# 获取背包中的所有卡槽
		var slots = []
		
		# 尝试获取左侧槽位
		var left_slots = bag_panel.get_node_or_null("HBoxContainer/LeftSlots")
		if left_slots:
			for child in left_slots.get_children():
				if child.is_class("Panel") and child.has_method("is_empty"):
					slots.append(child)
		
		# 尝试获取右侧槽位
		var right_slots = bag_panel.get_node_or_null("HBoxContainer/RightSlots")
		if right_slots:
			for child in right_slots.get_children():
				if child.is_class("Panel") and child.has_method("is_empty"):
					slots.append(child)
		
		# 检查每个卡槽
		for slot in slots:
			# 只考虑空卡槽
			if not slot.is_empty():
				continue
			
			var dist_sq = global_position.distance_squared_to(slot.global_position)
			if dist_sq < closest_distance_sq:
				closest_distance_sq = dist_sq
				closest_slot = slot
	
	return closest_slot

# 将卡片放入卡槽
func place_in_slot(slot: Control) -> void:
	if slot == null or not slot.has_method("place_card"):
		print("警告: 无效的卡槽")
		cardCurrentState = cardState.fixed
		return
	
	# 检查卡槽是否为空
	if not slot.is_empty():
		print("警告: 卡槽已有卡片")
		cardCurrentState = cardState.fixed
		return
	
	# 检查当前卡片是否有堆叠的子卡片
	if stacked_cards.size() > 0:
		print("警告: 带有堆叠卡片的卡片不能放入背包槽")
		cardCurrentState = cardState.fixed
		return
	
	# 记录原始父节点（用于从卡槽拿出时恢复）
	original_parent = get_parent()
	
	# 记录原始缩放
	original_scale = scale
	
	# 调用卡槽的 place_card 方法
	if slot.place_card(self):
		parent_slot = slot
		cardCurrentState = cardState.fixed
		print("卡片 %s 已放入卡槽 %s" % [name, slot.name])
	else:
		print("警告: 无法将卡片放入卡槽")
		cardCurrentState = cardState.fixed

# 从卡槽中移除卡片
func remove_from_slot() -> void:
	if parent_slot == null:
		return
	
	# 获取场景树引用
	var tree = get_tree()
	if tree == null or tree.root == null:
		push_error("无法获取场景树")
		return
	
	# 保存当前的全局位置
	var saved_global_position = global_position
	
	# 确定目标父节点（优先使用原始父节点，否则查找 CardManager）
	var target_parent = original_parent
	if target_parent == null or not is_instance_valid(target_parent):
		target_parent = tree.root.find_child("CardManager", true, false)
		if target_parent == null:
			# 如果找不到 CardManager，使用根节点的第一个有效容器
			target_parent = tree.root.get_child(0)
	
	# 从卡槽移除
	if parent_slot.has_method("remove_card"):
		parent_slot.remove_card()
	else:
		# 手动移除
		if get_parent() == parent_slot:
			parent_slot.remove_child(self)
	
	# 添加到目标父节点
	if target_parent:
		target_parent.add_child(self)
		
		# 恢复全局位置
		global_position = saved_global_position
		
		# 恢复原始缩放
		scale = original_scale
		
		# 重置 z_index
		z_index = 0
		
		print("卡片 %s 已从卡槽 %s 移除，移动到 %s" % [name, parent_slot.name, target_parent.name])
	
	# 清除卡槽引用
	parent_slot = null
