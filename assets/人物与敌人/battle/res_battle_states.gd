class_name BattleStates
extends CardInfo

signal stats_changed

@export var MAX_HP := 1 : set = set_MAX_HP
@export var ATK: int : set = set_ATK
@export var speed: int : set = set_speed
enum attackType {close, remote}
@export var attack_type: attackType = attackType.close

var HP: int : set = set_HP
@export var DEF: int : set = set_DEF


func set_HP(value : int) -> void:
	HP = clampi(value, 0, MAX_HP)
	stats_changed.emit()


func set_MAX_HP(value : int) -> void:
	var diff := value - MAX_HP
	MAX_HP = value
	
	if diff > 0:
		HP += diff
	elif HP > MAX_HP:
		HP = MAX_HP
	
	stats_changed.emit()


func set_DEF(value : int) -> void:
	DEF = clampi(value, 0, 999)
	stats_changed.emit()


func set_ATK(value: int) -> void:
	ATK = value
	stats_changed.emit()


func set_speed(value: int) -> void:
	speed = value
	stats_changed.emit()


func take_damage(damage : int) -> void:
	if damage <= 0:
		return
	var actual_damage = clampi(damage - DEF, 0, damage)
	HP -= actual_damage


func heal(amount : int) -> void:
	HP += amount
