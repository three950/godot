class_name BagMover
extends Node

var bag_area: Array[BagArea] = []  # 动态管理的背包列表

var dragging_card: Card = null  # 当前正在拖拽的卡片
var drag_start_position: Vector2 = Vector2.ZERO  # 拖拽开始时的位置

func _ready() -> void:
	Events.bag_registered.connect(_on_bag_registered)
	Events.bag_unregistered.connect(_on_bag_unregistered)
	# 监听卡片拖拽事件
	Events.card_drag_started.connect(_on_card_drag_started)
	Events.card_dropped.connect(_on_card_dropped)
	print("【BagMover】已连接事件系统")

func _on_bag_registered(bag: BagArea) -> void:
	if bag not in bag_area:
		bag_area.append(bag)

func _on_bag_unregistered(bag: BagArea) -> void:
	var index = bag_area.find(bag)
	if index >= 0:
		bag_area.remove_at(index)

func _on_card_drag_started(card: Card) -> void:
	dragging_card = card
	drag_start_position = card.global_position
	print("【BagMover】卡片开始拖拽：", card.name)

func _get_bag_area_for_position(global: Vector2) -> int:#获得是场景中的哪一个背包（索引）
	var dropoed_bag_index:=-1
	for index in bag_area.size():
		# 使用背包节点的包围盒检查是否包含该点
		var rect = Rect2(bag_area[index].global_position, bag_area[index].size)
		if rect.has_point(global):
			dropoed_bag_index=index
	return dropoed_bag_index

func _add_card_to_slot(global: Vector2, card: Card) -> void:
	var bag_index := _get_bag_area_for_position(global)
	if bag_index >= 0 and bag_index < bag_area.size():
		var bag = bag_area[bag_index]
		var slot = _get_slot_for_position(bag, global)
		if slot:
			slot.place_card(card)
	
func _get_slot_for_position(bag: BagArea, global: Vector2) -> BagSlot:#获得是哪一个槽位
	"""获取背包中包含指定位置的槽位"""
	# 检查左右手槽位
	for slot in bag.hand_slots:
		if slot.contains_global_point(global):
			return slot
	# 检查背包槽位
	for slot in bag.backpack_slots:
		if slot.contains_global_point(global):
			return slot
	return null

func _reset_card_to_starting_position(starting_position: Vector2, card: Node) -> void:
	"""将卡片重置到起始位置"""
	card.global_position = starting_position

func _move_card_to_slot(card: Card, slot: BagSlot) -> void:
	"""将卡片移动到指定槽位"""
	if slot and card:
		slot.place_card(card)


func _on_card_dropped(card: Card) -> void:
	"""处理卡片放置事件"""
	# 只处理我们正在追踪的卡片
	if card != dragging_card:
		return
	
	var drop_position = card.get_global_mouse_position()
	var target_bag_index = _get_bag_area_for_position(drop_position)
	var target_slot = null
	
	# 如果放置位置在某个背包内，获取对应的槽位
	if target_bag_index >= 0:
		target_slot = _get_slot_for_position(bag_area[target_bag_index], drop_position)
		print("【BagMover】卡片放置在背包索引：", target_bag_index)
	
	# 如果没有有效的目标槽位，不做处理（让卡片自己的逻辑处理）
	if not target_slot:
		print("【BagMover】卡片未放置在背包槽位中")
		dragging_card = null
		return
	
	# 获取起始位置的背包和槽位
	var start_bag_index = _get_bag_area_for_position(drag_start_position)
	var start_slot = null
	if start_bag_index >= 0:
		start_slot = _get_slot_for_position(bag_area[start_bag_index], drag_start_position)
	
	# 检查目标槽位是否已有卡片
	var existing_card = target_slot.get_card()
	
	if existing_card:
		# 如果有卡片，交换位置
		target_slot.remove_card()
		if start_slot:
			start_slot.remove_card()
			start_slot.place_card(existing_card)
		target_slot.place_card(card)
	else:
		# 目标槽位为空，直接放入
		_add_card_to_slot(drop_position, card)
	
	dragging_card = null
