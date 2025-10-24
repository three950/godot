extends "res://baggable_card.gd"
class_name EquipmentCard

# 装备卡片特有属性
# 装备卡片：有防具和武器，可以和遗物合成新的装备，本身可以是遗物
enum EquipmentType { WEAPON, ARMOR, RELIC }
@export var equipment_type: EquipmentType = EquipmentType.WEAPON
# value 和 is_relic 已在父类 BaggableCard 中定义
@export var atk_bonus: int = 0  # 攻击力加成
@export var def_bonus: int = 0  # 防御力加成
@export var hp_bonus: int = 0  # 生命值加成
@export var special_effect: String = ""  # 特殊效果描述

# 装备标签引用
var stats_label: Label = null
var equipped_character: CharacterCard = null  # 装备在哪个角色上

func _ready() -> void:
	super._ready()
	# 装备继承自 BaggableCard，可以放入背包、在商店出售
	var stats_lbl = get_node_or_null("Control/ColorRect/StatsLabel")
	if stats_lbl:
		stats_label = stats_lbl
		update_stats_label()

# 更新属性标签显示
func update_stats_label() -> void:
	if not stats_label:
		return
	
	var stats_text = ""
	if atk_bonus > 0:
		stats_text += "ATK +%d " % atk_bonus
	if def_bonus > 0:
		stats_text += "DEF +%d " % def_bonus
	if hp_bonus > 0:
		stats_text += "HP +%d" % hp_bonus
	
	stats_label.text = stats_text.strip_edges()

# synthesis() 函数：和遗物合成新的装备
func synthesis() -> void:
	if stacked_cards.is_empty():
		return
	
	# 检查堆叠的卡片中是否有遗物或装备
	var has_relic = false
	var has_equipment = false
	
	for card in stacked_cards:
		if card is EquipmentCard:
			if card.is_relic:
				has_relic = true
			else:
				has_equipment = true
	
	# 如果同时有遗物和装备，可以合成
	if has_relic or (is_relic and has_equipment):
		start_synthesis()

# 开始合成
func start_synthesis() -> void:
	print("装备合成开始: %s" % name)
	# 这里应该调用 CardManager 来创建新装备
	# 具体实现需要配合你的 CardManager

# 装备到角色
func equip_to_character(character: CharacterCard) -> bool:
	if character == null:
		return false
	
	# 如果已经装备在其他角色上，先卸下
	if equipped_character != null:
		unequip()
	
	equipped_character = character
	
	# 应用装备加成
	if atk_bonus > 0:
		character.modify_atk(atk_bonus)
	if def_bonus > 0:
		character.modify_defense(def_bonus)
	if hp_bonus > 0:
		character.modify_hp(hp_bonus)
	
	print("装备 %s 已装备到 %s" % [name, character.name])
	return true

# 卸下装备
func unequip() -> void:
	if equipped_character == null:
		return
	
	# 移除装备加成
	if atk_bonus > 0:
		equipped_character.modify_atk(-atk_bonus)
	if def_bonus > 0:
		equipped_character.modify_defense(-def_bonus)
	if hp_bonus > 0:
		equipped_character.modify_hp(-hp_bonus)
	
	print("装备 %s 已从 %s 卸下" % [name, equipped_character.name])
	equipped_character = null

# 设置装备属性
func set_equipment_stats(eq_type: EquipmentType, equipment_value: int, atk: int = 0, def: int = 0, hp: int = 0, relic: bool = false) -> void:
	equipment_type = eq_type
	value = equipment_value
	atk_bonus = atk
	def_bonus = def
	hp_bonus = hp
	is_relic = relic
	update_stats_label()
