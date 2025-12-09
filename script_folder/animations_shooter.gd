class_name Shooter
extends Node
@export var card:Card

const react_time:=0.4
func play_card_shooter(target_position:Vector2)-> void:
	var tween:=create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card,"global_position",target_position,react_time)
