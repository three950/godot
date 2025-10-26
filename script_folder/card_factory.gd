extends Node

## 卡片工厂类
## 提供通用的卡片创建方法，可以在项目的任何地方使用

# 根据 card_scene 路径创建卡片
# @param card_data: 包含卡片所有数据的字典，必须包含 "card_scene" 字段
# @param parent: 卡片的父节点（可选，如果为null则只创建不添加到场景树）
# @param position: 卡片的位置（默认 Vector2.ZERO）
# @param card_type: 卡片类型（可选，默认为 1 即 selling）
# @return: 创建的卡片实例，如果失败则返回 null
func create_by_card_scene(card_data: Dictionary, parent: Control = null, position: Vector2 = Vector2.ZERO, card_type: int = 1) -> Control:
	# 1. 获取并验证卡片场景路径
	var card_scene_path = card_data.get("card_scene", "")
	if card_scene_path == "":
		push_error("卡片数据缺少 card_scene 路径")
		return null
	
	# 2. 加载卡片场景
	var card_scene = load(card_scene_path) as PackedScene
	if card_scene == null:
		push_error("无法加载卡片场景: " + card_scene_path)
		return null
	
	# 3. 实例化卡片
	var card_instance = card_scene.instantiate()
	if card_instance == null:
		push_error("无法实例化卡片场景: " + card_scene_path)
		return null
	
	# 4. 设置卡片基本信息
	var card_name = card_data.get("名称", "未知卡片")
	card_instance.name = "Card_" + card_name
	
	# 5. 设置卡片类型
	if "card_type" in card_instance:
		card_instance.card_type = card_type
	
	# 6. 设置卡片位置
	card_instance.position = position
	
	# 7. 设置卡片数据（纹理和文本）
	_setup_card_data(card_instance, card_name, card_data)
	
	# 7.5. 如果卡片支持 init_from_data，调用它
	if card_instance.has_method("init_from_data"):
		card_instance.init_from_data(card_data)
	
	# 8. 如果提供了父节点，则添加到场景树
	if parent != null:
		parent.add_child(card_instance)
	
	print("创建卡片: %s (类型: %d, 场景: %s)" % [card_name, card_type, card_scene_path])
	
	return card_instance

# 内部方法：设置卡片数据（纹理和文本）
func _setup_card_data(card_instance: Control, card_name: String, card_data: Dictionary) -> void:
	# 尝试查找并设置Label节点（卡片名称）
	var label = card_instance.get_node_or_null("Control/ColorRect/Label")
	if label:
		label.text = card_name
	
	# 尝试设置纹理
	var texture_rect = card_instance.get_node_or_null("Control/ColorRect/TextureRect")
	if texture_rect:
		var texture_path = card_data.get("地址", "")
		if texture_path != "":
			# 尝试加载纹理（支持多种扩展名）
			var texture = _load_texture_with_extensions(texture_path)
			if texture:
				texture_rect.texture = texture
			else:
				push_warning("无法加载纹理: " + texture_path)

# 内部方法：尝试加载纹理（支持多种扩展名）
func _load_texture_with_extensions(base_path: String) -> Texture2D:
	# 如果已经有扩展名，直接加载
	if base_path.ends_with(".png") or base_path.ends_with(".jpg") or base_path.ends_with(".jpeg") or base_path.ends_with(".svg"):
		var texture = load(base_path)
		if texture:
			return texture
	
	# 否则尝试多种扩展名
	var extensions = [".png", ".jpg", ".jpeg", ".svg"]
	for ext in extensions:
		var full_path = base_path + ext
		var texture = load(full_path)
		if texture:
			return texture
	
	return null

