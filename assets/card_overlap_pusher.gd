class_name CardOverlapPusher
extends Node
## 卡片重叠自动挤压分离处理器
## 当两张非父子关系的卡片重叠，且都不在拖拽状态时，自动缓慢分离

## 每帧移动的像素距离
@export var push_speed: float = 4.0
## 最小分离距离（防止卡片完全重合时无法计算方向）
@export var min_separation: float = 1.0

var card: Card
## 当前正在与本卡片重叠的其他卡片集合
var overlapping_push_cards: Dictionary = {}  # Card -> bool

func _ready() -> void:
	# 获取父节点的Card引用
	card = get_parent() as Card
	if not card:
		push_error("CardOverlapPusher must be a child of a Card node")
		return
	
	# 连接重叠检测区域的信号
	var push_detector = card.get_node_or_null("CardPushDetectorArea")
	if push_detector:
		push_detector.area_entered.connect(_on_push_detector_area_entered)
		push_detector.area_exited.connect(_on_push_detector_area_exited)

func _physics_process(delta: float) -> void:
	if overlapping_push_cards.is_empty():
		return
	
	# 检查当前卡片是否在可以被推动的状态
	if not _can_be_pushed(card):
		return
	
	# 遍历所有重叠的卡片并进行推离
	var cards_to_remove: Array[Card] = []
	for other_card in overlapping_push_cards.keys():
		if not is_instance_valid(other_card):
			cards_to_remove.append(other_card)
			continue
		
		# 检查另一张卡片是否也可以被推动
		if not _can_be_pushed(other_card):
			continue
		
		# 检查是否是父子关系
		if _is_parent_child_relation(card, other_card):
			continue
		
		# 计算推离方向和距离
		_push_cards_apart(card, other_card, delta)
	
	# 清理无效的卡片引用
	for invalid_card in cards_to_remove:
		overlapping_push_cards.erase(invalid_card)

## 检查卡片是否可以被推动（不在拖拽状态）
func _can_be_pushed(check_card: Card) -> bool:
	if not check_card.card_state_machine or not check_card.card_state_machine.current_state:
		return true
	
	var current_state = check_card.card_state_machine.current_state.state
	# 在拖拽或堆叠拖拽状态时不进行推动
	if current_state == CardState.State.dragging or current_state == CardState.State.instackdragging or current_state == CardState.State.pickingup:
		return false
	return true

## 检查两张卡片是否有父子关系（通过堆叠形成的）
func _is_parent_child_relation(card_a: Card, card_b: Card) -> bool:
	# 检查card_a是否是card_b的children_card
	if card_a.children_card == card_b:
		return true
	# 检查card_b是否是card_a的children_card
	if card_b.children_card == card_a:
		return true
	# 检查follow_target关系
	if card_a.follow_target == card_b or card_b.follow_target == card_a:
		return true
	# 递归检查堆叠链
	var current = card_a.children_card
	while current:
		if current == card_b:
			return true
		current = current.children_card
	current = card_b.children_card
	while current:
		if current == card_a:
			return true
		current = current.children_card
	return false

## 让两张卡片相互推离
func _push_cards_apart(card_a: Card, card_b: Card, delta: float) -> void:
	var pos_a = card_a.global_position
	var pos_b = card_b.global_position
	
	# 计算从card_b指向card_a的方向
	var direction = pos_a - pos_b
	
	# 如果两张卡片完全重合，给一个随机方向
	if direction.length() < min_separation:
		direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	else:
		direction = direction.normalized()
	
	# 计算移动量，两张卡片各移动一半
	var move_amount = push_speed * delta * 60  # 乘以60使速度与帧率无关
	var half_move = move_amount / 2.0
	
	# 移动card_a（本卡片）向远离card_b的方向
	card_a.global_position += direction * half_move
	# 移动card_b向远离card_a的方向
	card_b.global_position -= direction * half_move
	
	# 如果卡片有子卡片，也需要更新子卡片位置
	card_a.update_children_position()
	card_b.update_children_position()

## 重叠检测区域进入信号处理
func _on_push_detector_area_entered(area: Area2D) -> void:
	var other_card = area.get_parent() as Card
	if not other_card or other_card == card:
		return
	
	# 检查是否是父子关系
	if _is_parent_child_relation(card, other_card):
		return
	
	# 检查两张卡片是否都不在拖拽状态
	if not _can_be_pushed(card) or not _can_be_pushed(other_card):
		return
	
	# 添加到重叠列表
	overlapping_push_cards[other_card] = true
	print("[Pusher] 卡片 %s 与 %s 开始重叠挤压" % [card.name, other_card.name])

## 重叠检测区域离开信号处理
func _on_push_detector_area_exited(area: Area2D) -> void:
	var other_card = area.get_parent() as Card
	if not other_card:
		return
	
	# 从重叠列表中移除
	if overlapping_push_cards.has(other_card):
		overlapping_push_cards.erase(other_card)
		print("[Pusher] 卡片 %s 与 %s 结束重叠挤压" % [card.name, other_card.name])
