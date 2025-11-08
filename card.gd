extends Control

# 信号：当有卡片堆叠到此卡片上时触发
signal card_stacked_on(stacked_card: Control)
# 信号：当卡片从堆叠中被移除时触发
signal card_removed_from_stack(removed_card: Control)
# 信号：当卡片固定位置时触发（拖动结束）
signal card_fixed()

enum cardState{fixed, dragging, bestacked}
enum cardType{normal, selling, architecture}  # 卡片类型
@export var cardCurrentState = cardState.fixed
@export var card_type: cardType = cardType.normal  # 默认为普通类型
@export var follow_target: Label
@export var stack_offset: Vector2 = Vector2(0, 15)  # 堆叠时的视觉偏移（Y轴留出label高度）
@export var can_accept_stack: bool = true  # 是否允许其他卡片堆叠在上面
@export var accept_value_only: bool = false  # 若为真，仅接受带有 value 属性的卡片

# 堆叠关系
var stacked_cards: Array[Control] = []  # 堆叠在这张卡片上的其他卡片
var parent_card: Control = null  # 如果这张卡片堆叠在其他卡片上，这是父卡片
var original_position: Vector2 = Vector2.ZERO  # 开始拖拽时的原始位置
var drag_offset_in_stack: Vector2 = Vector2.ZERO  # 在堆叠中的偏移量

# Area2D 重叠检测
var overlapping_cards: Array[Control] = []  # 当前与此卡片 Area2D 重叠的其他卡片

const DRAG_TEMP_Z := 100

func _ready() -> void:
	original_position = position
	
	# 连接 Area2D 信号
	var area2d = get_node_or_null("Area2D")
	if area2d:
		area2d.area_entered.connect(_on_area_entered)
		area2d.area_exited.connect(_on_area_exited)

func _process(_delta: float) -> void:
	match cardCurrentState:
		cardState.dragging:
			global_position = get_global_mouse_position() - size / 2
			z_index = DRAG_TEMP_Z
			# 同步更新子卡片层级与位置
			update_stacked_cards()
		cardState.fixed:
			pass
		cardState.bestacked:
			# 如果堆叠在其他卡片上，跟随父卡片的位置
			if parent_card != null:
				position = parent_card.position + drag_offset_in_stack

func _on_button_button_down() -> void:
	# architecture 类型不能拖拽
	if card_type == cardType.architecture:
		return
	
	cardCurrentState = cardState.dragging
	original_position = position
	
	# 如果这张卡片堆叠在其他卡片上，从堆叠中移除
	if parent_card != null:
		parent_card.remove_from_stack(self)
		parent_card = null
	
	# 将当前卡片移动到父节点的子节点列表末尾，使其显示在最上层
	get_parent().move_child(self, -1)
	
	# 同时将所有子卡片也移到后面，保持堆叠顺序
	move_stacked_cards_to_end()

func _on_button_button_up() -> void:
	z_index = 0
	# 恢复所有子卡片的 z_index 与位置
	update_stacked_cards()
	
	# 检测是否可以堆叠到其他卡片上
	var closest_card = find_closest_card()
	if closest_card != null:
		stack_on_card(closest_card)
	else:
		# 如果没有找到可堆叠的卡片，检查是否与背包区域重叠
		push_card_outside_bag_if_overlapping()
		
		# 设置为固定状态
		cardCurrentState = cardState.fixed
		original_position = position
		
		# 发射卡片固定信号
		card_fixed.emit()

# Area2D 信号处理：当有 Area 进入时
func _on_area_entered(area: Area2D) -> void:
	# 获取 Area2D 所属的卡片节点
	var other_card = area.get_parent()
	
	# 确保是有效的卡片节点且不是自己
	if other_card and other_card != self and other_card.is_in_group("Cards"):
		if other_card not in overlapping_cards:
			overlapping_cards.append(other_card)
			print("【Area2D】卡片 %s 进入重叠区域，当前重叠数: %d" % [other_card.name, overlapping_cards.size()])

# Area2D 信号处理：当有 Area 离开时
func _on_area_exited(area: Area2D) -> void:
	# 获取 Area2D 所属的卡片节点
	var other_card = area.get_parent()
	
	if other_card and other_card in overlapping_cards:
		overlapping_cards.erase(other_card)
		print("【Area2D】卡片 %s 离开重叠区域，当前重叠数: %d" % [other_card.name, overlapping_cards.size()])

# 查找最近的可堆叠卡片（从重叠的卡片中查找）
func find_closest_card() -> Control:
	# 只从当前重叠的卡片中查找
	var closest_card: Control = null
	var closest_distance_sq: float = INF
	
	for card in overlapping_cards:
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
		
		# 从重叠的卡片中找最近的一个
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
		
		# 发射卡片移除信号
		card_removed_from_stack.emit(card)

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

# 如果卡片与背包区域重叠，将其推到外面
func push_card_outside_bag_if_overlapping() -> void:
	# 查找所有背包面板
	var bag_panels = get_tree().get_nodes_in_group("BagPanel")
	if bag_panels.is_empty():
		return
	
	# 获取卡片的全局矩形
	var card_rect = Rect2(global_position, size)
	
	# 检查是否与任何背包面板重叠
	for bag_panel in bag_panels:
		if not is_instance_valid(bag_panel) or not bag_panel is Panel:
			continue
		
		# 获取背包面板的全局矩形
		var bag_rect = Rect2(bag_panel.global_position, bag_panel.size)
		
		# 如果卡片与背包区域重叠
		if card_rect.intersects(bag_rect):
			print("【卡片】检测到与背包重叠，正在移到外面...")
			
			# 计算需要移动的距离
			var push_offset = _calculate_push_offset(card_rect, bag_rect)
			
			# 移动卡片
			global_position += push_offset
			
			# 更新原始位置
			original_position = position
			
			print("【卡片】已移到背包外，偏移量: %s，新位置: %s" % [push_offset, global_position])
			break

# 计算将卡片推到背包外的偏移量（选择最短的推出方向）
func _calculate_push_offset(card_rect: Rect2, bag_rect: Rect2) -> Vector2:
	# 计算四个方向需要移动的距离
	var push_left = card_rect.end.x - bag_rect.position.x  # 向左推
	var push_right = bag_rect.end.x - card_rect.position.x  # 向右推
	var push_up = card_rect.end.y - bag_rect.position.y  # 向上推
	var push_down = bag_rect.end.y - card_rect.position.y  # 向下推
	
	# 找出最小的推动距离（刚好贴边）
	var margin = 1.0  # 最小间距，避免重叠
	var min_distance = INF
	var best_offset = Vector2.ZERO
	
	# 检查向左推
	if push_left > 0 and push_left < min_distance:
		min_distance = push_left
		best_offset = Vector2(-push_left - margin, 0)
	
	# 检查向右推
	if push_right > 0 and push_right < min_distance:
		min_distance = push_right
		best_offset = Vector2(push_right + margin, 0)
	
	# 检查向上推
	if push_up > 0 and push_up < min_distance:
		min_distance = push_up
		best_offset = Vector2(0, -push_up - margin)
	
	# 检查向下推
	if push_down > 0 and push_down < min_distance:
		min_distance = push_down
		best_offset = Vector2(0, push_down + margin)
	
	return best_offset
