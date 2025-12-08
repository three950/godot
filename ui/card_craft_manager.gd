class_name CraftManager
extends Node
@export var craft_pools: Array[CardInfo] = []
var _recipe_map: Dictionary = {}
# 正在合成的任务: { progress_bar: { "cards": Array[Card], "card_info": ThingsCard, "spawn_position": Vector2 } }
var _active_crafts: Dictionary = {}

#检测解析所有合成配方，实时检测堆叠数组并识别是否可合成
func _ready() -> void:
	_build_recipe_map()
	Events.stack_changed.connect(_get_array)

func _build_recipe_map() -> void:
	for card_info in craft_pools:
		if card_info is ThingsCard and card_info.has_craft_recipe:
			var material_names: Array[String] = []
			for material in card_info.craft_materials:
				material_names.append(material.name)
			material_names.sort()
			_recipe_map[material_names] = card_info
	print("Recipe Map: ", _recipe_map)

func _get_array(card: Card) -> void:
	var result_down: Array[String] = []
	var result_up: Array[String] = []
	var cards_to_free: Array[Card] = []
	
	# children_card向下遍历
	if card.children_card != null:
		var current = card.children_card
		while current != null:
			result_down.append(current.cardname)
			cards_to_free.append(current)
			current = current.children_card
	
	# follow_target向上遍历，同时找到最顶层的卡片
	var top_card: Card = card
	if card.follow_target != null:
		var current = card.follow_target
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
	print(result)
	
	# 查询配方
	if _recipe_map.has(result):
		var card_info: ThingsCard = _recipe_map[result]
		print("配方匹配成功: ", result, " -> ", card_info.name)
		
		cards_to_free.append(card)
		var spawn_position = top_card.global_position
		
		# 检查合成时间
		if card_info.合成时间 > 0:
			_start_crafting(top_card, cards_to_free, card_info, spawn_position)

## 开始合成：显示进度条并计时
func _start_crafting(top_card: Card, cards_to_free: Array[Card], card_info: ThingsCard, spawn_position: Vector2) -> void:
	var progress_bar = top_card.get_node("CardProgressBar") as CardProgressBar
	# 记录合成任务
	var craft_data := {
		"cards": cards_to_free,
		"card_info": card_info,
		"spawn_position": spawn_position
	}
	_active_crafts[progress_bar] = craft_data
	
	# 为卡组中的每张卡片连接 array_changed 信号
	for c in cards_to_free:
		if is_instance_valid(c):
			# 使用 lambda 捕获 progress_bar
			var callback = func(): _on_array_changed(progress_bar)
			c.array_changed.connect(callback, CONNECT_ONE_SHOT)
	
	# 连接完成信号
	progress_bar.progress_completed.connect(
		func(): _on_craft_completed(progress_bar),
		CONNECT_ONE_SHOT
	)
	progress_bar.start(card_info.合成时间)
	print("开始合成: ", card_info.name, " 需要 ", card_info.合成时间, " 秒")

## 当卡组发生变化时取消合成
func _on_array_changed(progress_bar: CardProgressBar) -> void:
	if not _active_crafts.has(progress_bar):
		return
	
	var craft_data: Dictionary = _active_crafts[progress_bar]
	print("卡组变化，取消合成: ", craft_data["card_info"].name)
	
	# 先从字典移除，再停止进度条
	_active_crafts.erase(progress_bar)
	progress_bar.stop()

## 合成进度完成回调
func _on_craft_completed(progress_bar: CardProgressBar) -> void:
	# 如果任务不存在（已被取消），直接返回
	if not _active_crafts.has(progress_bar):
		return
	
	var craft_data: Dictionary = _active_crafts[progress_bar]
	print("合成完成: ", craft_data["card_info"].name)
	
	_active_crafts.erase(progress_bar)
	_finish_crafting(craft_data["cards"], craft_data["card_info"], craft_data["spawn_position"])

## 完成合成：销毁材料卡片，生成新卡片
func _finish_crafting(cards_to_free: Array[Card], card_info: ThingsCard, spawn_position: Vector2) -> void:
	# 销毁所有相关卡片
	for c in cards_to_free:
		if is_instance_valid(c):
			c.queue_free()
	# 生成新卡片
	_spawn_crafted_card(card_info, spawn_position)

func _spawn_crafted_card(card_info: CardInfo, spawn_position: Vector2) -> void:
	var instance = card_info.card_scene.instantiate()
	instance.set_stats(card_info)
	
	# 将卡牌添加到Cards分组的根节点
	var cards_group = get_tree().get_first_node_in_group("Cards")
	if cards_group:
		cards_group.add_child(instance)
	instance.global_position = spawn_position
	print("合成卡牌已生成: ", card_info.name, " 位置: ", spawn_position)
