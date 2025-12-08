class_name CraftManager
extends Node
@export var craft_pools: Array[CardInfo] = []
var _recipe_map: Dictionary = {}

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
			result_down.append(current.name)
			cards_to_free.append(current)
			current = current.children_card
	
	# follow_target向上遍历，同时找到最顶层的卡片
	var top_card: Card = card
	if card.follow_target != null:
		var current = card.follow_target
		while current != null:
			result_up.append(current.name)
			cards_to_free.append(current)
			if current.follow_target == null:
				top_card = current
			current = current.follow_target
	
	var result: Array[String] = []
	result.assign(result_up + [card.name] + result_down)
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
		else:
			# 无合成时间，立即合成
			_finish_crafting(cards_to_free, card_info, spawn_position)

## 开始合成：显示进度条并计时
func _start_crafting(top_card: Card, cards_to_free: Array[Card], card_info: ThingsCard, spawn_position: Vector2) -> void:
	# 获取 top_card 的进度条并启动
	var progress_bar = top_card.get_node_or_null("CardProgressBar") as CardProgressBar
	if progress_bar:
		# 使用 lambda 捕获所有参数
		progress_bar.progress_completed.connect(
			func(): _on_craft_completed(cards_to_free, card_info, spawn_position),
			CONNECT_ONE_SHOT
		)
		progress_bar.start(card_info.合成时间)
		print("开始合成: ", card_info.name, " 需要 ", card_info.合成时间, " 秒")
	else:
		# 没有进度条，直接完成合成
		print("警告: top_card 没有 CardProgressBar，直接完成合成")
		_finish_crafting(cards_to_free, card_info, spawn_position)

## 合成进度完成回调
func _on_craft_completed(cards_to_free: Array[Card], card_info: ThingsCard, spawn_position: Vector2) -> void:
	print("合成完成: ", card_info.name)
	_finish_crafting(cards_to_free, card_info, spawn_position)

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
