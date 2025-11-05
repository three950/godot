extends HBoxContainer
class_name AttributeLabels

## 属性标签组件
## 封装 HP、ATK、DEF 三个属性的显示

# 标签引用
var hp_label: Label = null
var atk_label: Label = null
var def_label: Label = null

func _ready() -> void:
	# 获取标签引用
	hp_label = get_node_or_null("HPLabel")
	var right_stats = get_node_or_null("RightStats")
	if right_stats:
		atk_label = right_stats.get_node_or_null("ATKLabel")
		def_label = right_stats.get_node_or_null("DEFLabel")

# 更新所有属性标签显示
func update_labels(hp_value: int, atk_value: int, def_value: int) -> void:
	if hp_label:
		hp_label.text = "%d" % hp_value
	if atk_label:
		atk_label.text = "%d" % atk_value
	if def_label:
		def_label.text = "%d" % def_value

# 单独更新HP
func update_hp(value: int) -> void:
	if hp_label:
		hp_label.text = "%d" % value

# 单独更新ATK
func update_atk(value: int) -> void:
	if atk_label:
		atk_label.text = "%d" % value

# 单独更新DEF
func update_def(value: int) -> void:
	if def_label:
		def_label.text = "%d" % value

# 获取标签引用（供外部使用）
func get_hp_label() -> Label:
	return hp_label

func get_atk_label() -> Label:
	return atk_label

func get_def_label() -> Label:
	return def_label

