extends Card3DState

func enter() -> void:
	_reset_pickup_height_and_rotation()
	card.detach_from_follow_target()
	card.start_pickup_feedback()
	transition_requested.emit(self, Card3DState.State.dragging)


func on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			transition_requested.emit(self, Card3DState.State.falling)


func _reset_pickup_height_and_rotation() -> void:
	# pickup 状态统一从桌面平面开始，避免继承预览参考卡的高度和倾斜角。
	var next_position := card.global_position
	next_position.y = 0.0
	card.global_position = next_position
	card.global_rotation = Vector3.ZERO
	card._base_plane_y = 0.0
	card._drag_plane_y = 0.0
