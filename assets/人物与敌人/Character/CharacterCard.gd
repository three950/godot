class_name CharacterCard
extends BattleStates

@export var POW:int : set = set_POW
@export var aware:int
@export var card_scene:PackedScene = load("res://assets/人物与敌人/Character/character.tscn")

func set_POW(value: int) -> void:
	POW = value

@export var 武器: ThingsCard : set = set_weapon
@export var 防具: ThingsCard : set = set_armor
@export var 特性 : Array[String]

var _base_attack_type_initialized: bool = false
var _base_attack_type: attackType = attackType.close


func set_weapon(value: ThingsCard) -> void:
	# 人物每种装备最多只有一件；字段变化时通知所有 2D/3D 卡面刷新装备图标。
	武器 = value
	stats_changed.emit()


func set_armor(value: ThingsCard) -> void:
	# 防具同样是单槽位数据。
	防具 = value
	stats_changed.emit()


func create_runtime_instance() -> CardInfo:
	var instance := super.create_runtime_instance() as CharacterCard
	if instance == null:
		return self

	# 特性数组会在装备穿脱时 append/erase，数组本身也要脱离原始 .tres。
	instance.特性 = 特性.duplicate()
	instance._base_attack_type = instance.attack_type
	instance._base_attack_type_initialized = true

	# 初始装备是运行时数据的一部分，只在私有化实例创建时结算，避免显示节点重复实例化时重复加成。
	instance._apply_equipment_card_changes(instance.武器)
	instance._apply_equipment_card_changes(instance.防具)
	return instance


func replace_weapon(next_card: WeaponCard) -> ThingsCard:
	# WeaponCard 本身就代表武器；换装时只处理“旧装备离开、新装备进入”。
	var previous_card := 武器
	if previous_card == next_card:
		stats_changed.emit()
		return previous_card

	if previous_card != null:
		_remove_equipment_card_changes(previous_card)
	武器 = next_card
	if next_card != null:
		_apply_equipment_card_changes(next_card)

	stats_changed.emit()
	return previous_card


func replace_armor(next_card: ArmorCard) -> ThingsCard:
	# ArmorCard 本身就代表防具；防具数值仍由 EquipmentCard.attack/DEF 决定。
	var previous_card := 防具
	if previous_card == next_card:
		stats_changed.emit()
		return previous_card

	if previous_card != null:
		_remove_equipment_card_changes(previous_card)
	防具 = next_card
	if next_card != null:
		_apply_equipment_card_changes(next_card)

	stats_changed.emit()
	return previous_card


func unequip_weapon(expected_card: ThingsCard = null) -> bool:
	if 武器 == null:
		return false
	if expected_card != null and 武器 != expected_card:
		return false

	replace_weapon(null)
	return true


func unequip_armor(expected_card: ThingsCard = null) -> bool:
	if 防具 == null:
		return false
	if expected_card != null and 防具 != expected_card:
		return false

	replace_armor(null)
	return true


func _apply_equipment_card_changes(card: ThingsCard) -> void:
	if card == null:
		return

	if card.添加特性 != "" and not 特性.has(card.添加特性):
		特性.append(card.添加特性)
		print("【CharacterCard】添加装备特性：", card.添加特性, " 当前特性：", 特性)

	if card is EquipmentCard:
		var equipment_card := card as EquipmentCard
		print("【CharacterCard】添加装备效果：", card.name, " 攻击：", equipment_card.attack, " 防御：", equipment_card.DEF)
		if equipment_card.can_be_used_by_power(POW):
			_apply_equipment_numeric_changes(equipment_card, 1)
			if card is WeaponCard:
				_apply_weapon_attack_type(card as WeaponCard)


func _remove_equipment_card_changes(card: ThingsCard) -> void:
	if card == null:
		return

	if card.添加特性 != "":
		特性.erase(card.添加特性)
		print("【CharacterCard】移除装备特性：", card.添加特性, " 当前特性：", 特性)

	if card is EquipmentCard:
		var equipment_card := card as EquipmentCard
		if equipment_card.can_be_used_by_power(POW):
			_apply_equipment_numeric_changes(equipment_card, -1)
			if card is WeaponCard:
				_restore_base_attack_type()


func _apply_equipment_numeric_changes(equipment_card: EquipmentCard, multiplier: int) -> void:
	# 装备有什么数值就加什么数值；武器和防具类型不参与攻防数值判断。
	if equipment_card.attack != 0:
		ATK += equipment_card.attack * multiplier
	if equipment_card.DEF != 0:
		DEF += equipment_card.DEF * multiplier


func _apply_weapon_attack_type(weapon_card: WeaponCard) -> void:
	# 传进来的类型已经是 WeaponCard，这里只读取武器特有的攻击方式。
	_ensure_base_attack_type_captured()
	match weapon_card.weapon_type:
		WeaponCard.WeaponType.remote:
			attack_type = attackType.remote
		_:
			attack_type = attackType.close


func _restore_base_attack_type() -> void:
	_ensure_base_attack_type_captured()
	attack_type = _base_attack_type


func _ensure_base_attack_type_captured() -> void:
	if _base_attack_type_initialized:
		return

	_base_attack_type = attack_type
	_base_attack_type_initialized = true
