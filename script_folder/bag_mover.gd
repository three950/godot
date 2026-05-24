class_name BagMover
extends Node

var bag_area: Array[BagArea] = []  # 动态管理的防具列表

var dragging_card: Card = null  # 当前正在拖拽的卡片
var drag_start_position: Vector2 = Vector2.ZERO  # 拖拽开始时的位置
var drag_start_slot: Panel = null  # 拖拽开始时所在的槽位（如果有）
var current_highlight_slot: Panel = null  # 当前高亮的槽位

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
	
	# 1. 计算卡片中心位置，用来判断它起始时是否在某个槽位中
	var card_center = card.global_position + card.size * card.scale / 2.0
	var start_bag_index = _get_bag_area_for_position(card_center)
	drag_start_slot = null
	if start_bag_index >= 0:
		var bag = bag_area[start_bag_index]
		drag_start_slot = _get_slot_for_position(bag, card_center)
	
	# 2. 如果是从某个槽位开始拖拽，只移除该槽位中卡片的属性效果（不移除节点）
	if drag_start_slot:
		var start_bag := _get_bag_for_slot(drag_start_slot)
		if start_bag != null:
			start_bag.unequip_slot_only(drag_start_slot)

func _process(_delta: float) -> void:
	# 只在拖拽卡片时进行检测
	if not dragging_card:
		return
	
	# 计算卡片中心位置
	var card_center = dragging_card.global_position + dragging_card.size * dragging_card.scale / 2.0
	var target_bag_index = _get_bag_area_for_position(card_center)
	var target_slot: Panel = null
	
	# 找到目标槽位
	if target_bag_index >= 0:
		var bag = bag_area[target_bag_index]
		target_slot = _get_nearest_slot(bag, card_center)
	
	# 更新高亮状态
	_update_highlight(target_slot)

func _update_highlight(new_slot: Panel) -> void:
	"""更新槽位高亮状态"""
	# 如果目标槽位没变，不需要更新
	if new_slot == current_highlight_slot:
		return
	
	# 取消旧槽位的高亮
	if current_highlight_slot and is_instance_valid(current_highlight_slot):
		_set_slot_highlight(current_highlight_slot, false)
	
	# 设置新槽位的高亮
	if new_slot:
		_set_slot_highlight(new_slot, true)
	
	current_highlight_slot = new_slot

func _clear_all_highlights() -> void:
	"""清除所有高亮"""
	if current_highlight_slot and is_instance_valid(current_highlight_slot):
		_set_slot_highlight(current_highlight_slot, false)
	current_highlight_slot = null

func _get_bag_area_for_position(global: Vector2) -> int:#获得是场景中的哪一个防具（索引）
	var dropoed_bag_index:=-1
	for index in bag_area.size():
		# 使用防具节点的包围盒检查是否包含该点
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
			bag.place_card_in_slot(slot, card)
	
func _get_slot_for_position(bag: BagArea, global: Vector2) -> Panel:#获得是哪一个槽位
	"""获取防具中包含指定位置的槽位"""
	# 检查武器槽位
	for slot in bag.hand_slots:
		if bag.slot_contains_global_point(slot, global):
			return slot
	# 检查防具槽位
	for slot in bag.backpack_slots:
		if bag.slot_contains_global_point(slot, global):
			return slot
	return null

func _get_nearest_slot(bag: BagArea, global: Vector2) -> Panel:
	"""获取距离指定位置最近的槽位（用于处理鼠标在缝隙中的情况）"""
	var nearest_slot: Panel = null
	var min_distance: float = INF
	
	# 检查所有槽位，找到中心点距离最近的
	var all_slots: Array[Panel] = []
	all_slots.append_array(bag.hand_slots)
	all_slots.append_array(bag.backpack_slots)
	
	for slot in all_slots:
		var slot_center = bag.get_slot_center_global_position(slot)
		var distance = global.distance_to(slot_center)
		if distance < min_distance:
			min_distance = distance
			nearest_slot = slot
	
	return nearest_slot

func _reset_card_to_starting_position(starting_position: Vector2, card: Node) -> void:
	"""将卡片重置到起始位置"""
	card.global_position = starting_position

func _move_card_to_slot(card: Card, slot: Panel) -> void:
	"""将卡片移动到指定槽位"""
	var bag := _get_bag_for_slot(slot)
	if bag != null and card != null:
		bag.place_card_in_slot(slot, card)


func _on_card_dropped(card: Card) -> void:
	"""处理卡片放置事件"""
	# 只处理我们正在追踪的卡片
	if card != dragging_card:
		return
	
	# 清除高亮
	_clear_all_highlights()
	
	# 使用卡片中心位置来判断放置位置（比鼠标位置更可靠）
	var card_center = card.global_position + card.size * card.scale / 2.0
	var target_bag_index = _get_bag_area_for_position(card_center)
	var target_slot = null
	
	# 如果卡片中心在某个防具内，找到最近的槽位
	if target_bag_index >= 0:
		var bag = bag_area[target_bag_index]
		target_slot = _get_nearest_slot(bag, card_center)
		print("【BagMover】卡片放置在防具索引：", target_bag_index)
	
	# 如果没有有效的目标槽位，不做处理（让卡片自己的逻辑处理）
	if not target_slot:
		print("【BagMover】卡片未放置在防具槽位中")
		# 如果一开始是从某个槽位拖出来的，此时已经在 _on_card_drag_started 里卸下过装备效果，
		# 这里不再做属性变更，只是结束拖拽
		dragging_card = null
		drag_start_slot = null
		return
	
	# 检查目标槽位是否已有卡片
	var target_bag := bag_area[target_bag_index] as BagArea
	var existing_card = target_bag.get_card_in_slot(target_slot)
	
	if existing_card:
		# 如果有卡片，交换位置
		# 1. 从目标槽位取下原有卡片，BagArea 会同步 CharacterCard 的装备变化。
		var swapped_card: Card = target_bag.remove_card_from_slot(target_slot)
		# 2. 如果一开始是从某个槽位拖拽出来的，就把这张被换出来的卡放回起始槽位。
		if drag_start_slot and swapped_card:
			var start_bag := _get_bag_for_slot(drag_start_slot)
			if start_bag != null:
				start_bag.place_card_in_slot(drag_start_slot, swapped_card)
		# 3. 最后把正在拖拽的卡放入目标槽位。
		target_bag.place_card_in_slot(target_slot, card)
	else:
		# 目标槽位为空，直接放入
		target_bag.place_card_in_slot(target_slot, card)
	
	dragging_card = null
	drag_start_slot = null


func _set_slot_highlight(slot: Panel, enabled: bool) -> void:
	var bag := _get_bag_for_slot(slot)
	if bag != null:
		bag.set_slot_highlight(slot, enabled)


func _get_bag_for_slot(slot: Panel) -> BagArea:
	if slot == null:
		return null
	for bag in bag_area:
		if bag.hand_slots.has(slot) or bag.backpack_slots.has(slot):
			return bag
	return null
