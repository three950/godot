class_name BattleScene3DAreaController
extends RefCounted

var _owner: Node3D = null
var _battle_area_shape: CollisionShape3D = null
var _fill_mesh: MeshInstance3D = null
var _border_viewport: SubViewport = null
var _border_panel: Panel = null
var _border_frame: MeshInstance3D = null


func configure(
		owner: Node3D,
		battle_area_shape: CollisionShape3D,
		fill_mesh: MeshInstance3D,
		border_viewport: SubViewport,
		border_panel: Panel,
		border_frame: MeshInstance3D
) -> void:
	_owner = owner
	_battle_area_shape = battle_area_shape
	_fill_mesh = fill_mesh
	_border_viewport = border_viewport
	_border_panel = border_panel
	_border_frame = border_frame


func make_visual_resources_unique() -> void:
	if _fill_mesh and _fill_mesh.mesh:
		_fill_mesh.mesh = _fill_mesh.mesh.duplicate()
	if _border_frame and _border_frame.mesh:
		_border_frame.mesh = _border_frame.mesh.duplicate()
	if _border_frame and _border_frame.material_override:
		_border_frame.material_override = _border_frame.material_override.duplicate()
	if _battle_area_shape and _battle_area_shape.shape:
		_battle_area_shape.shape = _battle_area_shape.shape.duplicate()


func setup_border_viewport() -> void:
	if _border_viewport == null:
		return

	_border_viewport.disable_3d = true
	_border_viewport.transparent_bg = true
	_border_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_border_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS

	if _border_panel:
		_border_panel.anchor_left = 0.0
		_border_panel.anchor_top = 0.0
		_border_panel.anchor_right = 0.0
		_border_panel.anchor_bottom = 0.0
		_border_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var material: StandardMaterial3D = null
	if _border_frame:
		material = _border_frame.material_override as StandardMaterial3D
	if material:
		# StyleBoxTexture 先画到 2D viewport，再作为贴图显示到 3D 平面上。
		material.albedo_texture = _border_viewport.get_texture()


func relayout_cards(characters: Array[Card3D], enemies: Array[Card3D]) -> void:
	update_scene_bounds(characters, enemies)
	_layout_side(characters, _float_setting("character_row_z", 1.8))
	_layout_side(enemies, _float_setting("enemy_row_z", -1.8))


func update_scene_bounds(characters: Array[Card3D], enemies: Array[Card3D]) -> void:
	var visual_size := _calculate_visual_size(characters, enemies)
	_update_visual_size(visual_size)
	_update_detection_size(visual_size)


func _layout_side(cards: Array[Card3D], row_z: float) -> void:
	var count := cards.size()
	if count == 0 or _owner == null:
		return

	var card_spacing := _float_setting("card_spacing", 3.0)
	var start_x := -card_spacing * float(count - 1) * 0.5
	for index in range(count):
		var card := cards[index]
		if card == null or not is_instance_valid(card):
			continue

		var target_position := _get_slot_global_position(start_x + card_spacing * index, row_z)
		card.global_position = target_position


func _get_slot_global_position(slot_x: float, row_z: float) -> Vector3:
	if _owner == null:
		return Vector3(slot_x, 0.0, row_z)
	# 卡牌原点就是牌面中心，因此槽位目标点也使用中心坐标。
	return _owner.to_global(Vector3(slot_x, 0.0, row_z))


func _calculate_visual_size(characters: Array[Card3D], enemies: Array[Card3D]) -> Vector2:
	var max_side_count := maxi(characters.size(), enemies.size())
	var card_size := _get_card_face_size(characters, enemies)
	var card_spacing := _float_setting("card_spacing", 3.0)
	var min_visual_size := _vector2_setting("min_visual_size", Vector2(9.0, 7.0))
	var visual_padding := _vector2_setting("visual_padding", Vector2(0.7, 0.9))
	var content_width := card_size.x
	if max_side_count > 1:
		content_width += float(max_side_count - 1) * card_spacing

	var content_height := absf(
		_float_setting("character_row_z", 1.8) - _float_setting("enemy_row_z", -1.8)
	) + card_size.y
	return Vector2(
		maxf(min_visual_size.x, content_width + visual_padding.x * 2.0),
		maxf(min_visual_size.y, content_height + visual_padding.y * 2.0)
	)


func _get_card_face_size(characters: Array[Card3D], enemies: Array[Card3D]) -> Vector2:
	for card in characters:
		if card != null and is_instance_valid(card):
			return card.face_size
	for card in enemies:
		if card != null and is_instance_valid(card):
			return card.face_size
	return Vector2(2.64, 3.45)


func _update_visual_size(size: Vector2) -> void:
	var fill_plane: PlaneMesh = null
	if _fill_mesh:
		fill_plane = _fill_mesh.mesh as PlaneMesh
	if fill_plane:
		fill_plane.size = size

	_update_border_frame_size(size)


func _update_border_frame_size(size: Vector2) -> void:
	if _border_frame:
		var border_plane := _border_frame.mesh as PlaneMesh
		if border_plane:
			border_plane.size = size
		_border_frame.position = Vector3(0.0, _float_setting("border_height", 0.06) * 0.5 + 0.01, 0.0)

	if _border_viewport == null:
		return

	var pixels_per_unit := _float_setting("border_viewport_pixels_per_unit", 100.0)
	var viewport_size := Vector2i(
		maxi(1, int(ceil(size.x * pixels_per_unit))),
		maxi(1, int(ceil(size.y * pixels_per_unit)))
	)
	if _border_viewport.size != viewport_size:
		_border_viewport.size = viewport_size

	if _border_panel:
		_border_panel.position = Vector2.ZERO
		_border_panel.size = Vector2(float(viewport_size.x), float(viewport_size.y))


func _update_detection_size(size: Vector2) -> void:
	if _battle_area_shape == null:
		return

	var box_shape := _battle_area_shape.shape as BoxShape3D
	if box_shape == null:
		return

	box_shape.size = Vector3(size.x, 0.8, size.y)


func _float_setting(name: String, fallback: float) -> float:
	return float(_owner.get(name)) if _owner != null else fallback


func _vector2_setting(name: String, fallback: Vector2) -> Vector2:
	if _owner == null:
		return fallback
	var value: Vector2 = _owner.get(name)
	return value
