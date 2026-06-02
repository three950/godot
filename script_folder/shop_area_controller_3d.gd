extends Node
class_name ShopAreaController3D

const INVALID_VIEWPORT_POSITION := Vector2(INF, INF)

@export var ground_path: NodePath
@export var shop_bag_path: NodePath

@export_group("Ground Texture Mapping")
@export var viewport_size: Vector2 = Vector2(3840, 2160)
@export var ground_size: Vector2 = Vector2(34.71, 21.36)
@export var texture_top_is_negative_z: bool = true

@export_group("Shop Area")
@export var shop_area_rect: Rect2 = Rect2(0, 0, 3840, 397)
@export var package_hit_margin_px: float = 18.0
@export var shop_exit_padding_px: float = 220.0
@export var package_hitbox_y: float = 0.04
@export var package_hitbox_height: float = 0.8

var _ground: Node3D = null
var _shop_bag: Control = null
var _package_hitboxes: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("ShopArea3D")
	_ground = get_node_or_null(ground_path) as Node3D
	_shop_bag = get_node_or_null(shop_bag_path) as Control
	await get_tree().process_frame
	_rebuild_package_hitboxes()


func apply_card_drop_rules(card: Card3D) -> bool:
	if card == null or not is_instance_valid(card):
		return false

	var viewport_position := world_to_ground_viewport(card.global_position)
	if viewport_position == INVALID_VIEWPORT_POSITION:
		return false

	var package := _find_package_for_card(card, viewport_position)
	var package_handled := false
	var safe_world_position := _get_shop_exit_position(card, viewport_position)
	if package != null and package.has_method("try_accept_card_drop"):
		# 3D 卡只负责“落到哪里”；具体买包、扣钱、生成卡仍由 GroundPackage 自己处理。
		package_handled = bool(package.call("try_accept_card_drop", card, safe_world_position))

	if shop_area_rect.has_point(viewport_position) \
			and card != null \
			and is_instance_valid(card) \
			and not card.is_queued_for_deletion():
		_move_card_chain_out_of_shop(card, safe_world_position)

	return package_handled


func world_to_ground_viewport(world_position: Vector3) -> Vector2:
	if _ground == null or not is_instance_valid(_ground):
		return INVALID_VIEWPORT_POSITION
	if ground_size.x <= 0.0 or ground_size.y <= 0.0:
		return INVALID_VIEWPORT_POSITION

	var local_position := _ground.to_local(world_position)
	var normalized_x := local_position.x / ground_size.x + 0.5
	var normalized_y := local_position.z / ground_size.y + 0.5
	if not texture_top_is_negative_z:
		normalized_y = 1.0 - normalized_y

	return Vector2(normalized_x * viewport_size.x, normalized_y * viewport_size.y)


func ground_viewport_to_world(viewport_position: Vector2, world_y: float) -> Vector3:
	var normalized_x := viewport_position.x / viewport_size.x
	var normalized_y := viewport_position.y / viewport_size.y
	if not texture_top_is_negative_z:
		normalized_y = 1.0 - normalized_y

	var local_position := Vector3(
		(normalized_x - 0.5) * ground_size.x,
		0.0,
		(normalized_y - 0.5) * ground_size.y
	)
	var world_position := _ground.to_global(local_position)
	world_position.y = world_y
	return world_position


func _find_package_at_viewport_position(viewport_position: Vector2) -> Control:
	if _shop_bag == null or not is_instance_valid(_shop_bag):
		return null

	var packages := _collect_card_packages(_shop_bag)
	for package in packages:
		var package_rect := Rect2(package.global_position, package.size).grow(package_hit_margin_px)
		if package_rect.has_point(viewport_position):
			return package

	return null


func _find_package_for_card(card: Card3D, viewport_position: Vector2) -> Control:
	var area_package := _find_package_from_3d_hitbox(card)
	if area_package != null:
		return area_package
	return _find_package_at_viewport_position(viewport_position)


func _find_package_from_3d_hitbox(card: Card3D) -> Control:
	if card == null or not is_instance_valid(card):
		return null

	for hitbox_data in _package_hitboxes:
		var area := hitbox_data.get("area") as Area3D
		var package := hitbox_data.get("package") as Control
		if area == null or package == null:
			continue
		if not is_instance_valid(area) or not is_instance_valid(package):
			continue

		var size: Vector3 = hitbox_data.get("size", Vector3.ZERO)
		var local_card_position := area.to_local(card.global_position)
		if absf(local_card_position.x) <= size.x * 0.5 \
				and absf(local_card_position.y) <= size.y * 0.5 \
				and absf(local_card_position.z) <= size.z * 0.5:
			return package

	return null


func _rebuild_package_hitboxes() -> void:
	_clear_package_hitboxes()
	if _ground == null or not is_instance_valid(_ground):
		return
	if _shop_bag == null or not is_instance_valid(_shop_bag):
		return

	for package in _collect_card_packages(_shop_bag):
		_add_package_hitbox(package)


func _clear_package_hitboxes() -> void:
	for hitbox_data in _package_hitboxes:
		var area := hitbox_data.get("area") as Area3D
		if area != null and is_instance_valid(area):
			area.queue_free()
	_package_hitboxes.clear()


func _add_package_hitbox(package: Control) -> void:
	var package_rect := Rect2(package.global_position, package.size).grow(package_hit_margin_px)
	var center_viewport := package_rect.get_center()
	var center_local := _ground_viewport_to_ground_local(center_viewport)
	var hitbox_size := Vector3(
		package_rect.size.x / viewport_size.x * ground_size.x,
		package_hitbox_height,
		package_rect.size.y / viewport_size.y * ground_size.y
	)

	var area := Area3D.new()
	area.name = "%sShopDropArea3D" % package.name
	area.collision_layer = 0
	area.collision_mask = 2
	area.input_ray_pickable = false
	area.monitoring = true
	area.monitorable = false
	area.position = Vector3(center_local.x, package_hitbox_y, center_local.z)
	_ground.add_child(area)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = hitbox_size
	shape.shape = box_shape
	area.add_child(shape)

	_package_hitboxes.append({
		"area": area,
		"package": package,
		"size": hitbox_size,
	})


func _collect_card_packages(root: Node) -> Array[Control]:
	var result: Array[Control] = []
	for child in root.get_children():
		var control := child as Control
		if control != null and control.has_method("try_accept_card_drop"):
			result.append(control)
		result.append_array(_collect_card_packages(child))
	return result


func _get_shop_exit_position(card: Card3D, viewport_position: Vector2) -> Vector3:
	var safe_viewport_position := viewport_position
	safe_viewport_position.y = shop_area_rect.position.y + shop_area_rect.size.y + shop_exit_padding_px
	return ground_viewport_to_world(safe_viewport_position, card.global_position.y)


func _ground_viewport_to_ground_local(viewport_position: Vector2) -> Vector3:
	var normalized_x := viewport_position.x / viewport_size.x
	var normalized_y := viewport_position.y / viewport_size.y
	if not texture_top_is_negative_z:
		normalized_y = 1.0 - normalized_y

	return Vector3(
		(normalized_x - 0.5) * ground_size.x,
		0.0,
		(normalized_y - 0.5) * ground_size.y
	)


func _move_card_chain_out_of_shop(card: Card3D, safe_world_position: Vector3) -> void:
	card.global_position = safe_world_position
	if card.children_card != null:
		card.update_children_position()
