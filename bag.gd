extends Panel
class_name BagPanel

## 背包面板 - 管理所有卡片和槽位逻辑

# 预加载类以支持类型检查
const BaggableCardScript = preload("res://baggable_card.gd")
const ItemCardScript = preload("res://assets/item道具/item_card.gd")

# 信号：请求关闭背包
signal close_requested
# 信号：当卡片被放入卡槽
signal card_placed(card: Control, slot_index: int)
# 信号：当卡片被移出卡槽
signal card_removed(card: Control, slot_index: int)

# 当前背包所属的角色
var current_character: CharacterData = null
var current_character_card: CharacterCard = null  # 角色卡片引用（用于装备效果）

# 是否正在初次加载背包（用于避免重复应用装备效果）
var is_initial_load: bool = false

# 卡槽引用（纯背景）
var left_slot: BagSlot = null    # 索引 0
var right_slot: BagSlot = null   # 索引 1
var bag_slots: Array[BagSlot] = []  # 索引 2-7

# 卡片数组（实际存储卡片引用）
var cards: Array = []  # 总共 8 个槽位：[left, right, bag1-6]

func _ready() -> void:
	# 背包面板不需要拦截鼠标事件，让事件传递到子节点（卡片）
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 加入 BagPanel 组，方便查找
	add_to_group("BagPanel")
	
	# 获取所有卡槽的引用
	_initialize_slots()
	
	# 初始化卡片数组（8个槽位）
	cards.resize(8)
	for i in range(8):
		cards[i] = null

## 初始化卡槽引用
func _initialize_slots() -> void:
	bag_slots.clear()
	
	# 获取左侧的装备槽位（left 和 right）
	var left_slots = get_node_or_null("HBoxContainer/LeftSlots")
	if left_slots:
		left_slot = left_slots.get_node_or_null("Slot1")  # Slot1 对应 left（左手）
		right_slot = left_slots.get_node_or_null("Slot2")  # Slot2 对应 right（右手）
	
	# 获取右侧的背包槽位（bag1-6）
	var right_slots = get_node_or_null("HBoxContainer/RightSlots")
	if right_slots:
		for i in range(3, 9):  # Slot3-8 对应 bag1-6
			var slot = right_slots.get_node_or_null("Slot%d" % i)
			if slot:
				bag_slots.append(slot)
	
	print("【背包】初始化了装备槽位: left=%s, right=%s" % [left_slot != null, right_slot != null])
	print("【背包】初始化了 %d 个背包槽位" % bag_slots.size())

## 根据索引获取卡槽
func get_slot_by_index(index: int) -> BagSlot:
	if index == 0:
		return left_slot
	elif index == 1:
		return right_slot
	elif index >= 2 and index < 8:
		var bag_index = index - 2
		if bag_index < bag_slots.size():
			return bag_slots[bag_index]
	return null

## 根据卡槽获取索引
func get_index_by_slot(slot: BagSlot) -> int:
	if slot == left_slot:
		return 0
	elif slot == right_slot:
		return 1
	else:
		for i in range(bag_slots.size()):
			if bag_slots[i] == slot:
				return i + 2
	return -1

## 判断指定槽位是否为空
func is_slot_empty(index: int) -> bool:
	if index < 0 or index >= cards.size():
		return true
	return cards[index] == null

## 将卡片移到背包面板下（确保能接收鼠标事件）
func _move_card_to_bag_panel(card: Control) -> void:
	# 如果卡片已经是背包面板的子节点，跳过
	if card.get_parent() == self:
		return
	
	# 保存卡片的全局位置
	var saved_global_position = card.global_position
	var old_parent = card.get_parent()
	
	# 从原父节点移除
	if old_parent:
		old_parent.remove_child(card)
	
	# 添加到背包面板下
	add_child(card)
	
	# 恢复全局位置
	card.global_position = saved_global_position
	
	print("【背包】卡片 %s 已移到背包面板下（原父节点: %s）" % [card.name, old_parent.name if old_parent else "无"])

## 将卡片放入指定槽位
func place_card_at_slot(card: Control, slot_index: int) -> bool:
	# 检查索引有效性
	if slot_index < 0 or slot_index >= cards.size():
		push_error("【背包】无效的槽位索引: %d" % slot_index)
		return false
	
	# 检查槽位是否已满
	if not is_slot_empty(slot_index):
		print("【背包】槽位 %d 已有卡片" % slot_index)
		return false
	
	# 检查是否是可背包物品（BaggableCard）
	var is_baggable = card.get_script() != null and _is_baggable_card(card.get_script())
	if not is_baggable:
		print("【背包】只能放入可背包物品（装备、道具、资源）")
		return false
	
	# 检查卡片是否可以放入背包
	if card.has_method("can_put_in_bag") and not card.can_put_in_bag():
		print("【背包】该卡片当前状态不能放入背包")
		return false
	
	# 获取对应的卡槽
	var slot = get_slot_by_index(slot_index)
	if not slot:
		push_error("【背包】无法获取槽位 %d 的引用" % slot_index)
		return false
	
	# 保存卡片引用
	cards[slot_index] = card
	
	# 【关键】将卡片移到背包面板下，确保能接收鼠标事件
	_move_card_to_bag_panel(card)
	
	# 对齐卡片到卡槽中心位置
	_align_card_to_slot(card, slot)
	
	# 设置卡片的 z_index，确保在卡槽之上
	card.z_index = 10
	
	# 如果卡片有状态，设置为固定状态
	if "cardCurrentState" in card:
		card.cardCurrentState = card.cardState.fixed
	
	# 调用卡片的放入背包回调
	if card.has_method("on_put_in_bag"):
		card.on_put_in_bag(slot)
	
	# 【装备系统】如果是道具卡片，应用装备效果
	# 注意：初次加载背包时不应用效果（因为角色卡片初始化时已经应用过了）
	if not is_initial_load:
		if _is_item_card(card) and current_character_card != null:
			print("【背包】检测到道具卡片 %s，准备应用装备效果" % card.name)
			card.apply_equip_effects(current_character_card)
		elif _is_item_card(card):
			print("【背包】检测到道具卡片 %s，但角色卡片引用为空，无法应用效果" % card.name)
	
	# 发射信号
	card_placed.emit(card, slot_index)
	
	print("【背包】卡片已放入槽位 %d" % slot_index)
	return true

## 从指定槽位移除卡片
func remove_card_from_slot(slot_index: int) -> Control:
	# 检查索引有效性
	if slot_index < 0 or slot_index >= cards.size():
		return null
	
	# 检查槽位是否为空
	if is_slot_empty(slot_index):
		return null
	
	var card = cards[slot_index]
	cards[slot_index] = null
	
	# 重置卡片缩放
	card.scale = Vector2(1.0, 1.0)
	
	# 重置 z_index
	card.z_index = 0
	
	# 获取对应的卡槽
	var slot = get_slot_by_index(slot_index)
	
	# 【装备系统】如果是道具卡片，移除装备效果
	if _is_item_card(card) and current_character_card != null:
		print("【背包】检测到道具卡片 %s，准备移除装备效果" % card.name)
		card.remove_equip_effects(current_character_card)
	
	# 调用卡片的从背包取出回调
	if card.has_method("on_take_out_from_bag"):
		card.on_take_out_from_bag(slot)
	
	# 发射信号
	card_removed.emit(card, slot_index)
	
	print("【背包】卡片已从槽位 %d 移除" % slot_index)
	return card

## 检查脚本是否继承自 BaggableCard
func _is_baggable_card(script: Script) -> bool:
	if script == null:
		return false
	
	if script == BaggableCardScript:
		return true
	
	var base = script.get_base_script()
	while base != null:
		if base == BaggableCardScript:
			return true
		base = base.get_base_script()
	
	return false

## 检查卡片是否是道具卡片
func _is_item_card(card: Control) -> bool:
	if card == null:
		return false
	
	var script = card.get_script()
	if script == null:
		return false
	
	# 直接检查脚本
	if script == ItemCardScript:
		return true
	
	# 检查继承链
	var base = script.get_base_script()
	while base != null:
		if base == ItemCardScript:
			return true
		base = base.get_base_script()
	
	return false

## 对齐卡片到卡槽中心（等比缩放）
func _align_card_to_slot(card: Control, slot: BagSlot) -> void:
	# 计算缩放比例以适应卡槽
	var card_size = card.size
	var slot_size = slot.get_slot_size()
	
	print("【背包】对齐卡片 %s：卡片尺寸=%s，槽位尺寸=%s" % [card.name, card_size, slot_size])
	
	# 计算宽度和高度的缩放比例，取较小值以确保卡片完全适应
	var scale_x = slot_size.x / card_size.x if card_size.x > 0 else 1.0
	var scale_y = slot_size.y / card_size.y if card_size.y > 0 else 1.0
	var scale_factor = min(scale_x, scale_y)
	
	# 应用等比缩放
	card.scale = Vector2(scale_factor, scale_factor)
	
	# 对齐到卡槽中心
	var center_pos = slot.get_center_global_position()
	var scaled_card_size = card_size * scale_factor
	card.global_position = center_pos - scaled_card_size / 2.0
	
	print("【背包】卡片 %s 已对齐：缩放=%f，中心位置=%s，最终位置=%s" % [card.name, scale_factor, center_pos, card.global_position])

## 加载指定角色的背包数据
## @param character: 要加载背包的角色数据
## @param character_card: 角色卡片引用（可选）
func load_character_bag(character: CharacterData, character_card: CharacterCard = null) -> void:
	if not character:
		push_error("【背包】无效的角色数据")
		return
	
	print("【背包】正在加载角色 '%s' 的背包..." % character.character_name)
	
	# 设置初次加载标志（避免重复应用装备效果）
	is_initial_load = true
	
	# 清空当前背包
	clear_bag()
	
	# 保存当前角色引用
	current_character = character
	current_character_card = character_card
	
	# 准备所有槽位的物品名称（索引 0-7）
	var item_names = [
		character.left,   # 索引 0
		character.right,  # 索引 1
		character.bag1,   # 索引 2
		character.bag2,   # 索引 3
		character.bag3,   # 索引 4
		character.bag4,   # 索引 5
		character.bag5,   # 索引 6
		character.bag6    # 索引 7
	]
	
	# 遍历所有槽位
	for slot_index in range(item_names.size()):
		var item_name = item_names[slot_index]
		
		# 如果槽位为空，跳过
		if item_name == "" or item_name == null:
			continue
		
		# 从 GameData 获取物品数据
		var item_data = _get_item_data_by_name(item_name)
		if item_data.is_empty():
			push_warning("【背包】未找到物品数据: %s" % item_name)
			continue
		
		# 使用 CardFactory 创建卡片（card_type=0 表示 normal 类型，可以放入背包）
		var card = CardFactory.create_by_card_scene(item_data, null, Vector2.ZERO, 0)
		if card:
			# 将卡片添加为背包面板的直接子节点
			add_child(card)
			
			# 确保卡片可以接收鼠标事件
			if "mouse_filter" in card:
				card.mouse_filter = Control.MOUSE_FILTER_STOP
			
			# 等待下一帧，让 Godot 更新卡片的几何属性（size）
			await get_tree().process_frame
			
			# 将卡片放入对应的槽位
			if place_card_at_slot(card, slot_index):
				var slot_name = _get_slot_name(slot_index)
				print("【背包】✓ 加载物品到%s: %s" % [slot_name, item_name])
			else:
				push_error("【背包】✗ 无法将物品放入槽位 %d: %s" % [slot_index, item_name])
				card.queue_free()  # 释放未使用的卡片
		else:
			push_error("【背包】✗ 无法创建卡片: %s" % item_name)
	
	# 重置初次加载标志
	is_initial_load = false
	
	print("【背包】加载完成！")

## 获取槽位名称（用于日志）
func _get_slot_name(index: int) -> String:
	match index:
		0: return "左手"
		1: return "右手"
		_: return "背包槽位%d" % (index - 1)

## 从 GameData 获取物品数据（按名称）
## 尝试从资源、道具、装备数据库中查找
func _get_item_data_by_name(item_name: String) -> Dictionary:
	# 先尝试从资源数据库查找
	var item_data = GameData.get_resource(item_name)
	if not item_data.is_empty():
		return item_data
	
	# 再尝试从道具数据库查找
	item_data = GameData.get_item(item_name)
	if not item_data.is_empty():
		return item_data
	
	# 最后尝试从装备数据库查找
	item_data = GameData.get_equipment(item_name)
	if not item_data.is_empty():
		return item_data
	
	# 都没找到，返回空字典
	return {}

## 清空背包（移除所有卡片）
func clear_bag() -> void:
	print("【背包】正在清空背包...")
	
	# 收集所有要删除的卡片
	var cards_to_remove = []
	
	# 遍历所有槽位
	for slot_index in range(cards.size()):
		if not is_slot_empty(slot_index):
			var card = remove_card_from_slot(slot_index)
			if card:
				cards_to_remove.append(card)
	
	# 统一删除所有卡片
	for card in cards_to_remove:
		if is_instance_valid(card) and card.get_parent() == self:
			remove_child(card)
		if is_instance_valid(card):
			card.queue_free()
	
	print("【背包】清空完成！")

## 保存当前背包数据回角色
## 将卡槽中的物品名称写回角色的背包字段
func save_to_character() -> void:
	if not current_character:
		push_warning("【背包】没有关联的角色，无法保存")
		return
	
	print("【背包】正在保存背包数据到角色 '%s'..." % current_character.character_name)
	
	# 保存所有槽位数据（索引 0-7 对应 left, right, bag1-6）
	current_character.left = _get_card_name_from_index(0)
	current_character.right = _get_card_name_from_index(1)
	current_character.bag1 = _get_card_name_from_index(2)
	current_character.bag2 = _get_card_name_from_index(3)
	current_character.bag3 = _get_card_name_from_index(4)
	current_character.bag4 = _get_card_name_from_index(5)
	current_character.bag5 = _get_card_name_from_index(6)
	current_character.bag6 = _get_card_name_from_index(7)
	
	print("【背包】保存完成！")

## 关闭背包前的准备工作
## 将背包外的卡片移到主场景（避免被删除）
## 注意：槽位内的卡片在放入时就已经是背包面板的子节点了，会随背包一起被 queue_free 删除
func prepare_for_close() -> void:
	print("【背包】准备关闭，正在整理卡片...")
	
	# 保护背包外的卡片（移到主场景）
	_preserve_cards_outside_bag()
	
	print("【背包】卡片整理完成，槽位内的卡片将随背包一起被删除")

## 保护背包外的卡片（避免被删除）
func _preserve_cards_outside_bag() -> void:
	print("【背包】正在检查并保留背包外的卡片...")
	
	# 获取背包的全局矩形区域
	var bag_rect = Rect2(global_position, size)
	
	# 收集所有卡片
	var all_cards: Array[Control] = []
	
	# 从所有槽位收集卡片
	for slot_index in range(cards.size()):
		if not is_slot_empty(slot_index):
			all_cards.append(cards[slot_index])
	
	# 也收集背包面板的直接子节点中的卡片（可能被拖出但还未归位）
	for child in get_children():
		if child is Control and "cardCurrentState" in child:
			if child not in all_cards:
				all_cards.append(child)
	
	# 检查每张卡片
	for card in all_cards:
		if not is_instance_valid(card):
			continue
		
		# 检查卡片的全局位置是否在背包外
		var card_rect = Rect2(card.global_position, card.size)
		
		# 如果卡片不与背包区域相交，说明它在背包外
		if not card_rect.intersects(bag_rect):
			print("【背包】发现背包外的卡片: %s，位置: %s" % [card.name, card.global_position])
			_move_card_to_main_scene(card)

## 将卡片移动到主场景（CardManager）
func _move_card_to_main_scene(card: Control) -> void:
	var old_parent = card.get_parent()
	if old_parent == null:
		return
	
	# 保存卡片的全局位置
	var saved_global_position = card.global_position
	
	# 先获取场景树引用
	var tree = get_tree()
	if tree == null or tree.root == null:
		push_error("【背包】无法获取场景树")
		return
	
	# 尝试找到 CardManager 节点
	var card_manager = tree.root.find_child("CardManager", true, false)
	if card_manager == null:
		push_warning("【背包】找不到 CardManager，卡片将添加到根节点")
		card_manager = tree.root.get_child(0)  # 使用主场景作为目标
	
	# 清除卡片在数组中的引用
	var slot_index = _find_card_index(card)
	if slot_index != -1:
		cards[slot_index] = null
	
	# 从当前父节点移除
	old_parent.remove_child(card)
	
	# 添加到目标父节点
	card_manager.add_child(card)
	
	# 恢复全局位置
	card.global_position = saved_global_position
	
	# 重置卡片缩放（因为槽位会缩放卡片）
	card.scale = Vector2(1.0, 1.0)
	
	# 确保卡片处于固定状态
	if "cardCurrentState" in card:
		card.cardCurrentState = card.cardState.fixed
	
	# 重置 z_index
	card.z_index = 0
	
	print("【背包】卡片 %s 已移动到主场景，位置: %s" % [card.name, card.global_position])

## 从指定索引获取卡片名称
func _get_card_name_from_index(index: int) -> String:
	if index < 0 or index >= cards.size():
		return ""
	
	var card = cards[index]
	if not card:
		return ""
	
	# 尝试从卡片的 Label 获取名称
	var label = card.get_node_or_null("Control/ColorRect/Label")
	if label:
		return label.text
	
	return ""

## 获取当前背包中的物品数量（不包括装备槽）
func get_item_count() -> int:
	var count = 0
	# 只统计背包槽位（索引 2-7）
	for i in range(2, cards.size()):
		if not is_slot_empty(i):
			count += 1
	return count

## 查找卡片所在的槽位索引
func _find_card_index(card: Control) -> int:
	for i in range(cards.size()):
		if cards[i] == card:
			return i
	return -1
