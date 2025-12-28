extends "res://assets/物品/things.gd"
class_name Remains
################################################
# 遗物卡片场景脚本 - 继承自 Things 以复用通用功能
enum Rarity {COMMON,FORTH,THRID,SECOND,FRIST,SUPER}
const RARITY_COLORS:={
	Rarity.COMMON:Color("cbcac7ff"),
	Rarity.FORTH:Color("b790a8ff"),
	Rarity.THRID:Color("b4749fff"),
	Rarity.SECOND:Color("bc5ea4ff"),
	Rarity.FRIST:Color("934185ff"),
	Rarity.SUPER:Color("7a2569ff"),
}

@onready var grade_label: Label = %LevelLabel

# 遗物资源引用
@export var remains: RemainsCard

func get_things_resource() -> ThingsCard:
	return remains

func _ready() -> void:
	super._ready()
	_update_remains_display()

func _update_remains_display() -> void:
	# 调用父类通用更新（设置 name, cardname, label, texture, value）
	_update_things_display()
	# 更新遗物特有的等级标签
	if remains and grade_label:
		grade_label.text = "等级:%s" % ThingsCard.遗物等级.keys()[remains.是遗物]

func set_stats(value: RemainsCard) -> void:
	remains = value
	if is_node_ready():
		_update_remains_display()

# 从CSV数据初始化遗物信息
func initialize_from_csv(csv_data: Dictionary) -> void:
	if remains == null:
		remains = RemainsCard.new()
	if csv_data.has("名称"):
		remains.name = csv_data["名称"]
	if csv_data.has("等级"):
		var grade_str = str(csv_data["等级"])
		# 尝试将等级字符串转换为枚举值
		for i in ThingsCard.遗物等级.size():
			if ThingsCard.遗物等级.keys()[i] == grade_str:
				remains.是遗物 = i
				break
	if csv_data.has("value"):
		var value_str = str(csv_data["value"])
		if value_str.is_valid_int():
			remains.value = int(value_str)
	
	if is_node_ready():
		_update_remains_display()
