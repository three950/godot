@tool
class_name  Character
extends "res://assets/人物与敌人/battle_card.gd"

@export var character: CharacterCard : set = set_character_stats# 引用 characters 目录下的资源

func _ready() -> void:
	super._ready()
	# 角色生成时发送食物需求更新信号
	if not Engine.is_editor_hint():
		Events.food_need_update.emit(2)
		_init_equipment_features()

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

func _init_equipment_features() -> void:
	for card in character.左右手:
		if card is ItemCard:
			if card.添加特性 != "" and not character.特性.has(card.添加特性):
				character.特性.append(card.添加特性)
				print("【Character】初始化添加特性：", card.添加特性, " 当前特性：", character.特性)
