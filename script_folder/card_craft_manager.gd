class_name CraftManager
extends Node

const CARD_THROW_PHYSICS_SCRIPT: GDScript = preload("uid://cu1myihpo87b")
const CARD_PROGRESS_BAR_SCENE: PackedScene = preload("uid://m6rrjkc625gk")
const CARD_PROGRESS_BAR_NODE_NAME := "CardProgressBar"
const CARD_PROGRESS_BAR_3D_NODE_NAME := "CardProgressBar3D"
const CARD_PROGRESS_VIEWPORT_NODE_NAME := "ProgressViewport"
const CARD_PROGRESS_MESH_NODE_NAME := "ProgressMesh3D"
const CARD_PROGRESS_VIEWPORT_SIZE := Vector2i(264, 32)

@export var craft_pools: Array[CardInfo] = []
var _recipe_map: Dictionary = {}
# 正在合成的任务: { key: { "cards": Array[Card3D], "card_info": ThingsCard, "top_card": Card3D, "progress_bar": CardProgressBar } }
var _active_crafts: Dictionary = {}

#检测解析所有合成配方，实时检测堆叠数组并识别是否可合成
func _ready() -> void:
	_build_recipe_map()
	Events.stack_changed.connect(_get_array)
	print("[CraftManager] connected Events.stack_changed")

func _build_recipe_map() -> void:
	for card_info in craft_pools:
		if card_info is ThingsCard and card_info.has_craft_recipe:
			var material_names: Array[String] = []
			for material in card_info.craft_materials:
				material_names.append(material.name)
			material_names.sort()
			_recipe_map[material_names] = card_info
	print("Recipe Map: ", _recipe_map)

func _get_array(card: Card3D) -> void:
	print("[CraftManager] stack_changed received: %s" % card.cardname)
	var result_down: Array[String] = []
	var result_up: Array[String] = []
	var cards_to_free: Array[Card3D] = []
	
	# children_card向下遍历
	if card.children_card != null:
		var current: Card3D = card.children_card
		while current != null:
			result_down.append(current.cardname)
			cards_to_free.append(current)
			current = current.children_card
	
	# follow_target向上遍历，同时找到最顶层的卡片
	var top_card: Card3D = card
	if card.follow_target != null:
		var current: Card3D = card.follow_target
		while current != null:
			result_up.append(current.cardname)
			cards_to_free.append(current)
			if current.follow_target == null:
				top_card = current
			current = current.follow_target
	
	var result: Array[String] = []
	result.assign(result_up + [card.cardname] + result_down)
	if result:
		result.sort()
	print("[CraftManager] stack recipe key: ", result)
	
	# 查询配方
	if _recipe_map.has(result):
		var card_info: ThingsCard = _recipe_map[result]
		print("配方匹配成功: ", result, " -> ", card_info.name)
		
		cards_to_free.append(card)
		# 检查合成时间
		if card_info.合成时间 > 0:
			_start_crafting(top_card, cards_to_free, card_info)
		else:
			print("[CraftManager] recipe matched but craft time is 0: %s" % card_info.name)
	else:
		print("[CraftManager] no recipe matched for: ", result)

## 开始合成：显示进度条并计时
func _start_crafting(top_card: Card3D, cards_to_free: Array[Card3D], card_info: ThingsCard) -> void:
	print("[CraftManager] _start_crafting: top=%s result=%s position=%s" % [top_card.cardname, card_info.name, top_card.global_position])
	var progress_bar := _get_or_create_progress_bar(top_card)
	if progress_bar == null:
		push_error("[CraftManager] failed to create CardProgressBar for: %s" % top_card.name)
		return
	var craft_key: Object = progress_bar

	# 记录合成任务
	var craft_data := {
		"cards": cards_to_free,
		"card_info": card_info,
		"top_card": top_card,
		"progress_bar": progress_bar
	}
	_active_crafts[craft_key] = craft_data
	
	# 为卡组中的每张卡片连接 array_changed 信号
	for c in cards_to_free:
		if is_instance_valid(c):
			# 使用 lambda 捕获 craft_key
			var callback = func(): _cancel_crafting(craft_key)
			c.array_changed.connect(callback, CONNECT_ONE_SHOT)
	
	progress_bar.progress_completed.connect(
		func(): _on_craft_completed(craft_key),
		CONNECT_ONE_SHOT
	)
	progress_bar.start(card_info.合成时间)
	print("开始合成: ", card_info.name, " 需要 ", card_info.合成时间, " 秒")

func _get_or_create_progress_bar(card: Node) -> CardProgressBar:
	var progress_bar := card.get_node_or_null("%s/%s/%s" % [
		CARD_PROGRESS_BAR_3D_NODE_NAME,
		CARD_PROGRESS_VIEWPORT_NODE_NAME,
		CARD_PROGRESS_BAR_NODE_NAME
	]) as CardProgressBar
	if progress_bar != null:
		return progress_bar
	
	var progress_container := Node3D.new()
	progress_container.name = CARD_PROGRESS_BAR_3D_NODE_NAME
	progress_container.position = Vector3(0.0, 0.0, -1.95)
	card.add_child(progress_container)
	
	var progress_viewport := SubViewport.new()
	progress_viewport.name = CARD_PROGRESS_VIEWPORT_NODE_NAME
	progress_viewport.disable_3d = true
	progress_viewport.transparent_bg = true
	progress_viewport.size = CARD_PROGRESS_VIEWPORT_SIZE
	progress_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	progress_container.add_child(progress_viewport)
	
	progress_bar = CARD_PROGRESS_BAR_SCENE.instantiate() as CardProgressBar
	if progress_bar == null:
		progress_container.queue_free()
		return null
	
	progress_viewport.add_child(progress_bar)
	progress_bar.name = CARD_PROGRESS_BAR_NODE_NAME
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_bar.position = Vector2(6.0, 4.0)
	progress_bar.size = Vector2(252.0, 24.0)
	
	var progress_mesh := MeshInstance3D.new()
	progress_mesh.name = CARD_PROGRESS_MESH_NODE_NAME
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(2.8, 0.38)
	progress_mesh.mesh = quad_mesh
	progress_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.render_priority = 127
	material.albedo_texture = progress_viewport.get_texture()
	progress_mesh.material_override = material
	progress_container.add_child(progress_mesh)
	
	print("[CraftManager] attached 3D CardProgressBar above ground to card child: %s" % card.name)
	return progress_bar

## 当卡组发生变化时取消合成
func _cancel_crafting(craft_key: Object) -> void:
	if not _active_crafts.has(craft_key):
		return
	
	var craft_data: Dictionary = _active_crafts[craft_key]
	print("[CraftManager] stack changed, cancel crafting: ", craft_data["card_info"].name)
	
	# 先从字典移除，再停止进度条
	_active_crafts.erase(craft_key)
	var progress_bar := craft_data["progress_bar"] as CardProgressBar
	if progress_bar != null:
		progress_bar.stop()
		_free_progress_bar_3d(progress_bar)

func _free_progress_bar_3d(progress_bar: CardProgressBar) -> void:
	var progress_viewport := progress_bar.get_parent()
	if progress_viewport == null:
		return
	var progress_container := progress_viewport.get_parent()
	if progress_container != null:
		progress_container.queue_free()

## 合成进度完成回调
func _on_craft_completed(craft_key: Object) -> void:
	# 如果任务不存在（已被取消），直接返回
	if not _active_crafts.has(craft_key):
		return
	
	var craft_data: Dictionary = _active_crafts[craft_key]
	print("[CraftManager] craft completed: ", craft_data["card_info"].name)
	
	_active_crafts.erase(craft_key)
	_finish_crafting(craft_data["cards"], craft_data["card_info"], craft_data["top_card"])

## 完成合成：销毁材料卡片，生成新卡片
func _finish_crafting(cards_to_free: Array[Card3D], card_info: ThingsCard, top_card: Card3D) -> void:
	print("[CraftManager] _finish_crafting: freeing %d cards, spawning %s" % [cards_to_free.size(), card_info.name])
	var spawn_position := Vector3.ZERO
	var spawn_parent: Node = self
	if is_instance_valid(top_card):
		spawn_position = top_card.global_position
		spawn_parent = top_card.get_parent()
		_detach_top_card_if_stacked(top_card)
	
	# 销毁所有相关卡片
	for c in cards_to_free:
		if is_instance_valid(c):
			print("[CraftManager] queue_free material card: %s" % c.cardname)
			c.queue_free()
	# 生成新卡片
	_spawn_crafted_card(card_info, spawn_position, spawn_parent)

func _detach_top_card_if_stacked(top_card: Card3D) -> void:
	if not is_instance_valid(top_card) or top_card.card_state_machine == null:
		return
	
	var current_state := top_card.card_state_machine.current_state
	if current_state == null:
		return
	
	var is_in_stack_queue := current_state.state == Card3DState.State.instack \
			or current_state.state == Card3DState.State.instackdragging
	if not is_in_stack_queue:
		return
	
	# 合成期间头卡可能被堆到其他卡上；销毁前先断开，避免目标卡留下 children_card 空引用。
	top_card.detach_from_follow_target()

func _spawn_crafted_card(card_info: CardInfo, spawn_position: Vector3, spawn_parent: Node) -> void:
	print("[CraftManager] _spawn_crafted_card: %s at %s" % [card_info.name, spawn_position])
	var parent := spawn_parent if spawn_parent != null else self
	var instance := CARD_THROW_PHYSICS_SCRIPT.spawn_revealed_card(card_info, spawn_position, parent) as Card3D
	if instance == null:
		push_error("[CraftManager] failed to spawn crafted card: %s" % card_info.name)
		return

	print("合成卡牌已生成并开始3D动画: ", card_info.name, " 位置: ", spawn_position)
