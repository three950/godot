class_name CardState
extends Node

enum State{fixed, pickingup, dragging, falling, instack, instackdragging}
enum cardType{normal, selling, architecture}  # 卡片类型
signal transition_requested(from: CardState, to: State)
const STACK_STATE_BESTACKED = 1
const STACK_STATE_STACKING = 2
# 默认状态为0，表示不具有任何堆叠属性
@export var state: State
@export var type: cardType
var card: Card


func _ready() -> void:
	set_state_processing_enabled(false)


func set_state_processing_enabled(enabled: bool) -> void:
	set_process(enabled)
	set_physics_process(enabled)
	set_process_input(enabled)
	set_process_unhandled_input(enabled)


func enter() -> void:
	pass


func exit() -> void:
	pass


func post_enter() -> void:
	pass


func on_input(_event: InputEvent) -> void:
	pass


func on_gui_input(_event: InputEvent) -> void:
	pass


func on_mouse_entered() -> void:
	pass


func on_mouse_exited() -> void:
	pass
