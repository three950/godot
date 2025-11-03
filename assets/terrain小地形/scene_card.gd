extends "res://card.gd"
class_name SceneCard

## 场景卡片
## 场景卡片：获取资源的途径，固定在地图上，只有人物能堆叠
## 
## 两种使用模式：
## 1. 静态场景模式：使用 produce_items 和 produce_probabilities 配置固定产物
##    适用于地图上预设的场景，产物在场景配置中定义
## 
## 2. 动态掉落模式：使用 setup_exploration_loot() 配置掉落表
##    适用于探索生成的场景，掉落内容由创建者（如深度指示器）动态传入
##    示例：
##      var scene = scene_card_scene.instantiate()
##      scene.setup_exploration_loot(loot_table, max_explorations, depth_indicator)
##
## 场景卡片特有属性:
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
var depth_indicator: Node = null  # 深度指示器引用（用于调用掉落函数）

# 缓存的实际产出间隔（考虑特殊效果后）
var cached_produce_interval: float = 5.0

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
	
	# 初始化缓存的产出间隔
	cached_produce_interval = produce_interval
	
	# 如果场景名称为空，尝试从Label读取
	if scene_name == "":
		var label = get_node_or_null("Control/ColorRect/Label")
		if label and label.text != "" and label.text != "场景":
			scene_name = label.text
	
	# 连接堆叠信号
	card_stacked_on.connect(_on_card_stacked)
	card_removed_from_stack.connect(_on_card_removed)
	
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
		
		# 更新进度条（使用缓存的间隔值）
		if progress_bar:
			progress_bar.visible = true
			progress_bar.max_value = cached_produce_interval
			progress_bar.value = time_since_last_produce
		
		# 计时到达时触发产出
		if time_since_last_produce >= cached_produce_interval:
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

# 当有卡片堆叠上来时触发
func _on_card_stacked(_stacked_card: Control) -> void:
	# 更新产出间隔缓存
	update_produce_interval()

# 当卡片从堆叠中移除时触发
func _on_card_removed(_removed_card: Control) -> void:
	# 更新产出间隔缓存
	update_produce_interval()

# 更新实际产出间隔（考虑角色的特殊效果）
func update_produce_interval() -> void:
	var interval = produce_interval
	
	# 检查堆叠的角色是否有 fast_fish 效果（仅对河流场景有效）
	if is_river_scene():
		for card in stacked_cards:
			if card is CharacterCard:
				if card.has_method("has_special_effect") and card.has_special_effect("fast_fish"):
					interval = interval / 2.0  # 速度翻倍（间隔减半）
					print("【场景卡片】角色 %s 拥有 fast_fish 效果，产出间隔减半: %.1f -> %.1f" % [card.name, produce_interval, interval])
					break  # 只需要一个角色有该效果即可
	
	cached_produce_interval = interval

# 检查是否是河流场景
func is_river_scene() -> bool:
	# 检查场景名称是否包含"河流"等关键字
	return "河流" in scene_name or "river" in scene_name.to_lower()

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

# 生成新卡片（使用通用卡片生成系统）
func spawn_item(item_name: String) -> void:
	if not card_manager:
		push_warning("CardManager未找到，无法生成卡片")
		return
	
	# 使用 CardManager 的射出卡片函数
	# shoot_card 会自动处理：创建卡片、查找落点、播放动画
	var spawned_card = await card_manager.shoot_card(item_name, position)
	if spawned_card:
		print("✓ 场景 %s 产出了 %s" % [scene_name, item_name])

# 设置产出配置
func set_produce_config(items: Array[String], probabilities: Array[float]) -> void:
	produce_items = items
	produce_probabilities = probabilities

# 配置探索掉落（用于深度指示器等动态场景）
func setup_exploration_loot(loot_table: Array, max_explorations_count: int, depth_ind: Node = null) -> void:
	"""
	配置场景的探索掉落系统
	参数:
		loot_table: 掉落表数组，格式参考 JSON 配置
		             [
		               {
						 "category": "遗物",
						 "chance": 70,
						 "items": [
						   {"name": "五级太阳石", "chance": 90},
						   {"name": "四级太阳石", "chance": 10}
		                 ]
		               },
		               ...
		             ]
		max_explorations_count: 最大探索次数（-1 表示无限）
		depth_ind: 深度指示器引用（用于调用掉落生成函数）
	"""
	custom_loot_table = loot_table
	max_explorations = max_explorations_count
	depth_indicator = depth_ind
	
	# 设置自定义掉落回调
	custom_loot_callback = func(card: Control):
		if depth_indicator and depth_indicator.has_method("roll_loot_table"):
			depth_indicator.roll_loot_table(card, custom_loot_table, scene_name)
		else:
			push_warning("深度指示器未设置或缺少 roll_loot_table 方法")
	
	print("✓ 场景 '%s' 配置掉落表，最大探索次数: %d" % [scene_name, max_explorations])

# 通用初始化方法 - 从配置字典创建场景
func setup_from_config(config: Dictionary) -> void:
	"""
	从配置字典初始化场景卡片（更灵活的配置方式）
	config 可包含:
		- scene_name: 场景名称
		- loot_table: 掉落表
		- max_explorations: 最大探索次数
		- depth_indicator: 深度指示器引用
		- produce_interval: 产出间隔
	"""
	if config.has("scene_name"):
		scene_name = config["scene_name"]
	
	if config.has("produce_interval"):
		produce_interval = config["produce_interval"]
	
	# 如果有掉落表配置，使用动态掉落模式
	if config.has("loot_table"):
		var loot_table = config["loot_table"]
		var max_exp = config.get("max_explorations", -1)
		var depth_ind = config.get("depth_indicator", null)
		setup_exploration_loot(loot_table, max_exp, depth_ind)

# 从场景数据初始化（用于从CSV数据创建）
func initialize_from_scene_data(data: Dictionary) -> void:
	if data.has("名称"):
		scene_name = data["名称"]
	
	# 解析产物字段
	if data.has("产物") and data["产物"] != "":
		parse_produce_data(data["产物"])

# init_from_data 方法（CardFactory 会调用）
func init_from_data(data: Dictionary) -> void:
	# 设置场景名称
	if data.has("名称"):
		scene_name = data["名称"]
	
	# 如果有产物数据，解析它
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
