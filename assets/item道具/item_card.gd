extends "res://baggable_card.gd"
class_name ItemCard

# 道具卡片特有属性
# 道具卡片：具有各种特殊效果，是物品
# value 和 is_relic 已在父类 BaggableCard 中定义
@export var effect_type: String = ""  # 效果类型（如 "heal", "buff", "debuff" 等）
@export var effect_power: int = 0  # 效果强度
@export var is_consumable: bool = false  # 是否是消耗品
@export var effect_description: String = ""  # 效果描述

# 装备时效果（从CSV的"装备时"列解析）
var equip_effects: Dictionary = {}  # {"ATK": 100, "DEF": 5, "HP": -5, "special": "fast_fish"}

# 效果标签引用
var effect_label: Label = null

# 信号：装备到角色时
signal item_equipped(character: CharacterCard, item: ItemCard)
# 信号：从角色卸下时
signal item_unequipped(character: CharacterCard, item: ItemCard)

func _ready() -> void:
	super._ready()
	# 道具继承自 BaggableCard，可以放入背包、在商店出售
	# 获取效果标签
	var effect_lbl = get_node_or_null("Control/ColorRect/EffectLabel")
	if effect_lbl:
		effect_label = effect_lbl
		update_effect_label()

# 从数据初始化（CardFactory会调用）
func init_from_data(data: Dictionary) -> void:
	print("【道具卡片】init_from_data 被调用，数据: %s" % str(data.keys()))
	
	# 设置价值
	if data.has("VALUE"):
		var value_str = str(data["VALUE"])
		if value_str.is_valid_int():
			value = int(value_str)
			print("【道具卡片】设置 VALUE = %d" % value)
	
	# 设置是否是遗物
	if data.has("是否是遗物"):
		var relic_str = str(data["是否是遗物"]).to_upper()
		is_relic = (relic_str == "TRUE" or relic_str == "是")
		print("【道具卡片】设置 is_relic = %s" % is_relic)
	
	# 解析装备时效果
	if data.has("装备时"):
		var equip_str = str(data["装备时"])
		print("【道具卡片】找到'装备时'字段: '%s'" % equip_str)
		if not equip_str.is_empty():
			parse_equip_effects(equip_str)
		else:
			print("【道具卡片】警告：'装备时'字段为空")
	else:
		print("【道具卡片】警告：数据中没有'装备时'字段")

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

# ========== 装备系统 ==========

# 解析装备时效果（从CSV的"装备时"列）
# 格式: "ATK+100,DEF+5.一次性:HP-5" 或 "为角色添加fast_fish属性"
func parse_equip_effects(effect_string: String) -> void:
	if effect_string.is_empty():
		return
	
	equip_effects.clear()
	
	# 检查是否是特殊效果（如 fast_fish）
	if "fast_fish" in effect_string:
		equip_effects["special"] = "fast_fish"
		print("道具 %s 解析特殊效果: fast_fish" % name)
		return
	
	# 解析属性修改效果
	# 先移除"一次性:"前缀，然后分割
	var cleaned = effect_string.replace("一次性:", "")
	# 分割主要部分（用逗号和句号分隔）
	var parts = cleaned.replace(".", ",").split(",")
	
	for part in parts:
		part = part.strip_edges()
		
		if part.is_empty():
			continue
		
		# 解析 ATK+100, DEF+5, HP-5 格式
		if "ATK" in part:
			var value_str = part.replace("ATK", "").strip_edges()
			if value_str.is_valid_int():
				equip_effects["ATK"] = int(value_str)
		elif "DEF" in part:
			var value_str = part.replace("DEF", "").strip_edges()
			if value_str.is_valid_int():
				equip_effects["DEF"] = int(value_str)
		elif "HP" in part:
			var value_str = part.replace("HP", "").strip_edges()
			if value_str.is_valid_int():
				equip_effects["HP"] = int(value_str)
	
	print("道具 %s 解析装备效果: %s" % [name, str(equip_effects)])

# 应用装备效果到角色
func apply_equip_effects(character: CharacterCard) -> void:
	if character == null:
		return
	
	print("道具 %s 装备到角色 %s" % [name, character.name])
	print("  当前装备效果字典: %s" % str(equip_effects))
	
	# 应用属性修改
	if equip_effects.has("ATK"):
		character.modify_atk(equip_effects["ATK"])
		print("  ATK %+d" % equip_effects["ATK"])
	
	if equip_effects.has("DEF"):
		character.modify_defense(equip_effects["DEF"])
		print("  DEF %+d" % equip_effects["DEF"])
	
	if equip_effects.has("HP"):
		character.modify_hp(equip_effects["HP"])
		print("  HP %+d" % equip_effects["HP"])
	
	# 应用特殊效果
	if equip_effects.has("special"):
		var special_effect = equip_effects["special"]
		if character.has_method("add_special_effect"):
			character.add_special_effect(special_effect)
			print("  添加特殊效果: %s" % special_effect)
	
	# 发射装备信号
	item_equipped.emit(character, self)

# 移除装备效果
func remove_equip_effects(character: CharacterCard) -> void:
	if character == null:
		return
	
	print("道具 %s 从角色 %s 卸下" % [name, character.name])
	
	# 移除属性修改（反向应用）
	if equip_effects.has("ATK"):
		character.modify_atk(-equip_effects["ATK"])
		print("  ATK %+d" % (-equip_effects["ATK"]))
	
	if equip_effects.has("DEF"):
		character.modify_defense(-equip_effects["DEF"])
		print("  DEF %+d" % (-equip_effects["DEF"]))
	
	if equip_effects.has("HP"):
		character.modify_hp(-equip_effects["HP"])
		print("  HP %+d" % (-equip_effects["HP"]))
	
	# 移除特殊效果
	if equip_effects.has("special"):
		var special_effect = equip_effects["special"]
		if character.has_method("remove_special_effect"):
			character.remove_special_effect(special_effect)
			print("  移除特殊效果: %s" % special_effect)
	
	# 发射卸下信号
	item_unequipped.emit(character, self)

