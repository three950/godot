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
