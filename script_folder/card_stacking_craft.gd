extends Node

## 卡片堆叠合成组件
## 附加到资源卡和装备卡上，当多张卡片堆叠时自动检测并执行合成
## 类似《堆叠大陆》的自动合成机制

# 是否启用自动合成
@export var auto_craft_enabled: bool = true

# 合成延迟（秒），防止频繁检测
@export var craft_delay: float = 0.5

# 父卡牌节点
var parent_card = null

# 检测计时器
var craft_timer: Timer = null

func _ready() -> void:
	# 等待一帧，确保父节点完全初始化
	await get_tree().process_frame
	
	# 获取父节点（卡牌）
	parent_card = get_parent()
	
	if not parent_card:
		push_error("CardStackingCraft: 父节点不存在")
		return
	
	# 创建计时器
	craft_timer = Timer.new()
	craft_timer.one_shot = true
	craft_timer.wait_time = craft_delay
	craft_timer.timeout.connect(_on_craft_timer_timeout)
	add_child(craft_timer)
	
	# 连接父卡牌的按钮释放信号（堆叠完成后触发）
	if parent_card.has_node("Button"):
		var button = parent_card.get_node("Button")
		if button and button.has_signal("button_up"):
			button.button_up.connect(_on_parent_button_up)

## 当父卡牌的按钮释放时（堆叠完成后）
func _on_parent_button_up() -> void:
	if not auto_craft_enabled:
		return
	
	# 启动延迟检测
	if craft_timer and not craft_timer.is_stopped():
		craft_timer.stop()
	if craft_timer:
		craft_timer.start()

## 计时器超时，执行合成检测
func _on_craft_timer_timeout() -> void:
	check_and_craft()

## 检测堆叠的卡牌并尝试合成
func check_and_craft() -> void:
	if not parent_card or not is_instance_valid(parent_card):
		return
	
	# 获取堆叠的卡牌（包括自己）
	var all_stacked_cards = get_all_stacked_cards()
	
	# 如果只有1张或0张，不合成
	if all_stacked_cards.size() <= 1:
		return
	
	# 检查是否可以合成
	var product_name = CraftManager.check_craft(all_stacked_cards)
	
	if product_name != "":
		print("检测到可合成: %s (使用 %d 张卡牌)" % [product_name, all_stacked_cards.size()])
		
		# 执行合成
		execute_craft_with_effect(all_stacked_cards, product_name)

## 获取所有堆叠的卡牌（包括自己和所有子卡牌）
func get_all_stacked_cards() -> Array:
	var all_cards: Array = []
	
	if not parent_card:
		return all_cards
	
	# 添加自己
	all_cards.append(parent_card)
	
	# 添加所有堆叠的卡牌（递归获取）
	if parent_card.has("stacked_cards"):
		for stacked_card in parent_card.stacked_cards:
			if stacked_card and is_instance_valid(stacked_card):
				all_cards.append(stacked_card)
				# 递归获取子卡牌的堆叠卡牌
				if stacked_card.has("stacked_cards"):
					all_cards.append_array(get_cards_recursively(stacked_card))
	
	return all_cards

## 递归获取所有子卡牌
func get_cards_recursively(card) -> Array:
	var cards: Array = []
	if card and is_instance_valid(card) and card.has("stacked_cards"):
		for sub_card in card.stacked_cards:
			if sub_card and is_instance_valid(sub_card):
				cards.append(sub_card)
				cards.append_array(get_cards_recursively(sub_card))
	return cards

## 执行合成并播放特效
func execute_craft_with_effect(card_list: Array, product_name: String) -> void:
	# 计算中心位置
	var center_pos = Vector2.ZERO
	var valid_count = 0
	for card in card_list:
		if card is Node2D:
			center_pos += card.global_position
			valid_count += 1
	
	if valid_count > 0:
		center_pos /= valid_count
	
	# 播放合成特效（可选）
	play_craft_effect(center_pos)
	
	# 执行合成
	var new_card = CraftManager.execute_craft(card_list)
	
	if new_card:
		print("合成成功: %s" % product_name)
		
		# 为新卡牌添加堆叠合成组件
		add_craft_component_to_card(new_card)

## 播放合成特效
func play_craft_effect(_position: Vector2) -> void:
	# TODO: 添加你的特效
	# 例如：粒子效果、闪光、音效等
	# print("在位置 %s 播放合成特效" % position)
	pass

## 为新卡牌添加堆叠合成组件
func add_craft_component_to_card(card: Node) -> void:
	if not card:
		return
	
	# 检查是否是资源或装备卡
	if not (card is ResourceCard or card is EquipmentCard):
		return
	
	# 检查是否已经有组件
	if card.has_node("CardStackingCraft"):
		return
	
	# 动态添加组件
	var craft_component = load("res://script_folder/card_stacking_craft.gd").new()
	craft_component.name = "CardStackingCraft"
	card.add_child(craft_component)
	print("为新卡牌 %s 添加了堆叠合成组件" % card.name)

## 手动触发检测（可以从外部调用）
func trigger_detection() -> void:
	if craft_timer:
		craft_timer.start()
