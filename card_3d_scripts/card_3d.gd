@tool
class_name Card3D
extends Node3D

signal card_label_entered_stack_area(entering_card: Card3D)
signal card_label_exited_stack_area(exiting_card: Card3D)
signal stacking_on_you(children: Card3D)
signal stop_stacking_on_you()
signal dropped(source_state: Card3DState)
signal drag_started()
signal array_changed()
signal reparent_requested(which_card: Card3D)

enum cardType {normal, selling, architecture}

const RUNTIME_UNIQUE_RESOURCE_META := CardInfo.RUNTIME_UNIQUE_RESOURCE_META

@export var cardname: String
@export var card_type: cardType = cardType.normal
@export var can_stack: bool = true

@export_group("Card Data")
@export var card_info: CardInfo : set = set_card_info
@export var battle: BattleState

@export_group("3D Motion")
@export var hover_lift_y: float = 0.05
@export var pickup_lift_y: float = 0.1
@export var stack_offset_y: float = 0.01
@export var stack_offset_z: float = 0.48

@export_group("3D Input")
@export var ray_interaction_enabled: bool = true
# 点击开关只拦截左键按下；射线 hover 和命中检测仍可继续用于战斗中高亮/提示。
@export var mouse_click_enabled: bool = true
@export var face_size: Vector2 = Vector2(2.64, 3.45)

@export_group("Audio")
@export var pickup_sound: AudioStream
@export var fall_sound: AudioStream

@onready var card_state_machine: Card3DStateMachine = $Card3DStateMachine as Card3DStateMachine
@onready var stack_detector: Area3D = $CardStackDetectorArea as Area3D
@onready var front_face: Node3D = $FrontFace as Node3D
@onready var back_face: Node3D = $BackFace as Node3D
@onready var card_viewport: SubViewport = $FrontFace/SubViewport as SubViewport
var overlapping_cards: Array[Card3D] = []
var follow_target: Card3D = null
var stack_state: int = 0
var children_card: Card3D = null
var drag_offset: Vector3 = Vector3.ZERO
var is_hovered: bool = false
var is_picked_up: bool = false

var _drag_camera: Camera3D = null
var _drag_plane_y: float = 0.0
var _base_plane_y: float = 0.0
var _front_face_original_position: Vector3 = Vector3.ZERO
var _back_face_original_position: Vector3 = Vector3.ZERO
var _ray_hovered: bool = false
var _suppress_card_info_rebuild: bool = false
var card_2d: Control = null
var card_2d_label: Label = null
var card_2d_texture: TextureRect = null


func _ready() -> void:
	_base_plane_y = global_position.y
	_make_runtime_card_data_unique()
	_bind_viewport_texture_to_front_material()
	_build_card_view()
	_apply_card_info_to_view()
	_request_card_viewport_redraw()

	if front_face:
		_front_face_original_position = front_face.position
	if back_face:
		_back_face_original_position = back_face.position

	if Engine.is_editor_hint():
		if card_viewport:
			card_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		return

	add_to_group("Cards3D")

	if card_state_machine:
		card_state_machine.init(self)

	if stack_detector:
		stack_detector.area_entered.connect(_on_stack_detector_area_entered)
		stack_detector.area_exited.connect(_on_stack_detector_area_exited)

	if not stacking_on_you.is_connected(bestacked_on_me):
		stacking_on_you.connect(bestacked_on_me)
	if not stop_stacking_on_you.is_connected(stop_stacking_on_me):
		stop_stacking_on_you.connect(stop_stacking_on_me)


func _make_runtime_card_data_unique() -> void:
	# _ready 会在私有化后统一重建一次卡面；这里赋值会经过 setter，先压住 setter 的即时重建。
	_suppress_card_info_rebuild = true
	card_info = _get_runtime_card_data(card_info)
	_suppress_card_info_rebuild = false
	battle = _get_runtime_battle_state(battle)


func _get_runtime_card_data(value: CardInfo) -> CardInfo:
	if value == null:
		return null
	if Engine.is_editor_hint():
		return value
	if value.get_meta(RUNTIME_UNIQUE_RESOURCE_META, false):
		return value

	# CardInfo 子类自己决定是否需要从模板 .tres 复制出运行时数据。
	var instance := value.create_runtime_instance()
	if instance == null or instance == value:
		return value
	instance.set_meta(RUNTIME_UNIQUE_RESOURCE_META, true)
	return instance


func _get_runtime_battle_state(value: BattleState) -> BattleState:
	if value == null:
		return null
	if Engine.is_editor_hint():
		return value
	if value.get_meta(RUNTIME_UNIQUE_RESOURCE_META, false):
		return value

	var instance := value.create_runtime_instance()
	if instance == null or instance == value:
		return value
	instance.set_meta(RUNTIME_UNIQUE_RESOURCE_META, true)
	return instance


func _bind_viewport_texture_to_front_material() -> void:
	var front_mesh := front_face as MeshInstance3D
	if front_mesh == null or card_viewport == null:
		return

	var material := front_mesh.material_override as StandardMaterial3D
	if material == null:
		return

	# 每张 3D 卡牌都绑定自己的 SubViewport，避免 ViewportTexture 路径在实例化时失效。
	var instance_material := material.duplicate() as StandardMaterial3D
	instance_material.albedo_texture = card_viewport.get_texture()
	front_mesh.material_override = instance_material


func _cache_card_view_nodes() -> void:
	card_2d = card_viewport.get_node_or_null("Card2D") as Control if card_viewport else null
	if card_2d == null:
		card_2d_label = null
		card_2d_texture = null
		return

	card_2d_label = card_2d.get_node_or_null("CardColor/Panel/Label") as Label
	if card_2d_label == null:
		card_2d_label = card_2d.get_node_or_null("CardColor/Panel/Label") as Label
	if card_2d_label == null:
		card_2d_label = card_2d.find_child("Label", true, false) as Label
	card_2d_texture = card_2d.find_child("TextureRect", true, false) as TextureRect


func set_card_info(value: CardInfo) -> void:
	card_info = _get_runtime_card_data(value)
	if _suppress_card_info_rebuild:
		return
	if is_inside_tree():
		_build_card_view()
		_apply_card_info_to_view()
		_request_card_viewport_redraw()


func _build_card_view() -> void:
	if card_viewport == null:
		card_2d = null
		card_2d_label = null
		card_2d_texture = null
		return

	for child in card_viewport.get_children():
		card_viewport.remove_child(child)
		child.queue_free()

	card_2d = null
	card_2d_label = null
	card_2d_texture = null

	if card_info == null:
		_request_card_viewport_redraw()
		return

	var card_scene := card_info.get("card_scene") as PackedScene
	if card_scene == null:
		push_warning("Card3D: card_info %s has no card_scene." % card_info.name)
		_request_card_viewport_redraw()
		return

	var instance := card_scene.instantiate()
	if instance == null:
		push_warning("Card3D: failed to instantiate card_scene for %s." % card_info.name)
		_request_card_viewport_redraw()
		return

	instance.name = "Card2D"
	_assign_card_info_to_2d_view(instance)
	card_viewport.add_child(instance)

	card_2d = instance as Control
	_prepare_card_2d_control()
	_cache_card_view_nodes()
	_request_card_viewport_redraw()


func _assign_card_info_to_2d_view(view: Node) -> void:
	if view.has_method("set_stats"):
		view.call("set_stats", card_info)
		return
	if view.has_method("set_character_stats"):
		view.call("set_character_stats", card_info)
		return

	for property_name in ["character", "enemy", "scene", "item", "equipment", "recource", "remains"]:
		if _node_has_property(view, property_name):
			view.set(property_name, card_info)
			return


func _node_has_property(node: Object, property_name: String) -> bool:
	for property in node.get_property_list():
		if property.get("name") == property_name:
			return true
	return false


func _prepare_card_2d_control() -> void:
	if card_2d == null:
		return

	card_2d.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	card_2d.position = Vector2.ZERO
	if card_viewport:
		card_2d.size = Vector2(card_viewport.size.x, card_viewport.size.y)
	card_2d.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_card_info_to_view() -> void:
	if card_info == null:
		_request_card_viewport_redraw()
		return

	cardname = card_info.name
	can_stack = card_info.能被堆叠

	if card_2d == null:
		_request_card_viewport_redraw()
		return

	card_2d.name = card_info.name if card_info.name != "" else "Card2D"
	if card_2d_label:
		card_2d_label.text = card_info.name
	if card_2d_texture:
		card_2d_texture.texture = card_info.portrait
	_request_card_viewport_redraw()


func _request_card_viewport_redraw() -> void:
	if card_viewport == null:
		return

	# Card3D 只负责“卡面刚创建或静态内容刚写入”时刷新一帧。
	# 人物/敌人战斗数值变化后的额外刷新，由对应 2D 卡脚本在数据更新时请求。
	card_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if card_state_machine == null or card_state_machine.current_state == null:
		return

	var current := card_state_machine.current_state.state
	if current == Card3DState.State.pickingup \
			or current == Card3DState.State.dragging:
		card_state_machine.on_input(event)
		if _is_drag_input_event(event):
			get_viewport().set_input_as_handled()
		return

	if ray_interaction_enabled:
		_handle_ray_input(event)


func begin_drag(camera: Camera3D, mouse_position: Vector2, event_position: Vector3) -> void:
	_drag_camera = camera
	_drag_plane_y = global_position.y

	var hit_position := event_position
	var projected := _project_mouse_to_y_plane(mouse_position, _drag_plane_y, camera)
	if not projected.is_empty():
		hit_position = projected["position"]

	drag_offset = hit_position - global_position
	drag_offset.y = 0.0


func start_pickup_feedback() -> void:
	drag_started.emit()
	apply_pickup_offset()

	if pickup_sound:
		SFXPlayer.play(pickup_sound, false, 12.0)


func detach_from_follow_target() -> void:
	if not (stack_state & Card3DState.STACK_STATE_STACKING) or follow_target == null:
		return

	follow_target.stop_stacking_on_you.emit()
	stack_state = 0
	follow_target = null


func update_drag_from_mouse(mouse_position: Vector2) -> void:
	var camera := _get_drag_camera()
	if camera == null:
		return

	var projected := _project_mouse_to_y_plane(mouse_position, _drag_plane_y, camera)
	if projected.is_empty():
		return

	var hit_position: Vector3 = projected["position"]
	var next_position := global_position
	next_position.x = hit_position.x - drag_offset.x
	next_position.z = hit_position.z - drag_offset.z
	global_position = next_position


func end_drag() -> void:
	_drag_camera = null
	drag_offset = Vector3.ZERO


func set_stack_detector_enabled(enabled: bool) -> void:
	if stack_detector:
		stack_detector.set_deferred("monitoring", enabled)
		stack_detector.set_deferred("monitorable", enabled)


func bestacked_on_me(children: Card3D) -> void:
	stack_state |= Card3DState.STACK_STATE_BESTACKED
	children_card = children
	set_stack_detector_enabled(false)
	array_changed.emit()
	print("[Card3D] stack_changed emit: %s bestacked by %s" % [cardname, children.cardname])
	Events.stack_changed.emit(self)


func stop_stacking_on_me() -> void:
	stack_state &= ~Card3DState.STACK_STATE_BESTACKED
	children_card = null
	set_stack_detector_enabled(true)
	array_changed.emit()
	print("[Card3D] stack_changed emit: %s stop_stacking_on_me" % cardname)
	Events.stack_changed.emit(self)


func apply_pickup_offset() -> void:
	is_picked_up = true
	_update_lift_offset()
	if children_card:
		children_card.apply_pickup_offset()


func reset_offset() -> void:
	is_hovered = false
	is_picked_up = false
	_update_lift_offset()
	if children_card:
		children_card.reset_offset()


func update_children_position() -> void:
	if children_card == null:
		return

	children_card.global_position = get_child_stack_position()
	children_card.update_children_position()


func update_stack_chain_position() -> void:
	var head_card := get_stack_head()
	head_card.update_children_position()


func try_accept_stack_interaction(_stacked_card: Card3D) -> bool:
	# 普通 Card3D 不消费“贴上来”的卡；子类可覆盖此入口，实现装备、道具等类似堆叠触发的特殊逻辑。
	return false


func get_stack_head() -> Card3D:
	var current: Card3D = self
	while current.follow_target != null:
		current = current.follow_target
	return current


func get_child_stack_position() -> Vector3:
	return Vector3(global_position.x, global_position.y + stack_offset_y, global_position.z + stack_offset_z)


func snap_to_base_plane() -> void:
	var next_position := global_position
	next_position.y = _base_plane_y
	global_position = next_position


func _on_card_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if _is_left_button_press(event) and not mouse_click_enabled:
		# 战斗接管的卡牌仍允许鼠标悬停，但不允许左键重新触发 pickup/drag。
		get_viewport().set_input_as_handled()
		return

	var input_camera := camera as Camera3D
	if input_camera:
		_drag_camera = input_camera
	if card_state_machine:
		card_state_machine.on_area_input(input_camera, event, event_position, normal, shape_idx)
	if _is_left_button_press(event):
		get_viewport().set_input_as_handled()


func _on_mouse_entered() -> void:
	if card_state_machine:
		card_state_machine.on_mouse_entered()
	if follow_target != null:
		return
	is_hovered = true
	_apply_hover_offset()


func _on_mouse_exited() -> void:
	if card_state_machine:
		card_state_machine.on_mouse_exited()
	if follow_target != null:
		return
	_remove_hover_offset()


func _on_stack_detector_area_entered(area: Area3D) -> void:
	var entering_card := area.get_parent() as Card3D
	if entering_card == null or entering_card == self:
		return

	if not entering_card.overlapping_cards.has(self):
		entering_card.overlapping_cards.append(self)
	card_label_entered_stack_area.emit(entering_card)


func _on_stack_detector_area_exited(area: Area3D) -> void:
	var exiting_card := area.get_parent() as Card3D
	if exiting_card == null or exiting_card == self:
		return

	if exiting_card.overlapping_cards.has(self):
		exiting_card.overlapping_cards.erase(self)
	card_label_exited_stack_area.emit(exiting_card)


func _apply_hover_offset() -> void:
	_update_lift_offset()
	if children_card:
		children_card.is_hovered = true
		children_card._apply_hover_offset()


func _remove_hover_offset() -> void:
	is_hovered = false
	_update_lift_offset()
	if children_card:
		children_card._remove_hover_offset()


func _update_lift_offset() -> void:
	var total_lift := 0.0
	if is_hovered:
		total_lift += hover_lift_y
	if is_picked_up:
		total_lift += pickup_lift_y

	if front_face:
		var front_position := _front_face_original_position
		front_position.y += total_lift
		front_face.position = front_position
	if back_face:
		var back_position := _back_face_original_position
		back_position.y += total_lift
		back_face.position = back_position


func _get_drag_camera() -> Camera3D:
	if _drag_camera != null and is_instance_valid(_drag_camera):
		return _drag_camera
	return get_viewport().get_camera_3d()


func _handle_ray_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		_update_ray_hover(mouse_motion.position)
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT or not mouse_button.pressed:
			return

		var camera := get_viewport().get_camera_3d()
		var hit := _get_top_card_hit(mouse_button.position, camera)
		if hit.is_empty() or hit.get("card") != self:
			return

		if not mouse_click_enabled:
			# 手写射线路径同样只吃掉点击，不关闭 mouse motion 触发的 hover。
			get_viewport().set_input_as_handled()
			return

		card_state_machine.on_area_input(camera, mouse_button, hit["position"], hit["normal"], -1)
		get_viewport().set_input_as_handled()


func _update_ray_hover(mouse_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	var hit := _get_top_card_hit(mouse_position, camera)
	var is_hit: bool = not hit.is_empty() and hit.get("card") == self

	if is_hit and not _ray_hovered:
		_ray_hovered = true
		_on_mouse_entered()
	elif not is_hit and _ray_hovered:
		_ray_hovered = false
		_on_mouse_exited()


func _get_top_card_hit(mouse_position: Vector2, camera: Camera3D) -> Dictionary:
	if camera == null:
		return {}

	var best_hit := {}
	var best_distance := INF

	for node in get_tree().get_nodes_in_group("Cards3D"):
		var other_card := node as Card3D
		if other_card == null or not is_instance_valid(other_card) or not other_card.is_inside_tree():
			continue

		var hit := other_card._intersect_face_ray(mouse_position, camera)
		if hit.is_empty():
			continue

		var distance: float = hit["distance"]
		if distance < best_distance:
			best_distance = distance
			best_hit = hit
			best_hit["card"] = other_card

	return best_hit


func _intersect_face_ray(mouse_position: Vector2, camera: Camera3D) -> Dictionary:
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_normal := camera.project_ray_normal(mouse_position)
	var local_origin := to_local(ray_origin)
	var local_normal := global_transform.basis.inverse() * ray_normal

	if absf(local_normal.y) < 0.00001:
		return {}

	var distance_to_plane := -local_origin.y / local_normal.y
	if distance_to_plane < 0.0:
		return {}

	var local_hit := local_origin + local_normal * distance_to_plane
	var half_size := face_size * 0.5
	if absf(local_hit.x) > half_size.x or absf(local_hit.z) > half_size.y:
		return {}

	var global_hit := to_global(local_hit)
	return {
		"position": global_hit,
		"local_position": local_hit,
		"normal": global_transform.basis.y.normalized(),
		"distance": ray_origin.distance_to(global_hit),
	}


func _project_mouse_to_y_plane(mouse_position: Vector2, plane_y: float, camera: Camera3D) -> Dictionary:
	if camera == null:
		return {}

	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_normal := camera.project_ray_normal(mouse_position)
	if absf(ray_normal.y) < 0.00001:
		return {}

	var distance := (plane_y - ray_origin.y) / ray_normal.y
	if distance < 0.0:
		return {}

	return {"position": ray_origin + ray_normal * distance}


func _is_drag_input_event(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		return true
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		return mouse_button.button_index == MOUSE_BUTTON_LEFT
	return false


func _is_left_button_press(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false

	var mouse_button := event as InputEventMouseButton
	return mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed
