@tool
extends Card
class_name Scene
@onready var label: Label = $Panel/Label
@onready var texture_rect: TextureRect = $TextureRect
@onready var card_progress_bar: CardProgressBar = $CardProgressBar
var spawn_card_info:CardInfo
@export var scene: SceneCard
#生成卡牌相关
@export var spawn_offset: Vector2 = Vector2(0, 120)
@export var cardpool:CardPool
# 计时相关
var _is_timing: bool = false
var _connected_cards: Array[Card] = []  # 存储已连接信号的人物卡

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

#只允许类型为"人物"的卡牌堆叠
func _on_stack_detector_area_entered(area: Area2D) -> void:
	var entering_card = area.get_parent() as Card
	if entering_card:
		var card_resource = entering_card.get_card_resource()
		if card_resource and card_resource.type == CardInfo.CardType.人物:
			print("人物卡牌 %s 可以堆叠到深度卡牌 %s 上" % [entering_card.name, name])
			# 将当前卡片（目标卡片）添加到进入卡片的重叠数组中
			if not entering_card.overlapping_cards.has(self):
				entering_card.overlapping_cards.append(self)
				print("深度卡牌 %s 添加到人物卡牌 %s 的重叠数组中" % [name, entering_card.name])
			# 发送信号通知
			card_label_entered_stack_area.emit(entering_card)
		else:
			print("卡牌 %s 不是人物类型，无法堆叠到深度卡牌 %s 上" % [entering_card.name, name])

func bestacked_on_me(children: Card) -> void:
	super.bestacked_on_me(children)
	# 更新信号连接，监听所有堆叠人物卡的状态变化
	_update_signal_connections()
	if _is_timing:
		_update_timing_with_current_progress()
	else:
		_start_timing()

## 收集所有堆叠在此卡上的人物卡（递归）
func _collect_all_character_cards(start_card: Card) -> Array[Card]:
	var character_cards: Array[Card] = []
	var current_card = start_card
	
	while is_instance_valid(current_card):
		var card_resource = current_card.get_card_resource()
		if card_resource and card_resource.type == CardInfo.CardType.人物:
			character_cards.append(current_card)
		# 继续向上查找堆叠的卡
		current_card = current_card.children_card
	
	return character_cards

## 更新信号连接：连接所有堆叠人物卡的 array_changed 信号
func _update_signal_connections() -> void:
	# 收集所有堆叠的人物卡
	var character_cards = _collect_all_character_cards(children_card)
	
	# 为每张人物卡连接 array_changed 信号
	for card in character_cards:
		if is_instance_valid(card):
			if not card.array_changed.is_connected(_on_stack_state_changed):
				card.array_changed.connect(_on_stack_state_changed)
				_connected_cards.append(card)
				print("已连接人物卡 %s 的 array_changed 信号" % card.name)

## 断开所有已连接的信号
func _disconnect_all_signals() -> void:
	for card in _connected_cards:
		if is_instance_valid(card):
			if card.array_changed.is_connected(_on_stack_state_changed):
				card.array_changed.disconnect(_on_stack_state_changed)
	_connected_cards.clear()

## 当堆叠状态变化时的回调（通过信号触发）
func _on_stack_state_changed() -> void:
	# 如果正在计时，保留当前进度并更新计时
	if _is_timing:
		print("检测到堆叠状态变化，保留进度并更新计时")
		# 更新信号连接（因为堆叠结构可能已改变）
		_update_signal_connections()
		# 更新计时（保留当前进度）
		_update_timing_with_current_progress()
	else:
		# 如果没在计时，也更新信号连接
		_update_signal_connections()

## 计算所有堆叠人物卡的平均speed
func _calculate_average_speed() -> float:
	var character_cards = _collect_all_character_cards(children_card)
	var total_speed := 0.0
	var valid_count := 0
	
	for card in character_cards:
		var card_resource = card.get_card_resource()
		if card_resource and "speed" in card_resource:
			var speed = float(card_resource.speed)
			if speed > 0.0:
				total_speed += speed
				valid_count += 1	
	if valid_count == 0:
		return 1.0
	return total_speed / float(valid_count)

## 启动计时
func _start_timing() -> void:
	# 如果没有子卡堆叠，不启动计时
	if not is_instance_valid(children_card):
		_cancel_timing()
		return
	_is_timing = true
	var average_speed = _calculate_average_speed()
	var duration = 100.0 / average_speed
	
	# 连接进度条完成信号
	card_progress_bar.progress_completed.connect(
		func(): _on_spawn_timer_completed(),
		CONNECT_ONE_SHOT
	)
	
	# 启动进度条（从头开始）
	card_progress_bar.start(duration)
	var character_cards = _collect_all_character_cards(children_card)
	print("开始计时生成卡牌，堆叠人物卡数量: %d，平均speed: %s，计时时长: %s 秒" % [character_cards.size(), average_speed, duration])

## 更新计时，保留当前进度
func _update_timing_with_current_progress() -> void:
	# 如果没有子卡堆叠，不启动计时
	if not is_instance_valid(children_card):
		_cancel_timing()
		return
	
	# 确保正在计时
	_is_timing = true
	
	# 根据所有堆叠人物卡的平均 speed 属性计算新的计时时长：100 / 平均speed
	var average_speed = _calculate_average_speed()
	var new_duration = 100.0 / average_speed
	
	# 获取当前进度比例
	var current_progress = card_progress_bar.get_progress_ratio()
	
	# 使用新时长继续计时，保留当前进度
	card_progress_bar.continue_with_new_duration(new_duration, true)
	
	var character_cards = _collect_all_character_cards(children_card)
	print("更新计时，堆叠人物卡数量: %d，平均speed: %s，新计时时长: %s 秒，当前进度: %.1f%%" % [character_cards.size(), average_speed, new_duration, current_progress * 100])

## 重写父类方法，当卡牌离开时处理计时
func stop_stacking_on_me() -> void:
	super.stop_stacking_on_me()
	# 更新信号连接
	_update_signal_connections()
	# 如果还有子卡堆叠，保留进度并更新计时
	if is_instance_valid(children_card):
		if _is_timing:
			_update_timing_with_current_progress()
		else:
			_start_timing()
	else:
		# 没有子卡了，取消计时并断开所有信号
		if _is_timing:
			print("所有卡牌已离开，取消计时")
			_cancel_timing()
		_disconnect_all_signals()

## 取消计时并隐藏进度条
func _cancel_timing() -> void:
	_is_timing = false
	card_progress_bar.stop()  # stop() 方法会自动隐藏进度条
	_disconnect_all_signals()  # 断开所有信号连接

## 计时完成回调
func _on_spawn_timer_completed() -> void:
	# 如果任务已被取消，直接返回
	if not _is_timing:
		return
	
	# 生成卡牌
	var type=cardpool.get_random_type_in_abyss()
	spawn_card_info=cardpool.get_cards_by_type(type)
	print("type: ", type)
	print("spawn_card_info: ", spawn_card_info)
	_spawn_card()
	
	# 生成卡牌后，如果仍有子卡堆叠，则继续按平均速度重新计时
	if is_instance_valid(children_card):
		print("卡牌仍在堆叠，继续计时生成下一张卡牌")
		_start_timing()
		return

	# 没有子卡堆叠，停止计时
	_cancel_timing()

## 生成卡牌
func _spawn_card() -> void:
	# 根据卡牌资源类型选择正确的场景并实例化
	var card_instance = _create_card_instance()
	
	# 计算生成位置（当前位置的下方）
	var spawn_position = global_position + spawn_offset
	card_instance.z_index = 1
	
	# 将卡牌添加到Cards分组的根节点
	var cards_group = get_tree().get_first_node_in_group("Cards")
	if cards_group:
		cards_group.add_child(card_instance)
	card_instance.global_position = global_position
	card_instance.shooter.play_card_shooter(spawn_position)
	print("卡牌已生成于位置: %s, 卡牌名称: %s" % [spawn_position, spawn_card_info.name if spawn_card_info else "默认"])

## 根据卡牌资源类型创建对应的卡牌实例
func _create_card_instance() -> Node:
	var instance = spawn_card_info.card_scene.instantiate()
	instance.set_stats(spawn_card_info)
	return instance
