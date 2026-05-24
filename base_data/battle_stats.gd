extends Resource
class_name BattleState
enum Phase{
	COMMON,
	BATTLE
}

@export var current_state:Phase:
	set(value):
		current_state = value
		changed.emit()


func create_runtime_instance() -> BattleState:
	# 战斗阶段会被战斗区域直接改动，每张 3D 卡需要独立状态。
	var instance := duplicate() as BattleState
	return instance if instance != null else self
