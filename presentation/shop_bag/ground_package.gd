extends Button
class_name CardPackage
signal package_bought(CardPackage)
@export var game_stats:GameStats
@export_multiline var package_name: String = ""  # 可导出的名称变量
@export var mean_layer:int
@export var package_price: int = 3  # 可导出的价格变量
## 卡牌生成延迟时间（秒）
@export var spawn_delay: float = 2.0
## 卡牌生成位置偏移（相对于当前位置向下）
@export var spawn_offset: Vector2 = Vector2(0, 360)
@export var spawn_card_info: BagResource
@onready var packagename: Label = %packagename
@onready var value: Label = %value
@onready var panel_3: Panel = $Panel3
@export var coin_sound:AudioStream

var _spawn_timers: Array[Timer] = []


func _ready() -> void:
	_update_display()
	Events.max_layer_changed.connect(_update_state)
	if not Events.timers_pause_changed.is_connected(_on_timers_pause_changed):
		Events.timers_pause_changed.connect(_on_timers_pause_changed)
	_update_state()


func _update_display() -> void:
	# 更新名称和价格显示
	packagename.text = package_name
	value.text = str(package_price)

func _on_pressed() -> void:
	# 购买现在只由 3D 金币卡落到 GroundPackage 上触发，按钮点击只保留视觉按钮状态。
	pass


func try_accept_card_drop(dropped_card: Node, remaining_position: Variant = null) -> bool:
	var coin_stack := dropped_card as CoinCard3D
	if coin_stack == null:
		return false
	return _buy_package_with_coin_stack(coin_stack, remaining_position)


func _buy_package_with_coin_stack(coin_stack: CoinCard3D, remaining_position: Variant) -> bool:
	if disabled or game_stats == null or spawn_card_info == null:
		return false
	if not coin_stack.can_pay_coin_count(package_price):
		return false
	package_bought.emit(self)
	coin_stack.spend_from_coin_stack(package_price, remaining_position)
	# 延迟生成卡牌
	_spawn_card_delayed()
	if coin_sound:
		SFXPlayer.play(coin_sound)
	return true

## 延迟生成卡牌
func _spawn_card_delayed() -> void:
	# 用场景内 Timer 代替 SceneTreeTimer，确保全局暂停时商店发包延迟也会停住。
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = spawn_delay
	timer.paused = Events.timers_paused
	add_child(timer)
	_spawn_timers.append(timer)
	timer.timeout.connect(_on_spawn_timer_timeout.bind(timer))
	timer.start()


func _on_spawn_timer_timeout(timer: Timer) -> void:
	_spawn_timers.erase(timer)
	timer.queue_free()
	_spawn_card()


func _on_timers_pause_changed(is_paused: bool) -> void:
	for timer in _spawn_timers.duplicate():
		if timer == null or not is_instance_valid(timer):
			_spawn_timers.erase(timer)
			continue
		timer.paused = is_paused

## 生成卡牌
func _spawn_card() -> void:
	# 根据卡牌资源类型选择正确的场景并实例化
	var card_instance = _create_card_instance()
	
	# 计算生成位置（当前位置的下方）
	var spawn_position = global_position+spawn_offset*1.1
	card_instance.global_position = spawn_position
	card_instance.z_index = 1
	
	# 将卡牌添加到Cards分组的根节点
	var cards_group = get_tree().get_first_node_in_group("Cards")
	if cards_group:
		cards_group.add_child(card_instance)
	print("卡牌已生成")

## 根据卡牌资源类型创建对应的卡牌实例
func _create_card_instance() -> Node:
	var instance = spawn_card_info.card_scene.instantiate()
	instance.bagresource = spawn_card_info
	instance.set_layer(mean_layer)
	return instance

	
func _update_state() -> void:
	if game_stats.max_layer <= mean_layer:
		panel_3.show()
		set_disabled(true)  # 禁用按钮交互
	else:
		panel_3.hide()  # 隐藏面板
		set_disabled(false)  # 启用按钮交互
