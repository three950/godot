extends "res://card.gd"
class_name DialogueCard

# 对话卡片特有属性
@export var dialogue_content: String = ""
@export var dialogue_type: String = "normal"  # 对话类型: normal 或 reply

# 对话内容标签引用
var content_label: Label = null

func _ready() -> void:
	super._ready()
	# 获取标签引用
	var label = get_node_or_null("Control/ColorRect/Label")
	content_label = get_node_or_null("Control/ColorRect/ContentLabel")
	
	# Label 固定显示"对话"（用于堆叠识别，所有对话卡片会堆叠在一起）
	if label:
		label.text = "对话"
	# ContentLabel 显示实际对话内容
	if content_label:
		content_label.text = dialogue_content

# 更新对话内容显示
func update_content() -> void:
	if content_label:
		content_label.text = dialogue_content

# 设置对话内容
func set_dialogue(content: String, type: String = "normal") -> void:
	dialogue_content = content
	dialogue_type = type
	update_content()



