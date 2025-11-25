class_name CharacterCard
extends BattleStates

@export var POW:int : set = set_POW
@export var aware:int
@export var card_scene:PackedScene = load("res://assets/人物与敌人/Character/character.tscn")

func set_POW(value: int) -> void:
	POW = value
func set_ATK(_value: int) -> void:
	ATK = POW
@export var 左右手: Array[CharacterCard] = [null, null]
@export var 背包: Array[CharacterCard] = [null, null, null, null, null, null]
