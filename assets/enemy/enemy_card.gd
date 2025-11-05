extends "res://card.gd"
class_name EnemyCard

# 敌人卡片脚本
# 继承自基础卡片的所有功能

# 敌人属性
@export var enemy_hp: int = 100
@export var enemy_atk: int = 10
@export var enemy_def: int = 5

# 属性标签组件引用
var attribute_labels: AttributeLabels = null

func _ready() -> void:
	super._ready()
	# 自动获取属性标签组件引用
	attribute_labels = get_node_or_null("Control/ColorRect/AttributeLabels")
	update_stat_labels()
	
	# 敌人卡片的特殊初始化
	print("敌人卡片 %s 已创建 [HP:%d ATK:%d DEF:%d]" % [name, enemy_hp, enemy_atk, enemy_def])

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

