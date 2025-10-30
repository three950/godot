extends "res://card.gd"
class_name DialogueCard

# 对话卡片特有属性
@export var dialogue_content: String = ""
@export var dialogue_type: String = "normal"  # 对话类型: normal 或 reply

# 对话内容标签引用
var content_label: Label = null

func _ready() -> void:
	super._ready()
	# 获取对话内容标签引用
	content_label = get_node_or_null("Control/ColorRect/ContentLabel")
	if content_label:
		update_content()

# 更新对话内容显示
func update_content() -> void:
	if content_label:
		content_label.text = dialogue_content

# 设置对话内容
func set_dialogue(content: String, type: String = "normal") -> void:
	dialogue_content = content
	dialogue_type = type
	update_content()


