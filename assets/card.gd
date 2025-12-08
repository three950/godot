extends Control
class_name Card
# 信号：当一个卡片的CardLabel进入此卡片的CardStackDetectorArea时触发
signal card_label_entered_stack_area(entering_card: Control)
# 信号：当一个卡片的CardLabel离开此卡片的CardStackDetectorArea时触发
signal card_label_exited_stack_area(exiting_card: Control)
# 由堆叠在此卡上的其他卡发出，让此卡设置control区域和状态转换
signal stacking_on_you(children: Card)
signal stop_stacking_on_you()
signal dropped
signal drag_started
signal leave_you()
# 信号：当此卡片的堆叠状态发生变化时触发（有卡片堆上来或离开）
signal array_changed()
# 信号：请求重新设置父节点
signal reparent_requested(which_card: Card)
enum cardType{normal, selling, architecture}  # 卡片类型
@export var cardname:String
@export var card_type: cardType = cardType.normal  # 默认为普通类型
@export var can_stack: bool = true  # 是否允许其他卡片堆叠在上面
var original_position: Vector2 = Vector2.ZERO  # 开始拖拽时的原始位置
var drag_offset: Vector2 = Vector2.ZERO  # 拖拽时鼠标相对于卡片的偏移量
@onready var card_state_machine:CardStateMachine=$CardStateMachine as CardStateMachine
@onready var shooter: Shooter = $Shooter
# Area2D 重叠检测
var overlapping_cards: Array[Control] = []  # 当前与此卡片 Area2D 重叠的其他卡片
const DRAG_TEMP_Z := 100
var follow_target: Card = null  # 目标卡片，若为null则不跟随
var stack_state: int = 0  # 堆叠状态位标记，参照 CardState.STACK_STATE_*
var children_card: Card = null# 堆叠在卡片上的子卡片
func _ready() -> void:
	card_state_machine.init(self)
	original_position = position
	# 连接 CardStackDetectorArea 信号
	var stack_detector = get_node("CardStackDetectorArea")
	if stack_detector:
		stack_detector.area_entered.connect(_on_stack_detector_area_entered)
		stack_detector.area_exited.connect(_on_stack_detector_area_exited)
	stacking_on_you.connect(bestacked_on_me)
	stop_stacking_on_you.connect(stop_stacking_on_me)
# CardStackDetectorArea 信号处理：当有 Area 进入时
func _on_stack_detector_area_entered(area: Area2D) -> void:
	# 找到进入区域的Area2D所属的卡片实例
	var entering_card = area.get_parent() as Card
	if entering_card:
		print("卡片 %s 可以堆叠到卡片 %s 上 (目标卡片can_stack=%s)" % [entering_card.name, name, can_stack])
		# 将当前卡片（目标卡片）添加到进入卡片的重叠数组中
		if not entering_card.overlapping_cards.has(self):
			entering_card.overlapping_cards.append(self)
			print("卡片 %s 添加到卡片 %s 的重叠数组中" % [name, entering_card.name])
		# 发送信号通知
		card_label_entered_stack_area.emit(entering_card)

# CardStackDetectorArea 信号处理：当有 Area 离开时
func _on_stack_detector_area_exited(area: Area2D) -> void:
	# 找到离开区域的Area2D所属的卡片实例
	var exiting_card = area.get_parent() as Card
	if exiting_card:
		print("卡片 %s 离开卡片 %s 的检测区域 (目标卡片can_stack=%s)" % [exiting_card.name, name, can_stack])
		# 将当前卡片从离开卡片的重叠数组中移除
		if exiting_card.overlapping_cards.has(self):
			exiting_card.overlapping_cards.erase(self)
			print("卡片 %s 从卡片 %s 的重叠数组中移除" % [name, exiting_card.name])
		# 发送信号通知
		card_label_exited_stack_area.emit(exiting_card)

func bestacked_on_me(children: Card) -> void:
	stack_state |= CardState.STACK_STATE_BESTACKED
	children_card = children
	print("一宿你")
	var label_panel := get_node("Panel")
	if label_panel:
		size = label_panel.size
	array_changed.emit()
	Events.stack_changed.emit(self)

func stop_stacking_on_me() -> void:
	stack_state &= ~CardState.STACK_STATE_BESTACKED
	children_card = null
	print("不要走")
	var card_panel:= get_node("CardPanel")
	if card_panel:
		size=card_panel.size
	array_changed.emit()
	Events.stack_changed.emit(self)
func _input(event: InputEvent) -> void:
	card_state_machine.on_input(event)

func _on_gui_input(event: InputEvent) -> void:
	card_state_machine.on_gui_input(event)


func _on_mouse_entered() -> void:
	card_state_machine.on_mouse_entered()


func _on_mouse_exited() -> void:
	card_state_machine.on_mouse_exited()
