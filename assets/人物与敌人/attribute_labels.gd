extends HBoxContainer
class_name AttributeLabels

# 标签引用
@onready var hp_label: Label = $HPLabel
@onready var atk_label: Label = $RightStats/ATKLabel
@onready var def_label: Label = $RightStats/DEFLabel

# 更新所有属性标签显示
func update_labels(hp_value: int, atk_value: int, def_value: int) -> void:
	hp_label.text = str(hp_value)
	atk_label.text = str(atk_value)
	def_label.text = str(def_value)
