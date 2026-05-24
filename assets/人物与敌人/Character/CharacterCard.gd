class_name CharacterCard
extends BattleStates

@export var POW:int : set = set_POW
@export var aware:int
@export var card_scene:PackedScene = load("res://assets/人物与敌人/Character/character.tscn")

func set_POW(value: int) -> void:
	POW = value

@export var 武器: ThingsCard : set = set_weapon
@export var 防具: ThingsCard : set = set_armour
@export var 特性 : Array[String]


func set_weapon(value: ThingsCard) -> void:
	# 人物每种装备最多只有一件；字段变化时通知所有 2D/3D 卡面刷新装备图标。
	武器 = value
	stats_changed.emit()


func set_armour(value: ThingsCard) -> void:
	# 防具同样是单槽位数据。
	防具 = value
	stats_changed.emit()
