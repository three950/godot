@tool
class_name Enemy
extends "res://assets/人物与敌人/battle_card.gd"
@export var enemy: EnemyCard : set = set_enemy_stats# 引用 enemys 目录下的资源

func _ready() -> void:
	super._ready()

func get_battle_resource() -> BattleStates:
	return enemy

func set_enemy_stats(value: EnemyCard) -> void:
	enemy = value
	_connect_and_update(enemy)

func _update_battle_card() -> void:
	if enemy == null:
		return
	name = enemy.name  # 设置节点名称
	name_label.text = enemy.name
	portrait_rect.texture = enemy.portrait
	enemy.HP = enemy.MAX_HP
	update_stats()
func set_stats(value:EnemyCard)-> void:
	enemy = value
