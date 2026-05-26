class_name BattleScene3D
extends Node3D

signal card_entered_battle_area(battle_scene: BattleScene3D, card: Card3D)
signal battle_area_touched(battle_scene: BattleScene3D, other_scene: BattleScene3D)
signal battle_finished(battle_scene: BattleScene3D)

const COMBAT_CONTROLLER_SCRIPT := preload("res://presentation/battle_scene/battle_scene_3d_combat_controller.gd")
const BATTLE_COMBAT_PROFILE_SCRIPT := preload("res://presentation/battle_scene/combat/battle_combat_profile.gd")

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
# 白闪参数仍暴露在战斗场景上，实际读取和播放由 CombatController 负责。
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
var is_battle_active := false

var _area_controller := BattleScene3DAreaController.new()
var _card_guard := BattleScene3DCardGuard.new()
var _combat_controller = COMBAT_CONTROLLER_SCRIPT.new()
var _is_finishing := false
var _non_battle_cleanup_pending := false


func _ready() -> void:
	add_to_group("BattleScenes3D")
	_configure_helpers()
	_area_controller.make_visual_resources_unique()
	_area_controller.setup_border_viewport()
	update_scene_bounds()
	if battle_area and not battle_area.area_entered.is_connected(_on_battle_area_area_entered):
		battle_area.area_entered.connect(_on_battle_area_area_entered)


func _exit_tree() -> void:
	# BattleScene3D 是 combat controller 的生命周期所有者；场景退出时统一断开计时信号和清理 Timer。
	_combat_controller.shutdown()


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
	_combat_controller.configure(self, effects_root, characters, enemies)
	_connect_combat_controller_signals()


func _connect_combat_controller_signals() -> void:
	if not _combat_controller.unit_died.is_connected(_on_combat_unit_died):
		_combat_controller.unit_died.connect(_on_combat_unit_died)
	if not _combat_controller.battle_ended.is_connected(_on_combat_battle_ended):
		_combat_controller.battle_ended.connect(_on_combat_battle_ended)


func add_card(card: Card3D, insert_left := false, next_attack_time := -1.0, relayout := true) -> bool:
	if _is_finishing:
		return false

	var unit := _card_guard.accept_battle_unit(card, self, characters, enemies)
	if unit == null:
		return false

	if _is_character_unit(unit):
		if insert_left:
			characters.insert(0, unit)
		else:
			characters.append(unit)
	else:
		if insert_left:
			enemies.insert(0, unit)
		else:
			enemies.append(unit)

	# BattleScene3D 只维护角色侧/非角色侧队列；新增单位的行动运行时由 combat controller 接管。
	_combat_controller.add_unit(unit, next_attack_time)

	print("【BattleScene3D】加入战斗单位: %s (%d 角色 vs %d 非角色)" % [unit.cardname, characters.size(), enemies.size()])

	if relayout:
		relayout_cards()
	else:
		update_scene_bounds()

	if not is_battle_active and _has_both_sides():
		start_battle()

	_request_non_battle_card_cleanup()
	return true


func start_battle() -> void:
	_cleanup_invalid_units()
	if is_battle_active or not _has_both_sides() or _is_finishing:
		return

	if not _combat_controller.start_battle(characters, enemies):
		return

	is_battle_active = true
	print("【BattleScene3D】战斗开始: %d 角色 vs %d 非角色" % [characters.size(), enemies.size()])


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
	# 合并由 BattleScene3D 协调；迁移单位前先要求 combat controller 停止旧攻击动画。
	_combat_controller.stop_for_merge()
	_cleanup_invalid_units()

	var result := []
	for card in characters.duplicate():
		_append_merge_card(result, card)
	for card in enemies.duplicate():
		_append_merge_card(result, card)

	_combat_controller.shutdown()
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
		"next_attack_time": _combat_controller.get_preserved_attack_time(card_3d),
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
	_combat_controller.shutdown()
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


func _on_combat_unit_died(unit: Card3D) -> void:
	if _is_finishing:
		return

	_remove_dead_unit(unit)


func _on_combat_battle_ended() -> void:
	if _is_finishing:
		return

	_finish_battle()


func _finish_battle() -> void:
	if _is_finishing:
		return

	_is_finishing = true
	is_battle_active = false
	_combat_controller.shutdown()

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

	# 死亡后的掉落/奖励生成也应该接在这里，保持 combat controller 只做演算和信号。
	_combat_controller.forget_unit(unit_card)
	characters.erase(unit_card)
	enemies.erase(unit_card)
	if is_instance_valid(unit_card):
		unit_card.queue_free()
	relayout_cards()


func _cleanup_invalid_units() -> void:
	_remove_invalid_cards_from_side(characters)
	_remove_invalid_cards_from_side(enemies)
	_combat_controller.cleanup_invalid_entries()


func _remove_invalid_cards_from_side(cards: Array[Card3D]) -> void:
	var index := cards.size() - 1
	while index >= 0:
		var card := _get_valid_card(cards[index])
		if card == null or not _card_guard.is_battle_card(card):
			cards.remove_at(index)
		index -= 1


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


func _get_battle_resource(card) -> BiologyCard:
	var card_3d := _get_valid_card(card)
	if card_3d == null:
		return null
	return card_3d.card_info as BiologyCard


func _get_combat_profile(card) -> BattleCombatProfile:
	var resource := _get_battle_resource(card)
	if resource == null:
		return null
	return resource.get_combat_profile()


func _is_character_unit(card) -> bool:
	var profile := _get_combat_profile(card)
	return profile != null and profile.faction == BATTLE_COMBAT_PROFILE_SCRIPT.Faction.CHARACTER


func _get_valid_card(candidate) -> Card3D:
	if candidate == null or not (candidate is Object):
		return null
	if not is_instance_valid(candidate):
		return null
	return candidate as Card3D
