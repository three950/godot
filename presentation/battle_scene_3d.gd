class_name BattleScene3D
extends Node3D

signal card_entered_battle_area(battle_scene: BattleScene3D, card: Card3D)
signal battle_area_touched(battle_scene: BattleScene3D, other_scene: BattleScene3D)
signal battle_finished(battle_scene: BattleScene3D)

const BASE_ATTACK_INTERVAL := 2.0
const MIN_ATTACK_INTERVAL := 0.3
const BATTLE_META_KEY := "battle_scene_3d"
const PREV_CAN_STACK_META_KEY := "battle_3d_prev_can_stack"
const PREV_RAY_META_KEY := "battle_3d_prev_ray_interaction"
const PREV_STACK_MONITORING_META_KEY := "battle_3d_prev_stack_monitoring"
const PREV_STACK_MONITORABLE_META_KEY := "battle_3d_prev_stack_monitorable"

@export var creation_index: int = 0
@export var card_spacing: float = 3.0
@export var character_row_z: float = 1.8
@export var enemy_row_z: float = -1.8
@export var card_move_duration: float = 0.2
@export var min_visual_size: Vector2 = Vector2(9.0, 7.0)
@export var visual_padding: Vector2 = Vector2(0.7, 0.9)
@export var detection_padding: Vector2 = Vector2(1.0, 1.0)
@export var border_height: float = 0.06
@export var border_viewport_pixels_per_unit: float = 100.0
@export var non_battle_card_push_margin: float = 0.35

@onready var battle_area: Area3D = $BattleArea as Area3D
@onready var battle_area_shape: CollisionShape3D = $BattleArea/CollisionShape3D as CollisionShape3D
@onready var fill_mesh: MeshInstance3D = $Visual/Fill as MeshInstance3D
@onready var border_viewport: SubViewport = $Visual/BorderViewport as SubViewport
@onready var border_panel: Panel = $Visual/BorderViewport/BorderPanel as Panel
@onready var border_frame: MeshInstance3D = $Visual/BorderFrame as MeshInstance3D
@onready var effects_root: Node3D = $Effects as Node3D

var characters: Array[Card3D] = []
var enemies: Array[Card3D] = []
var unit_timers: Dictionary = {}
var next_attack_times: Dictionary = {}
var is_battle_active := false

var _running_tweens: Array[Tween] = []
var _is_finishing := false
var _non_battle_cleanup_pending := false


func _ready() -> void:
	add_to_group("BattleScenes3D")
	_make_visual_resources_unique()
	_setup_border_viewport()
	update_scene_bounds()
	if battle_area and not battle_area.area_entered.is_connected(_on_battle_area_area_entered):
		battle_area.area_entered.connect(_on_battle_area_area_entered)


func add_card(card: Card3D, insert_left := false, next_attack_time := -1.0, relayout := true) -> bool:
	if card == null or not is_instance_valid(card) or _is_finishing:
		return false
	if not _is_battle_card(card):
		return false
	if characters.has(card) or enemies.has(card):
		return false

	_lock_card_for_battle(card)
	if card.get_parent() != self:
		card.reparent(self, true)

	if card.card_info is CharacterCard:
		if insert_left:
			characters.insert(0, card)
		else:
			characters.append(card)
	elif card.card_info is EnemyCard:
		if insert_left:
			enemies.insert(0, card)
		else:
			enemies.append(card)

	if relayout:
		relayout_cards()
	else:
		update_scene_bounds()

	if is_battle_active:
		_create_timer_for_unit(card, next_attack_time)
	elif _has_both_sides():
		start_battle()

	_request_non_battle_card_cleanup()
	return true


func start_battle() -> void:
	if is_battle_active or not _has_both_sides() or _is_finishing:
		return

	is_battle_active = true
	for card in get_all_cards():
		_create_timer_for_unit(card)
	print("【BattleScene3D】战斗开始: %d 角色 vs %d 敌人" % [characters.size(), enemies.size()])


func get_all_cards() -> Array[Card3D]:
	var cards: Array[Card3D] = []
	cards.append_array(characters)
	cards.append_array(enemies)
	return cards


func get_unit_count() -> int:
	return characters.size() + enemies.size()


func extract_cards_for_merge() -> Array:
	_is_finishing = true
	is_battle_active = false

	var result := []
	for card in characters.duplicate():
		_append_merge_card(result, card)
	for card in enemies.duplicate():
		_append_merge_card(result, card)

	_clear_all_timers()
	_stop_running_tweens()
	characters.clear()
	enemies.clear()
	return result


func _append_merge_card(result: Array, card: Card3D) -> void:
	if card == null or not is_instance_valid(card):
		return
	if not _is_battle_card(card):
		return

	result.append({
		"card": card,
		"next_attack_time": _get_preserved_attack_time(card),
	})


func relayout_cards() -> void:
	update_scene_bounds()
	_layout_side(characters, character_row_z)
	_layout_side(enemies, enemy_row_z)


func update_scene_bounds() -> void:
	var visual_size := _calculate_visual_size()
	_update_visual_size(visual_size)
	_update_detection_size(visual_size + detection_padding * 2.0)
	_request_non_battle_card_cleanup()


func wait_for_animations() -> void:
	while not _running_tweens.is_empty():
		var tween := _running_tweens[0]
		if tween != null and tween.is_running():
			await tween.finished
		else:
			_running_tweens.erase(tween)


func shutdown_after_merge() -> void:
	_clear_all_timers()
	queue_free()


func _on_battle_area_area_entered(area: Area3D) -> void:
	if _is_finishing:
		return

	var card := area.get_parent() as Card3D
	if card != null:
		if not _is_battle_card(card):
			_force_card_outside_battle_area(card)
			return
		card_entered_battle_area.emit(self, card)
		return

	var other_scene := area.get_parent() as BattleScene3D
	if other_scene != null and other_scene != self:
		battle_area_touched.emit(self, other_scene)


func _layout_side(cards: Array[Card3D], row_z: float) -> void:
	var count := cards.size()
	if count == 0:
		return

	var start_x := -card_spacing * float(count - 1) * 0.5
	for index in range(count):
		var card := cards[index]
		if card == null or not is_instance_valid(card):
			continue

		var target_position := _get_slot_global_position(start_x + card_spacing * index, row_z)
		var tween := create_tween()
		_track_tween(tween)
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(card, "global_position", target_position, card_move_duration)


func _get_slot_global_position(slot_x: float, row_z: float) -> Vector3:
	# 卡牌原点就是牌面中心，因此槽位目标点也使用中心坐标。
	return to_global(Vector3(slot_x, 0.0, row_z))


func _request_non_battle_card_cleanup() -> void:
	if _non_battle_cleanup_pending or not is_inside_tree() or _is_finishing:
		return

	_non_battle_cleanup_pending = true
	call_deferred("_cleanup_non_battle_cards_in_area")


func _cleanup_non_battle_cards_in_area() -> void:
	_non_battle_cleanup_pending = false
	if _is_finishing or not is_inside_tree():
		return

	var tree := get_tree()
	if tree == null:
		return

	for node in tree.get_nodes_in_group("Cards3D"):
		var card := node as Card3D
		if card == null or not is_instance_valid(card):
			continue
		if _is_battle_card(card):
			continue
		if _is_card_overlapping_battle_area(card):
			_force_card_outside_battle_area(card)


func _is_card_overlapping_battle_area(card: Card3D) -> bool:
	if card == null or battle_area_shape == null:
		return false

	var box_shape := battle_area_shape.shape as BoxShape3D
	if box_shape == null:
		return false

	var local_position := battle_area_shape.to_local(card.global_position)
	var area_extents := box_shape.size * 0.5
	var card_half_size := card.face_size * 0.5
	return absf(local_position.x) <= area_extents.x + card_half_size.x \
			and absf(local_position.z) <= area_extents.z + card_half_size.y


func _force_card_outside_battle_area(card: Card3D) -> void:
	if card == null or not is_instance_valid(card) or battle_area_shape == null:
		return

	var move_card := card.get_stack_head()
	if move_card == null or not is_instance_valid(move_card):
		return

	var box_shape := battle_area_shape.shape as BoxShape3D
	if box_shape == null:
		return

	var local_position := battle_area_shape.to_local(card.global_position)
	var area_extents := box_shape.size * 0.5
	var card_half_size := card.face_size * 0.5
	var outside_x := area_extents.x + card_half_size.x + non_battle_card_push_margin
	var outside_z := area_extents.z + card_half_size.y + non_battle_card_push_margin
	var x_overlap := outside_x - absf(local_position.x)
	var z_overlap := outside_z - absf(local_position.z)

	# 从最近的边推出去，避免非战斗卡长期卡在战斗检测区内。
	if x_overlap < z_overlap:
		local_position.x = _signed_distance(local_position.x, outside_x)
	else:
		local_position.z = _signed_distance(local_position.z, outside_z)

	var target_position := battle_area_shape.to_global(local_position)
	target_position.y = card.global_position.y
	move_card.global_position += target_position - card.global_position
	move_card.update_stack_chain_position()


func _signed_distance(value: float, distance: float) -> float:
	return -distance if value < 0.0 else distance


func _track_tween(tween: Tween) -> void:
	if tween == null:
		return
	_running_tweens.append(tween)
	tween.finished.connect(func(): _running_tweens.erase(tween), CONNECT_ONE_SHOT)


func _lock_card_for_battle(card: Card3D) -> void:
	if not card.has_meta(PREV_CAN_STACK_META_KEY):
		card.set_meta(PREV_CAN_STACK_META_KEY, card.can_stack)
	if not card.has_meta(PREV_RAY_META_KEY):
		card.set_meta(PREV_RAY_META_KEY, card.ray_interaction_enabled)
	if card.stack_detector:
		if not card.has_meta(PREV_STACK_MONITORING_META_KEY):
			card.set_meta(PREV_STACK_MONITORING_META_KEY, card.stack_detector.monitoring)
		if not card.has_meta(PREV_STACK_MONITORABLE_META_KEY):
			card.set_meta(PREV_STACK_MONITORABLE_META_KEY, card.stack_detector.monitorable)

	card.detach_from_follow_target()
	card.reset_offset()
	card.can_stack = false
	card.ray_interaction_enabled = false
	card.set_stack_detector_enabled(false)
	card.set_meta(BATTLE_META_KEY, self)
	if card.battle:
		card.battle.current_state = BattleState.Phase.BATTLE


func _restore_card_after_battle(card: Card3D) -> void:
	if card == null or not is_instance_valid(card):
		return

	if card.has_meta(PREV_CAN_STACK_META_KEY):
		card.can_stack = card.get_meta(PREV_CAN_STACK_META_KEY)
		card.remove_meta(PREV_CAN_STACK_META_KEY)
	if card.has_meta(PREV_RAY_META_KEY):
		card.ray_interaction_enabled = card.get_meta(PREV_RAY_META_KEY)
		card.remove_meta(PREV_RAY_META_KEY)
	if card.stack_detector:
		if card.has_meta(PREV_STACK_MONITORING_META_KEY):
			card.stack_detector.set_deferred("monitoring", card.get_meta(PREV_STACK_MONITORING_META_KEY))
			card.remove_meta(PREV_STACK_MONITORING_META_KEY)
		if card.has_meta(PREV_STACK_MONITORABLE_META_KEY):
			card.stack_detector.set_deferred("monitorable", card.get_meta(PREV_STACK_MONITORABLE_META_KEY))
			card.remove_meta(PREV_STACK_MONITORABLE_META_KEY)

	if card.has_meta(BATTLE_META_KEY):
		card.remove_meta(BATTLE_META_KEY)
	if card.battle:
		card.battle.current_state = BattleState.Phase.COMMON


func _create_timer_for_unit(unit: Card3D, preserved_next_attack_time := -1.0) -> void:
	if unit == null or not is_instance_valid(unit) or unit_timers.has(unit):
		return

	var resource := _get_battle_resource(unit)
	if resource == null or resource.HP <= 0:
		return

	var interval := _calculate_attack_interval(resource.speed)
	var now := _now()
	var next_time := preserved_next_attack_time if preserved_next_attack_time >= 0.0 else now + interval
	var wait_time := maxf(next_time - now, 0.05)

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = wait_time
	timer.timeout.connect(_on_unit_attack.bind(unit))
	add_child(timer)
	unit_timers[unit] = timer
	next_attack_times[unit] = now + wait_time
	timer.start()


func _on_unit_attack(attacker: Card3D) -> void:
	_remove_unit_timer(attacker)
	if not is_battle_active or _is_finishing:
		return
	if attacker == null or not is_instance_valid(attacker) or not _is_alive(attacker):
		_remove_dead_unit(attacker)
		_check_battle_end()
		return

	var target := _get_attack_target(attacker)
	if target == null:
		_check_battle_end()
		return

	await _perform_attack(attacker, target)
	_check_battle_end()

	if is_battle_active and is_instance_valid(attacker) and _is_alive(attacker):
		var resource := _get_battle_resource(attacker)
		var next_time := _now() + _calculate_attack_interval(resource.speed)
		_create_timer_for_unit(attacker, next_time)


func _get_attack_target(attacker: Card3D) -> Card3D:
	var target_side: Array[Card3D] = enemies if attacker.card_info is CharacterCard else characters
	for card in target_side:
		if card != null and is_instance_valid(card) and _is_alive(card):
			return card
	return null


func _perform_attack(attacker: Card3D, target: Card3D) -> void:
	if not _is_alive(attacker) or not _is_alive(target):
		return

	var attacker_resource := _get_battle_resource(attacker)
	if attacker_resource == null:
		return

	var damage := attacker_resource.ATK
	await _play_projectile(attacker.global_position, target.global_position)

	if not _is_alive(attacker) or not _is_alive(target):
		return

	var target_resource := _get_battle_resource(target)
	if target_resource == null:
		return

	target_resource.take_damage(damage)
	await _play_hit_effect(target)

	if not is_instance_valid(target):
		return
	if target_resource.HP <= 0:
		_remove_dead_unit(target)


func _play_projectile(from_position: Vector3, to_position: Vector3) -> void:
	var bullet := MeshInstance3D.new()
	bullet.name = "BattleBullet"

	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	bullet.mesh = mesh

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.86, 0.25, 1.0)
	bullet.material_override = material

	effects_root.add_child(bullet)
	bullet.global_position = from_position + Vector3(0.0, 0.25, 0.0)

	var tween := create_tween()
	_track_tween(tween)
	tween.tween_property(bullet, "global_position", to_position + Vector3(0.0, 0.25, 0.0), 0.25)
	await tween.finished

	if is_instance_valid(bullet):
		bullet.queue_free()


func _play_hit_effect(target: Card3D) -> void:
	if target == null or not is_instance_valid(target):
		return

	var tree := get_tree()
	if tree == null:
		return

	var original_position := target.global_position
	for _i in range(3):
		if target == null or not is_instance_valid(target):
			return
		var offset := Vector3(randf_range(-0.08, 0.08), 0.05, randf_range(-0.08, 0.08))
		target.global_position = original_position + offset
		await tree.create_timer(0.04).timeout

	if target == null or not is_instance_valid(target):
		return
	target.global_position = original_position
	await tree.create_timer(0.04).timeout


func _check_battle_end() -> void:
	if not is_battle_active or _is_finishing:
		return
	if _count_alive(characters) == 0 or _count_alive(enemies) == 0:
		_finish_battle()


func _finish_battle() -> void:
	if _is_finishing:
		return

	_is_finishing = true
	is_battle_active = false
	_clear_all_timers()
	await wait_for_animations()

	var release_parent := _get_release_parent()
	for card in get_all_cards():
		if card == null or not is_instance_valid(card):
			continue
		if _is_alive(card):
			_release_survivor_card(card, release_parent)
		else:
			card.queue_free()

	characters.clear()
	enemies.clear()
	battle_finished.emit(self)
	queue_free()


func _get_release_parent() -> Node:
	var release_parent := get_parent()
	if release_parent != null and is_instance_valid(release_parent):
		return release_parent

	var tree := get_tree()
	if tree == null:
		return null
	if tree.current_scene != null and tree.current_scene != self:
		return tree.current_scene
	return tree.root


func _release_survivor_card(card: Card3D, release_parent: Node) -> void:
	if card == null or not is_instance_valid(card):
		return

	var preserved_transform := card.global_transform
	_restore_card_after_battle(card)
	if release_parent == null or not is_instance_valid(release_parent):
		push_warning("【BattleScene3D】战斗结束时无法释放存活卡牌: %s" % card.name)
		return

	# reparent 后显式恢复全局变换，避免父节点释放时把存活单位一起带走。
	if card.get_parent() != release_parent:
		card.reparent(release_parent, false)
	card.global_transform = preserved_transform


func _remove_dead_unit(unit: Card3D) -> void:
	if unit == null:
		return
	_remove_unit_timer(unit)
	characters.erase(unit)
	enemies.erase(unit)
	if is_instance_valid(unit):
		unit.queue_free()
	relayout_cards()


func _remove_unit_timer(unit: Card3D) -> void:
	if not unit_timers.has(unit):
		return
	var timer := unit_timers[unit] as Timer
	unit_timers.erase(unit)
	next_attack_times.erase(unit)
	if timer != null and is_instance_valid(timer):
		timer.stop()
		timer.queue_free()


func _clear_all_timers() -> void:
	for unit in unit_timers.keys():
		var timer := unit_timers[unit] as Timer
		if timer != null and is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
	unit_timers.clear()
	next_attack_times.clear()


func _stop_running_tweens() -> void:
	for tween in _running_tweens.duplicate():
		if tween != null and tween.is_running():
			tween.kill()
	_running_tweens.clear()


func _get_preserved_attack_time(unit: Card3D) -> float:
	if next_attack_times.has(unit):
		return next_attack_times[unit]
	var resource := _get_battle_resource(unit)
	if resource == null:
		return _now()
	return _now() + _calculate_attack_interval(resource.speed)


func _calculate_attack_interval(speed: int) -> float:
	return maxf(BASE_ATTACK_INTERVAL - (float(speed) / 50.0), MIN_ATTACK_INTERVAL)


func _count_alive(cards: Array[Card3D]) -> int:
	var count := 0
	for card in cards:
		if _is_alive(card):
			count += 1
	return count


func _has_both_sides() -> bool:
	return _count_alive(characters) > 0 and _count_alive(enemies) > 0


func _is_alive(card: Card3D) -> bool:
	if card == null or not is_instance_valid(card):
		return false
	var resource := _get_battle_resource(card)
	return resource != null and resource.HP > 0


func _is_battle_card(card: Card3D) -> bool:
	return card != null and (card.card_info is CharacterCard or card.card_info is EnemyCard)


func _get_battle_resource(card: Card3D) -> BattleStates:
	if card == null:
		return null
	return card.card_info as BattleStates


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _make_visual_resources_unique() -> void:
	if fill_mesh and fill_mesh.mesh:
		fill_mesh.mesh = fill_mesh.mesh.duplicate()
	if border_frame and border_frame.mesh:
		border_frame.mesh = border_frame.mesh.duplicate()
	if border_frame and border_frame.material_override:
		border_frame.material_override = border_frame.material_override.duplicate()
	if battle_area_shape and battle_area_shape.shape:
		battle_area_shape.shape = battle_area_shape.shape.duplicate()


func _setup_border_viewport() -> void:
	if border_viewport == null:
		return

	border_viewport.disable_3d = true
	border_viewport.transparent_bg = true
	border_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	border_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS

	if border_panel:
		border_panel.anchor_left = 0.0
		border_panel.anchor_top = 0.0
		border_panel.anchor_right = 0.0
		border_panel.anchor_bottom = 0.0
		border_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var material: StandardMaterial3D = null
	if border_frame:
		material = border_frame.material_override as StandardMaterial3D
	if material:
		# StyleBoxTexture 先画到 2D viewport，再作为贴图显示到 3D 平面上。
		material.albedo_texture = border_viewport.get_texture()


func _calculate_visual_size() -> Vector2:
	var max_side_count := maxi(characters.size(), enemies.size())
	var card_size := _get_card_face_size()
	var content_width := card_size.x
	if max_side_count > 1:
		content_width += float(max_side_count - 1) * card_spacing

	var content_height := absf(character_row_z - enemy_row_z) + card_size.y
	return Vector2(
		maxf(min_visual_size.x, content_width + visual_padding.x * 2.0),
		maxf(min_visual_size.y, content_height + visual_padding.y * 2.0)
	)


func _get_card_face_size() -> Vector2:
	for card in get_all_cards():
		if card != null and is_instance_valid(card):
			return card.face_size
	return Vector2(2.64, 3.45)


func _update_visual_size(size: Vector2) -> void:
	var fill_plane: PlaneMesh = null
	if fill_mesh:
		fill_plane = fill_mesh.mesh as PlaneMesh
	if fill_plane:
		fill_plane.size = size

	_update_border_frame_size(size)


func _update_border_frame_size(size: Vector2) -> void:
	if border_frame:
		var border_plane := border_frame.mesh as PlaneMesh
		if border_plane:
			border_plane.size = size
		border_frame.position = Vector3(0.0, border_height * 0.5 + 0.01, 0.0)

	if border_viewport == null:
		return

	var viewport_size := Vector2i(
		maxi(1, int(ceil(size.x * border_viewport_pixels_per_unit))),
		maxi(1, int(ceil(size.y * border_viewport_pixels_per_unit)))
	)
	if border_viewport.size != viewport_size:
		border_viewport.size = viewport_size

	if border_panel:
		border_panel.position = Vector2.ZERO
		border_panel.size = Vector2(float(viewport_size.x), float(viewport_size.y))


func _update_detection_size(size: Vector2) -> void:
	if battle_area_shape == null:
		return

	var box_shape := battle_area_shape.shape as BoxShape3D
	if box_shape == null:
		return

	box_shape.size = Vector3(size.x, 0.8, size.y)
