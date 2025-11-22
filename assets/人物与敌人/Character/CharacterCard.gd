class_name CharacterCard
extends CardInfo
signal stats_changed
@export var POW:int
@export var aware:int
@export var speed:int
@export var MAX_HP:int
@export var DEF:int
@export var ATK:int
var HP:int

@export_group("左右手")
@export var left: String = ""
@export var right: String = ""

@export_group("背包")
@export var slot_1: String = ""
@export var slot_2: String = ""
@export var slot_3: String = ""
@export var slot_4: String = ""
@export var slot_5: String = ""
@export var slot_6: String = ""
