class_name CharacterCard
extends BattleStates

@export var POW:int : set = set_POW
@export var aware:int
@export var card_scene:PackedScene = load("res://assets/人物与敌人/Character/character.tscn")

func set_POW(value: int) -> void:
	POW = value
	set_ATK(POW)

@export var 左右手: Array[ThingsCard] = [null, null]
@export var 背包: Array[ThingsCard] = [null, null, null, null, null, null]
@export var 特性 : Array[String]
