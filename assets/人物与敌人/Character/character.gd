@tool
class_name  Character
extends "res://assets/人物与敌人/battle_card.gd"

@export var character: CharacterCard : set = set_character_stats# 引用 characters 目录下的资源

func _ready() -> void:
	super._ready()
	# 角色生成时发送食物需求更新信号
	if not Engine.is_editor_hint():
		Events.food_need_update.emit(2)
		_update_features()

func _exit_tree() -> void:
	# 角色被删除时发送食物需求减少信号（排除拖拽时的 reparent 情况）
	if is_queued_for_deletion():
		Events.food_need_update.emit(-2)

func get_battle_resource() -> BattleStates:
	return character

func set_character_stats(value: CharacterCard) -> void:
	character = value
	_connect_and_update(character)

func _update_battle_card() -> void:
	if character == null:
		return
	super._update_battle_card()
	character.HP = character.MAX_HP
	update_stats()

func _update_features() -> void:
	for card in character.左右手:
		if card is ItemCard:
			if card.添加特性 != "" and not character.特性.has(card.添加特性):
				character.特性.append(card.添加特性)
				print("【Character】初始化添加特性：", card.添加特性, " 当前特性：", character.特性)
				# 标记这件物品的特性已经在角色初始化阶段应用过一次，
				# 后续第一次被放入背包槽位时就不要再重复加成
				card.set_meta("init_applied", true)
		if card is EquipmentCard:
			print("【Character】初始化添加装备效果：", card.equip_type, " 当前装备效果：", card.equip_effect)
			if card.need_power < character.POW:
				print("【Character】力量足够，添加装备效果：", card.equip_type, " 当前装备效果：", card.equip_effect)
				match card.equip_type:
					0:character.ATK += card.equip_effect
					1:character.DEF += card.equip_effect
				# 标记这件装备的效果已经在角色初始化阶段应用过一次，
				# 后续第一次被放入背包槽位时就不要再重复加成
				card.set_meta("init_applied", true)
