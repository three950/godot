class_name BattleScene3DCombatController
extends RefCounted

signal unit_died(unit: Card3D)
signal battle_ended

const BASE_ATTACK_INTERVAL := 2.0
const MIN_ATTACK_INTERVAL := 0.3
const PROJECTILE_SCENE := preload("res://presentation/特效/bullet_3d.tscn")
const HIT_EFFECT_SCENE := preload("res://presentation/特效/attack_3d.tscn")
const PROJECTILE_HEIGHT_OFFSET := Vector3(0.0, 0.25, 0.0)
const PROJECTILE_TRAVEL_TIME := 0.25
const HIT_FEEDBACK_OFFSET := Vector3(1.0, 0.28, 1.3)
const HIT_FEEDBACK_LIFETIME := 0.5
const HIT_SHAKE_STEP_TIME := 0.04

var is_active := false

var _owner: Node3D = null
var _effects_root: Node3D = null
var _characters: Array[Card3D] = []
var _enemies: Array[Card3D] = []
var _unit_timers: Dictionary = {}
var _next_attack_times: Dictionary = {}
var _attack_queue: Array[int] = []
var _is_attack_queue_running := false
var _attack_animation_tweens: Array[Tween] = []
var _attack_animation_wait_timers: Array[Timer] = []
var _timers_paused := false
var _battle_end_reported := false


func configure(
		owner: Node3D,
		effects_root: Node3D,
		characters: Array[Card3D],
		enemies: Array[Card3D]
) -> void:
	_owner = owner
	_effects_root = effects_root
	set_unit_views(characters, enemies)
	_connect_global_timer_pause()


func set_unit_views(characters: Array[Card3D], enemies: Array[Card3D]) -> void:
	# controller 只读取这两个队列；增删队列仍由 BattleScene3D 负责。
	_characters = characters
	_enemies = enemies


func start_battle(characters: Array[Card3D], enemies: Array[Card3D]) -> bool:
	set_unit_views(characters, enemies)
	cleanup_invalid_entries()
	if is_active or not _has_both_sides():
		return false

	is_active = true
	_battle_end_reported = false
	for card in _get_all_cards():
		add_unit(card)
	return true


func add_unit(unit, preserved_next_attack_time := -1.0) -> void:
	var unit_card := _get_valid_card(unit)
	if unit_card == null:
		return

	# 合并战斗时会把原场景剩余冷却带过来；若战斗尚未重启，先缓存到 next_attack_times。
	if preserved_next_attack_time >= 0.0:
		_next_attack_times[unit_card] = preserved_next_attack_time

	if is_active:
		_create_timer_for_unit(unit_card, float(_next_attack_times.get(unit_card, preserved_next_attack_time)))


func forget_unit(unit) -> void:
	var unit_card := _get_valid_card(unit)
	if unit_card == null:
		cleanup_invalid_entries()
		return

	_remove_unit_timer(unit_card)
	_next_attack_times.erase(unit_card)
	_attack_queue.erase(unit_card.get_instance_id())


func stop_for_merge() -> void:
	# BattleScene3D 负责发起合并；controller 在这里停掉队列动画，保证迁移时没有旧动画继续结算。
	is_active = false
	_battle_end_reported = true
	_clear_attack_sequence_state()


func shutdown() -> void:
	is_active = false
	_battle_end_reported = true
	_clear_all_timers()
	_clear_attack_sequence_state()
	_disconnect_global_timer_pause()


func cleanup_invalid_entries() -> void:
	_cleanup_invalid_timer_entries()


func get_preserved_attack_time(unit) -> float:
	var unit_card := _get_valid_card(unit)
	if unit_card == null:
		return _now()

	var timer := _unit_timers.get(unit_card) as Timer
	if timer != null and is_instance_valid(timer):
		return _now() + maxf(timer.time_left, 0.0)
	if _next_attack_times.has(unit_card):
		return _next_attack_times[unit_card]

	var resource := _get_battle_resource(unit_card)
	if resource == null:
		return _now()
	return _now() + _calculate_attack_interval(resource.speed)


func _connect_global_timer_pause() -> void:
	_timers_paused = Events.timers_paused
	if not Events.timers_pause_changed.is_connected(_on_timers_pause_changed):
		Events.timers_pause_changed.connect(_on_timers_pause_changed)


func _disconnect_global_timer_pause() -> void:
	if Events.timers_pause_changed.is_connected(_on_timers_pause_changed):
		Events.timers_pause_changed.disconnect(_on_timers_pause_changed)


func _on_timers_pause_changed(is_paused: bool) -> void:
	_set_timers_paused(is_paused)


func _set_timers_paused(is_paused: bool) -> void:
	if _timers_paused == is_paused:
		return

	_timers_paused = is_paused
	_update_attack_timers_pause_state()
	_update_attack_animation_pause_state()


func _update_attack_timers_pause_state() -> void:
	cleanup_invalid_entries()
	var now := _now()
	for unit in _unit_timers.keys():
		var timer := _unit_timers[unit] as Timer
		if timer == null or not is_instance_valid(timer):
			continue

		_next_attack_times[unit] = now + maxf(timer.time_left, 0.0)
		timer.paused = _timers_paused


func _update_attack_animation_pause_state() -> void:
	# 攻击动画会影响下一轮冷却开始时间，因此 Tween/等待 Timer 都跟随全局战斗暂停。
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
	if unit_card == null or _unit_timers.has(unit_card):
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
	# Timer 只绑定实例 id；超时后重新找单位，避免持有已 queue_free 的 Card3D。
	timer.timeout.connect(_on_unit_attack.bind(unit_card.get_instance_id()))
	_owner.add_child(timer)
	_unit_timers[unit_card] = timer
	_next_attack_times[unit_card] = now + wait_time
	timer.start()


func _on_unit_attack(attacker_id: int) -> void:
	var attacker := _get_unit_by_instance_id(attacker_id)
	if attacker != null:
		_remove_unit_timer(attacker)
	else:
		cleanup_invalid_entries()

	if not is_active:
		return
	if attacker == null:
		_check_battle_end()
		return
	if not _is_alive(attacker):
		_report_dead_unit(attacker)
		_check_battle_end()
		return

	_queue_unit_attack(attacker_id)


func _queue_unit_attack(attacker_id: int) -> void:
	# Timer 到点只登记一次攻击请求；真正动画由队列串行播放，避免同时出手时特效重叠。
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
		if not is_active:
			_attack_queue.clear()
			break

		var attacker_id := int(_attack_queue.pop_front())
		await _perform_queued_attack(attacker_id)

	_is_attack_queue_running = false


func _perform_queued_attack(attacker_id: int) -> void:
	var attacker := _get_unit_by_instance_id(attacker_id)
	if not is_active:
		return
	if attacker == null:
		_check_battle_end()
		return
	if not _is_alive(attacker):
		_report_dead_unit(attacker)
		_check_battle_end()
		return

	var target := _get_attack_target(attacker)
	if target == null:
		_check_battle_end()
		return

	await _perform_attack(attacker, target)
	_check_battle_end()

	# 一次完整攻击动画结束后，才重新计算并开启下一轮攻击 Timer。
	if is_active and _is_alive(attacker):
		var resource := _get_battle_resource(attacker)
		if resource == null:
			return
		var next_time := _now() + _calculate_attack_interval(resource.speed)
		_create_timer_for_unit(attacker, next_time)


func _get_attack_target(attacker) -> Card3D:
	var attacker_card := _get_valid_card(attacker)
	if attacker_card == null:
		return null

	var target_side: Array[Card3D] = _enemies if attacker_card.card_info is CharacterCard else _characters
	for card in target_side:
		var target_card := _get_valid_card(card)
		if target_card != null and _is_alive(target_card):
			return target_card
	return null


func _perform_attack(attacker, target) -> void:
	var attacker_card := _get_valid_card(attacker)
	var target_card := _get_valid_card(target)
	if attacker_card == null or target_card == null:
		return

	var attacker_resource := _get_battle_resource(attacker_card)
	if attacker_resource == null or not _is_alive(attacker_card) or not _is_alive(target_card):
		return

	var damage := attacker_resource.ATK
	var attack_from := attacker_card.global_position
	var attack_to := target_card.global_position

	# 每次攻击前重新读取 attack_type；人物换武器后，下一次出手会立刻改用新动画。
	match attacker_resource.attack_type:
		BattleStates.attackType.remote:
			await _play_projectile(attack_from, attack_to)
		_:
			# 近战攻击不移动卡牌本体；命中表现交给白闪、伤害数字和受击抖动。
			pass

	# 子弹飞行期间目标若已离场，本次攻击直接放弃，不再做额外补偿。
	target_card = _get_valid_card(target)
	if target_card == null or not _is_alive(target_card):
		return

	_show_hit_flash(target_card)

	var target_resource := _get_battle_resource(target_card)
	if target_resource == null:
		return

	var hp_before := target_resource.HP
	target_resource.take_damage(damage)
	var actual_damage := hp_before - target_resource.HP
	_show_hit_feedback(target_card.global_position, actual_damage)
	if target_resource.HP <= 0:
		_report_dead_unit(target_card)
		return

	await _play_hit_effect(target_card)


func _play_projectile(from_position: Vector3, to_position: Vector3) -> void:
	# 子弹外观放在独立场景里，controller 只负责生成、移动和回收。
	var bullet := PROJECTILE_SCENE.instantiate() as Node3D
	if bullet == null or _effects_root == null:
		return
	bullet.name = "BattleBullet"

	_effects_root.add_child(bullet)
	bullet.global_position = from_position + PROJECTILE_HEIGHT_OFFSET

	var tween := _create_attack_animation_tween()
	tween.tween_property(bullet, "global_position", to_position + PROJECTILE_HEIGHT_OFFSET, PROJECTILE_TRAVEL_TIME)
	await tween.finished

	bullet.queue_free()


func _create_attack_animation_tween() -> Tween:
	var tween := _owner.create_tween()
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

	var timer := _create_attack_animation_wait_timer(duration)
	timer.start()
	await timer.timeout

	_attack_animation_wait_timers.erase(timer)
	timer.queue_free()


func _start_attack_animation_timeout(duration: float, callback: Callable) -> void:
	if duration <= 0.0:
		if callback.is_valid():
			callback.call()
		return

	var timer := _create_attack_animation_wait_timer(duration)
	timer.timeout.connect(_on_attack_animation_timeout.bind(timer, callback), CONNECT_ONE_SHOT)
	timer.start()


func _create_attack_animation_wait_timer(duration: float) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = duration
	timer.paused = _timers_paused
	_owner.add_child(timer)
	_attack_animation_wait_timers.append(timer)
	return timer


func _on_attack_animation_timeout(timer: Timer, callback: Callable) -> void:
	_attack_animation_wait_timers.erase(timer)
	if callback.is_valid():
		callback.call()
	timer.queue_free()


func _show_hit_feedback(target_position: Vector3, damage: int) -> void:
	if _effects_root == null:
		return

	var hit_feedback := HIT_EFFECT_SCENE.instantiate() as Attack3D
	if hit_feedback == null:
		return
	hit_feedback.name = "HitFeedback"
	# 受击反馈挂在 Effects 下并使用一次性全局坐标，避免目标卡牌抖动时特效跟着抖。
	_effects_root.add_child(hit_feedback)
	hit_feedback.global_position = target_position + HIT_FEEDBACK_OFFSET
	hit_feedback.damage = damage

	await _wait_attack_animation_time(HIT_FEEDBACK_LIFETIME)
	hit_feedback.queue_free()


func _show_hit_flash(target_card: Card3D) -> void:
	if target_card == null or _effects_root == null:
		return

	var flash_mesh := MeshInstance3D.new()
	flash_mesh.name = "HitWhiteMask"
	flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash_mesh.mesh = _create_hit_flash_mesh(target_card.face_size)
	flash_mesh.material_override = _create_hit_flash_material()

	# 遮罩使用命中瞬间的全局姿态；之后卡牌抖动不会带着遮罩一起抖。
	_effects_root.add_child(flash_mesh)
	flash_mesh.global_transform = target_card.global_transform
	var card_normal := target_card.global_transform.basis.y.normalized()
	flash_mesh.global_position = target_card.global_position + card_normal * _float_setting("hit_flash_surface_offset", 0.08)

	_start_attack_animation_timeout(
		_float_setting("hit_flash_lifetime", 0.05),
		func() -> void:
			flash_mesh.queue_free()
	)


func _create_hit_flash_mesh(card_face_size: Vector2) -> PlaneMesh:
	var mesh := PlaneMesh.new()
	mesh.size = card_face_size * _float_setting("hit_flash_scale", 1.05)
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
	# 这段抖动会阻塞下一段攻击动画，所以等待也必须跟随全局计时暂停。
	await _wait_attack_animation_time(HIT_SHAKE_STEP_TIME)


func _check_battle_end() -> void:
	if not is_active or _battle_end_reported:
		return
	cleanup_invalid_entries()
	if _count_alive(_characters) == 0 or _count_alive(_enemies) == 0:
		_finish_battle()


func _finish_battle() -> void:
	if _battle_end_reported:
		return

	_battle_end_reported = true
	is_active = false
	_clear_all_timers()
	_clear_attack_sequence_state()
	battle_ended.emit()


func _report_dead_unit(unit: Card3D) -> void:
	var unit_card := _get_valid_card(unit)
	if unit_card == null:
		cleanup_invalid_entries()
		return

	var unit_id := unit_card.get_instance_id()
	_remove_unit_timer(unit_card)
	_attack_queue.erase(unit_id)
	unit_died.emit(unit_card)


func _remove_unit_timer(unit) -> void:
	if not _unit_timers.has(unit):
		return
	var timer := _unit_timers[unit] as Timer
	_unit_timers.erase(unit)
	_next_attack_times.erase(unit)
	if timer != null:
		timer.stop()
		timer.queue_free()


func _clear_all_timers() -> void:
	for unit in _unit_timers.keys():
		var timer := _unit_timers[unit] as Timer
		if timer != null:
			timer.stop()
			timer.queue_free()
	_unit_timers.clear()
	_next_attack_times.clear()


func _clear_attack_sequence_state() -> void:
	_attack_queue.clear()
	_is_attack_queue_running = false

	for tween in _attack_animation_tweens.duplicate():
		if tween != null and tween.is_valid():
			tween.kill()
	_attack_animation_tweens.clear()

	for timer in _attack_animation_wait_timers.duplicate():
		if timer != null:
			timer.stop()
			timer.queue_free()
	_attack_animation_wait_timers.clear()
	_clear_combat_effect_nodes()


func _clear_combat_effect_nodes() -> void:
	if _effects_root == null:
		return

	# Effects 节点只承载战斗表现；合并或结束时直接清空，避免旧子弹/白闪残留。
	for child in _effects_root.get_children():
		child.queue_free()


func _cleanup_invalid_timer_entries() -> void:
	for unit in _unit_timers.keys():
		var unit_card := _get_valid_card(unit)
		var timer := _unit_timers[unit] as Timer
		if unit_card == null or not _is_registered_unit(unit_card):
			if timer != null and is_instance_valid(timer):
				timer.stop()
				timer.queue_free()
			_unit_timers.erase(unit)
			_next_attack_times.erase(unit)
			continue
		if timer == null or not is_instance_valid(timer):
			_unit_timers.erase(unit)
			_next_attack_times.erase(unit)

	for unit in _next_attack_times.keys():
		var unit_card := _get_valid_card(unit)
		if unit_card == null or not _is_registered_unit(unit_card):
			_next_attack_times.erase(unit)


func _is_registered_unit(unit) -> bool:
	var unit_card := _get_valid_card(unit)
	return unit_card != null and (_characters.has(unit_card) or _enemies.has(unit_card))


func _get_unit_by_instance_id(unit_id: int) -> Card3D:
	for card in _get_all_cards():
		if card.get_instance_id() == unit_id:
			return card
	return null


func _get_all_cards() -> Array[Card3D]:
	var cards: Array[Card3D] = []
	for card in _characters:
		var valid_character := _get_valid_card(card)
		if valid_character != null:
			cards.append(valid_character)
	for card in _enemies:
		var valid_enemy := _get_valid_card(card)
		if valid_enemy != null:
			cards.append(valid_enemy)
	return cards


func _calculate_attack_interval(speed: int) -> float:
	return maxf(BASE_ATTACK_INTERVAL - (float(speed) / 50.0), MIN_ATTACK_INTERVAL)


func _count_alive(cards: Array) -> int:
	var count := 0
	for card in cards:
		if _is_alive(card):
			count += 1
	return count


func _has_both_sides() -> bool:
	return _count_alive(_characters) > 0 and _count_alive(_enemies) > 0


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


func _float_setting(name: String, fallback: float) -> float:
	var value = _owner.get(name)
	return fallback if value == null else float(value)


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
