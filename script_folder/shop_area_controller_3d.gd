extends Node
class_name ShopAreaController3D

const INVALID_VIEWPORT_POSITION := Vector2(INF, INF)

@export var ground_path: NodePath
@export var shop_bag_path: NodePath
@export var ground_node_name: String = "Ground"
@export var shop_bag_node_name: String = "ShopBag"

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
@export var nearest_package_x_acceptance: float = 1.45

@export_group("Debug")
@export var debug_drop_logs: bool = true

var _ground: Node3D = null
var _shop_bag: Control = null
var _package_hitboxes: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("ShopArea3D")
	await get_tree().process_frame
	await get_tree().process_frame
	_ensure_scene_references(false)
	_rebuild_package_hitboxes()
	_debug_ready_log()


func apply_card_drop_rules(card: Card3D) -> bool:
	if card == null or not is_instance_valid(card):
		return false

	_ensure_scene_references()
	var viewport_position := world_to_ground_viewport(card.global_position)
	if viewport_position == INVALID_VIEWPORT_POSITION:
		_debug_drop_log(card, viewport_position, null, false, _get_mapping_failure_status())
		return false

	var package := _find_package_for_card(card, viewport_position)
	var package_handled := false
	var safe_world_position := _get_shop_exit_position(card, viewport_position)
	var debug_status := _get_drop_debug_status(card, package, viewport_position)
	var debug_coin_count := _get_coin_count(card)
	if package != null and package.has_method("try_accept_card_drop"):
		# 3D 卡只负责“落到哪里”；具体买包、扣钱、生成卡仍由 GroundPackage 自己处理。
		package_handled = bool(package.call("try_accept_card_drop", card, safe_world_position))
		if package_handled:
			debug_status = "bought"

	if shop_area_rect.has_point(viewport_position) \
			and card != null \
			and is_instance_valid(card) \
			and not card.is_queued_for_deletion():
		_move_card_chain_out_of_shop(card, safe_world_position)

	_debug_drop_log(card, viewport_position, package, package_handled, debug_status, debug_coin_count)
	return package_handled


func world_to_ground_viewport(world_position: Vector3) -> Vector2:
	_ensure_scene_references()
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


func _ensure_scene_references(allow_hitbox_rebuild: bool = true) -> bool:
	var had_ground := _ground != null and is_instance_valid(_ground)
	var had_shop_bag := _shop_bag != null and is_instance_valid(_shop_bag)

	if not had_ground:
		_ground = _resolve_node(ground_path, ground_node_name) as Node3D
	if not had_shop_bag:
		_shop_bag = _resolve_node(shop_bag_path, shop_bag_node_name) as Control

	# 外部编辑场景或热重载脚本时，导出的 NodePath 可能还是空的；
	# 自动找回引用后补建 3D 商品命中盒，避免下一次落牌仍然走普通堆叠。
	if allow_hitbox_rebuild \
			and _package_hitboxes.is_empty() \
			and _ground != null \
			and is_instance_valid(_ground) \
			and _shop_bag != null \
			and is_instance_valid(_shop_bag):
		_rebuild_package_hitboxes()

	return _ground != null and is_instance_valid(_ground)


func _resolve_node(configured_path: NodePath, fallback_name: String) -> Node:
	if not str(configured_path).is_empty():
		var configured_node := get_node_or_null(configured_path)
		if configured_node != null and is_instance_valid(configured_node):
			return configured_node

	# 先从当前场景根节点找，避免误拿到其他场景或 Autoload 里的同名节点。
	var current_scene := get_tree().current_scene
	var scene_node := _find_node_by_name(current_scene, fallback_name)
	if scene_node != null:
		return scene_node

	return _find_node_by_name(get_tree().root, fallback_name)


func _find_node_by_name(search_root: Node, fallback_name: String) -> Node:
	if search_root == null or fallback_name.is_empty():
		return null
	if search_root.name == fallback_name:
		return search_root
	return search_root.find_child(fallback_name, true, false)


func _get_mapping_failure_status() -> String:
	if _ground == null or not is_instance_valid(_ground):
		return "invalid_ground_mapping_ground_missing path=%s fallback=%s parent=%s" % [
			str(ground_path),
			ground_node_name,
			get_parent().name if get_parent() != null else "none",
		]
	if ground_size.x <= 0.0 or ground_size.y <= 0.0:
		return "invalid_ground_mapping_bad_ground_size"
	return "invalid_ground_mapping"


func _find_package_for_card(card: Card3D, viewport_position: Vector2) -> Control:
	var area_package := _find_package_from_3d_hitbox(card)
	if area_package != null:
		return area_package
	var nearest_shop_package := _find_nearest_package_in_shop_strip(card, viewport_position)
	if nearest_shop_package != null:
		return nearest_shop_package
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


func _find_nearest_package_in_shop_strip(card: Card3D, viewport_position: Vector2) -> Control:
	if card == null or not is_instance_valid(card):
		return null
	if not shop_area_rect.has_point(viewport_position):
		return null

	var nearest_package: Control = null
	var nearest_normalized_x := INF
	for hitbox_data in _package_hitboxes:
		var area := hitbox_data.get("area") as Area3D
		var package := hitbox_data.get("package") as Control
		if area == null or package == null:
			continue
		if not is_instance_valid(area) or not is_instance_valid(package):
			continue

		var size: Vector3 = hitbox_data.get("size", Vector3.ZERO)
		if size.x <= 0.0:
			continue

		# 当 2D 视口和 3D 地面有轻微偏差时，只要卡已经落进商店条带，
		# 就按横向距离匹配最近的商品，避免金币被普通堆叠逻辑抢走。
		var local_card_position := area.to_local(card.global_position)
		var normalized_x := absf(local_card_position.x) / (size.x * 0.5)
		if normalized_x < nearest_normalized_x:
			nearest_normalized_x = normalized_x
			nearest_package = package

	if nearest_normalized_x <= nearest_package_x_acceptance:
		return nearest_package

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
	if package_rect.size.x <= 0.0 or package_rect.size.y <= 0.0:
		return

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


func _get_drop_debug_status(card: Card3D, package: Control, viewport_position: Vector2) -> String:
	if package != null and package.has_method("get_coin_purchase_debug_status"):
		return str(package.call("get_coin_purchase_debug_status", card))
	if package == null and shop_area_rect.has_point(viewport_position):
		return "inside_shop_no_package"
	if package == null:
		return "outside_shop"
	return "package_has_no_drop_debug"


func _get_coin_count(card: Card3D) -> int:
	var coin_card := card as CoinCard3D
	if coin_card == null or not is_instance_valid(coin_card):
		return 0
	return coin_card.get_coin_stack_count()


func _debug_drop_log(
		card: Card3D,
		viewport_position: Vector2,
		package: Control,
		handled: bool,
		status: String,
		coin_count_override: int = -1
) -> void:
	if not debug_drop_logs:
		return

	# 测试日志只关注金币或商店附近的落点，避免普通卡牌到处掉落时刷屏。
	var should_log := card is CoinCard3D \
			or package != null \
			or shop_area_rect.has_point(viewport_position)
	if not should_log:
		return

	var card_name := "null"
	if card != null and is_instance_valid(card):
		card_name = card.name

	var package_name := "none"
	if package != null and is_instance_valid(package):
		package_name = package.name

	var coin_count := coin_count_override
	if coin_count < 0:
		coin_count = _get_coin_count(card)

	print("[ShopArea3D] drop card=%s viewport=%s package=%s coins=%d handled=%s status=%s" % [
		card_name,
		viewport_position,
		package_name,
		coin_count,
		str(handled),
		status,
	])


func _debug_ready_log() -> void:
	if not debug_drop_logs:
		return

	var ground_name := "none"
	if _ground != null and is_instance_valid(_ground):
		ground_name = _ground.name

	var shop_name := "none"
	if _shop_bag != null and is_instance_valid(_shop_bag):
		shop_name = _shop_bag.name

	print("[ShopArea3D] ready ground=%s shop=%s package_hitboxes=%d" % [
		ground_name,
		shop_name,
		_package_hitboxes.size(),
	])
