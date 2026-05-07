class_name Card3DState
extends Node

enum State {fixed, pickingup, dragging, falling, instack, instackdragging}
enum CardType {normal, selling, architecture}

signal transition_requested(from: Card3DState, to: State)

const STACK_STATE_BESTACKED := 1
const STACK_STATE_STACKING := 2

@export var state: State
@export var type: CardType

var card: Card3D


func enter() -> void:
	pass


func exit() -> void:
	pass


func post_enter() -> void:
	pass


func on_input(_event: InputEvent) -> void:
	pass


func on_area_input(_camera: Camera3D, _event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	pass


func on_mouse_entered() -> void:
	pass


func on_mouse_exited() -> void:
	pass
