extends "res://baggable_card.gd"
class_name Item

# 道具卡片特有属性
# 道具卡片：具有各种特殊效果，是物品
# value 和 is_relic 已在父类 BaggableCard 中定义
@export var effect_type: String = ""  # 效果类型（如 "heal", "buff", "debuff" 等）
@export var effect_power: int = 0  # 效果强度
@export var is_consumable: bool = false  # 是否是消耗品
@export var effect_description: String = ""  # 效果描述

# 效果标签引用
var effect_label: Label = null
# 价值标签引用
var value_label: Label = null

func _ready() -> void:
	super._ready()
	# 道具继承自 BaggableCard，可以放入背包、在商店出售
	# 获取效果标签
	var effect_lbl = get_node_or_null("Control/ColorRect/EffectLabel")
	if effect_lbl:
		effect_label = effect_lbl
		update_effect_label()
	
	# 获取价值标签
	var val_lbl = get_node_or_null("Control/ColorRect/ValueLabel")
	if val_lbl:
		value_label = val_lbl
		update_value_label()

# 从数据初始化（CardFactory会调用）
func init_from_data(data: Dictionary) -> void:
	print("【道具卡片】init_from_data 被调用，数据: %s" % str(data.keys()))
	
	# 设置价值
	if data.has("VALUE"):
		var value_str = str(data["VALUE"])
		if value_str.is_valid_int():
			value = int(value_str)
			print("【道具卡片】设置 VALUE = %d" % value)
			update_value_label()
	
	# 设置是否是遗物
	if data.has("是否是遗物"):
		var relic_str = str(data["是否是遗物"]).to_upper()
		is_relic = (relic_str == "TRUE" or relic_str == "是")
		print("【道具卡片】设置 is_relic = %s" % is_relic)
	
	# 使用父类的统一装备效果解析方法
	init_equip_effects_from_data(data)

# 更新效果标签显示
func update_effect_label() -> void:
	if effect_label and not effect_type.is_empty():
		effect_label.text = "%s +%d" % [effect_type, effect_power]

# 更新价值标签显示
func update_value_label() -> void:
	if value_label:
		value_label.text = "价值: %d" % value

# 使用道具（触发效果）
func use_item(target: Node = null) -> bool:
	if not can_use():
		return false
	
	var success = apply_effect(target)
	
	if success and is_consumable:
		# 如果是消耗品，使用后删除
		queue_free()
	
	return success

# 检查是否可以使用
func can_use() -> bool:
	return not effect_type.is_empty()

# 应用效果
func apply_effect(target: Node) -> bool:
	if target == null:
		return false
	
	match effect_type:
		"heal":
			# 治疗效果
			if target is CharacterCard:
				target.modify_hp(effect_power)
				print("道具 %s 对 %s 使用，恢复 %d HP" % [name, target.name, effect_power])
				return true
		"atk_buff":
			# 攻击力增强
			if target is CharacterCard:
				target.modify_atk(effect_power)
				print("道具 %s 对 %s 使用，增加 %d ATK" % [name, target.name, effect_power])
				return true
		"def_buff":
			# 防御力增强
			if target is CharacterCard:
				target.modify_defense(effect_power)
				print("道具 %s 对 %s 使用，增加 %d DEF" % [name, target.name, effect_power])
				return true
		_:
			print("未知效果类型: %s" % effect_type)
			return false
	
	return false

# 设置道具属性
func set_item_stats(item_value: int, eff_type: String, power: int, consumable: bool = false) -> void:
	value = item_value
	effect_type = eff_type
	effect_power = power
	is_consumable = consumable
	update_effect_label()
