extends "res://card.gd"
class_name EnemyCard

# 敌人卡片脚本
# 继承自基础卡片的所有功能

# 敌人属性
@export var card_name: String = "敌人"  # 敌人名称
@export var enemy_hp: int = 100
@export var enemy_atk: int = 10
@export var enemy_def: int = 5

# 存储原始卡片数据
var card_data: Dictionary = {}

# 属性标签组件引用
var attribute_labels: AttributeLabels = null

func _ready() -> void:
	super._ready()
	# 自动获取属性标签组件引用
	attribute_labels = get_node_or_null("Control/ColorRect/AttributeLabels")
	
	# 更新显示
	update_display()
	update_stat_labels()
	
	# 敌人卡片的特殊初始化
	print("敌人卡片 %s 已创建 [HP:%d ATK:%d DEF:%d]" % [card_name, enemy_hp, enemy_atk, enemy_def])

# 更新属性标签显示
func update_stat_labels() -> void:
	if attribute_labels:
		attribute_labels.update_labels(enemy_hp, enemy_atk, enemy_def)

# 设置敌人属性
func set_enemy_stats(hp: int, atk: int, def: int) -> void:
	enemy_hp = hp
	enemy_atk = atk
	enemy_def = def
	update_stat_labels()

# 修改HP
func modify_hp(amount: int) -> void:
	enemy_hp += amount
	if enemy_hp < 0:
		enemy_hp = 0
	update_stat_labels()

# 修改ATK
func modify_atk(amount: int) -> void:
	enemy_atk += amount
	if enemy_atk < 0:
		enemy_atk = 0
	update_stat_labels()

# 修改防御
func modify_def(amount: int) -> void:
	enemy_def += amount
	if enemy_def < 0:
		enemy_def = 0
	update_stat_labels()

# 设置属性标签组件引用（手动设置）
func set_attribute_labels(labels: AttributeLabels) -> void:
	attribute_labels = labels
	update_stat_labels()

## 从数据字典初始化卡片（与CardFactory配合使用）
func init_from_data(data: Dictionary) -> void:
	card_data = data
	card_name = data.get("名称", "未知敌人")
	
	# 设置敌人属性
	enemy_hp = int(data.get("HP", 100))
	enemy_atk = int(data.get("ATK", 10))
	enemy_def = int(data.get("DEF", 5))
	
	# 更新显示
	update_display()
	update_stat_labels()

## 更新卡片显示（名称和图片）
func update_display() -> void:
	# 更新名称标签
	var label = get_node_or_null("Control/ColorRect/Label")
	if label:
		label.text = card_name
	
	# 更新图片（如果有地址数据）
	var texture_rect = get_node_or_null("Control/ColorRect/TextureRect")
	if texture_rect and card_data.has("地址"):
		var texture_path = card_data["地址"]
		if texture_path != "":
			# 尝试加载纹理
			if ResourceLoader.exists(texture_path + ".png"):
				var texture = load(texture_path + ".png")
				if texture:
					texture_rect.texture = texture
			elif ResourceLoader.exists(texture_path + ".jpg"):
				var texture = load(texture_path + ".jpg")
				if texture:
					texture_rect.texture = texture

## 获取卡片名称（用于合成系统等）
func get_card_name() -> String:
	return card_name

