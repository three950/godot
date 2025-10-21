extends Node2D

## 卡片管理器（重构版）
## 使用 GameData 单例获取角色数据，不再直接读取 CSV

# 卡片预制体场景
@export var card_scene: PackedScene
# 角色卡片预制体场景
@export var character_card_scene: PackedScene
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
	
	# 如果是角色卡片，设置属性（在add_child之后调用）
	if card_instance.has_method("set_character_stats"):
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
