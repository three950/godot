class_name Enemy
extends "res://assets/人物与敌人/battle_card.gd"

# 标记敌人是否已经进入战斗；目前由外部战斗流程读取或重置。
@export var _battle_started := false

# 敌人卡片数据。Card3D 创建 2D 卡面时会通过 set_stats() 注入这个资源。
@export var enemy: EnemyCard : set = set_stats


func get_battle_resource() -> BattleStates:
	return enemy


func set_stats(value: EnemyCard) -> void:
	enemy = value
	_connect_and_update(enemy)


func _update_battle_card() -> void:
	if enemy == null:
		return

	# 复用 BattleCard/Card 的通用显示逻辑和 SubViewport 刷新。
	super._update_battle_card()
	enemy.HP = enemy.MAX_HP
	update_stats()


func heal(amount: int) -> void:
	if enemy == null:
		return

	enemy.heal(amount)


func 退出战斗状态() -> void:
	_battle_started = false
