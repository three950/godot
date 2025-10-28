extends "res://card.gd"
class_name SceneCard

# 场景卡片特有属性
# 场景卡片：获取资源的途径，固定在地图上，只有人物能堆叠，堆叠后每过五秒会根据概率出现一个产物
@export var produce_interval: float = 5.0  # 产出间隔（秒）
@export var produce_items: Array[String] = []  # 可生成的卡片类型数组
@export var produce_probabilities: Array[float] = []  # 对应的生成概率数组
@export var scene_name: String = ""  # 场景名称

var time_since_last_produce: float = 0.0
var can_produce: bool = false  # 是否可以产出（需要有人物堆叠）
var progress_bar: ProgressBar = null  # 进度条引用
var card_manager: Node2D = null  # CardManager引用

# 自定义掉落表配置（用于深渊探索等）
var custom_loot_table: Array = []  # 掉落表配置
var custom_loot_callback: Callable  # 自定义掉落回调函数
var max_explorations: int = -1  # 最大探索次数（-1表示无限）
var current_explorations: int = 0  # 当前探索次数

func _ready() -> void:
	super._ready()
	# 场景卡片类型设置为 architecture（固定在地图上）
	card_type = cardType.architecture
	# 获取进度条引用
	progress_bar = get_node_or_null("Control/ProgressBar")
	if progress_bar:
		progress_bar.visible = false
		progress_bar.value = 0.0
	time_since_last_produce = 0.0
	
	# 等待CardManager加载
	await get_tree().process_frame
	# 获取CardManager引用
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		card_manager = main.get_node_or_null("CardManager")

func _process(delta: float) -> void:
	super._process(delta)
	
	# 检查是否有人物卡片堆叠
	check_character_stacked()
	
	# 如果有人物堆叠，进行产出计时
	if can_produce and cardCurrentState == cardState.fixed:
		time_since_last_produce += delta
		
		# 更新进度条
		if progress_bar:
			progress_bar.visible = true
			progress_bar.value = time_since_last_produce
		
		# 计时到达时触发产出
		if time_since_last_produce >= produce_interval:
			find()  # 触发产出
			time_since_last_produce = 0.0
			if progress_bar:
				progress_bar.value = 0.0
	else:
		# 没有人物堆叠时隐藏进度条
		if progress_bar:
			progress_bar.visible = false
		time_since_last_produce = 0.0

# 检查是否有人物卡片堆叠在上面
func check_character_stacked() -> void:
	can_produce = false
	for card in stacked_cards:
		if card is CharacterCard:
			can_produce = true
			break

# find() 函数：根据概率生成新卡片
func find() -> void:
	# 检查探索次数限制
	if max_explorations > 0:
		if current_explorations >= max_explorations:
			print("场景 %s 已达到最大探索次数 %d" % [scene_name, max_explorations])
			return
		current_explorations += 1
		print("场景 %s 探索: %d/%d" % [scene_name, current_explorations, max_explorations])
	
	# 先触发人物抖动动画
	trigger_character_shake()
	
	# 等待动画完成后再生成卡片
	await get_tree().create_timer(0.5).timeout
	
	# 如果有自定义掉落回调，优先使用
	if custom_loot_callback.is_valid():
		custom_loot_callback.call(self)
		return
	
	# 否则使用默认的产物系统
	if produce_items.is_empty() or produce_probabilities.is_empty():
		return
	
	if produce_items.size() != produce_probabilities.size():
		print("错误：产物数组和概率数组长度不匹配")
		return
	
	# 根据概率随机选择一个产物
	var random_value = randf() * 100.0  # 转换为百分比
	var cumulative_prob = 0.0
	
	for i in range(produce_probabilities.size()):
		cumulative_prob += produce_probabilities[i]
		if random_value <= cumulative_prob:
			spawn_item(produce_items[i])
			print("场景 %s 产出了 %s" % [scene_name, produce_items[i]])
			break

# 触发堆叠在上面的人物卡片抖动动画
func trigger_character_shake() -> void:
	for card in stacked_cards:
		if card is CharacterCard:
			shake_card(card)

# 抖动动画
func shake_card(card: Control) -> void:
	var original_pos = card.position
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# 左右抖动
	tween.tween_property(card, "position", original_pos + Vector2(5, 0), 0.05)
	tween.tween_property(card, "position", original_pos + Vector2(-5, 0), 0.05)
	tween.tween_property(card, "position", original_pos + Vector2(5, 0), 0.05)
	tween.tween_property(card, "position", original_pos + Vector2(-5, 0), 0.05)
	tween.tween_property(card, "position", original_pos, 0.05)

# 生成新卡片（需要配合 CardManager 使用）
func spawn_item(item_name: String) -> void:
	if not card_manager:
		push_warning("CardManager未找到，无法生成卡片")
		return
	
	# 查找随机的空闲位置
	var spawn_position = find_random_empty_position()
	if spawn_position == Vector2.ZERO:
		push_warning("未找到合适的生成位置")
		return
	
	# 调用CardManager生成遗物卡片
	if card_manager.has_method("create_remains_card_with_animation"):
		card_manager.create_remains_card_with_animation(item_name, position, spawn_position)
	else:
		push_warning("CardManager 没有 create_remains_card_with_animation 方法")

# 查找场景周围随机的空闲位置
func find_random_empty_position() -> Vector2:
	var max_attempts = 20
	var min_distance = 100.0  # 最小距离
	var max_distance = 200.0  # 最大距离
	
	for i in range(max_attempts):
		# 随机角度和距离
		var angle = randf() * TAU  # 0 到 2π
		var distance = randf_range(min_distance, max_distance)
		
		var test_position = position + Vector2(cos(angle), sin(angle)) * distance
		
		# 检查该位置是否有其他卡片
		if is_position_empty(test_position):
			return test_position
	
	# 如果没有找到合适位置，返回默认位置
	return position + Vector2(0, 150)

# 检查位置是否为空（没有卡片）
func is_position_empty(test_pos: Vector2) -> bool:
	var cards = get_tree().get_nodes_in_group("Cards")
	var safe_distance = 90.0  # 安全距离
	
	for card in cards:
		if card == self:
			continue
		var distance = card.position.distance_to(test_pos)
		if distance < safe_distance:
			return false
	
	return true

# 设置产出配置
func set_produce_config(items: Array[String], probabilities: Array[float]) -> void:
	produce_items = items
	produce_probabilities = probabilities

# 从场景数据初始化
func initialize_from_scene_data(data: Dictionary) -> void:
	if data.has("名称"):
		scene_name = data["名称"]
	
	# 解析产物字段
	if data.has("产物") and data["产物"] != "":
		parse_produce_data(data["产物"])

# 解析产物数据（格式：["五级太阳石":"80","四级太阳石":"20"]）
func parse_produce_data(produce_str: String) -> void:
	# 移除外层括号和引号
	var cleaned = produce_str.strip_edges()
	if cleaned.begins_with("["):
		cleaned = cleaned.substr(1, cleaned.length() - 2)
	
	# 分割各个产物项
	var items_array: Array[String] = []
	var probs_array: Array[float] = []
	
	# 使用正则表达式或简单字符串处理
	var pairs = cleaned.split(",")
	for pair in pairs:
		# 格式: "五级太阳石":"80"
		var parts = pair.split(":")
		if parts.size() >= 2:
			var item_name = parts[0].strip_edges().replace("\"", "")
			var prob_str = parts[1].strip_edges().replace("\"", "")
			if prob_str.is_valid_float():
				items_array.append(item_name)
				probs_array.append(float(prob_str))
	
	produce_items = items_array
	produce_probabilities = probs_array
	
	print("场景 %s 配置产物: %s" % [scene_name, str(produce_items)])
	print("概率: %s" % str(produce_probabilities))
