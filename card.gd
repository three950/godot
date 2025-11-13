extends Control
class_name Card
# 信号：当有卡片堆叠到此卡片上时触发
signal card_stacked_on(stacked_card: Control)
# 信号：当卡片从堆叠中被移除时触发
signal card_removed_from_stack(removed_card: Control)
# 信号：当卡片固定位置时触发（拖动结束）
signal card_fixed()
# 信号：当一个卡片的CardLabel进入此卡片的CardStackDetectorArea时触发
signal card_label_entered_stack_area(entering_card: Control)
# 信号：当一个卡片的CardLabel离开此卡片的CardStackDetectorArea时触发
signal card_label_exited_stack_area(exiting_card: Control)

enum cardState{fixed, pickingup, dragging, falling}
var CAN_STACK_ON: bool = false
const STACK_STATE_BESTACKED = 1
const STACK_STATE_STACKING = 2
# 默认状态为0，表示不具有任何堆叠属性
@export var cardStackState: int = 0
enum cardType{normal, selling, architecture}  # 卡片类型
@export var cardCurrentState = cardState.fixed
@export var card_type: cardType = cardType.normal  # 默认为普通类型
@export var follow_target: Card = null  # 目标卡片，若为null则不跟随
@export var can_accept_stack: bool = true  # 是否允许其他卡片堆叠在上面
@export var accept_value_only: bool = false  # 若为真，仅接受带有 value 属性的卡片
var original_position: Vector2 = Vector2.ZERO  # 开始拖拽时的原始位置
# Area2D 重叠检测
var overlapping_cards: Array[Control] = []  # 当前与此卡片 Area2D 重叠的其他卡片
const DRAG_TEMP_Z := 100

func _ready() -> void:
	original_position = position	
	# 连接 CardStackDetectorArea 信号
	var stack_detector = get_node_or_null("Control/CardStackDetectorArea")
	if stack_detector:
		stack_detector.area_entered.connect(_on_stack_detector_area_entered)
		stack_detector.area_exited.connect(_on_stack_detector_area_exited)
	

func _process(_delta: float) -> void:
	# 当卡片处于stacking状态且有follow_target时，卡片的cardState完全按照follow_target来
	if cardStackState & STACK_STATE_STACKING and follow_target != null:
		print("卡片 %s 跟随目标 %s 的状态变化" % [name, follow_target.name])
		cardCurrentState = follow_target.cardCurrentState	
	match cardCurrentState:
		cardState.dragging:
			if follow_target == null:#第一张卡，跟随鼠标移动
				global_position = get_global_mouse_position() - size / 2
			else:#其他卡片，跟随前一张卡的Label节点正下方
				if follow_target.has_node("Label"):
					var label_pos = follow_target.Label.global_position
					var label_size = follow_target.Label.size
					global_position = Vector2(label_pos.x, label_pos.y + label_size.y)
			z_index = DRAG_TEMP_Z

		cardState.pickingup:
			if cardStackState & STACK_STATE_STACKING and follow_target != null:#被拿起时，断开与前一张卡的连接
				print("卡片 %s 断开与目标 %s 的连接" % [name, follow_target.name])
				follow_target = null
			cardCurrentState = cardState.dragging##
		cardState.falling:##先根据当前所属位置，变换场景父节点
			print("卡片 %s 处于下落状态" % name)
			z_index = 0
			# 检测是否可以堆叠到其他卡片上
			var closest_card_falling = find_closest_card()
			if closest_card_falling != null:
					print("卡片 %s 找到最近的卡片 %s 进行堆叠" % [name, closest_card_falling.name])
					stack_on_card(closest_card_falling)
			if cardStackState & STACK_STATE_BESTACKED:
				print("卡片 %s 已堆叠到最顶部" % name)
				cardCurrentState = follow_target.cardCurrentState
			else:
				card_fixed.emit()
				print("卡片 %s 已固定" % name)
				cardCurrentState = cardState.fixed##		
		cardState.fixed:
			pass

func _on_button_button_down() -> void:
	# architecture 类型不能拖拽
	if card_type == cardType.architecture:
		return	
	print("按钮按下，卡片 %s 开始拾取" % name)
	cardCurrentState = cardState.pickingup
	original_position = position	

func _on_button_button_up() -> void:	
		# 设置为固定状态
		print("按钮释放，卡片 %s 开始下落" % name)
		cardCurrentState = cardState.falling
		original_position = position
# CardStackDetectorArea 信号处理：当有 Area 进入时
func _on_stack_detector_area_entered(area: Area2D) -> void:
	# 找到进入区域的Area2D所属的卡片实例
	var entering_card = area.get_parent().get_parent() as Card
	if entering_card:
		print("卡片 %s 可以堆叠到卡片 %s 上" % [entering_card.name, name])
		entering_card.CAN_STACK_ON = true
		# 将当前卡片添加到进入卡片的重叠数组中
		if not entering_card.overlapping_cards.has(self):
			entering_card.overlapping_cards.append(self)
			print("卡片 %s 添加到卡片 %s 的重叠数组中" % [name, entering_card.name])
		# 发送信号通知
		card_label_entered_stack_area.emit(entering_card)

# CardStackDetectorArea 信号处理：当有 Area 离开时
func _on_stack_detector_area_exited(area: Area2D) -> void:
	# 找到离开区域的Area2D所属的卡片实例
	var exiting_card = area.get_parent().get_parent() as Card
	if exiting_card:
		print("卡片 %s 不能堆叠到卡片 %s 上" % [exiting_card.name, name])
		exiting_card.CAN_STACK_ON = false
		# 将当前卡片从离开卡片的重叠数组中移除
		if exiting_card.overlapping_cards.has(self):
			exiting_card.overlapping_cards.erase(self)
			print("卡片 %s 从卡片 %s 的重叠数组中移除" % [name, exiting_card.name])
		# 发送信号通知
		card_label_exited_stack_area.emit(exiting_card)

# 查找最近的可堆叠卡片（从重叠的卡片中查找）
func find_closest_card() -> Control:
	# 只从当前重叠的卡片中查找
	print("卡片 %s 开始查找最近的可堆叠卡片" % name)
	var closest_card: Control = null
	var closest_distance_sq: float = INF
	
	for card in overlapping_cards:
		# 只查找状态为fixed且未被堆叠的卡片
		if not ("cardCurrentState" in card and card.cardCurrentState == cardState.fixed):
			print("1")
			continue
		# 检查卡片是否未被堆叠
		if "cardStackState" in card and (card.cardStackState & STACK_STATE_BESTACKED):
			print("2")
			continue
		# 如果目标卡片是 selling 类型，不能堆叠在上面
		if "card_type" in card:
			if card.card_type == cardType.selling:
				print("3")
				continue
		# 检查目标卡片是否允许堆叠
		if "can_accept_stack" in card and not card.can_accept_stack:
			print("4")
			continue
		# 如果目标卡片只接受带 value 的卡片
		if "accept_value_only" in card and card.accept_value_only:
			# 拖拽的卡必须有 value 属性
			if not ("value" in self):
				print("5")
				continue
		# 从重叠的卡片中找最近的一个
		var dist_sq = global_position.distance_squared_to(card.global_position)
		if dist_sq < closest_distance_sq:
			closest_distance_sq = dist_sq
			closest_card = card	
	return closest_card

# 堆叠到目标卡片上
func stack_on_card(target_card: Control) -> void:
	# 设置当前卡片的堆叠状态为stacking
	print("卡片 %s 开始堆叠到卡片 %s 上" % [name, target_card.name])
	cardStackState = STACK_STATE_STACKING
	# 设置跟随目标
	follow_target = target_card
		
	
	# 设置目标卡片的堆叠状态为bestacked
	target_card.cardStackState = STACK_STATE_BESTACKED
	print("目标卡片 %s 的堆叠状态设置为bestacked" % target_card.name)
	
	# 设置初始位置：跟随目标卡片的Label节点正下方
	if target_card.has_node("Label"):
		var label_pos = target_card.Label.global_position
		var label_size = target_card.Label.size
		global_position = Vector2(label_pos.x, label_pos.y + label_size.y)
	
	# 设置层级
	z_index = target_card.z_index + 1
	print("卡片 %s 堆叠完成，层级设置为 %d" % [name, z_index])
