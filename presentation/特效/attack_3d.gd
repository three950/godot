@tool
class_name Attack3D
extends Node3D

@export var damage: int = 0 : set = set_damage

@onready var damage_label: Label3D = $DamageLabel as Label3D


func _ready() -> void:
	_refresh_damage_label()


func set_damage(value: int) -> void:
	damage = maxi(value, 0)
	_refresh_damage_label()


func _refresh_damage_label() -> void:
	if damage_label == null:
		return

	# 伤害数字直接来自场景里的 Label3D；外部脚本只需要设置 damage 变量。
	damage_label.text = str(damage)
