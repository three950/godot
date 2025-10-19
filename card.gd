extends Control
enum cardState{fixed, dragging, bestacked}
enum cardType{normal, selling, architecture}  # 卡片类型
@export var cardCurrentState = cardState.fixed
@export var card_type: cardType = cardType.normal  # 默认为普通类型
@export var follow_target: Label
@export var snap_distance: float = 80.0  # 吸附检测的最大距离
@export var stack_offset: Vector2 = Vector2(0, 15)  # 堆叠时的视觉偏移（Y轴留出label高度）

# 堆叠关系
var stacked_cards: Array[Control] = []  # 堆叠在这张卡片上的其他卡片
var parent_card: Control = null  # 如果这张卡片堆叠在其他卡片上，这是父卡片
var original_position: Vector2 = Vector2.ZERO  # 开始拖拽时的原始位置
var drag_offset_in_stack: Vector2 = Vector2.ZERO  # 在堆叠中的偏移量

func _ready() -> void:
	original_position = position

func _process(delta: float) -> void:
	match cardCurrentState:
		cardState.dragging:
			global_position = get_global_mouse_position() - size / 2
			z_index = 100
			# 同时更新所有子卡片的 z_index 和位置
			update_stacked_cards_z_index()
			update_stacked_cards_position()
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
	# 恢复所有子卡片的 z_index
	update_stacked_cards_z_index()
	
	# selling 类型拖动后回到原始位置
	if card_type == cardType.selling:
		position = original_position
		cardCurrentState = cardState.fixed
		return
	
	# 检测是否可以堆叠到其他卡片上
	var closest_card = find_closest_card()
	if closest_card != null:
		stack_on_card(closest_card)
	else:
		# 如果没有找到可堆叠的卡片，设置为固定状态
		cardCurrentState = cardState.fixed
		original_position = position

# 查找最近的可堆叠卡片
func find_closest_card() -> Control:
	var cards = get_tree().get_nodes_in_group("Cards")
	var closest_card: Control = null
	var closest_distance: float = snap_distance
	
	for card in cards:
		if card == self or card == parent_card:
			continue
		
		# 如果目标卡片堆叠在当前卡片上，跳过（避免循环堆叠）
		if is_card_in_stack(card):
			continue
		
		# 如果目标卡片是 selling 或 architecture 类型，不能堆叠在上面
		# 检查是否是同类型的 card 节点（有 card_type 属性）
		if card.get_script() == get_script():
			if card.card_type == cardType.selling or card.card_type == cardType.architecture:
				continue
		
		var distance = global_position.distance_to(card.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_card = card
	
	return closest_card

# 堆叠到目标卡片上
func stack_on_card(target_card: Control) -> void:
	# selling 和 architecture 类型不能被堆叠
	# 注意：architecture 理论上不会进入拖拽状态，但这里做防御性检查
	if card_type == cardType.selling or card_type == cardType.architecture:
		cardCurrentState = cardState.fixed
		return
	
	parent_card = target_card
	cardCurrentState = cardState.bestacked
	
	# 计算堆叠偏移量（基于目标卡片上已有的堆叠数量）
	var stack_index = target_card.stacked_cards.size()
	drag_offset_in_stack = stack_offset * (stack_index + 1)
	
	# 添加到目标卡片的堆叠列表
	target_card.add_to_stack(self)
	
	# 设置位置
	position = target_card.position + drag_offset_in_stack
	
	# 设置层级，堆叠的卡片层级更高
	z_index = target_card.z_index + stack_index + 1
	
	# 关键：调整场景树顺序，确保子卡片在父卡片后面，优先接收输入
	adjust_scene_tree_order()
	
	print("卡片 %s 堆叠到 %s 上" % [name, target_card.name])

# 添加卡片到堆叠
func add_to_stack(card: Control) -> void:
	# selling 和 architecture 类型不允许其他卡片堆叠在上面
	if card_type == cardType.selling or card_type == cardType.architecture:
		print("警告: %s 类型的卡片不允许堆叠其他卡片" % cardType.keys()[card_type])
		return
	
	if card not in stacked_cards:
		stacked_cards.append(card)
		print("  堆叠数量: %d" % stacked_cards.size())

# 从堆叠中移除卡片
func remove_from_stack(card: Control) -> void:
	if card in stacked_cards:
		stacked_cards.erase(card)
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

# 更新所有堆叠卡片的 z_index
func update_stacked_cards_z_index() -> void:
	for i in range(stacked_cards.size()):
		var card = stacked_cards[i]
		card.z_index = z_index + i + 1
		# 递归更新子卡片的子卡片
		if card.has_method("update_stacked_cards_z_index"):
			card.update_stacked_cards_z_index()

# 更新所有堆叠卡片的位置（拖动时子卡片跟随）
func update_stacked_cards_position() -> void:
	for i in range(stacked_cards.size()):
		var card = stacked_cards[i]
		card.position = position + card.drag_offset_in_stack
		# 递归更新子卡片的子卡片
		if card.has_method("update_stacked_cards_position"):
			card.update_stacked_cards_position()

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
