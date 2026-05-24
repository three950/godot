class_name CharacterCard
extends BattleStates

const EQUIPMENT_SLOT_WEAPON := "weapon"
const EQUIPMENT_SLOT_armor := "armor"

@export var POW:int : set = set_POW
@export var aware:int
@export var card_scene:PackedScene = load("res://assets/人物与敌人/Character/character.tscn")

func set_POW(value: int) -> void:
	POW = value

@export var 武器: ThingsCard : set = set_weapon
@export var 防具: ThingsCard : set = set_armor
@export var 特性 : Array[String]

var _initial_equipment_effects_applied: bool = false


func set_weapon(value: ThingsCard) -> void:
	# 人物每种装备最多只有一件；字段变化时通知所有 2D/3D 卡面刷新装备图标。
	武器 = value
	stats_changed.emit()


func set_armor(value: ThingsCard) -> void:
	# 防具同样是单槽位数据。
	防具 = value
	stats_changed.emit()


func claim_initial_equipment_effects() -> bool:
	# 同一个 CharacterCard 可能被主界面卡和 3D 卡 SubViewport 同时实例化。
	# 初始化装备效果只能应用一次，否则卸装时只扣一次会留下重复加成。
	if _initial_equipment_effects_applied:
		return false
	_initial_equipment_effects_applied = true
	return true


func apply_initial_equipment_changes_once() -> void:
	if not claim_initial_equipment_effects():
		return

	_apply_equipment_card_changes(武器)
	_apply_equipment_card_changes(防具)
	stats_changed.emit()


func sync_equipment_slots(weapon_card: ThingsCard, armor_card: ThingsCard) -> void:
	# 背包 UI 以槽位里的真实卡片为准；这里统一处理字段、属性、特性和刷新通知。
	var did_change_equipment := false
	if 武器 != weapon_card:
		_replace_equipment_slot(EQUIPMENT_SLOT_WEAPON, weapon_card)
		did_change_equipment = true
	if 防具 != armor_card:
		_replace_equipment_slot(EQUIPMENT_SLOT_armor, armor_card)
		did_change_equipment = true
	if did_change_equipment:
		stats_changed.emit()


func equip_card_by_type(equipment_card: EquipmentCard) -> ThingsCard:
	if equipment_card == null:
		return null

	return replace_equipment_slot(_slot_name_for_equipment_card(equipment_card), equipment_card)


func replace_equipment_slot(slot_name: String, next_card: ThingsCard) -> ThingsCard:
	var previous_card := _get_equipment_slot(slot_name)
	if previous_card == next_card:
		stats_changed.emit()
		return previous_card

	_replace_equipment_slot(slot_name, next_card)
	stats_changed.emit()
	return previous_card


func unequip_from_slot(slot_name: String, expected_card: ThingsCard = null) -> bool:
	var current_card := _get_equipment_slot(slot_name)
	if current_card == null:
		return false
	if expected_card != null and current_card != expected_card:
		return false

	_replace_equipment_slot(slot_name, null)
	stats_changed.emit()
	return true


func unequip_card(card: ThingsCard) -> bool:
	if card == null:
		return false
	if 武器 == card:
		return unequip_from_slot(EQUIPMENT_SLOT_WEAPON, card)
	if 防具 == card:
		return unequip_from_slot(EQUIPMENT_SLOT_armor, card)
	return false


func get_equipped_card_for_type(equipment_card: EquipmentCard) -> ThingsCard:
	if equipment_card == null:
		return null
	return _get_equipment_slot(_slot_name_for_equipment_card(equipment_card))


func _replace_equipment_slot(slot_name: String, next_card: ThingsCard) -> ThingsCard:
	var previous_card := _get_equipment_slot(slot_name)
	if previous_card == next_card:
		return previous_card

	if previous_card != null:
		_remove_equipment_card_changes(previous_card)
	_set_equipment_slot(slot_name, next_card)
	if next_card != null:
		_apply_equipment_card_changes(next_card)
	return previous_card


func _get_equipment_slot(slot_name: String) -> ThingsCard:
	match slot_name:
		EQUIPMENT_SLOT_WEAPON:
			return 武器
		EQUIPMENT_SLOT_armor:
			return 防具
		_:
			return null


func _set_equipment_slot(slot_name: String, card: ThingsCard) -> void:
	match slot_name:
		EQUIPMENT_SLOT_WEAPON:
			武器 = card
		EQUIPMENT_SLOT_armor:
			防具 = card


func _slot_name_for_equipment_card(equipment_card: EquipmentCard) -> String:
	# EquipmentCard 只负责说明自己是哪类装备；人物资源仍只关心固定槽位名。
	if equipment_card.get_slot_name() == EQUIPMENT_SLOT_armor:
		return EQUIPMENT_SLOT_armor
	return EQUIPMENT_SLOT_WEAPON


func _apply_equipment_card_changes(card: ThingsCard) -> void:
	if card == null:
		return

	if card.添加特性 != "" and not 特性.has(card.添加特性):
		特性.append(card.添加特性)
		print("【CharacterCard】添加装备特性：", card.添加特性, " 当前特性：", 特性)

	if card is EquipmentCard:
		var equipment_card := card as EquipmentCard
		print("【CharacterCard】添加装备效果：", equipment_card.get_slot_name(), " 当前装备效果：", equipment_card.get_effect_value())
		if equipment_card.can_be_used_by_power(POW):
			if equipment_card.is_weapon():
				ATK += equipment_card.get_effect_value()
			elif equipment_card.is_armor():
				DEF += equipment_card.get_effect_value()


func _remove_equipment_card_changes(card: ThingsCard) -> void:
	if card == null:
		return

	if card.添加特性 != "":
		特性.erase(card.添加特性)
		print("【CharacterCard】移除装备特性：", card.添加特性, " 当前特性：", 特性)

	if card is EquipmentCard:
		var equipment_card := card as EquipmentCard
		if equipment_card.can_be_used_by_power(POW):
			if equipment_card.is_weapon():
				ATK -= equipment_card.get_effect_value()
			elif equipment_card.is_armor():
				DEF -= equipment_card.get_effect_value()
