class_name CharacterCard
extends BattleStates

@export var POW:int : set = set_POW
@export var aware:int


func set_POW(value: int) -> void:
	POW = value
func set_ATK(value: int) -> void:
	ATK = POW

@export_group("左右手")
@export var left: CharacterCard = null
@export var right: CharacterCard = null

@export_group("背包")
@export var Slot1: CharacterCard = null
@export var Slot2: CharacterCard = null
@export var Slot3: CharacterCard = null
@export var Slot4: CharacterCard = null
@export var Slot5: CharacterCard = null
@export var Slot6: CharacterCard = null
