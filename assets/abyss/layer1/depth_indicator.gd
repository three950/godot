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
	
	# 先判断是否生成场景
	try_spawn_scene(layer_data)
	
	# 再判断是否生成装备
	try_spawn_equipment(layer_data)

## 尝试生成场景
func try_spawn_scene(layer_data: Dictionary) -> void:
	if not layer_data.has("scenes"):
		return
	
	var scene_spawn_chance = layer_data.get("scene_spawn_chance", 100)
	
	# 检查场景生成概率
	if randf() * 100 > scene_spawn_chance:
		return
	
	var scenes = layer_data["scenes"]
	
	# 遍历所有场景类型
	for scene_name in scenes.keys():
		var scene_data = scenes[scene_name]
		var spawn_chance = scene_data.get("spawn_chance", 100)
		var max_count = scene_data.get("max_count", 1)
		
		# 检查已生成数量
		var current_count = 0
		if spawned_scenes.has(scene_name):
			current_count = spawned_scenes[scene_name]["cards"].size()
		
		# 如果已达到最大数量，跳过
		if current_count >= max_count:
			continue
		
		# 根据概率判断是否生成
		if randf() * 100 <= spawn_chance:
			spawn_exploration_scene(scene_name, scene_data)
			break  # 每次只生成一个场景

## 生成探索场景卡片
func spawn_exploration_scene(scene_name: String, scene_data: Dictionary) -> void:
	# 加载场景卡片场景
	var scene_card_scene = load("res://assets/terrain小地形/scene_card.tscn")
	if not scene_card_scene:
		push_error("无法加载场景卡片场景")
		return
	
	# 找到合适的生成位置
	var spawn_pos = find_random_empty_position()
	
	# 实例化场景卡片
	var card_instance = scene_card_scene.instantiate()
	card_instance.name = "ExplorationScene_" + scene_name
	card_instance.position = spawn_pos
	
	# 设置场景名称
	if "scene_name" in card_instance:
		card_instance.scene_name = scene_name
	
	# 设置标签
	var label = card_instance.get_node_or_null("Control/ColorRect/Label")
	if label:
		label.text = scene_name
	
	# 添加到场景树
	get_parent().add_child(card_instance)
	
	# 配置场景的掉落表和探索限制
	setup_scene_card(card_instance, scene_name, scene_data)
	
	# 记录场景
	if not spawned_scenes.has(scene_name):
		spawned_scenes[scene_name] = {
			"cards": [],
			"max_explorations": scene_data.get("max_explorations", -1)
		}
	spawned_scenes[scene_name]["cards"].append(card_instance)
	
	print("✓ 生成探索场景: %s" % scene_name)

## 配置场景卡片的掉落和探索限制
func setup_scene_card(scene_card: Control, scene_name: String, scene_data: Dictionary) -> void:
	if not scene_data.has("loot_table"):
		return
	
	var loot_table = scene_data["loot_table"]
	var max_explorations = scene_data.get("max_explorations", -1)
	
	# 记录探索次数
	if not spawned_scenes[scene_name].has("explorations"):
		spawned_scenes[scene_name]["explorations"] = {}
	spawned_scenes[scene_name]["explorations"][scene_card] = 0
	
	# 覆盖场景卡片的 find 方法
	scene_card.find = func():
		# 检查探索次数限制
		if max_explorations > 0:
			var current_explorations = spawned_scenes[scene_name]["explorations"][scene_card]
			if current_explorations >= max_explorations:
				print("场景 %s 已达到最大探索次数 %d" % [scene_name, max_explorations])
				return
			
			# 增加探索次数
			spawned_scenes[scene_name]["explorations"][scene_card] = current_explorations + 1
			print("场景 %s 探索: %d/%d" % [scene_name, current_explorations + 1, max_explorations])
		
		# 触发抖动动画
		if scene_card.has_method("trigger_character_shake"):
			scene_card.trigger_character_shake()
		
		await scene_card.get_tree().create_timer(0.5).timeout
		
		# 根据掉落表生成物品
		roll_loot_table(scene_card, loot_table, scene_name)

## 根据掉落表掉落物品
func roll_loot_table(scene_card: Control, loot_table: Array, scene_name: String) -> void:
	# 第一步：选择类别（category）
	var roll = randf() * 100.0
	var cumulative = 0.0
	var selected_category = null
	
	for category_data in loot_table:
		cumulative += category_data.get("chance", 0)
		if roll <= cumulative:
			selected_category = category_data
			break
	
	if not selected_category:
		print("未掉落任何物品")
		return
	
	# 第二步：在选中的类别中选择物品
	var items = selected_category.get("items", [])
	if items.is_empty():
		return
	
	roll = randf() * 100.0
	cumulative = 0.0
	var selected_item = null
	
	for item_data in items:
		cumulative += item_data.get("chance", 0)
		if roll <= cumulative:
			selected_item = item_data
			break
	
	if not selected_item:
		return
	
	var item_name = selected_item.get("name", "")
	var is_unique = selected_item.get("unique", false)
	
	# 检查唯一物品是否已经掉落过
	if is_unique and item_name in dropped_unique_items:
		print("唯一物品 %s 已经掉落过，本次不掉落" % item_name)
		return
	
	# 生成物品
	var category = selected_category.get("category", "")
	spawn_loot_card(item_name, category, scene_card.position)
	
	# 记录唯一物品
	if is_unique:
		dropped_unique_items.append(item_name)
	
	print("场景 %s 掉落: %s (%s)" % [scene_name, item_name, category])

## 尝试生成装备
func try_spawn_equipment(layer_data: Dictionary) -> void:
	if not layer_data.has("equipment_spawn"):
		return
	
	var equipment_spawn = layer_data["equipment_spawn"]
	var spawn_chance = equipment_spawn.get("chance", 100)
	
	# 检查是否生成装备
	if randf() * 100 > spawn_chance:
		return
	
	var items = equipment_spawn.get("items", [])
	if items.is_empty():
		return
	
	# 根据概率选择装备
	var roll = randf() * 100.0
	var cumulative = 0.0
	
	for item_data in items:
		cumulative += item_data.get("chance", 0)
		if roll <= cumulative:
			var item_name = item_data.get("name", "")
			var spawn_pos = find_random_empty_position()
			spawn_equipment_card(item_name, spawn_pos)
			print("✓ 生成装备: %s" % item_name)
			break

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

