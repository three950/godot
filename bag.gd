extends Panel
class_name BagPanel

# 信号：请求关闭背包
signal close_requested

# 当前背包所属的角色
var current_character: CharacterData = null

# 装备槽位引用（左右手）
var left_slot: BagSlot = null
var right_slot: BagSlot = null

# 背包槽位引用（bag1-6）
var bag_slots: Array[BagSlot] = []

func _ready() -> void:
	# 确保可以检测鼠标事件
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 获取所有卡槽的引用
	_initialize_slots()

# 处理未处理的输入（用于检测点击背包外部）
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 检查点击位置是否在背包外部
			var mouse_pos = get_global_mouse_position()
			var bag_rect = Rect2(global_position, size)
			
			if not bag_rect.has_point(mouse_pos):
				# 点击在背包外部，发出关闭请求
				print("【背包】检测到点击背包外部，请求关闭")
				close_requested.emit()
				get_viewport().set_input_as_handled()

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

## 加载指定角色的背包数据
## @param character: 要加载背包的角色数据
func load_character_bag(character: CharacterData) -> void:
	if not character:
		push_error("【背包】无效的角色数据")
		return
	
	print("【背包】正在加载角色 '%s' 的背包..." % character.character_name)
	
	# 清空当前背包
	clear_bag()
	
	# 保存当前角色引用
	current_character = character
	
	# 1. 加载装备槽位（left 和 right）
	_load_equipment_slot(left_slot, character.left, "左手")
	_load_equipment_slot(right_slot, character.right, "右手")
	
	# 2. 获取角色的背包物品名称数组
	var bag_items = [
		character.bag1,
		character.bag2,
		character.bag3,
		character.bag4,
		character.bag5,
		character.bag6
	]
	
	# 3. 遍历每个背包槽位
	for i in range(min(bag_items.size(), bag_slots.size())):
		var item_name = bag_items[i]
		
		# 如果槽位为空，跳过
		if item_name == "" or item_name == null:
			continue
		
		# 从 GameData 获取物品数据
		var item_data = _get_item_data_by_name(item_name)
		if item_data.is_empty():
			push_warning("【背包】未找到物品数据: %s" % item_name)
			continue
		
		# 使用 CardFactory 创建卡片
		var card = CardFactory.create_by_card_scene(item_data, null, Vector2.ZERO, 3)  # card_type=3 表示背包中的卡片
		if card:
			# 确保卡片可以接收鼠标事件
			if "mouse_filter" in card:
				card.mouse_filter = Control.MOUSE_FILTER_STOP
			
			# 将卡片放入对应的卡槽
			if bag_slots[i].place_card(card):
				print("【背包】✓ 加载物品到背包槽位 %d: %s" % [i + 1, item_name])
			else:
				push_error("【背包】✗ 无法将物品放入背包槽位 %d: %s" % [i + 1, item_name])
				card.queue_free()  # 释放未使用的卡片
		else:
			push_error("【背包】✗ 无法创建卡片: %s" % item_name)
	
	print("【背包】加载完成！")

## 加载单个装备槽位
func _load_equipment_slot(slot: BagSlot, item_name: String, slot_name: String) -> void:
	if not slot:
		return
	
	if item_name == "" or item_name == null:
		return
	
	# 从 GameData 获取物品数据
	var item_data = _get_item_data_by_name(item_name)
	if item_data.is_empty():
		push_warning("【背包】未找到装备数据: %s" % item_name)
		return
	
	# 使用 CardFactory 创建卡片
	var card = CardFactory.create_by_card_scene(item_data, null, Vector2.ZERO, 3)
	if card:
		# 确保卡片可以接收鼠标事件
		if "mouse_filter" in card:
			card.mouse_filter = Control.MOUSE_FILTER_STOP
		
		# 将卡片放入槽位
		if slot.place_card(card):
			print("【背包】✓ 加载装备到%s槽位: %s" % [slot_name, item_name])
		else:
			push_error("【背包】✗ 无法将装备放入%s槽位: %s" % [slot_name, item_name])
			card.queue_free()
	else:
		push_error("【背包】✗ 无法创建装备卡片: %s" % item_name)

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
	
	# 清空装备槽位
	if left_slot and not left_slot.is_empty():
		var card = left_slot.remove_card()
		if card:
			card.queue_free()
	
	if right_slot and not right_slot.is_empty():
		var card = right_slot.remove_card()
		if card:
			card.queue_free()
	
	# 清空背包槽位
	for slot in bag_slots:
		if not slot.is_empty():
			var card = slot.remove_card()
			if card:
				card.queue_free()  # 释放卡片节点
	
	print("【背包】清空完成！")

## 保存当前背包数据回角色
## 将卡槽中的物品名称写回角色的背包字段
func save_to_character() -> void:
	if not current_character:
		push_warning("【背包】没有关联的角色，无法保存")
		return
	
	print("【背包】正在保存背包数据到角色 '%s'..." % current_character.character_name)
	
	# 1. 保存装备槽位数据
	if left_slot:
		current_character.left = _get_card_name_from_slot(left_slot)
	if right_slot:
		current_character.right = _get_card_name_from_slot(right_slot)
	
	# 2. 保存背包槽位数据
	var bag_fields = ["bag1", "bag2", "bag3", "bag4", "bag5", "bag6"]
	
	# 遍历卡槽，提取物品名称
	for i in range(min(bag_slots.size(), bag_fields.size())):
		var slot = bag_slots[i]
		var field_name = bag_fields[i]
		current_character.set(field_name, _get_card_name_from_slot(slot))
	
	print("【背包】保存完成！")

## 从卡槽中获取卡片名称
func _get_card_name_from_slot(slot: BagSlot) -> String:
	if not slot or slot.is_empty():
		return ""
	
	var card = slot.get_card()
	if not card:
		return ""
	
	# 尝试从卡片的 Label 获取名称
	var label = card.get_node_or_null("Control/ColorRect/Label")
	if label:
		return label.text
	
	return ""

## 获取当前背包中的物品数量
func get_item_count() -> int:
	var count = 0
	for slot in bag_slots:
		if not slot.is_empty():
			count += 1
	return count

## 在关闭背包前，将背包外的卡片移到主场景
## 这样这些卡片就不会随着背包一起被删除
func preserve_cards_outside_bag() -> void:
	print("【背包】正在检查并保留背包外的卡片...")
	
	# 获取背包的全局矩形区域
	var bag_rect = Rect2(global_position, size)
	
	# 收集所有卡片（包括槽位中的和可能拖出的）
	var all_cards: Array[Control] = []
	
	# 从所有槽位收集卡片
	if left_slot and not left_slot.is_empty():
		all_cards.append(left_slot.get_card())
	if right_slot and not right_slot.is_empty():
		all_cards.append(right_slot.get_card())
	for slot in bag_slots:
		if not slot.is_empty():
			all_cards.append(slot.get_card())
	
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
	
	# 从当前父节点移除
	old_parent.remove_child(card)
	
	# 如果卡片在槽位中，需要清除槽位的引用
	if old_parent is BagSlot:
		if old_parent.stored_card == card:
			old_parent.stored_card = null
	
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
