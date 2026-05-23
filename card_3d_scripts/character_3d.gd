@tool
class_name Character3D
extends Card3D

@onready var bottom_left_hover_timer: Timer = get_node_or_null("BottomLeftHoverArea/BottomLeftHoverTimer") as Timer

var _is_bottom_left_hovered: bool = false


func _ready() -> void:
	super._ready()

	if Engine.is_editor_hint():
		return

	# character_3d 专属的左下角悬停检测，不影响通用 Card3D。
	if bottom_left_hover_timer:
		bottom_left_hover_timer.one_shot = true
		bottom_left_hover_timer.wait_time = 0.6
		if not bottom_left_hover_timer.timeout.is_connected(_on_bottom_left_hover_timer_timeout):
			bottom_left_hover_timer.timeout.connect(_on_bottom_left_hover_timer_timeout)


func _on_mouse_exited() -> void:
	super._on_mouse_exited()
	_set_bottom_left_hovered(false)


func _on_bottom_left_hover_area_mouse_entered() -> void:
	_set_bottom_left_hovered(true)


func _on_bottom_left_hover_area_mouse_exited() -> void:
	_set_bottom_left_hovered(false)


func _set_bottom_left_hovered(is_hovered_now: bool) -> void:
	if _is_bottom_left_hovered == is_hovered_now:
		return

	_is_bottom_left_hovered = is_hovered_now
	if bottom_left_hover_timer == null:
		return

	if _is_bottom_left_hovered:
		# 鼠标进入左下区域后重新计时，停留到计时结束才触发打印。
		bottom_left_hover_timer.start()
	else:
		# 离开区域就取消本次悬停检测，避免短暂停留也触发。
		bottom_left_hover_timer.stop()


func _on_bottom_left_hover_timer_timeout() -> void:
	if not _is_bottom_left_hovered:
		return
	print("鼠标悬停触发")


func _update_ray_hover(mouse_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	var hit := _get_top_card_hit(mouse_position, camera)
	var is_hit: bool = not hit.is_empty() and hit.get("card") == self
	var is_bottom_left_hit := false

	if is_hit:
		# PlaneMesh 卡面以 X/Z 表示宽高；这里取左下四分之一区域。
		var local_position: Vector3 = hit["local_position"]
		var half_size := face_size * 0.5
		is_bottom_left_hit = local_position.x >= -half_size.x and local_position.x <= 0.0 \
				and local_position.z >= 0.0 and local_position.z <= half_size.y
	_set_bottom_left_hovered(is_bottom_left_hit)

	if is_hit and not _ray_hovered:
		_ray_hovered = true
		_on_mouse_entered()
	elif not is_hit and _ray_hovered:
		_ray_hovered = false
		_on_mouse_exited()
