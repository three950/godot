extends "res://card.gd"
class_name ItemCard

# 道具卡片特有属性
# 道具卡片：具有各种特殊效果，是物品
@export var value: int = 1  # 道具价值
@export var effect_type: String = ""  # 效果类型（如 "heal", "buff", "debuff" 等）
@export var effect_power: int = 0  # 效果强度
@export var is_consumable: bool = false  # 是否是消耗品
@export var effect_description: String = ""  # 效果描述

# 效果标签引用
var effect_label: Label = null

func _ready() -> void:
	super._ready()
	# 道具是物品，可以放入背包、在商店出售
	# 获取效果标签
	var effect_lbl = get_node_or_null("Control/ColorRect/EffectLabel")
	if effect_lbl:
		effect_label = effect_lbl
		update_effect_label()

# 更新效果标签显示
func update_effect_label() -> void:
	if effect_label and not effect_type.is_empty():
		effect_label.text = "%s +%d" % [effect_type, effect_power]

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

