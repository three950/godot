extends Node

const BATTLE_SCENE_3D: PackedScene = preload("uid://dm28lkdhyoemx")
const BATTLE_META_KEY := "battle_scene_3d"

var active_battle_scenes: Array[BattleScene3D] = []

var _connected_cards: Dictionary = {}
var _next_creation_index := 0
var _active_merge_keys := {}


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_connect_existing_cards")
	print("【BattleManager】3D 多战斗调度器已初始化")


func _connect_existing_cards() -> void:
	for node in get_tree().get_nodes_in_group("Cards3D"):
		var card := node as Card3D
		if card != null:
			_connect_card(card)


func _on_node_added(node: Node) -> void:
	var card := node as Card3D
	if card == null:
		return
	if not card.is_node_ready():
		await card.ready
	_connect_card(card)


func _connect_card(card: Card3D) -> void:
	if card == null or not is_instance_valid(card):
		return

	var card_id := card.get_instance_id()
	if _connected_cards.has(card_id):
		return

	_connected_cards[card_id] = true
	if not card.card_label_entered_stack_area.is_connected(_on_card_contact):
		card.card_label_entered_stack_area.connect(_on_card_contact.bind(card_id))
	# tree_exiting 只绑定实例 id，不捕获即将释放的 Card3D。
	card.tree_exiting.connect(_on_connected_card_tree_exiting.bind(card_id), CONNECT_ONE_SHOT)


func _on_connected_card_tree_exiting(card_id: int) -> void:
	_connected_cards.erase(card_id)


func _on_card_contact(entering_card: Card3D, target_card_id: int) -> void:
	var entering_card_id := _get_instance_id(entering_card)
	if entering_card_id == 0:
		return
	call_deferred("_handle_card_contact_by_id", entering_card_id, target_card_id)


func _handle_card_contact_by_id(entering_card_id: int, target_card_id: int) -> void:
	_handle_card_contact(
		_get_card_by_instance_id(entering_card_id),
		_get_card_by_instance_id(target_card_id)
	)


func _handle_card_contact(entering_card, target_card) -> void:
	if entering_card == null or target_card == null:
		return
	if not is_instance_valid(entering_card) or not is_instance_valid(target_card):
		return
	if entering_card == target_card:
		return
	if not _is_battle_card(entering_card) or not _is_battle_card(target_card):
		return

	var entering_scene := _get_card_battle_scene(entering_card)
	var target_scene := _get_card_battle_scene(target_card)

	if entering_scene != null and target_scene != null:
		if entering_scene != target_scene:
			_request_merge(entering_scene, target_scene)
		return

	if entering_scene != null:
		entering_scene.add_card(target_card)
		entering_scene.start_battle()
		return

	if target_scene != null:
		target_scene.add_card(entering_card)
		target_scene.start_battle()
		return

	if _are_opponents(entering_card, target_card):
		_create_battle_scene(entering_card, target_card)


func _create_battle_scene(first_card: Card3D, second_card: Card3D) -> BattleScene3D:
	var battle_scene := BATTLE_SCENE_3D.instantiate() as BattleScene3D
	if battle_scene == null:
		push_error("【BattleManager】无法实例化 BattleScene3D")
		return null

	battle_scene.creation_index = _next_creation_index
	_next_creation_index += 1

	var scene_parent := get_parent()
	if scene_parent == null:
		scene_parent = self
	scene_parent.add_child(battle_scene)

	var center := (first_card.global_position + second_card.global_position) * 0.5
	center.y = 0.0
	battle_scene.global_position = center

	active_battle_scenes.append(battle_scene)
	battle_scene.card_entered_battle_area.connect(_on_battle_card_entered)
	battle_scene.battle_area_touched.connect(_on_battle_area_touched)
	battle_scene.battle_finished.connect(_on_battle_finished)
	# 战斗场景释放时按实例 id 清理，避免 signal 回调闭包持有 BattleScene3D。
	battle_scene.tree_exiting.connect(_on_battle_scene_tree_exiting.bind(battle_scene.get_instance_id()), CONNECT_ONE_SHOT)

	battle_scene.add_card(first_card, false, -1.0, false)
	battle_scene.add_card(second_card, false, -1.0, false)
	battle_scene.relayout_cards()
	battle_scene.start_battle()

	print("【BattleManager】创建 3D 战斗场景: %s + %s" % [first_card.cardname, second_card.cardname])
	return battle_scene


func _on_battle_card_entered(battle_scene: BattleScene3D, card: Card3D) -> void:
	var battle_scene_id := _get_instance_id(battle_scene)
	var card_id := _get_instance_id(card)
	if battle_scene_id == 0 or card_id == 0:
		return
	call_deferred("_handle_battle_card_entered_by_id", battle_scene_id, card_id)


func _handle_battle_card_entered_by_id(battle_scene_id: int, card_id: int) -> void:
	_handle_battle_card_entered(
		_get_battle_scene_by_instance_id(battle_scene_id),
		_get_card_by_instance_id(card_id)
	)


func _handle_battle_card_entered(battle_scene, card) -> void:
	if battle_scene == null or card == null:
		return
	if not active_battle_scenes.has(battle_scene):
		return
	if not _is_battle_card(card):
		return

	var current_scene := _get_card_battle_scene(card)
	if current_scene == battle_scene:
		return
	if current_scene != null:
		_request_merge(battle_scene, current_scene)
		return

	battle_scene.add_card(card)
	battle_scene.start_battle()


func _on_battle_area_touched(battle_scene: BattleScene3D, other_scene: BattleScene3D) -> void:
	_request_merge(battle_scene, other_scene)


func _request_merge(first_scene: BattleScene3D, second_scene: BattleScene3D) -> void:
	if first_scene == null or second_scene == null or first_scene == second_scene:
		return
	if not is_instance_valid(first_scene) or not is_instance_valid(second_scene):
		return
	if not active_battle_scenes.has(first_scene) or not active_battle_scenes.has(second_scene):
		return

	var merge_key := _get_merge_key(first_scene, second_scene)
	if _active_merge_keys.has(merge_key):
		return

	_active_merge_keys[merge_key] = true
	call_deferred("_merge_battle_scenes", first_scene, second_scene, merge_key)


func _merge_battle_scenes(first_scene: BattleScene3D, second_scene: BattleScene3D, merge_key: String) -> void:
	if not is_instance_valid(first_scene) or not is_instance_valid(second_scene):
		_active_merge_keys.erase(merge_key)
		return

	var keeper := _choose_merge_keeper(first_scene, second_scene)
	var merged := second_scene if keeper == first_scene else first_scene
	var insert_left := merged.global_position.x < keeper.global_position.x

	print("【BattleManager】合并 3D 战斗: 保留 #%d，迁移 #%d" % [keeper.creation_index, merged.creation_index])
	var migrated_units := merged.extract_cards_for_merge()
	if not is_instance_valid(keeper) or not is_instance_valid(merged):
		_active_merge_keys.erase(merge_key)
		return

	for unit_data in migrated_units:
		var card := unit_data["card"] as Card3D
		if card == null or not is_instance_valid(card):
			continue
		var next_attack_time := float(unit_data["next_attack_time"])
		keeper.add_card(card, insert_left, next_attack_time, false)

	keeper.relayout_cards()
	keeper.start_battle()
	active_battle_scenes.erase(merged)
	merged.shutdown_after_merge()
	_active_merge_keys.erase(merge_key)


func _choose_merge_keeper(first_scene: BattleScene3D, second_scene: BattleScene3D) -> BattleScene3D:
	var first_count := first_scene.get_unit_count()
	var second_count := second_scene.get_unit_count()
	if first_count > second_count:
		return first_scene
	if second_count > first_count:
		return second_scene
	return first_scene if first_scene.creation_index <= second_scene.creation_index else second_scene


func _on_battle_finished(battle_scene: BattleScene3D) -> void:
	active_battle_scenes.erase(battle_scene)


func _on_battle_scene_tree_exiting(battle_scene_id: int) -> void:
	for battle_scene in active_battle_scenes.duplicate():
		if battle_scene == null or not is_instance_valid(battle_scene):
			active_battle_scenes.erase(battle_scene)
			continue
		if battle_scene.get_instance_id() == battle_scene_id:
			active_battle_scenes.erase(battle_scene)
			return


func _get_card_battle_scene(card) -> BattleScene3D:
	var card_3d := _get_valid_card(card)
	if card_3d == null or not card_3d.has_meta(BATTLE_META_KEY):
		return null

	var battle_scene := card_3d.get_meta(BATTLE_META_KEY) as BattleScene3D
	if battle_scene == null or not is_instance_valid(battle_scene):
		card_3d.remove_meta(BATTLE_META_KEY)
		return null

	return battle_scene


func _get_merge_key(first_scene: BattleScene3D, second_scene: BattleScene3D) -> String:
	var first_id := first_scene.get_instance_id()
	var second_id := second_scene.get_instance_id()
	if first_id < second_id:
		return "%s:%s" % [first_id, second_id]
	return "%s:%s" % [second_id, first_id]


func _is_battle_card(card) -> bool:
	var card_3d := _get_valid_card(card)
	return card_3d != null and card_3d.card_info is BiologyCard


func _are_opponents(first_card, second_card) -> bool:
	var first_card_3d := _get_valid_card(first_card)
	var second_card_3d := _get_valid_card(second_card)
	if first_card_3d == null or second_card_3d == null:
		return false
	return (first_card_3d.card_info is CharacterCard and second_card_3d.card_info is EnemyCard) \
			or (first_card_3d.card_info is EnemyCard and second_card_3d.card_info is CharacterCard)


func _get_card_by_instance_id(card_id: int) -> Card3D:
	return _get_valid_card(instance_from_id(card_id))


func _get_battle_scene_by_instance_id(battle_scene_id: int) -> BattleScene3D:
	var instance := instance_from_id(battle_scene_id)
	if instance == null or not is_instance_valid(instance):
		return null
	return instance as BattleScene3D


func _get_valid_card(candidate) -> Card3D:
	if candidate == null or not (candidate is Object):
		return null
	if not is_instance_valid(candidate):
		return null
	return candidate as Card3D


func _get_instance_id(candidate) -> int:
	if candidate == null or not (candidate is Object):
		return 0
	if not is_instance_valid(candidate):
		return 0
	return candidate.get_instance_id()
