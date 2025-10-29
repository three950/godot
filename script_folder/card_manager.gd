extends Node2D

## 卡片管理器（重构版）
## 使用 GameData 单例获取角色数据，不再直接读取 CSV

# 卡片预制体场景
@export var card_scene: PackedScene
# 角色卡片预制体场景
@export var character_card_scene: PackedScene
# 场景卡片预制体场景
@export var scene_card_scene: PackedScene
# 遗物卡片预制体场景
@export var remains_card_scene: PackedScene
# 卡片生成的起始位置
@export var start_position: Vector2 = Vector2(50, 50)
# 卡片之间的间距
@export var card_spacing: Vector2 = Vector2(100, 0)

func _ready() -> void:
	# 等待一帧，确保 GameData 单例已初始化
	await get_tree().process_frame
	
	if not GameData.is_data_loaded:
		push_warning("GameData 尚未加载，等待加载完成...")
		await get_tree().create_timer(0.1).timeout
	
	generate_cards()
	generate_scene_cards()

# ==================== Drag & Drop 系统 - 处理拖拽到空白区域 ====================

# 接受所有卡片拖放到主场景
func _can_drop_data(_at_position: Vector2, data) -> bool:
	# 只接受卡片拖放
	if typeof(data) == TYPE_DICTIONARY and data.has("card"):
		return true
	return false

# 将卡片放置到主场景的指定位置
func _drop_data(at_position: Vector2, data) -> void:
	if typeof(data) != TYPE_DICTIONARY or not data.has("card"):
		return
	
	var card = data["card"]
	
	# 确保卡片在 CardManager 下
	if card.get_parent() != self:
		var saved_global_pos = card.global_position
		var old_parent = card.get_parent()
		
		if old_parent:
			old_parent.remove_child(card)
		
		add_child(card)
		card.global_position = saved_global_pos
		
		print("卡片 %s 已从 %s 移动到 CardManager" % [card.name, old_parent.name if old_parent else "null"])
	
	# 将卡片移动到鼠标位置（转换为本地坐标）
	card.position = at_position - card.size / 2
	
	# 设置卡片状态
	if "cardCurrentState" in card and "cardState" in card:
		card.cardCurrentState = card.cardState.fixed
		card.original_position = card.position
	
	# 恢复卡片的正常缩放（可能从背包槽中缩放过）
	if "original_scale" in card and card.original_scale != Vector2.ZERO:
		card.scale = card.original_scale
	else:
		card.scale = Vector2.ONE
	
	# 重置 z_index
	card.z_index = 0
	
	print("卡片 %s 被拖拽到主场景位置: %s" % [card.name, card.position])

## 生成所有角色卡片
func generate_cards() -> void:
	var all_characters = GameData.get_all_characters()
	
	if all_characters.is_empty():
		push_error("没有可用的角色数据！")
		return
	
	print("开始生成 %d 张角色卡片..." % all_characters.size())
	
	for i in range(all_characters.size()):
		var char_data: CharacterData = all_characters[i]
		create_character_card(char_data, i)

## 生成场景卡片
func generate_scene_cards() -> void:
	# 在固定位置创建小洞穴场景卡片
	create_scene_card("小洞穴", Vector2(400, 300))
	print("场景卡片初始化完成")

## 创建单张角色卡片
func create_character_card(char_data: CharacterData, index: int) -> void:
	# 使用角色卡片场景
	var card_instance = character_card_scene.instantiate() if character_card_scene else card_scene.instantiate()
	
	# 设置卡片名称
	card_instance.name = "Card_" + char_data.character_name
	
	# 设置卡片位置
	card_instance.position = start_position + card_spacing * index
	
	# 查找并设置子节点
	var texture_rect = card_instance.get_node("Control/ColorRect/TextureRect")
	var label = card_instance.get_node("Control/ColorRect/Label")
	
	# 设置纹理（优先使用已加载的纹理）
	if char_data.character_texture:
		texture_rect.texture = char_data.character_texture
	elif char_data.texture_path != "":
		var texture = load(char_data.texture_path)
		if texture:
			texture_rect.texture = texture
		else:
			push_warning("无法加载纹理: " + char_data.texture_path)
	
	# 设置标签文本
	label.text = char_data.character_name
	
	# 设置 z_index 为固定值，防止渲染层级差异
	card_instance.z_index = 0
	
	# 添加到场景树（必须先添加，这样_ready()才会被调用，标签才能被获取）
	add_child(card_instance)
	
	# 如果是角色卡片，设置角色数据引用和属性（在add_child之后调用）
	if card_instance is CharacterCard:
		# 设置角色数据引用
		card_instance.character_data = char_data
		# 设置属性
		card_instance.set_character_stats(
			char_data.max_hp,
			char_data.atk,
			char_data.defense,
			char_data.equipment
		)
	
	print("✓ 生成角色卡片: %s (HP:%d ATK:%d DEF:%d)" % [
		char_data.character_name, 
		char_data.max_hp, 
		char_data.atk, 
		char_data.defense
	])

# 保留原来的create_card方法用于普通卡片
func create_card(char_name: String, texture_path: String, index: int) -> void:
	# 实例化卡片场景
	var card_instance = card_scene.instantiate()
	
	# 设置卡片名称
	card_instance.name = "Card_" + char_name
	
	# 设置卡片位置
	card_instance.position = start_position + card_spacing * index
	
	# 查找并设置子节点
	var texture_rect = card_instance.get_node("Control/ColorRect/TextureRect")
	var label = card_instance.get_node("Control/ColorRect/Label")
	
	# 加载并设置纹理
	var texture = load(texture_path)
	if texture:
		texture_rect.texture = texture
	else:
		push_warning("无法加载纹理: " + texture_path)
	
	# 设置标签文本
	label.text = char_name
	
	# 设置 z_index 为固定值，防止渲染层级差异
	card_instance.z_index = 0
	
	# 添加到场景树
	add_child(card_instance)
	
	print("生成卡片: " + char_name)

## 创建场景卡片
func create_scene_card(scene_name: String, spawn_pos: Vector2) -> void:
	if not scene_card_scene:
		push_error("场景卡片场景未设置！")
		return
	
	# 获取场景数据
	var scene_data = GameData.get_scene(scene_name)
	if scene_data.is_empty():
		push_error("未找到场景数据: " + scene_name)
		return
	
	# 实例化场景卡片
	var card_instance = scene_card_scene.instantiate()
	card_instance.name = "SceneCard_" + scene_name
	card_instance.position = spawn_pos
	
	# 添加到场景树
	add_child(card_instance)
	
	# 设置场景数据
	if card_instance.has_method("initialize_from_scene_data"):
		card_instance.initialize_from_scene_data(scene_data)
	
	# 设置纹理
	var texture_rect = card_instance.get_node_or_null("Control/ColorRect/TextureRect")
	var label = card_instance.get_node_or_null("Control/ColorRect/Label")
	
	if label:
		label.text = scene_name
	
	if texture_rect and scene_data.has("picture_path") and scene_data["picture_path"] != "":
		var texture_path = scene_data["picture_path"] + ".png"
		var texture = load(texture_path)
		if texture:
			texture_rect.texture = texture
		else:
			push_warning("无法加载纹理: " + texture_path)
	
	print("✓ 生成场景卡片: %s 在位置 %s" % [scene_name, spawn_pos])

## ==================== 通用卡片生成系统 ====================

## 射出卡片（自动处理：创建卡片、确定落点、播放动画、自动堆叠）
## 参数:
##   card_name: 卡片名称（自动识别遗物/场景/角色等类型）
##   start_pos: 起始位置
##   end_pos: 目标位置（留空则自动在起始位置周围查找空闲位置）
## 返回: 创建的卡片实例
func shoot_card(card_name: String, start_pos: Vector2, end_pos: Vector2 = Vector2.ZERO) -> Control:
	# 1. 根据名称创建卡片
	var card = _create_card_by_name(card_name)
	if not card:
		push_error("卡片创建失败: " + card_name)
		return null
	
	# 2. 设置初始位置和缩放
	card.position = start_pos
	card.scale = Vector2.ZERO
	
	# 3. 添加到场景树（这样 _ready() 才会被调用，卡片才能完全初始化）
	add_child(card)
	
	# 4. 等待一帧，确保 _ready() 完成，Label 已更新
	await get_tree().process_frame
	
	# 5. 在区域内查找同类型同名的卡片（用于自动堆叠）
	var target_stack_card = find_same_type_and_label_card(card, start_pos)
	
	# 6. 确定目标位置
	if target_stack_card:
		# 如果找到可堆叠的卡片，目标位置设为该卡片的位置
		end_pos = target_stack_card.global_position
	elif end_pos == Vector2.ZERO:
		# 否则自动查找空闲位置
		end_pos = find_empty_position(start_pos)
	
	# 7. 播放射出动画
	await _play_shoot_animation(card, end_pos)
	
	# 8. 动画完成后，如果找到可堆叠的卡片，执行堆叠
	if target_stack_card and is_instance_valid(target_stack_card):
		card.stack_on_card(target_stack_card)
	else:
		# 否则设置为固定状态
		if "cardCurrentState" in card and "cardState" in card:
			card.cardCurrentState = card.cardState.fixed
			card.original_position = card.position
	
	return card

## 根据卡片名称创建卡片实例（内部辅助函数）
func _create_card_by_name(card_name: String) -> Control:
	# 在 GameData 中统一查找（只查询一次）
	var result = GameData.find_card_data(card_name)
	
	if result.is_empty():
		push_warning("未找到卡片数据: " + card_name)
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
