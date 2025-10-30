extends Node

## 卡片射出管理器（全局单例）
## 提供全局可访问的 shoot_card 功能

# 卡片预制体场景引用
var remains_card_scene: PackedScene
var scene_card_scene: PackedScene
var character_card_scene: PackedScene
var dialogue_card_scene: PackedScene

# 目标容器节点（卡片将被添加到这个节点下）
var target_container: Node = null

func _ready() -> void:
	# 预加载卡片场景
	remains_card_scene = load("res://assets/remains/remains_card.tscn")
	scene_card_scene = load("res://assets/terrain小地形/terrain_card.tscn")
	character_card_scene = load("res://assets/character/character_card.tscn")
	dialogue_card_scene = load("res://dialogue/dialogue_card.tscn")

## 设置卡片容器（通常在游戏初始化时调用）
func set_target_container(container: Node) -> void:
	target_container = container

## 射出卡片（全局调用接口）
## @param card_name: 卡片名称（String）或 Dialogue 对象
## @param start_pos: 起始位置
## @param end_pos: 目标位置（如果为 Vector2.ZERO 则自动查找）
## @param container: 可选的容器节点，不指定则使用默认容器
func shoot_card(card_name: Variant, start_pos: Vector2, end_pos: Vector2 = Vector2.ZERO, container: Node = null) -> Control:
	# 确定使用哪个容器
	var actual_container = container if container != null else target_container
	
	if not is_instance_valid(actual_container):
		push_error("CardShooter: 未设置目标容器，无法射出卡片")
		return null
	
	# 1. 根据名称创建卡片
	var card = _create_card_by_name(card_name)
	if not card:
		push_error("卡片创建失败: " + card_name)
		return null
	
	# 2. 设置初始位置和缩放
	card.position = start_pos
	card.scale = Vector2.ZERO
	
	# 3. 添加到场景树
	actual_container.add_child(card)
	
	# 4. 等待一帧，确保 _ready() 完成，Label 已更新
	await get_tree().process_frame
	
	# 5. 在区域内查找同类型同名的卡片（用于自动堆叠）
	var target_stack_card = find_same_type_and_label_card(card, start_pos)
	
	# 6. 确定目标位置
	if target_stack_card:
		# 如果找到可堆叠的卡片，计算堆叠后的实际位置
		var stack_index = target_stack_card.get_total_stack_size() if target_stack_card.has_method("get_total_stack_size") else 0
		var stack_offset = card.stack_offset if "stack_offset" in card else Vector2(0, 15)
		var final_offset = stack_offset * (stack_index + 1)
		end_pos = target_stack_card.global_position + final_offset
	elif end_pos == Vector2.ZERO:
		# 否则自动查找空闲位置
		end_pos = find_empty_position(start_pos)
	
	# 7. 播放射出动画
	await _play_shoot_animation(card, end_pos)
	
	# 8. 动画完成后，如果找到可堆叠的卡片，执行堆叠
	if target_stack_card and is_instance_valid(target_stack_card):
		# 堆叠时，z_index 由 stack_on_card 函数设置
		card.stack_on_card(target_stack_card)
	else:
		# 否则设置为固定状态，恢复正常 z_index
		if "cardCurrentState" in card and "cardState" in card:
			card.cardCurrentState = card.cardState.fixed
			card.original_position = card.position
		card.z_index = 0
	
	return card

## 根据卡片名称创建卡片实例（内部辅助函数）
## 支持传入 Dialogue 对象作为 card_name 参数来创建对话卡片
func _create_card_by_name(card_name: Variant) -> Control:
	# 检查是否是 Dialogue 对象（对话卡片）
	if card_name is Dialogue:
		if not dialogue_card_scene:
			push_error("对话卡片场景未加载")
			return null
		var dialogue: Dialogue = card_name
		var card = dialogue_card_scene.instantiate()
		card.dialogue_content = dialogue.content
		card.dialogue_type = dialogue.type
		return card
	
	# 否则按字符串名称在 GameData 中查找
	var result = GameData.find_card_data(card_name)
	
	if result.is_empty():
		push_warning("未找到卡片数据: " + str(card_name))
		return null
	
	var card_data = result["data"]
	var card_type = result["type"]
	
	# 根据类型创建对应的卡片
	if card_type == "remains" and remains_card_scene:
		var card = remains_card_scene.instantiate()
		if card.has_method("initialize_from_csv"):
			card.initialize_from_csv(card_data)
		return card
	
	if card_type == "scene" and scene_card_scene:
		var card = scene_card_scene.instantiate()
		if card.has_method("initialize_from_scene_data"):
			card.initialize_from_scene_data(card_data)
		return card
	
	if card_type == "character" and character_card_scene:
		return character_card_scene.instantiate()
	
	return null

## 查找空闲位置
func find_empty_position(reference_pos: Vector2, search_radius: float = 200.0) -> Vector2:
	var max_attempts = 30
	var min_distance = 100.0
	var max_distance = search_radius
	
	for i in range(max_attempts):
		var angle = randf() * TAU
		var distance = randf_range(min_distance, max_distance)
		var test_position = reference_pos + Vector2(cos(angle), sin(angle)) * distance
		
		if is_position_empty(test_position):
			return test_position
	
	# 如果没有找到合适位置，返回参考位置下方
	return reference_pos + Vector2(0, 150)

## 检查位置是否为空
func is_position_empty(test_pos: Vector2, safe_distance: float = 90.0) -> bool:
	var cards = get_tree().get_nodes_in_group("Cards")
	
	for card in cards:
		if not is_instance_valid(card):
			continue
		var distance = card.global_position.distance_to(test_pos)
		if distance < safe_distance:
			return false
	
	return true

## 查找同类型且同名的卡片（用于自动堆叠）
func find_same_type_and_label_card(new_card: Control, reference_pos: Vector2, search_radius: float = 300.0) -> Control:
	# 获取新卡片的类型（使用脚本路径作为类型标识）
	var new_card_script = new_card.get_script()
	if not new_card_script:
		return null
	
	# 获取新卡片的 label 文本
	var new_card_label = ""
	var label_node = new_card.get_node_or_null("Control/ColorRect/Label")
	if label_node and label_node is Label:
		new_card_label = label_node.text
	
	# 如果没有 label，无法匹配
	if new_card_label == "":
		return null
	
	# 在搜索范围内查找所有卡片
	var cards = get_tree().get_nodes_in_group("Cards")
	var matching_cards: Array[Control] = []
	
	for card in cards:
		if not is_instance_valid(card) or card == new_card:
			continue
		
		# 只检测牌堆最上面的卡片（即没有其他卡片堆叠在其上的卡片）
		if "stacked_cards" in card and not card.stacked_cards.is_empty():
			continue
		
		# 检查距离
		var distance = card.global_position.distance_to(reference_pos)
		if distance > search_radius:
			continue
		
		# 检查类型是否相同（比较脚本路径）
		var card_script = card.get_script()
		if not card_script or card_script.resource_path != new_card_script.resource_path:
			continue
		
		# 检查 label 是否相同
		var card_label_node = card.get_node_or_null("Control/ColorRect/Label")
		if not card_label_node or not card_label_node is Label:
			continue
		
		var card_label_text = card_label_node.text
		if card_label_text == new_card_label:
			# 检查卡片是否允许堆叠
			if "can_accept_stack" in card and not card.can_accept_stack:
				continue
			
			# 检查卡片类型（不能堆叠到 selling 或 architecture 类型上）
			if "card_type" in card and "cardType" in card:
				if card.card_type == card.cardType.selling or card.card_type == card.cardType.architecture:
					continue
			
			matching_cards.append(card)
	
	# 如果找到匹配的卡片，返回最近的一张
	if matching_cards.size() > 0:
		var closest_card: Control = matching_cards[0]
		var closest_distance = closest_card.global_position.distance_to(reference_pos)
		
		for card in matching_cards:
			var dist = card.global_position.distance_to(reference_pos)
			if dist < closest_distance:
				closest_distance = dist
				closest_card = card
		
		return closest_card
	
	return null

## 播放射出动画（内部辅助函数）
func _play_shoot_animation(card: Control, end_pos: Vector2) -> void:
	# 设置高z_index，避免被其他卡片遮挡
	card.z_index = 100
	
	# 第一阶段：缩放出现
	var tween1 = create_tween()
	tween1.set_trans(Tween.TRANS_BACK)
	tween1.set_ease(Tween.EASE_OUT)
	tween1.tween_property(card, "scale", Vector2.ONE * 0.5, 0.2)
	
	await tween1.finished
	
	# 第二阶段：射出到目标位置
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.set_trans(Tween.TRANS_CUBIC)
	tween2.set_ease(Tween.EASE_OUT)
	tween2.tween_property(card, "position", end_pos, 0.5)
	tween2.tween_property(card, "scale", Vector2.ONE, 0.5)
	
	await tween2.finished
	
	# 第三阶段：反弹效果
	var tween3 = create_tween()
	tween3.tween_property(card, "scale", Vector2.ONE * 1.1, 0.1)
	tween3.tween_property(card, "scale", Vector2.ONE, 0.1)
	
	await tween3.finished



