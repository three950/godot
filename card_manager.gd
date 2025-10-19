extends Node2D

# 卡片预制体场景
@export var card_scene: PackedScene
# 卡片生成的起始位置
@export var start_position: Vector2 = Vector2(50, 50)
# 卡片之间的间距
@export var card_spacing: Vector2 = Vector2(100, 0)

# 角色数据列表
var character_data = [
	{"name": "莉可", "texture_path": "res://assets/人物_莉可.png"},
	{"name": "雷古", "texture_path": "res://assets/人物_雷古.png"},
	{"name": "娜娜奇", "texture_path": "res://assets/人物_娜娜奇.png"}
]

func _ready() -> void:
	generate_cards()

func generate_cards() -> void:
	for i in range(character_data.size()):
		var char_data = character_data[i]
		create_card(char_data["name"], char_data["texture_path"], i)

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
