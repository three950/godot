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
@onready var shooter: Shooter = get_node_or_null("Shooter") as Shooter
# 通用UI元素引用 - 子类可以重写这些路径
@onready var card_label: Label = get_node_or_null("cardColor/Panel/Label") as Label
@onready var card_texture: TextureRect = get_node_or_null("TextureRect") as TextureRect
@onready var surface: TextureRect = get_node_or_null("surface") as TextureRect
@onready var shadow: TextureRect = get_node_or_null("shadow") as TextureRect
# 动画播放器
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
# surface 的原始位置
var surface_original_position: Vector2 = Vector2.ZERO
# shadow 的原始位置
var shadow_original_position: Vector2 = Vector2.ZERO
# 悬停时向上移动的距离
const HOVER_OFFSET_Y := -5.0
# 拾取时额外向上移动的距离
const PICKUP_OFFSET_Y := -8.0
# shadow 的最大偏移量（根据位置计算）
const SHADOW_MAX_OFFSET := 8.0
# 当前是否处于悬停状态
var is_hovered: bool = false
# 当前是否处于拾取状态
var is_picked_up: bool = false


# Area2D 重叠检测
var overlapping_cards: Array[Control] = []  # 当前与此卡片 Area2D 重叠的其他卡片
const DRAG_TEMP_Z := 100
var follow_target: Card = null  # 目标卡片，若为null则不跟随
var stack_state: int = 0  # 堆叠状态位标记，参照 CardState.STACK_STATE_*
var children_card: Card = null# 堆叠在卡片上的子卡片
#战斗
@export var battle:BattleState
#音乐
@export var pickup_sound:AudioStream
@export var fall_sound:AudioStream
func _ready() -> void:
	card_state_machine.init(self)
	original_position = position
	# 保存 surface 的原始位置
	if surface:
		surface_original_position = surface.position
	# 保存 shadow 的原始位置
	if shadow:
		shadow_original_position = shadow.position
	# 让材质唯一化，避免多个卡片共享同一个材质导致动画相互影响
	_make_materials_unique()
	# 连接 CardStackDetectorArea 信号
	var stack_detector = get_node("CardStackDetectorArea")
	if stack_detector:
		stack_detector.area_entered.connect(_on_stack_detector_area_entered)
		stack_detector.area_exited.connect(_on_stack_detector_area_exited)
	stacking_on_you.connect(bestacked_on_me)
	stop_stacking_on_you.connect(stop_stacking_on_me)

## 让卡片的材质唯一化，避免多个实例共享材质
func _make_materials_unique() -> void:
	var surface_node := get_node_or_null("surface") as TextureRect
	var shadow_node := get_node_or_null("shadow") as TextureRect
	if surface_node and surface_node.material:
		surface_node.material = surface_node.material.duplicate()
	if shadow_node and shadow_node.material:
		shadow_node.material = shadow_node.material.duplicate()

# 启用 / 禁用堆叠检测 Area
func set_stack_detector_enabled(enabled: bool) -> void:
	var stack_detector = get_node("CardStackDetectorArea")
	if stack_detector:
		stack_detector.set_deferred("monitoring", enabled)
		stack_detector.set_deferred("monitorable", enabled)

# 子类需要重写此方法，返回对应的 CardInfo 资源
func get_card_resource() -> CardInfo:
	return null

# 通用的卡片信息更新方法，子类可以调用 super 后添加额外逻辑
func _update_card_display() -> void:
	var resource = get_card_resource()
	if resource == null:
		return
	# 设置节点名称和卡片名称
	name = resource.name
	cardname = resource.name
	# 更新标签文字
	if card_label:
		card_label.text = resource.name
	# 更新纹理
	if card_texture:
		card_texture.texture = resource.portrait
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
	# 当前卡牌作为“被堆叠的底卡”，不再需要参与新的堆叠检测，禁用检测区域
	set_stack_detector_enabled(false)
	var label_panel := get_node_or_null("cardColor/Panel") as Control
	if label_panel:
		size = label_panel.size
	array_changed.emit()

func stop_stacking_on_me() -> void:
	stack_state &= ~CardState.STACK_STATE_BESTACKED
	children_card = null
	print("不要走")
	# 不再被堆叠，重新允许其他卡堆到自己身上，恢复检测
	set_stack_detector_enabled(true)
	var card_panel := get_node_or_null("cardColor/CardPanel") as Control
	if card_panel:
		size=card_panel.size
	array_changed.emit()
func _physics_process(_delta: float) -> void:
	# 根据卡片在 cardsArea 中的全局位置更新 shadow 偏移
	update_shadow_offset()

func _input(event: InputEvent) -> void:
	card_state_machine.on_input(event)

func _on_gui_input(event: InputEvent) -> void:
	card_state_machine.on_gui_input(event)


func _on_mouse_entered() -> void:
	card_state_machine.on_mouse_entered()
	# 如果卡片在堆叠中且有父卡（follow_target），不进行偏移
	# 偏移由头卡递归应用
	if follow_target != null:
		return
	# 鼠标进入时，应用悬停偏移
	is_hovered = true
	_apply_hover_offset()

func _on_mouse_exited() -> void:
	card_state_machine.on_mouse_exited()
	# 如果卡片在堆叠中且有父卡（follow_target），不进行偏移
	if follow_target != null:
		return
	# 鼠标移出时，移除悬停偏移（包括子卡片）
	_remove_hover_offset()

# 应用悬停偏移（卡片上移，阴影下移），并递归应用到子卡片
func _apply_hover_offset() -> void:
	_update_offset()
	# 递归应用到子卡片（只处理surface，不处理shadow）
	if children_card:
		children_card.is_hovered = true
		children_card._apply_hover_offset()

# 移除悬停偏移，并递归移除子卡片的偏移
func _remove_hover_offset() -> void:
	is_hovered = false
	_update_offset()
	# 递归移除子卡片的偏移
	if children_card:
		children_card._remove_hover_offset()

# 应用拾取偏移（在悬停偏移基础上再偏移），并递归应用到子卡片
func apply_pickup_offset() -> void:
	is_picked_up = true
	_update_offset()
	# 递归应用到子卡片
	if children_card:
		children_card.apply_pickup_offset()

# 重置所有偏移到原始位置，并递归重置子卡片
func reset_offset() -> void:
	is_hovered = false
	is_picked_up = false
	_update_offset()
	# 递归重置子卡片
	if children_card:
		children_card.reset_offset()

# 根据当前状态更新 surface 和 shadow 的位置
func _update_offset() -> void:
	var total_surface_offset: float = 0.0
	var total_shadow_offset: float = 0.0
	
	if is_hovered:
		total_surface_offset += HOVER_OFFSET_Y
		total_shadow_offset -= HOVER_OFFSET_Y  # 阴影反方向移动
	
	if is_picked_up:
		total_surface_offset += PICKUP_OFFSET_Y
		total_shadow_offset -= PICKUP_OFFSET_Y  # 阴影反方向移动
	
	if surface:
		surface.position.y = surface_original_position.y + total_surface_offset
	if shadow:
		shadow.position.y = shadow_original_position.y + total_shadow_offset

# 递归更新所有子卡牌的位置和z_index
func update_children_position() -> void:
	if children_card == null:
		return
	
	# 更新直接子卡牌的位置Panel 在卡片内的相对位置 + 卡片的全局位置来计算
	var label_node := get_node_or_null("cardColor/Panel") as Control
	if label_node:
		var label_relative_y = label_node.position.y
		var label_size = label_node.size
		# 子卡片位置 = 父卡片全局位置.y + Panel相对位置.y + Panel高度
		children_card.global_position = Vector2(global_position.x, global_position.y + label_relative_y + label_size.y)
		children_card.z_index = z_index + 1
	
	# 递归更新子卡牌的子卡牌
	children_card.update_children_position()

# 找到堆叠链的头卡（没有follow_target的卡）
func get_stack_head() -> Card:
	var current: Card = self
	# 向上遍历找到头卡
	while current.follow_target != null:
		current = current.follow_target
	return current

# 从当前卡片开始，更新整个堆叠链的位置
# 如果当前卡片在堆叠中，会先找到头卡，然后从头卡向下更新整个链
func update_stack_chain_position() -> void:
	# 如果当前卡片在堆叠中（有follow_target），找到头卡
	var head_card: Card = get_stack_head()
	# 从头卡开始向下更新整个堆叠链
	head_card.update_children_position()

# 根据卡片在 cardsArea 中的全局位置更新 shadow 的 X 轴偏移量
func update_shadow_offset() -> void:
	if not shadow:
		return
	
	# 查找 cardsArea 节点
	var cards_area: Control = null
	var cards_nodes = get_tree().get_nodes_in_group("Cards")
	for node in cards_nodes:
		if node is Control and node.name == "cardsArea":
			cards_area = node as Control
			break
	if cards_area == null:
		return
	# 计算卡片在 cardsArea 中的相对位置（0.0 到 1.0）
	var card_global_pos = global_position
	var area_global_pos = cards_area.global_position
	var relative_x = (card_global_pos.x - area_global_pos.x) / cards_area.size.x
	
	# 将相对位置限制在 0.0 到 1.0 之间
	relative_x = clamp(relative_x, 0.0, 1.0)
	
	# 计算偏移量：左边偏左（负值），右边偏右（正值）
	# 使用 -1.0 到 1.0 的范围，然后乘以最大偏移量
	var offset_x = (relative_x * 2.0 - 1.0) * SHADOW_MAX_OFFSET
	
	# 只更新 shadow 的 X 轴位置，保留 Y 轴的状态偏移
	shadow.position.x = shadow_original_position.x + offset_x
