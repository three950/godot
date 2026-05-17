class_name CraftManager
extends Node

const CARD_THROW_PHYSICS_SCRIPT: GDScript = preload("res://script_folder/card_throw_physics_test.gd")

@export var craft_pools: Array[CardInfo] = []
var _recipe_map: Dictionary = {}
# 正在合成的任务: { key: { "cards": Array[Card3D], "card_info": ThingsCard, "spawn_position": Vector3, "spawn_parent": Node, "progress_bar": CardProgressBar } }
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
		var spawn_position: Vector3 = top_card.global_position
		
		# 检查合成时间
		if card_info.合成时间 > 0:
			_start_crafting(top_card, cards_to_free, card_info, spawn_position)
		else:
			print("[CraftManager] recipe matched but craft time is 0: %s" % card_info.name)
	else:
		print("[CraftManager] no recipe matched for: ", result)

## 开始合成：显示进度条并计时
func _start_crafting(top_card: Card3D, cards_to_free: Array[Card3D], card_info: ThingsCard, spawn_position: Vector3) -> void:
	print("[CraftManager] _start_crafting: top=%s result=%s position=%s" % [top_card.cardname, card_info.name, spawn_position])
	var progress_bar = top_card.get_node_or_null("CardProgressBar") as CardProgressBar
	var craft_key: Object = progress_bar
	if craft_key == null:
		craft_key = top_card

	# 记录合成任务
	var craft_data := {
		"cards": cards_to_free,
		"card_info": card_info,
		"spawn_position": spawn_position,
		"spawn_parent": top_card.get_parent(),
		"progress_bar": progress_bar
	}
	_active_crafts[craft_key] = craft_data
	
	# 为卡组中的每张卡片连接 array_changed 信号
	for c in cards_to_free:
		if is_instance_valid(c):
			# 使用 lambda 捕获 craft_key
			var callback = func(): _cancel_crafting(craft_key)
			c.array_changed.connect(callback, CONNECT_ONE_SHOT)
	
	if progress_bar != null:
		progress_bar.progress_completed.connect(
			func(): _on_craft_completed(craft_key),
			CONNECT_ONE_SHOT
		)
		progress_bar.start(card_info.合成时间)
	else:
		print("[CraftManager] no CardProgressBar on 3D card, using timer fallback: %s" % top_card.name)
		get_tree().create_timer(card_info.合成时间).timeout.connect(
			func(): _on_craft_completed(craft_key),
			CONNECT_ONE_SHOT
		)
	print("开始合成: ", card_info.name, " 需要 ", card_info.合成时间, " 秒")

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

## 合成进度完成回调
func _on_craft_completed(craft_key: Object) -> void:
	# 如果任务不存在（已被取消），直接返回
	if not _active_crafts.has(craft_key):
		return
	
	var craft_data: Dictionary = _active_crafts[craft_key]
	print("[CraftManager] craft completed: ", craft_data["card_info"].name)
	
	_active_crafts.erase(craft_key)
	_finish_crafting(craft_data["cards"], craft_data["card_info"], craft_data["spawn_position"], craft_data["spawn_parent"])

## 完成合成：销毁材料卡片，生成新卡片
func _finish_crafting(cards_to_free: Array[Card3D], card_info: ThingsCard, spawn_position: Vector3, spawn_parent: Node) -> void:
	print("[CraftManager] _finish_crafting: freeing %d cards, spawning %s" % [cards_to_free.size(), card_info.name])
	# 销毁所有相关卡片
	for c in cards_to_free:
		if is_instance_valid(c):
			print("[CraftManager] queue_free material card: %s" % c.cardname)
			c.queue_free()
	# 生成新卡片
	_spawn_crafted_card(card_info, spawn_position, spawn_parent)

func _spawn_crafted_card(card_info: CardInfo, spawn_position: Vector3, spawn_parent: Node) -> void:
	print("[CraftManager] _spawn_crafted_card: %s at %s" % [card_info.name, spawn_position])
	var parent := spawn_parent if spawn_parent != null else self
	var instance := CARD_THROW_PHYSICS_SCRIPT.spawn_revealed_card(card_info, spawn_position, parent) as Card3D
	if instance == null:
		push_error("[CraftManager] failed to spawn crafted card: %s" % card_info.name)
		return

	print("合成卡牌已生成并开始3D动画: ", card_info.name, " 位置: ", spawn_position)
