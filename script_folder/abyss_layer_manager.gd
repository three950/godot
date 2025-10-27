extends Node2D

## 深渊层管理器
## 负责根据 JSON 配置文件生成探索层的场景和装备

# JSON 配置数据
var layer_config: Dictionary = {}

# 场景卡片场景引用
@export var scene_card_scene: PackedScene
# 装备卡片场景引用
@export var equipment_card_scene: PackedScene
# 资源卡片场景引用
@export var resource_card_scene: PackedScene
# 遗物卡片场景引用
@export var remains_card_scene: PackedScene

# 生成位置配置
@export var spawn_center: Vector2 = Vector2(600, 400)
@export var spawn_radius: float = 300.0

# 已生成的场景卡片（用于跟踪探索次数和唯一物品）
var spawned_scenes: Dictionary = {}  # key: 场景名称, value: {cards: Array, explorations: Dictionary}

func _ready() -> void:
	await get_tree().process_frame
	
	# 确保 GameData 已加载
	if not GameData.is_data_loaded:
		await get_tree().create_timer(0.1).timeout

## 加载层级配置
func load_layer_config(json_path: String) -> bool:
	var file = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("无法打开JSON文件: " + json_path)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("JSON解析失败: " + json.get_error_message())
		return false
	
	layer_config = json.data
	print("成功加载层级配置: " + json_path)
	return true

## 生成指定层级的探索内容
func generate_exploration_layer(layer_name: String) -> void:
	if not layer_config.has("exploration_layers"):
		push_error("配置文件缺少 exploration_layers 字段")
		return
	
	var layers = layer_config["exploration_layers"]
	if not layers.has(layer_name):
		push_error("未找到层级配置: " + layer_name)
		return
	
	var layer_data = layers[layer_name]
	
	# 初始化场景跟踪
	spawned_scenes.clear()
	
	# 生成场景
	generate_scenes(layer_data)
	
	# 生成装备
	generate_equipment(layer_data)

## 生成场景卡片
func generate_scenes(layer_data: Dictionary) -> void:
	if not layer_data.has("scenes"):
		return
	
	var scene_spawn_chance = layer_data.get("scene_spawn_chance", 100)
	
	# 检查是否生成场景
	if randf() * 100 > scene_spawn_chance:
		print("本次未触发场景生成")
		return
	
	var scenes = layer_data["scenes"]
	
	for scene_name in scenes.keys():
		var scene_data = scenes[scene_name]
		var spawn_chance = scene_data.get("spawn_chance", 100)
		var max_count = scene_data.get("max_count", 1)
		
		# 根据概率和最大数量生成场景
		for i in range(max_count):
			if randf() * 100 <= spawn_chance:
				create_exploration_scene_card(scene_name, scene_data)

## 创建探索场景卡片
func create_exploration_scene_card(scene_name: String, scene_data: Dictionary) -> void:
	if not scene_card_scene:
		push_error("场景卡片场景未设置")
		return
	
	# 生成随机位置
	var spawn_pos = get_random_spawn_position()
	
	# 实例化场景卡片
	var card_instance = scene_card_scene.instantiate()
	card_instance.name = "ExplorationScene_" + scene_name
	card_instance.position = spawn_pos
	card_instance.card_type = 2  # architecture 类型
	
	# 添加到场景树
	add_child(card_instance)
	
	# 设置场景名称
	if card_instance.has("scene_name"):
		card_instance.scene_name = scene_name
	
	# 设置标签
	var label = card_instance.get_node_or_null("Control/ColorRect/Label")
	if label:
		label.text = scene_name
	
	# 配置产出物品
	setup_scene_loot_table(card_instance, scene_data)
	
	# 记录场景
	if not spawned_scenes.has(scene_name):
		spawned_scenes[scene_name] = {
			"cards": [],
			"explorations": {},
			"max_explorations": scene_data.get("max_explorations", -1)
		}
	
	spawned_scenes[scene_name]["cards"].append(card_instance)
	spawned_scenes[scene_name]["explorations"][card_instance] = 0
	
	# 如果有最大探索次数限制，连接信号
	var max_explorations = scene_data.get("max_explorations", -1)
	if max_explorations > 0:
		# 覆盖场景的 find 方法，添加探索次数检查
		setup_exploration_limit(card_instance, scene_name, max_explorations)
	
	print("✓ 生成探索场景: %s 在位置 %s" % [scene_name, spawn_pos])

## 配置场景的掉落表
func setup_scene_loot_table(scene_card: Control, scene_data: Dictionary) -> void:
	if not scene_data.has("loot_table"):
		return
	
	var loot_table = scene_data["loot_table"]
	
	# 覆盖场景卡片的 find 方法
	scene_card.find = func():
		# 触发抖动动画
		if scene_card.has_method("trigger_character_shake"):
			scene_card.trigger_character_shake()
		
		await scene_card.get_tree().create_timer(0.5).timeout
		
		# 根据掉落表生成物品
		roll_loot_table(scene_card, loot_table)

## 根据掉落表掉落物品
func roll_loot_table(scene_card: Control, loot_table: Array) -> void:
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
	if is_unique:
		var scene_name = scene_card.scene_name if "scene_name" in scene_card else ""
		if spawned_scenes.has(scene_name):
			var scene_info = spawned_scenes[scene_name]
			if scene_info.has("dropped_uniques") and item_name in scene_info["dropped_uniques"]:
				print("唯一物品 %s 已经掉落过，本次不掉落" % item_name)
				return
			
			# 记录唯一物品
			if not scene_info.has("dropped_uniques"):
				scene_info["dropped_uniques"] = []
			scene_info["dropped_uniques"].append(item_name)
	
	# 生成物品
	var category = selected_category.get("category", "")
	spawn_loot_card(item_name, category, scene_card.position)
	
	print("场景掉落: %s (%s)" % [item_name, category])

## 生成掉落的卡片
func spawn_loot_card(item_name: String, category: String, scene_pos: Vector2) -> void:
	var spawn_pos = find_random_position_near(scene_pos)
	
	match category:
		"遗物":
			create_remains_card_with_animation(item_name, scene_pos, spawn_pos)
		"资源":
			create_resource_card_with_animation(item_name, scene_pos, spawn_pos)
		"装备":
			create_equipment_card_with_animation(item_name, scene_pos, spawn_pos)
		_:
			push_warning("未知的物品类别: " + category)

## 设置探索次数限制
func setup_exploration_limit(scene_card: Control, scene_name: String, max_explorations: int) -> void:
	# 保存原始的 find 方法
	var original_find = scene_card.find
	
	# 创建新的 find 方法包装
	scene_card.find = func():
		var scene_info = spawned_scenes.get(scene_name, {})
		var current_explorations = scene_info.get("explorations", {}).get(scene_card, 0)
		
		if current_explorations >= max_explorations:
			print("场景 %s 已达到最大探索次数 %d" % [scene_name, max_explorations])
			# 可以在这里添加视觉提示或禁用场景
			return
		
		# 增加探索次数
		spawned_scenes[scene_name]["explorations"][scene_card] = current_explorations + 1
		print("场景 %s 探索次数: %d/%d" % [scene_name, current_explorations + 1, max_explorations])
		
		# 调用原始方法
		await original_find.call()

## 生成装备掉落
func generate_equipment(layer_data: Dictionary) -> void:
	if not layer_data.has("equipment_spawn"):
		return
	
	var equipment_spawn = layer_data["equipment_spawn"]
	var spawn_chance = equipment_spawn.get("chance", 100)
	
	# 检查是否生成装备
	if randf() * 100 > spawn_chance:
		print("本次未触发装备生成")
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
			var spawn_pos = get_random_spawn_position()
			create_equipment_card(item_name, spawn_pos)
			print("✓ 生成装备掉落: %s" % item_name)
			break

## 创建装备卡片
func create_equipment_card(equipment_name: String, spawn_pos: Vector2) -> Control:
	# 检查装备是否在数据库中
	var equipment_data = GameData.get_equipment(equipment_name)
	if equipment_data.is_empty():
		push_error("未找到装备数据: " + equipment_name)
		return null
	
	if not equipment_card_scene:
		# 尝试加载默认装备卡片场景
		equipment_card_scene = load("res://assets/equipment/equipment_card.tscn")
	
	if not equipment_card_scene:
		push_error("装备卡片场景未设置")
		return null
	
	# 实例化装备卡片
	var card_instance = equipment_card_scene.instantiate()
	card_instance.name = "Equipment_" + equipment_name
	card_instance.position = spawn_pos
	
	# 添加到场景树
	add_child(card_instance)
	
	# 初始化卡片数据
	if card_instance.has_method("init_from_data"):
		card_instance.init_from_data(equipment_data)
	
	return card_instance

## 创建资源卡片（带动画）
func create_resource_card_with_animation(resource_name: String, start_pos: Vector2, end_pos: Vector2) -> void:
	var resource_data = GameData.get_resource(resource_name)
	if resource_data.is_empty():
		push_error("未找到资源数据: " + resource_name)
		return
	
	if not resource_card_scene:
		resource_card_scene = load("res://assets/resources/resource_card.tscn")
	
	if not resource_card_scene:
		push_error("资源卡片场景未找到")
		return
	
	var card_instance = resource_card_scene.instantiate()
	card_instance.name = "Resource_" + resource_name
	card_instance.position = start_pos
	card_instance.scale = Vector2.ZERO
	
	add_child(card_instance)
	
	# 初始化数据
	if card_instance.has_method("init_from_data"):
		card_instance.init_from_data(resource_data)
	
	# 播放动画
	play_spawn_animation(card_instance, end_pos)

## 创建遗物卡片（带动画）
func create_remains_card_with_animation(remains_name: String, start_pos: Vector2, end_pos: Vector2) -> void:
	var remains_data = GameData.get_remains(remains_name)
	if remains_data.is_empty():
		push_error("未找到遗物数据: " + remains_name)
		return
	
	if not remains_card_scene:
		remains_card_scene = load("res://assets/remains/remains_card.tscn")
	
	if not remains_card_scene:
		push_error("遗物卡片场景未找到")
		return
	
	var card_instance = remains_card_scene.instantiate()
	card_instance.name = "Remains_" + remains_name
	card_instance.position = start_pos
	card_instance.scale = Vector2.ZERO
	
	add_child(card_instance)
	
	# 初始化数据
	if card_instance.has_method("initialize_from_csv"):
		card_instance.initialize_from_csv(remains_data)
	
	# 播放动画
	play_spawn_animation(card_instance, end_pos)

## 创建装备卡片（带动画）
func create_equipment_card_with_animation(equipment_name: String, start_pos: Vector2, end_pos: Vector2) -> void:
	var equipment_data = GameData.get_equipment(equipment_name)
	if equipment_data.is_empty():
		push_error("未找到装备数据: " + equipment_name)
		return
	
	if not equipment_card_scene:
		equipment_card_scene = load("res://assets/equipment/equipment_card.tscn")
	
	if not equipment_card_scene:
		push_error("装备卡片场景未找到")
		return
	
	var card_instance = equipment_card_scene.instantiate()
	card_instance.name = "Equipment_" + equipment_name
	card_instance.position = start_pos
	card_instance.scale = Vector2.ZERO
	
	add_child(card_instance)
	
	# 初始化数据
	if card_instance.has_method("init_from_data"):
		card_instance.init_from_data(equipment_data)
	
	# 播放动画
	play_spawn_animation(card_instance, end_pos)

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

## 获取随机生成位置
func get_random_spawn_position() -> Vector2:
	var angle = randf() * TAU
	var distance = randf() * spawn_radius
	return spawn_center + Vector2(cos(angle), sin(angle)) * distance

## 在指定位置附近查找随机位置
func find_random_position_near(center_pos: Vector2, min_dist: float = 100.0, max_dist: float = 200.0) -> Vector2:
	var angle = randf() * TAU
	var distance = randf_range(min_dist, max_dist)
	return center_pos + Vector2(cos(angle), sin(angle)) * distance

