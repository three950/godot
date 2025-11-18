class_name CharacterCard
extends Resource
signal stats_changed

@export var ATK:int
@export var 意识:int
@export var 速度:int
@export var HP:int
@export var DEF:int

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
