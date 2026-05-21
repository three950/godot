class_name BattleScene3D
extends Node3D

signal card_entered_battle_area(battle_scene: BattleScene3D, card: Card3D)
signal battle_area_touched(battle_scene: BattleScene3D, other_scene: BattleScene3D)
signal battle_finished(battle_scene: BattleScene3D)

const BASE_ATTACK_INTERVAL := 2.0
const MIN_ATTACK_INTERVAL := 0.3

@export var creation_index: int = 0
@export var card_spacing: float = 3.0
@export var character_row_z: float = 1.8
@export var enemy_row_z: float = -1.8
@export var min_visual_size: Vector2 = Vector2(9.0, 7.0)
@export var visual_padding: Vector2 = Vector2(0.7, 0.9)
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

var _area_controller := BattleScene3DAreaController.new()
var _card_guard := BattleScene3DCardGuard.new()
var _is_finishing := false
var _non_battle_cleanup_pending := false
var _timers_paused := false


func _ready() -> void:
	add_to_group("BattleScenes3D")
	_configure_helpers()
	_area_controller.make_visual_resources_unique()
	_area_controller.setup_border_viewport()
	_connect_global_timer_pause()
	update_scene_bounds()
	if battle_area and not battle_area.area_entered.is_connected(_on_battle_area_area_entered):
		battle_area.area_entered.connect(_on_battle_area_area_entered)


func _configure_helpers() -> void:
	_area_controller.configure(
		self,
		battle_area_shape,
		fill_mesh,
		border_viewport,
		border_panel,
		border_frame
	)
	_card_guard.configure(battle_area_shape, non_battle_card_push_margin)


func add_card(card: Card3D, insert_left := false, next_attack_time := -1.0, relayout := true) -> bool:
	if card == null or not is_instance_valid(card) or _is_finishing:
		return false
	if not _card_guard.is_battle_card(card):
		return false
	if characters.has(card) or enemies.has(card):
		return false

	_card_guard.lock_card_for_battle(card, self)
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
	characters.clear()
	enemies.clear()
	return result


func _append_merge_card(result: Array, card: Card3D) -> void:
	if card == null or not is_instance_valid(card):
		return
	if not _card_guard.is_battle_card(card):
		return

	result.append({
		"card": card,
		"next_attack_time": _get_preserved_attack_time(card),
	})


func relayout_cards() -> void:
	_area_controller.relayout_cards(characters, enemies)
	_request_non_battle_card_cleanup()


func update_scene_bounds() -> void:
	_area_controller.update_scene_bounds(characters, enemies)
	_request_non_battle_card_cleanup()


func shutdown_after_merge() -> void:
	_clear_all_timers()
	queue_free()


func _on_battle_area_area_entered(area: Area3D) -> void:
	if _is_finishing:
		return

	var card := area.get_parent() as Card3D
	if card != null:
		if not _card_guard.is_battle_card(card):
			_emit_cards_entered_battle_area(_card_guard.push_non_battle_card_from_area(card))
			return
		card_entered_battle_area.emit(self, card)
		return

	var other_scene := area.get_parent() as BattleScene3D
	if other_scene != null and other_scene != self:
		battle_area_touched.emit(self, other_scene)


func _request_non_battle_card_cleanup() -> void:
	if _non_battle_cleanup_pending or not is_inside_tree() or _is_finishing:
		return

	_non_battle_cleanup_pending = true
	call_deferred("_cleanup_non_battle_cards_in_area")


func _cleanup_non_battle_cards_in_area() -> void:
	_non_battle_cleanup_pending = false
	if _is_finishing or not is_inside_tree():
		return

	_emit_cards_entered_battle_area(_card_guard.cleanup_non_battle_cards_in_area(self))


func _emit_cards_entered_battle_area(cards: Array[Card3D]) -> void:
	for card in cards:
		if card == null or not is_instance_valid(card):
			continue
		if not _card_guard.is_battle_card(card):
			continue
		if _card_guard.is_card_overlapping_battle_area(card):
			card_entered_battle_area.emit(self, card)


func _connect_global_timer_pause() -> void:
	_timers_paused = Events.timers_paused
	if not Events.timers_pause_changed.is_connected(_on_timers_pause_changed):
		Events.timers_pause_changed.connect(_on_timers_pause_changed)


func _on_timers_pause_changed(is_paused: bool) -> void:
	_set_timers_paused(is_paused)


func _set_timers_paused(is_paused: bool) -> void:
	if _timers_paused == is_paused:
		return

	_timers_paused = is_paused
	_update_attack_timers_pause_state()


func _update_attack_timers_pause_state() -> void:
	var now := _now()
	for unit in unit_timers.keys():
		var timer := unit_timers[unit] as Timer
		if timer == null or not is_instance_valid(timer):
			continue

		next_attack_times[unit] = now + maxf(timer.time_left, 0.0)
		timer.paused = _timers_paused


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
	timer.paused = _timers_paused
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
	# 命中特效是纯视觉反馈，战斗暂停只作用于攻击 Timer。
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

	var release_parent := _get_release_parent()
	for card in get_all_cards():
		if card == null or not is_instance_valid(card):
			continue
		if _is_alive(card):
			_card_guard.release_survivor_card(card, release_parent)
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


func _remove_dead_unit(unit) -> void:
	if unit == null:
		return
	_remove_unit_timer(unit)
	characters.erase(unit)
	enemies.erase(unit)
	if is_instance_valid(unit):
		unit.queue_free()
	relayout_cards()


func _remove_unit_timer(unit) -> void:
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


func _get_preserved_attack_time(unit: Card3D) -> float:
	var timer := unit_timers.get(unit) as Timer
	if timer != null and is_instance_valid(timer):
		return _now() + maxf(timer.time_left, 0.0)
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


func _is_alive(card) -> bool:
	if card == null or not is_instance_valid(card):
		return false
	var resource := _get_battle_resource(card)
	return resource != null and resource.HP > 0


func _get_battle_resource(card) -> BattleStates:
	if card == null or not is_instance_valid(card):
		return null
	var card_3d := card as Card3D
	if card_3d == null:
		return null
	return card_3d.card_info as BattleStates


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
