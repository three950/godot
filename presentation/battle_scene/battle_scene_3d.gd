class_name BattleScene3D
extends Node3D

signal card_entered_battle_area(battle_scene: BattleScene3D, card: Card3D)
signal battle_area_touched(battle_scene: BattleScene3D, other_scene: BattleScene3D)
signal battle_finished(battle_scene: BattleScene3D)

const BASE_ATTACK_INTERVAL := 2.0
const MIN_ATTACK_INTERVAL := 0.3
const PROJECTILE_SCENE := preload("res://presentation/特效/bullet_3d.tscn")
const HIT_EFFECT_SCENE := preload("res://presentation/特效/attack_3d.tscn")
const PROJECTILE_HEIGHT_OFFSET := Vector3(0.0, 0.25, 0.0)
const PROJECTILE_TRAVEL_TIME := 0.25
const HIT_FEEDBACK_OFFSET := Vector3(1, 0.28, 1.3)
const HIT_FEEDBACK_LIFETIME := 0.5
const HIT_SHAKE_STEP_TIME := 0.04

@export var creation_index: int = 0
@export var card_spacing: float = 3.0
@export var character_row_z: float = 1.8
@export var enemy_row_z: float = -1.8
@export var min_visual_size: Vector2 = Vector2(9.0, 7.0)
@export var visual_padding: Vector2 = Vector2(0.7, 0.9)
@export var border_height: float = 0.06
@export var border_viewport_pixels_per_unit: float = 100.0
@export var non_battle_card_push_margin: float = 0.35
@export_group("Hit Flash")
@export var hit_flash_scale: float = 1.05
@export var hit_flash_lifetime: float = 0.05
@export var hit_flash_surface_offset: float = 0.08

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
var _attack_queue: Array[int] = []
var _is_attack_queue_running := false
var _attack_animation_tweens: Array[Tween] = []
var _attack_animation_wait_timers: Array[Timer] = []


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
	if _is_finishing:
		return false

	var unit := _card_guard.accept_battle_unit(card, self, characters, enemies)
	if unit == null:
		return false

	if unit.card_info is CharacterCard:
		if insert_left:
			characters.insert(0, unit)
		else:
			characters.append(unit)
	elif unit.card_info is EnemyCard:
		if insert_left:
			enemies.insert(0, unit)
		else:
			enemies.append(unit)

	print("【BattleScene3D】加入战斗单位: %s (%d 角色 vs %d 敌人)" % [unit.cardname, characters.size(), enemies.size()])

	if relayout:
		relayout_cards()
	else:
		update_scene_bounds()

	if is_battle_active:
		_create_timer_for_unit(unit, next_attack_time)
	elif _has_both_sides():
		start_battle()

	_request_non_battle_card_cleanup()
	return true


func start_battle() -> void:
	_cleanup_invalid_units()
	if is_battle_active or not _has_both_sides() or _is_finishing:
		return

	is_battle_active = true
	for card in get_all_cards():
		_create_timer_for_unit(card)
	print("【BattleScene3D】战斗开始: %d 角色 vs %d 敌人" % [characters.size(), enemies.size()])


func get_all_cards() -> Array[Card3D]:
	_cleanup_invalid_units()
	var cards: Array[Card3D] = []
	for card in characters:
		var valid_character := _get_valid_card(card)
		if valid_character != null:
			cards.append(valid_character)
	for card in enemies:
		var valid_enemy := _get_valid_card(card)
		if valid_enemy != null:
			cards.append(valid_enemy)
	return cards


func get_unit_count() -> int:
	_cleanup_invalid_units()
	return characters.size() + enemies.size()


func extract_cards_for_merge() -> Array:
	_is_finishing = true
	is_battle_active = false
	# 合并战斗时先停掉还没播完的攻击动画，避免旧队列继续结算已迁移的单位。
	_clear_attack_sequence_state()
	_cleanup_invalid_units()

	var result := []
	for card in characters.duplicate():
		_append_merge_card(result, card)
	for card in enemies.duplicate():
		_append_merge_card(result, card)

	_clear_all_timers()
	characters.clear()
	enemies.clear()
	return result


func _append_merge_card(result: Array, card) -> void:
	var card_3d := _get_valid_card(card)
	if card_3d == null:
		return
	if not _card_guard.is_battle_card(card_3d):
		return

	result.append({
		"card": card_3d,
		"next_attack_time": _get_preserved_attack_time(card_3d),
	})


func relayout_cards() -> void:
	_cleanup_invalid_units()
	_area_controller.relayout_cards(characters, enemies)
	_request_non_battle_card_cleanup()


func update_scene_bounds() -> void:
	_cleanup_invalid_units()
	_area_controller.update_scene_bounds(characters, enemies)
	_request_non_battle_card_cleanup()


func shutdown_after_merge() -> void:
	_clear_all_timers()
	_clear_attack_sequence_state()
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
	_update_attack_animation_pause_state()


func _update_attack_timers_pause_state() -> void:
	_cleanup_invalid_units()
	var now := _now()
	for unit in unit_timers.keys():
		var timer := unit_timers[unit] as Timer
		if timer == null or not is_instance_valid(timer):
			continue

		next_attack_times[unit] = now + maxf(timer.time_left, 0.0)
		timer.paused = _timers_paused


func _update_attack_animation_pause_state() -> void:
	# 攻击动画现在会决定下一轮冷却何时开始，因此这些 Tween/Timer 也必须跟随全局计时暂停。
	for tween in _attack_animation_tweens.duplicate():
		if tween == null or not tween.is_valid():
			_attack_animation_tweens.erase(tween)
			continue
		if _timers_paused:
			tween.pause()
		else:
			tween.play()

	for timer in _attack_animation_wait_timers.duplicate():
		if timer == null or not is_instance_valid(timer):
			_attack_animation_wait_timers.erase(timer)
			continue
		timer.paused = _timers_paused


func _create_timer_for_unit(unit, preserved_next_attack_time := -1.0) -> void:
	var unit_card := _get_valid_card(unit)
	if unit_card == null or unit_timers.has(unit_card):
		return

	var resource := _get_battle_resource(unit_card)
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
	# Timer 只绑定实例 id，不绑定卡牌对象本身；超时后重新查找，避免 await/queue_free 后拿到悬空 Node。
	timer.timeout.connect(_on_unit_attack.bind(unit_card.get_instance_id()))
	add_child(timer)
	unit_timers[unit_card] = timer
	next_attack_times[unit_card] = now + wait_time
	timer.start()


func _on_unit_attack(attacker_id: int) -> void:
	var attacker = _get_unit_by_instance_id(attacker_id)
	if attacker != null:
		_remove_unit_timer(attacker)
	else:
		_cleanup_invalid_units()

	if not is_battle_active or _is_finishing:
		return
	if not _is_alive(attacker):
		_remove_dead_unit(attacker)
		_check_battle_end()
		return

	_queue_unit_attack(attacker_id)


func _queue_unit_attack(attacker_id: int) -> void:
	# Timer 到点只登记一次攻击请求；真正的动画由队列串行播放，避免双方同时出手时特效重叠。
	if not _attack_queue.has(attacker_id):
		_attack_queue.append(attacker_id)
	_start_attack_queue_if_needed()


func _start_attack_queue_if_needed() -> void:
	if _is_attack_queue_running:
		return

	_is_attack_queue_running = true
	call_deferred("_drain_attack_queue")


func _drain_attack_queue() -> void:
	while _attack_queue.size() > 0:
		if not is_battle_active or _is_finishing:
			_attack_queue.clear()
			break

		var attacker_id := int(_attack_queue.pop_front())
		await _perform_queued_attack(attacker_id)

	_is_attack_queue_running = false


func _perform_queued_attack(attacker_id: int) -> void:
	var attacker = _get_unit_by_instance_id(attacker_id)
	if not is_battle_active or _is_finishing:
		return
	if not _is_alive(attacker):
		_remove_dead_unit(attacker)
		_check_battle_end()
		return

	var target := _get_attack_target(attacker)
	if target == null:
		_check_battle_end()
		return

	await _perform_attack(attacker, target)
	_check_battle_end()

	# 只有自己的完整攻击动画结束后，才重新计算并开启下一轮攻击 Timer。
	attacker = _get_unit_by_instance_id(attacker_id)
	if is_battle_active and _is_alive(attacker):
		var resource := _get_battle_resource(attacker)
		if resource == null:
			return
		var next_time := _now() + _calculate_attack_interval(resource.speed)
		_create_timer_for_unit(attacker, next_time)


func _get_attack_target(attacker) -> Card3D:
	var attacker_card := _get_valid_card(attacker)
	if attacker_card == null:
		return null

	var target_side: Array[Card3D] = enemies if attacker_card.card_info is CharacterCard else characters
	for card in target_side:
		var target_card := _get_valid_card(card)
		if target_card != null and _is_alive(target_card):
			return target_card
	return null


func _perform_attack(attacker, target) -> void:
	var attacker_card := _get_valid_card(attacker)
	var target_card := _get_valid_card(target)
	if not _is_alive(attacker_card) or not _is_alive(target_card):
		return

	var attacker_resource := _get_battle_resource(attacker_card)
	if attacker_resource == null:
		return

	var damage := attacker_resource.ATK
	var attack_from := attacker_card.global_position
	var attack_to := target_card.global_position

	# 每次真正播放攻击前都重新读取 attack_type；人物换武器后，下一次出手会立刻改用新动画。
	match attacker_resource.attack_type:
		BattleStates.attackType.remote:
			await _play_projectile(attack_from, attack_to)
		_:
			# 近战攻击不再移动卡牌本体；命中表现交给后续白闪、伤害数字和受击抖动。
			pass

	# 远程攻击的 await 期间任意一张卡都可能已被合并、死亡或释放，必须重新校验再读属性。
	attacker_card = _get_valid_card(attacker)
	target_card = _get_valid_card(target)
	if not _is_alive(attacker_card) or not _is_alive(target_card):
		return

	_show_hit_flash(target_card)

	var target_resource := _get_battle_resource(target_card)
	if target_resource == null:
		return

	var hp_before := target_resource.HP
	target_resource.take_damage(damage)
	var actual_damage := hp_before - target_resource.HP
	_show_hit_feedback(target_card.global_position, actual_damage)
	await _play_hit_effect(target_card)

	target_card = _get_valid_card(target)
	if target_card == null:
		return
	if target_resource.HP <= 0:
		_remove_dead_unit(target_card)


func _play_projectile(from_position: Vector3, to_position: Vector3) -> void:
	# 子弹外观放在独立场景里，脚本只负责生成、移动和回收，方便之后在编辑器里调整特效。
	var bullet := PROJECTILE_SCENE.instantiate() as Node3D
	if bullet == null:
		return
	bullet.name = "BattleBullet"

	effects_root.add_child(bullet)
	bullet.global_position = from_position + PROJECTILE_HEIGHT_OFFSET

	var tween := _create_attack_animation_tween()
	tween.tween_property(bullet, "global_position", to_position + PROJECTILE_HEIGHT_OFFSET, PROJECTILE_TRAVEL_TIME)
	await tween.finished

	# Tween 结束前战斗场景可能被合并/释放，回收前必须确认子弹实例仍然有效。
	if is_instance_valid(bullet):
		bullet.queue_free()


func _create_attack_animation_tween() -> Tween:
	var tween := create_tween()
	_attack_animation_tweens.append(tween)
	if _timers_paused:
		tween.pause()
	tween.finished.connect(_on_attack_animation_tween_finished.bind(tween), CONNECT_ONE_SHOT)
	return tween


func _on_attack_animation_tween_finished(tween: Tween) -> void:
	_attack_animation_tweens.erase(tween)


func _wait_attack_animation_time(duration: float) -> void:
	if duration <= 0.0:
		return

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = duration
	timer.paused = _timers_paused
	add_child(timer)
	_attack_animation_wait_timers.append(timer)
	timer.start()
	await timer.timeout

	_attack_animation_wait_timers.erase(timer)
	if is_instance_valid(timer):
		timer.queue_free()


func _show_hit_feedback(target_position: Vector3, damage: int) -> void:
	if effects_root == null:
		return

	var tree := get_tree()
	if tree == null:
		return

	var hit_feedback := HIT_EFFECT_SCENE.instantiate() as Attack3D
	if hit_feedback == null:
		return
	hit_feedback.name = "HitFeedback"
	# 受击反馈挂在 Effects 下并使用一次性全局坐标，避免目标卡牌抖动时特效跟着抖。
	effects_root.add_child(hit_feedback)
	hit_feedback.global_position = target_position + HIT_FEEDBACK_OFFSET
	hit_feedback.damage = damage

	# 这是纯视觉停留时间，不参与攻击冷却；保持和原受击抖动一样不接入全局战斗暂停。
	await tree.create_timer(HIT_FEEDBACK_LIFETIME).timeout
	if is_instance_valid(hit_feedback):
		hit_feedback.queue_free()


func _show_hit_flash(target_card: Card3D) -> void:
	if target_card == null or effects_root == null:
		return

	var tree := get_tree()
	if tree == null:
		return

	var flash_mesh := MeshInstance3D.new()
	flash_mesh.name = "HitWhiteMask"
	flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash_mesh.mesh = _create_hit_flash_mesh(target_card.face_size)
	flash_mesh.material_override = _create_hit_flash_material()

	# 遮罩挂在 Effects 下，使用命中瞬间的卡牌全局姿态；之后卡牌抖动不会带着遮罩一起抖。
	effects_root.add_child(flash_mesh)
	flash_mesh.global_transform = target_card.global_transform
	var card_normal := target_card.global_transform.basis.y.normalized()
	flash_mesh.global_position = target_card.global_position + card_normal * hit_flash_surface_offset

	# 这是纯视觉闪白，不参与攻击冷却；不等待它结束，避免拖慢后续扣血和受击反馈。
	tree.create_timer(hit_flash_lifetime).timeout.connect(
		func() -> void:
			if is_instance_valid(flash_mesh):
				flash_mesh.queue_free()
	)


func _create_hit_flash_mesh(card_face_size: Vector2) -> PlaneMesh:
	var mesh := PlaneMesh.new()
	mesh.size = card_face_size * hit_flash_scale
	return mesh


func _create_hit_flash_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = -80
	material.albedo_color = Color.WHITE
	material.disable_receive_shadows = true
	material.no_depth_test = true
	return material


func _play_hit_effect(target) -> void:
	var target_card := _get_valid_card(target)
	if target_card == null:
		return

	var tree := get_tree()
	if tree == null:
		return

	var original_position := target_card.global_position
	for _i in range(3):
		target_card = _get_valid_card(target)
		if target_card == null:
			return
		var offset := Vector3(randf_range(-0.08, 0.08), 0.05, randf_range(-0.08, 0.08))
		target_card.global_position = original_position + offset
		await _wait_attack_animation_time(HIT_SHAKE_STEP_TIME)

	target_card = _get_valid_card(target)
	if target_card == null:
		return
	target_card.global_position = original_position
	# 这段抖动会阻塞下一段攻击动画，所以它的等待也跟随全局计时暂停。
	await _wait_attack_animation_time(HIT_SHAKE_STEP_TIME)


func _check_battle_end() -> void:
	if not is_battle_active or _is_finishing:
		return
	_cleanup_invalid_units()
	if _count_alive(characters) == 0 or _count_alive(enemies) == 0:
		_finish_battle()


func _finish_battle() -> void:
	if _is_finishing:
		return

	_is_finishing = true
	is_battle_active = false
	_clear_all_timers()
	_clear_attack_sequence_state()

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
	var unit_card := _get_valid_card(unit)
	if unit_card == null:
		_cleanup_invalid_units()
		return
	_remove_unit_timer(unit_card)
	characters.erase(unit_card)
	enemies.erase(unit_card)
	if is_instance_valid(unit_card):
		unit_card.queue_free()
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


func _clear_attack_sequence_state() -> void:
	_attack_queue.clear()
	_is_attack_queue_running = false

	for tween in _attack_animation_tweens.duplicate():
		if tween != null and tween.is_valid():
			tween.kill()
	_attack_animation_tweens.clear()

	for timer in _attack_animation_wait_timers.duplicate():
		if timer != null and is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
	_attack_animation_wait_timers.clear()


func _get_preserved_attack_time(unit) -> float:
	var unit_card := _get_valid_card(unit)
	if unit_card == null:
		return _now()

	var timer := unit_timers.get(unit_card) as Timer
	if timer != null and is_instance_valid(timer):
		return _now() + maxf(timer.time_left, 0.0)
	if next_attack_times.has(unit_card):
		return next_attack_times[unit_card]
	var resource := _get_battle_resource(unit_card)
	if resource == null:
		return _now()
	return _now() + _calculate_attack_interval(resource.speed)


func _cleanup_invalid_units() -> void:
	_remove_invalid_cards_from_side(characters)
	_remove_invalid_cards_from_side(enemies)
	_cleanup_invalid_timer_entries()


func _remove_invalid_cards_from_side(cards: Array[Card3D]) -> void:
	var index := cards.size() - 1
	while index >= 0:
		var card := _get_valid_card(cards[index])
		if card == null or not _card_guard.is_battle_card(card):
			cards.remove_at(index)
		index -= 1


func _cleanup_invalid_timer_entries() -> void:
	for unit in unit_timers.keys():
		var unit_card := _get_valid_card(unit)
		var timer := unit_timers[unit] as Timer
		if unit_card == null or not _is_registered_unit(unit_card):
			if timer != null and is_instance_valid(timer):
				timer.stop()
				timer.queue_free()
			unit_timers.erase(unit)
			next_attack_times.erase(unit)
			continue
		if timer == null or not is_instance_valid(timer):
			unit_timers.erase(unit)
			next_attack_times.erase(unit)

	for unit in next_attack_times.keys():
		var unit_card := _get_valid_card(unit)
		if unit_card == null or not _is_registered_unit(unit_card):
			next_attack_times.erase(unit)


func _is_registered_unit(unit) -> bool:
	var unit_card := _get_valid_card(unit)
	return unit_card != null and (characters.has(unit_card) or enemies.has(unit_card))


func _get_unit_by_instance_id(unit_id: int) -> Card3D:
	for card in get_all_cards():
		if card.get_instance_id() == unit_id:
			return card
	return null


func _calculate_attack_interval(speed: int) -> float:
	return maxf(BASE_ATTACK_INTERVAL - (float(speed) / 50.0), MIN_ATTACK_INTERVAL)


func _count_alive(cards: Array) -> int:
	var count := 0
	for card in cards:
		if _is_alive(card):
			count += 1
	return count


func _has_both_sides() -> bool:
	return _count_alive(characters) > 0 and _count_alive(enemies) > 0


func _is_alive(card) -> bool:
	var resource := _get_battle_resource(card)
	return resource != null and resource.HP > 0


func _get_battle_resource(card) -> BattleStates:
	var card_3d := _get_valid_card(card)
	if card_3d == null:
		return null
	return card_3d.card_info as BattleStates


func _get_valid_card(candidate) -> Card3D:
	if candidate == null or not (candidate is Object):
		return null
	if not is_instance_valid(candidate):
		return null
	return candidate as Card3D


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
