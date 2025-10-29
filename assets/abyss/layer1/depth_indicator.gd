extends "res://card.gd"

## 深度指示器卡片
## 只能被人物卡堆叠，堆叠后每2秒根据JSON配置的概率生成场景或装备卡片

# JSON 配置文件路径
@export var config_path: String = "res://assets/abyss/layer1/500m.json"
# 探索间隔（秒）
@export var exploration_interval: float = 2.0

# 配置数据
var layer_config: Dictionary = {}
var layer_name: String = "500m"

# 计时器
var time_since_last_exploration: float = 0.0
var can_explore: bool = false  # 是否可以探索（需要有人物堆叠）

# 进度条引用
var progress_bar: ProgressBar = null

# 已生成的场景跟踪（用于限制场景数量和探索次数）
var spawned_scenes: Dictionary = {}  # key: 场景名, value: {cards: Array, explorations: Dictionary}

# 唯一物品跟踪
var dropped_unique_items: Array[String] = []

# CardManager 引用
var card_manager: Node2D = null

func _ready() -> void:
	super._ready()
	
	# 设置为建筑类型（固定在地图上，不能拖拽）
	card_type = cardType.architecture
	
	# 加载进度条
	setup_progress_bar()
	
	# 加载 JSON 配置
	load_config()

func _process(delta: float) -> void:
	super._process(delta)
	
	# 检查是否有人物卡片堆叠
	check_character_stacked()
	
	# 如果有人物堆叠且卡片固定，进行探索计时
	if can_explore and cardCurrentState == cardState.fixed:
		time_since_last_exploration += delta
		
		# 更新进度条
		if progress_bar:
			progress_bar.visible = true
			progress_bar.value = (time_since_last_exploration / exploration_interval) * 100.0
		
		# 计时到达时触发探索
		if time_since_last_exploration >= exploration_interval:
			explore()
			time_since_last_exploration = 0.0
			if progress_bar:
				progress_bar.value = 0.0
	else:
		# 没有人物堆叠时隐藏进度条并重置计时
		if progress_bar:
			progress_bar.visible = false
		time_since_last_exploration = 0.0

## 设置进度条
func setup_progress_bar() -> void:
	# 查找已有的进度条
	progress_bar = get_node_or_null("Control/ProgressBar")
	
	# 如果没有，创建一个
	if not progress_bar:
		progress_bar = ProgressBar.new()
		progress_bar.name = "ProgressBar"
		progress_bar.size = Vector2(82, 10)
		progress_bar.position = Vector2(0, 102)
		progress_bar.max_value = 100.0
		progress_bar.value = 0.0
		progress_bar.show_percentage = false
		
		var control = get_node_or_null("Control/ColorRect")
		if control:
			control.add_child(progress_bar)
	
	if progress_bar:
		progress_bar.visible = false

## 检查是否有人物卡片堆叠在上面
func check_character_stacked() -> void:
	can_explore = false
	for card in stacked_cards:
		# 检查是否是人物卡片
		if card.get_script() and card.get_script().get_global_name() == "CharacterCard":
			can_explore = true
			break
		# 也可以通过类名检查
		if card is CharacterCard:
			can_explore = true
			break

## 加载 JSON 配置文件
func load_config() -> void:
	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		push_error("无法打开JSON配置文件: " + config_path)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("JSON解析失败: " + json.get_error_message())
		return
	
	layer_config = json.data
	print("✓ 深度指示器加载配置: " + config_path)

## 探索函数 - 每2秒触发一次
func explore() -> void:
	print("========== 开始探索 %s ==========" % layer_name)
	
	if layer_config.is_empty():
		push_warning("配置为空，无法探索")
		return
	
	if not layer_config.has("exploration_layers"):
		push_warning("配置缺少 exploration_layers")
		return
	
	var layers = layer_config["exploration_layers"]
	if not layers.has(layer_name):
		push_warning("未找到层级配置: " + layer_name)
		return
	
	var layer_data = layers[layer_name]
	
	# 触发人物抖动动画
	trigger_character_shake()
	
	# 等待动画
	await get_tree().create_timer(0.3).timeout
	
	# 第一步：决定生成场景还是装备
	if not layer_data.has("generation_types"):
		push_warning("配置缺少 generation_types")
		print("========== 探索结束 ==========\n")
		return
	
	var generation_types = layer_data["generation_types"]
	var roll = randf() * 100.0
	var cumulative = 0.0
	var selected_type = ""
	
	print("  [类型判定] 第一步：决定生成类型，骰子: %.2f" % roll)
	
	for type_name in generation_types.keys():
		var type_chance = generation_types[type_name]
		cumulative += type_chance
		print("  [类型判定] 检查类型 '%s' (概率 %d%%, 累计 %.2f)" % [type_name, type_chance, cumulative])
		
		if roll <= cumulative:
			selected_type = type_name
			print("  [类型判定] ✓ 选中类型: %s" % type_name)
			break
	
	# 根据选中的类型生成对应内容
	var spawned = false
	if selected_type == "场景":
		spawned = try_spawn_scene(layer_data)
		# 如果场景都满了，自动切换到生成装备
		if not spawned:
			print("  [场景判定] 所有场景已满，切换到生成装备")
			spawned = try_spawn_equipment(layer_data)
	elif selected_type == "装备":
		spawned = try_spawn_equipment(layer_data)
	else:
		print("  [类型判定] 未选中任何类型")
	
	if not spawned:
		print("本次探索未能生成物品")
	
	print("========== 探索结束 ==========\n")

## 尝试生成场景
func try_spawn_scene(layer_data: Dictionary) -> bool:
	print("  [场景判定] 第二步：选择具体场景...")
	
	if not layer_data.has("scenes"):
		print("  [场景判定] 配置中没有场景数据")
		return false
	
	var scenes = layer_data["scenes"]
	
	# 收集可生成的场景（未达到最大数量）
	var available_scenes = []
	for scene_name in scenes.keys():
		var scene_data = scenes[scene_name]
		var max_count = scene_data.get("max_count", 1)
		
		# 检查已生成数量
		var current_count = 0
		if spawned_scenes.has(scene_name):
			current_count = spawned_scenes[scene_name]["cards"].size()
		
		if current_count >= max_count:
			print("  [场景判定] '%s' 已达到最大数量 %d/%d，跳过" % [scene_name, current_count, max_count])
			continue
		
		available_scenes.append({"name": scene_name, "data": scene_data, "chance": scene_data.get("spawn_chance", 100)})
	
	if available_scenes.is_empty():
		print("  [场景判定] 所有场景都已达到最大数量")
		return false
	
	# 计算可用场景的总概率（用于归一化）
	var total_chance = 0.0
	for scene_info in available_scenes:
		total_chance += scene_info["chance"]
	
	print("  [场景判定] 可用场景总概率: %.2f" % total_chance)
	
	# 根据概率选择场景
	var roll = randf() * total_chance  # 注意这里使用 total_chance 而不是 100
	var cumulative = 0.0
	print("  [场景判定] 场景选择骰子: %.2f (范围: 0-%.2f)" % [roll, total_chance])
	
	for scene_info in available_scenes:
		var scene_chance = scene_info["chance"]
		cumulative += scene_chance
		print("  [场景判定] 检查场景 '%s' (概率 %d%%, 累计 %.2f)" % [scene_info["name"], scene_chance, cumulative])
		
		if roll <= cumulative:
			print("  [场景判定] ✓ 选中场景: %s" % scene_info["name"])
			spawn_exploration_scene(scene_info["name"], scene_info["data"])
			return true
	
	# 如果由于浮点误差没有选中，选择最后一个可用场景
	print("  [场景判定] 由于浮点误差，强制选择最后一个可用场景")
	var last_scene = available_scenes[-1]
	spawn_exploration_scene(last_scene["name"], last_scene["data"])
	return true

## 生成探索场景卡片
func spawn_exploration_scene(scene_name: String, scene_data: Dictionary) -> void:
	# 从 GameData 获取场景数据
	var card_data = GameData.get_scene(scene_name)
	if card_data.is_empty():
		push_error("未找到场景数据: " + scene_name)
		return
	
	# 找到合适的生成位置
	var spawn_pos = find_random_empty_position()
	
	# 使用 CardFactory 创建场景卡片（architecture 类型）
	var card_instance = CardFactory.create_by_card_scene(
		card_data,
		get_parent(),
		spawn_pos,
		0  # cardType.architecture
	)
	
	if not card_instance:
		push_error("CardFactory 创建场景卡片失败: " + scene_name)
		return
	
	# 记录场景
	if not spawned_scenes.has(scene_name):
		spawned_scenes[scene_name] = {
			"cards": [],
			"max_explorations": scene_data.get("max_explorations", -1)
		}
	spawned_scenes[scene_name]["cards"].append(card_instance)
	
	# 配置场景的掉落表和探索限制（使用场景卡片的配置方法）
	if card_instance.has_method("setup_exploration_loot") and scene_data.has("loot_table"):
		card_instance.setup_exploration_loot(
			scene_data["loot_table"],
			scene_data.get("max_explorations", -1),
			self  # 传入深度指示器自身的引用
		)
	
	print("✓ 生成探索场景: %s (位置: %s)" % [scene_name, spawn_pos])

## 根据掉落表掉落物品
func roll_loot_table(scene_card: Control, loot_table: Array, scene_name: String) -> void:
	print("    [掉落判定] 场景 '%s' 开始掉落判定" % scene_name)
	
	# 第一步：选择类别（category）
	# 计算类别总概率
	var total_category_chance = 0.0
	for category_data in loot_table:
		total_category_chance += category_data.get("chance", 0)
	
	var roll = randf() * total_category_chance
	var cumulative = 0.0
	var selected_category = null
	
	print("    [掉落判定] 类别选择骰子: %.2f (范围: 0-%.2f)" % [roll, total_category_chance])
	
	for category_data in loot_table:
		var category_name = category_data.get("category", "")
		var category_chance = category_data.get("chance", 0)
		cumulative += category_chance
		print("    [掉落判定] 检查类别 '%s' (概率 %d%%, 累计 %.2f)" % [category_name, category_chance, cumulative])
		
		if roll <= cumulative:
			selected_category = category_data
			print("    [掉落判定] ✓ 选中类别: %s" % category_name)
			break
	
	# 保底：如果没有选中（浮点误差），选择最后一个类别
	if not selected_category and not loot_table.is_empty():
		selected_category = loot_table[-1]
		print("    [掉落判定] 由于浮点误差，强制选中类别: %s" % selected_category.get("category", ""))
	
	if not selected_category:
		print("    [掉落判定] 未选中任何类别，不掉落物品")
		return
	
	# 第二步：在选中的类别中选择物品
	var items = selected_category.get("items", [])
	if items.is_empty():
		print("    [掉落判定] 类别 '%s' 中没有物品" % selected_category.get("category", ""))
		return
	
	# 计算物品总概率
	var total_item_chance = 0.0
	for item_data in items:
		total_item_chance += item_data.get("chance", 0)
	
	roll = randf() * total_item_chance
	cumulative = 0.0
	var selected_item = null
	
	print("    [掉落判定] 物品选择骰子: %.2f (范围: 0-%.2f)" % [roll, total_item_chance])
	
	for item_data in items:
		var check_item_name = item_data.get("name", "")
		var item_chance = item_data.get("chance", 0)
		cumulative += item_chance
		print("    [掉落判定] 检查物品 '%s' (概率 %d%%, 累计 %.2f)" % [check_item_name, item_chance, cumulative])
		
		if roll <= cumulative:
			selected_item = item_data
			print("    [掉落判定] ✓ 选中物品: %s" % check_item_name)
			break
	
	# 保底：如果没有选中（浮点误差），选择最后一个物品
	if not selected_item and not items.is_empty():
		selected_item = items[-1]
		print("    [掉落判定] 由于浮点误差，强制选中物品: %s" % selected_item.get("name", ""))
	
	if not selected_item:
		print("    [掉落判定] 未选中任何物品")
		return
	
	var item_name = selected_item.get("name", "")
	var is_unique = selected_item.get("unique", false)
	
	# 检查唯一物品是否已经掉落过
	if is_unique:
		if item_name in dropped_unique_items:
			print("    [掉落判定] 唯一物品 '%s' 已经掉落过，本次不掉落" % item_name)
			return
		else:
			print("    [掉落判定] '%s' 是唯一物品，首次掉落" % item_name)
	
	# 生成物品
	var category = selected_category.get("category", "")
	spawn_loot_card(item_name, category, scene_card.position)
	
	# 记录唯一物品
	if is_unique:
		dropped_unique_items.append(item_name)
	
	print("    [掉落判定] ✓✓✓ 场景 '%s' 掉落: %s (%s)" % [scene_name, item_name, category])

## 尝试生成装备
func try_spawn_equipment(layer_data: Dictionary) -> bool:
	print("  [装备判定] 第二步：选择具体装备...")
	
	if not layer_data.has("equipment_spawn"):
		print("  [装备判定] 配置中没有装备数据")
		return false
	
	var equipment_spawn = layer_data["equipment_spawn"]
	var items = equipment_spawn.get("items", [])
	
	if items.is_empty():
		print("  [装备判定] 装备列表为空")
		return false
	
	# 计算总概率
	var total_chance = 0.0
	for item_data in items:
		total_chance += item_data.get("chance", 0)
	
	print("  [装备判定] 装备总概率: %.2f" % total_chance)
	
	# 根据概率选择装备
	var roll = randf() * total_chance
	var cumulative = 0.0
	print("  [装备判定] 装备选择骰子: %.2f (范围: 0-%.2f)" % [roll, total_chance])
	
	for item_data in items:
		var item_chance = item_data.get("chance", 0)
		cumulative += item_chance
		print("  [装备判定] 检查 '%s' (概率 %d%%, 累计 %.2f)" % [item_data.get("name", ""), item_chance, cumulative])
		
		if roll <= cumulative:
			var item_name = item_data.get("name", "")
			var spawn_pos = find_random_empty_position()
			spawn_equipment_card(item_name, spawn_pos)
			print("  [装备判定] ✓ 生成装备: %s" % item_name)
			return true
	
	# 如果由于浮点误差没有选中，选择最后一个装备
	print("  [装备判定] 由于浮点误差，强制选择最后一个装备")
	var last_item = items[-1]
	var item_name = last_item.get("name", "")
	var spawn_pos = find_random_empty_position()
	spawn_equipment_card(item_name, spawn_pos)
	print("  [装备判定] ✓ 生成装备: %s" % item_name)
	return true

## 生成掉落的卡片
func spawn_loot_card(item_name: String, category: String, scene_pos: Vector2) -> void:
	var spawn_pos = find_random_position_near(scene_pos)
	
	match category:
		"遗物":
			spawn_remains_card(item_name, scene_pos, spawn_pos)
		"资源":
			spawn_resource_card(item_name, scene_pos, spawn_pos)
		"装备":
			spawn_equipment_card(item_name, spawn_pos)
		_:
			push_warning("未知的物品类别: " + category)

## 生成遗物卡片
func spawn_remains_card(remains_name: String, start_pos: Vector2, end_pos: Vector2) -> void:
	var remains_data = GameData.get_remains(remains_name)
	if remains_data.is_empty():
		push_error("未找到遗物数据: " + remains_name)
		return
	
	var remains_card_scene = load("res://assets/remains/remains_card.tscn")
	if not remains_card_scene:
		push_error("无法加载遗物卡片场景")
		return
	
	var card_instance = remains_card_scene.instantiate()
	card_instance.name = "Remains_" + remains_name
	card_instance.position = start_pos
	card_instance.scale = Vector2.ZERO
	
	get_parent().add_child(card_instance)
	
	# 初始化数据
	if card_instance.has_method("initialize_from_csv"):
		card_instance.initialize_from_csv(remains_data)
	
	# 播放动画
	play_spawn_animation(card_instance, end_pos)

## 生成资源卡片
func spawn_resource_card(resource_name: String, start_pos: Vector2, end_pos: Vector2) -> void:
	var resource_data = GameData.get_resource(resource_name)
	if resource_data.is_empty():
		push_error("未找到资源数据: " + resource_name)
		return
	
	var resource_card_scene = load("res://assets/resources/resource_card.tscn")
	if not resource_card_scene:
		push_error("无法加载资源卡片场景")
		return
	
	var card_instance = resource_card_scene.instantiate()
	card_instance.name = "Resource_" + resource_name
	card_instance.position = start_pos
	card_instance.scale = Vector2.ZERO
	
	get_parent().add_child(card_instance)
	
	# 初始化数据
	if card_instance.has_method("init_from_data"):
		card_instance.init_from_data(resource_data)
	
	# 播放动画
	play_spawn_animation(card_instance, end_pos)

## 生成装备卡片
func spawn_equipment_card(equipment_name: String, spawn_pos: Vector2) -> void:
	var equipment_data = GameData.get_equipment(equipment_name)
	if equipment_data.is_empty():
		push_error("未找到装备数据: " + equipment_name)
		return
	
	var equipment_card_scene = load("res://assets/equipment/equipment_card.tscn")
	if not equipment_card_scene:
		push_error("无法加载装备卡片场景")
		return
	
	var card_instance = equipment_card_scene.instantiate()
	card_instance.name = "Equipment_" + equipment_name
	card_instance.position = position  # 从深度指示器位置开始
	card_instance.scale = Vector2.ZERO
	
	get_parent().add_child(card_instance)
	
	# 初始化数据
	if card_instance.has_method("init_from_data"):
		card_instance.init_from_data(equipment_data)
	
	# 播放动画
	play_spawn_animation(card_instance, spawn_pos)

## 播放生成动画
func play_spawn_animation(card: Control, end_pos: Vector2) -> void:
	# 缩放动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "scale", Vector2.ONE * 0.5, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	# 射出动画
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.set_trans(Tween.TRANS_CUBIC)
	tween2.set_ease(Tween.EASE_OUT)
	tween2.tween_property(card, "position", end_pos, 0.5)
	tween2.tween_property(card, "scale", Vector2.ONE, 0.5)
	
	await tween2.finished
	
	# 反弹效果
	var tween3 = create_tween()
	tween3.tween_property(card, "scale", Vector2.ONE * 1.1, 0.1)
	tween3.tween_property(card, "scale", Vector2.ONE, 0.1)

## 触发堆叠在上面的人物卡片抖动动画
func trigger_character_shake() -> void:
	for card in stacked_cards:
		if card is CharacterCard:
			shake_card(card)

## 抖动动画
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

## 查找随机的空闲位置
func find_random_empty_position() -> Vector2:
	var max_attempts = 20
	var min_distance = 100.0
	var max_distance = 250.0
	
	for i in range(max_attempts):
		var angle = randf() * TAU
		var distance = randf_range(min_distance, max_distance)
		var test_position = position + Vector2(cos(angle), sin(angle)) * distance
		
		if is_position_empty(test_position):
			return test_position
	
	# 如果没找到，返回默认位置
	return position + Vector2(0, 150)

## 在指定位置附近查找随机位置
func find_random_position_near(center_pos: Vector2, min_dist: float = 80.0, max_dist: float = 150.0) -> Vector2:
	var angle = randf() * TAU
	var distance = randf_range(min_dist, max_dist)
	return center_pos + Vector2(cos(angle), sin(angle)) * distance

## 检查位置是否为空
func is_position_empty(test_pos: Vector2) -> bool:
	var cards = get_tree().get_nodes_in_group("Cards")
	var safe_distance = 90.0
	
	for card in cards:
		if card == self:
			continue
		var distance = card.position.distance_to(test_pos)
		if distance < safe_distance:
			return false
	
	return true
