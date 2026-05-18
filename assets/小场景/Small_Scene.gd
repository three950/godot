extends Card
class_name Small_Scene

@onready var label: Label = $Panel/Label
@onready var texture_rect: TextureRect = $TextureRect
@onready var card_progress_bar: CardProgressBar = $CardProgressBar

@export var scene: SceneCard
@export var spawn_offset: Vector2 = Vector2(0, 360)
@export var cardpool: CardPool

var spawn_card_info: CardInfo
var _is_timing: bool = false
var _connected_cards: Array[Card] = []

func set_stats(value: SceneCard) -> void:
	scene = value
	if is_node_ready():
		_update_item_card()

func _ready() -> void:
	super._ready()
	_update_item_card()

func _update_item_card() -> void:
	if scene == null:
		return
	label.text = scene.name
	texture_rect.texture = scene.portrait

# 只允许类型为"人物"的卡牌堆叠
func _on_stack_detector_area_entered(area: Area2D) -> void:
	var entering_card = area.get_parent() as Card
	if entering_card:
		var card_resource = entering_card.get_card_resource()
		if card_resource and card_resource.type == CardInfo.CardType.人物:
			print("人物卡牌 %s 可以堆叠到深度卡牌 %s 上" % [entering_card.name, name])
			if not entering_card.overlapping_cards.has(self):
				entering_card.overlapping_cards.append(self)
				print("深度卡牌 %s 添加到人物卡牌 %s 的重叠数组中" % [name, entering_card.name])
			card_label_entered_stack_area.emit(entering_card)
		else:
			print("卡牌 %s 不是人物类型，无法堆叠到深度卡牌 %s 上" % [entering_card.name, name])

func bestacked_on_me(children: Card) -> void:
	super.bestacked_on_me(children)
	_update_signal_connections()
	if _is_timing:
		_update_timing_with_current_progress()
	else:
		_start_timing()

func _collect_all_character_cards(start_card: Card) -> Array[Card]:
	var character_cards: Array[Card] = []
	var current_card = start_card
	
	while is_instance_valid(current_card):
		var card_resource = current_card.get_card_resource()
		if card_resource and card_resource.type == CardInfo.CardType.人物:
			character_cards.append(current_card)
		current_card = current_card.children_card
	
	return character_cards

func _update_signal_connections() -> void:
	var character_cards = _collect_all_character_cards(children_card)
	
	for card in character_cards:
		if is_instance_valid(card):
			if not card.array_changed.is_connected(_on_stack_state_changed):
				card.array_changed.connect(_on_stack_state_changed)
				_connected_cards.append(card)
				print("已连接人物卡 %s 的 array_changed 信号" % card.name)

func _disconnect_all_signals() -> void:
	for card in _connected_cards:
		if is_instance_valid(card):
			if card.array_changed.is_connected(_on_stack_state_changed):
				card.array_changed.disconnect(_on_stack_state_changed)
	_connected_cards.clear()

func _on_stack_state_changed() -> void:
	if _is_timing:
		print("检测到堆叠状态变化，保留进度并更新计时")
		_update_signal_connections()
		_update_timing_with_current_progress()
	else:
		_update_signal_connections()

## 计算所有堆叠人物卡的速度（重写父类方法，每个人物卡使用相同的默认速度，速度累加）
func _calculate_average_speed() -> float:
	var character_cards = _collect_all_character_cards(children_card)
	if character_cards.size() == 0:
		return 1.0

	const DEFAULT_SPEED = 20.0
	var total_speed := 0.0
	
	for card in character_cards:
		var card_resource = card.get_card_resource()
		if card_resource is CharacterCard:
			var character_card = card_resource as CharacterCard
			var 特性数组 = character_card.特性
			
			# 如果 scene 是 SceneCardPool 类型，调用 speed_change 获取速度倍数；否则默认为1
			var speed_multiplier = 1
			if scene is SceneCardPool:
				var scene_card_pool = scene as SceneCardPool
				speed_multiplier = scene_card_pool.speed_change(特性数组)
			
			# 每个人物卡的基础速度乘以倍数后累加
			total_speed += DEFAULT_SPEED * float(speed_multiplier)
	
	# 返回累加的总速度（父类会用 100.0 / average_speed 计算时间）
	return total_speed

func _start_timing() -> void:
	if not is_instance_valid(children_card):
		_cancel_timing()
		return
	_is_timing = true
	var average_speed = _calculate_average_speed()
	var duration = 100.0 / average_speed
	
	card_progress_bar.progress_completed.connect(
		func(): _on_spawn_timer_completed(),
		CONNECT_ONE_SHOT
	)
	
	card_progress_bar.start(duration)
	var character_cards = _collect_all_character_cards(children_card)
	print("开始计时生成卡牌，堆叠人物卡数量: %d，平均speed: %s，计时时长: %s 秒" % [character_cards.size(), average_speed, duration])

func _update_timing_with_current_progress() -> void:
	if not is_instance_valid(children_card):
		_cancel_timing()
		return
	
	_is_timing = true
	var average_speed = _calculate_average_speed()
	var new_duration = 100.0 / average_speed
	var current_progress = card_progress_bar.get_progress_ratio()
	card_progress_bar.continue_with_new_duration(new_duration, true)
	
	var character_cards = _collect_all_character_cards(children_card)
	print("更新计时，堆叠人物卡数量: %d，平均speed: %s，新计时时长: %s 秒，当前进度: %.1f%%" % [character_cards.size(), average_speed, new_duration, current_progress * 100])

func stop_stacking_on_me() -> void:
	super.stop_stacking_on_me()
	_update_signal_connections()
	if is_instance_valid(children_card):
		if _is_timing:
			_update_timing_with_current_progress()
		else:
			_start_timing()
	else:
		if _is_timing:
			print("所有卡牌已离开，取消计时")
			_cancel_timing()
		_disconnect_all_signals()

func _cancel_timing() -> void:
	_is_timing = false
	card_progress_bar.stop()
	_disconnect_all_signals()

## 计时完成回调
func _on_spawn_timer_completed() -> void:#TODO 目前没有设置具体的概率，所以使用pick_random重写
	# 如果任务已被取消，直接返回
	if not _is_timing:return

	spawn_card_info=scene.card_pool.pick_random()
	print("spawn_card_info: ", spawn_card_info)
	_spawn_card()
	
	if is_instance_valid(children_card):
		print("卡牌仍在堆叠，继续计时生成下一张卡牌")
		_start_timing()
		return

	_cancel_timing()

func _spawn_card() -> void:
	var card_instance = _create_card_instance()
	var spawn_position = global_position + spawn_offset
	card_instance.z_index = 1
	
	var cards_group = get_tree().get_first_node_in_group("Cards")
	if cards_group:
		cards_group.add_child(card_instance)
	card_instance.global_position = global_position
	card_instance.shooter.play_card_shooter(spawn_position)
	print("卡牌已生成于位置: %s, 卡牌名称: %s" % [spawn_position, spawn_card_info.name if spawn_card_info else "默认"])

func _create_card_instance() -> Node:
	var instance = spawn_card_info.card_scene.instantiate()
	instance.set_stats(spawn_card_info)
	return instance
