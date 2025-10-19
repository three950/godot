extends Node2D

# 卡片预制体场景
@export var card_scene: PackedScene
# 卡槽容器
@export var slot_container: HBoxContainer

# 商品数据列表（用于随机选择）
var selling_items = [
	{"name": "鱼", "texture_path": "res://assets/food/fish.jpg"},
	{"name": "肉", "texture_path": "res://assets/food/meat.png"},
	{"name": "盾牌", "texture_path": "res://assets/equipment/armour防具/盾牌.png"},
	{"name": "锥", "texture_path": "res://assets/equipment/weapon/锥.jpg"},
]

# 卡槽数组，用于存储卡槽节点
var slots: Array[Control] = []

func _ready() -> void:
	if slot_container == null:
		push_error("slot_container 未设置！")
		return
	
	# 确保容器不阻挡鼠标事件和不裁剪内容
	slot_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_container.clip_contents = false
	
	generate_shop()

func generate_shop() -> void:
	# 创建8个卡槽
	for i in range(8):
		var slot = create_slot(i)
		slots.append(slot)
		slot_container.add_child(slot)
	
	# 第一个卡槽：固定的建筑卡片（architecture 类型）
	create_architecture_card(slots[0], "探窟家协会", "res://assets/neutral_buildings/Association_of_Grotters.png")
	
	# 从第2个卡槽开始，按顺序放置3个商品卡片（selling 类型）
	# 创建一个临时数组并打乱顺序，确保不重复
	var shuffled_items = selling_items.duplicate()
	shuffled_items.shuffle()
	
	for i in range(3):
		var slot_index = i + 1  # 卡槽 1, 2, 3
		var item_data = shuffled_items[i]
		create_selling_card(slots[slot_index], item_data["name"], item_data["texture_path"])

# 创建卡槽
func create_slot(index: int) -> Control:
	var slot = Control.new()
	slot.name = "Slot_" + str(index)
	slot.custom_minimum_size = Vector2(88, 115)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 允许鼠标事件穿透
	slot.clip_contents = false  # 不裁剪超出边界的内容
	
	# 添加视觉边框
	var panel = Panel.new()
	panel.size = Vector2(88, 115)
	panel.modulate = Color(0.7, 0.7, 0.7, 0.6)  # 半透明灰色背景
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 允许鼠标事件穿透
	slot.add_child(panel)
	
	# 添加边框效果
	var border = ColorRect.new()
	border.size = Vector2(88, 115)
	border.color = Color(0.5, 0.5, 0.5, 0.8)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(border)
	
	var inner = ColorRect.new()
	inner.position = Vector2(2, 2)
	inner.size = Vector2(84, 111)
	inner.color = Color(0.2, 0.2, 0.2, 0.3)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(inner)
	
	return slot

# 创建建筑类型卡片（不可拖拽）
func create_architecture_card(slot: Control, card_name: String, texture_path: String) -> void:
	var card_instance = card_scene.instantiate()
	card_instance.name = "Card_" + card_name
	
	# 设置卡片类型为 architecture
	card_instance.card_type = 2  # cardType.architecture
	
	# 设置卡片位置（相对于卡槽）
	card_instance.position = Vector2(0, 0)
	
	# 设置卡片内容
	setup_card_content(card_instance, card_name, texture_path)
	
	# 将卡片添加到卡槽
	slot.add_child(card_instance)
	
	print("创建建筑卡片: " + card_name)

# 创建商品类型卡片（可拖拽，但会回到原位）
func create_selling_card(slot: Control, card_name: String, texture_path: String) -> void:
	var card_instance = card_scene.instantiate()
	card_instance.name = "Card_" + card_name
	
	# 设置卡片类型为 selling
	card_instance.card_type = 1  # cardType.selling
	
	# 设置卡片位置（相对于卡槽）
	card_instance.position = Vector2(0, 0)
	
	# 设置卡片内容
	setup_card_content(card_instance, card_name, texture_path)
	
	# 将卡片添加到卡槽
	slot.add_child(card_instance)
	
	print("创建商品卡片: " + card_name)

# 设置卡片内容（纹理和文本）
func setup_card_content(card_instance: Control, card_name: String, texture_path: String) -> void:
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
	label.text = card_name
