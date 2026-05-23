class_name CharacterCard
extends BattleStates

@export var POW:int : set = set_POW
@export var aware:int
@export var card_scene:PackedScene = load("res://assets/人物与敌人/Character/character.tscn")

func set_POW(value: int) -> void:
	POW = value

@export var 武器: Array[ThingsCard] = [null]
@export var 防具: Array[ThingsCard] = [null]
@export var 特性 : Array[String]
