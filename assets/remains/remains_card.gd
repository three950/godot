extends "res://card.gd"
class_name RemainsCard

# 遗物卡片特有属性
@export var remains_name: String = ""  # 遗物名称
@export var grade: String = ""  # 等级
@export var effect: String = ""  # 效果
@export var attribute: String = ""  # 属性
@export var value: int = 0  # 遗物价值

# 标签引用
var name_label: Label = null
var grade_label: Label = null
var value_label: Label = null

func _ready() -> void:
	super._ready()
	# 自动获取标签引用
	var color_rect = get_node_or_null("Control/ColorRect")
	if color_rect:
		name_label = color_rect.get_node_or_null("NameLabel")
		var info_container = color_rect.get_node_or_null("InfoContainer")
		if info_container:
			grade_label = info_container.get_node_or_null("GradeLabel")
			value_label = info_container.get_node_or_null("ValueLabel")
	update_labels()

# 更新标签显示
func update_labels() -> void:
	if name_label:
		name_label.text = remains_name
	if grade_label:
		grade_label.text = "等级:%s" % grade
	if value_label:
		value_label.text = "价值:%d" % value

# 设置遗物属性
func set_remains_data(r_name: String, r_grade: String, r_effect: String, r_attribute: String, r_value: int) -> void:
	remains_name = r_name
	grade = r_grade
	effect = r_effect
	attribute = r_attribute
	value = r_value
	update_labels()

# 从CSV数据初始化遗物信息
func initialize_from_csv(csv_data: Dictionary) -> void:
	if csv_data.has("名称"):
		remains_name = csv_data["名称"]
	if csv_data.has("等级"):
		grade = str(csv_data["等级"])
	if csv_data.has("效果"):
		effect = csv_data["效果"]
	if csv_data.has("属性"):
		attribute = csv_data["属性"]
	if csv_data.has("value"):
		var value_str = str(csv_data["value"])
		if value_str.is_valid_int():
			value = int(value_str)
		else:
			value = 0
	
	update_labels()
