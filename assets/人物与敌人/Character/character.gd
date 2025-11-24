@tool
class_name  Character
extends "res://assets/人物与敌人/battle_card.gd"

@export var character: CharacterCard : set = set_character_stats# 引用 characters 目录下的资源

func get_battle_resource() -> BattleStates:
	return character

func set_character_stats(value: CharacterCard) -> void:
	character = value
	_connect_and_update(character)
	_update_bag_panel()

func _update_battle_card() -> void:
	if character == null:
		return
	name_label.text = character.name
	portrait_rect.texture = character.portrait
	# ATK 会自动从 POW 初始化，无需手动设置
	character.HP = character.MAX_HP
	update_stats()

func _update_bag_panel() -> void:
	var bag_panel := get_node_or_null("Bag")
	if bag_panel:
		bag_panel.character = character
