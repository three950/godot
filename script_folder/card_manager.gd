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

## 创建遗物卡片
func create_remains_card(remains_name: String, spawn_pos: Vector2) -> Control:
	if not remains_card_scene:
		push_error("遗物卡片场景未设置！")
		return null
	
	# 获取遗物数据
	var remains_data = GameData.get_remains(remains_name)
	if remains_data.is_empty():
		push_error("未找到遗物数据: " + remains_name)
		return null
	
	# 实例化遗物卡片
	var card_instance = remains_card_scene.instantiate()
	card_instance.name = "RemainsCard_" + remains_name
	card_instance.position = spawn_pos
	
	# 添加到场景树
	add_child(card_instance)
	
	# 设置遗物数据
	if card_instance.has_method("initialize_from_csv"):
		card_instance.initialize_from_csv(remains_data)
	
	print("✓ 生成遗物卡片: %s 在位置 %s" % [remains_name, spawn_pos])
	return card_instance

## 创建遗物卡片（带射出动画）
func create_remains_card_with_animation(remains_name: String, start_pos: Vector2, end_pos: Vector2) -> void:
	# 创建卡片在起始位置
	var card = create_remains_card(remains_name, start_pos)
	if not card:
		return
	
	# 初始缩放为0
	card.scale = Vector2.ZERO
	
	# 创建动画
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 缩放动画（从中心放大）
	tween.tween_property(card, "scale", Vector2.ONE * 0.5, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 等待缩放完成
	await tween.finished
	
	# 射出动画
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.set_trans(Tween.TRANS_CUBIC)
	tween2.set_ease(Tween.EASE_OUT)
	
	# 位置动画（快速射出）
	tween2.tween_property(card, "position", end_pos, 0.5)
	# 同时恢复正常大小
	tween2.tween_property(card, "scale", Vector2.ONE, 0.5)
	
	await tween2.finished
	
	# 到达目标位置后的反弹效果
	var tween3 = create_tween()
	tween3.tween_property(card, "scale", Vector2.ONE * 1.1, 0.1)
	tween3.tween_property(card, "scale", Vector2.ONE, 0.1)
	
	print("遗物卡片 %s 射出动画完成" % remains_name)
