extends Node

## 堆叠合成检测器
## 附加到资源卡和装备卡上，监听堆叠事件并触发合成检测
## 当堆叠的卡片数量 > 1 时，检查是否可以合成

# 父卡片引用
var parent_card: Control = null

# 检测延迟（避免频繁检测）
var check_delay: float = 0.3
var check_timer: float = 0.0
var need_check: bool = false

func _ready() -> void:
	# 等待一帧后获取父节点
	await get_tree().process_frame
	parent_card = get_parent()
	
	if parent_card == null:
		push_error("StackCraftDetector 必须附加到卡片节点上")
		return
	
	# 连接堆叠信号
	if parent_card.has_signal("card_stacked_on"):
		parent_card.card_stacked_on.connect(_on_card_stacked)
	else:
		push_error("父卡片缺少 card_stacked_on 信号")
	
	# 连接卡片移除信号（当有卡片从堆叠中被拖走）
	if parent_card.has_signal("card_removed_from_stack"):
		parent_card.card_removed_from_stack.connect(_on_card_removed)
	
	# 连接卡片固定信号（当这张卡片被拖动后固定）
	if parent_card.has_signal("card_fixed"):
		parent_card.card_fixed.connect(_on_card_fixed)

func _process(delta: float) -> void:
	if need_check:
		check_timer += delta
		if check_timer >= check_delay:
			check_timer = 0.0
			need_check = false
			check_and_craft()

## 当有卡片堆叠到父卡片上时触发
func _on_card_stacked(_stacked_card: Control) -> void:
	# 延迟检测，避免频繁检测
	need_check = true
	check_timer = 0.0

## 检查并执行合成
func check_and_craft() -> void:
	if parent_card == null or not is_instance_valid(parent_card):
		return
	
	# 找到整组卡牌的根卡片（最底层的父卡片）
	var root_card = find_root_card(parent_card)
	if root_card == null or not is_instance_valid(root_card):
		return
	
	# 检查根卡片是否有堆叠
	if not "stacked_cards" in root_card:
		return
	
	# 递归收集整个堆叠链上的所有卡片
	var all_cards: Array = []
	collect_all_stacked_cards(root_card, all_cards)
	
	if all_cards.size() < 2:
		return  # 至少需要2张卡片才能合成
	
	print("【合成检测】检测到 %d 张卡片堆叠 (根卡片: %s)" % [all_cards.size(), root_card.name])
	
	# 使用 CraftManager 检查是否可以合成
	var product_name = CraftManager.check_craft(all_cards)
	
	if product_name != "":
		print("【合成检测】可以合成: %s" % product_name)
		# 执行合成
		execute_craft_with_effect(all_cards, product_name)
	else:
		print("【合成检测】没有匹配的配方")

## 找到堆叠组的根卡片（最底层没有parent_card的卡片）
func find_root_card(card: Control) -> Control:
	var current = card
	# 向上查找，直到找到没有parent_card的卡片
	while current != null and is_instance_valid(current):
		if "parent_card" in current and current.parent_card != null:
			current = current.parent_card
		else:
			# 找到根卡片
			return current
	return card

## 递归收集所有堆叠的卡片（包括当前卡片和所有子堆叠）
func collect_all_stacked_cards(card: Control, result: Array) -> void:
	if card == null or not is_instance_valid(card):
		return
	
	# 添加当前卡片
	result.append(card)
	
	# 递归添加所有堆叠在当前卡片上的卡片
	if "stacked_cards" in card:
		var stacked = card.stacked_cards
		if stacked != null:
			for stacked_card in stacked:
				collect_all_stacked_cards(stacked_card, result)

## 执行合成并添加特效
func execute_craft_with_effect(cards: Array, _product_name: String) -> void:
	# 计算合成位置（根卡片的位置）
	var root_card = find_root_card(parent_card)
	var craft_position = root_card.global_position if root_card else Vector2.ZERO
	
	# 可以在这里添加合成特效
	# play_craft_effect(craft_position)
	
	# 执行合成
	var new_card = CraftManager.execute_craft(cards)
	
	if new_card:
		print("【合成成功】已生成新卡片于位置: %s" % craft_position)
		# 可以在这里添加成功音效
		# play_craft_sound()

## 播放合成特效（预留接口）
func play_craft_effect(_position: Vector2) -> void:
	# TODO: 添加粒子特效、闪光等
	pass

## 播放合成音效（预留接口）
func play_craft_sound() -> void:
	# TODO: 播放音效
	pass

## 手动触发检测（可选，用于外部调用）
func trigger_check() -> void:
	need_check = true
	check_timer = 0.0

## 当有卡片从堆叠中被移除时触发
func _on_card_removed(_removed_card: Control) -> void:
	print("【合成检测】卡片被移除，触发检测")
	# 延迟检测原地剩余的卡片
	need_check = true
	check_timer = 0.0

## 当卡片被拖动后固定时触发
func _on_card_fixed() -> void:
	print("【合成检测】卡片固定，触发检测")
	# 延迟检测固定后的卡片组
	need_check = true
	check_timer = 0.0
