extends "res://card.gd"
class_name CharacterCard

# 角色卡片特有属性
@export var hp: int = 10
@export var atk: int = 1
@export var defense: int = 0
@export var equipment: String = ""

# 角色数据引用
var character_data: CharacterData = null

# 是否已经应用过初始装备效果（避免重复应用）
var _initial_effects_applied: bool = false

# 特殊效果管理（装备道具后获得的效果）
var special_effects: Array[String] = []  # 例如: ["fast_fish", "water_breathing"]

# 属性标签引用
var hp_label: Label = null
var atk_label: Label = null
var defense_label: Label = null

# 背包相关
var bag_instance: Panel = null  # 背包实例
var bag_scene = preload("res://bag.tscn")  # 预加载背包场景
var bag_button: Button = null  # 背包按钮

func _ready() -> void:
	super._ready()
	# 自动获取标签引用
	var stats_container = get_node_or_null("Control/ColorRect/StatsContainer")
	if stats_container:
		hp_label = stats_container.get_node_or_null("HPLabel")
		var right_stats = stats_container.get_node_or_null("RightStats")
		if right_stats:
			atk_label = right_stats.get_node_or_null("ATKLabel")
			defense_label = right_stats.get_node_or_null("DEFLabel")
	update_stat_labels()
	
	# 获取背包按钮引用并连接信号
	_setup_bag_button()

func _process(delta: float) -> void:
	super._process(delta)
	# 更新背包位置，使其跟随角色卡片
	update_bag_position()

# 更新属性标签显示（使用Label动态显示，值可以随时改变）
func update_stat_labels() -> void:
	if hp_label:
		hp_label.text = "%d" % hp
	if atk_label:
		atk_label.text = "%d" % atk
	if defense_label:
		defense_label.text = "%d" % defense

# 设置角色属性
func set_character_stats(char_hp: int, char_atk: int, char_defense: int, char_equipment: String = "") -> void:
	hp = char_hp
	atk = char_atk
	defense = char_defense
	equipment = char_equipment
	update_stat_labels()
	
	# 在设置基础属性后，应用初始装备效果
	if character_data and not _initial_effects_applied:
		_initial_effects_applied = true
		apply_initial_equipment_effects()

# 修改HP（可以用于战斗等场景）
func modify_hp(amount: int) -> void:
	hp += amount
	if hp < 0:
		hp = 0
	update_stat_labels()

# 修改ATK
func modify_atk(amount: int) -> void:
	atk += amount
	if atk < 0:
		atk = 0
	update_stat_labels()

# 修改防御
func modify_defense(amount: int) -> void:
	defense += amount
	if defense < 0:
		defense = 0
	update_stat_labels()

# 设置标签引用（手动设置）
func set_stat_labels(hp_lbl: Label, atk_lbl: Label, def_lbl: Label) -> void:
	hp_label = hp_lbl
	atk_label = atk_lbl
	defense_label = def_lbl
	update_stat_labels()

# 设置背包按钮（从场景中获取）
func _setup_bag_button() -> void:
	# 获取场景中定义的背包按钮
	bag_button = get_node_or_null("bagbutton")
	
	if bag_button:
		# 连接按钮点击信号
		bag_button.pressed.connect(toggle_bag)
		print("【角色卡片】背包按钮已连接")
	else:
		push_warning("【角色卡片】未找到 bagbutton 节点")

# 切换背包显示状态
func toggle_bag() -> void:
	if bag_instance and is_instance_valid(bag_instance):
		# 如果背包已显示，则关闭
		close_bag()
	else:
		# 如果背包未显示，则打开
		open_bag()

# 打开背包
func open_bag() -> void:
	print("【角色卡片】打开背包")
	if bag_instance and is_instance_valid(bag_instance):
		print("【角色卡片】背包已经显示")
		return  # 背包已经显示
	
	# 实例化背包
	bag_instance = bag_scene.instantiate()
	
	# 将背包添加到场景树的根节点
	var root = get_tree().root
	root.add_child(bag_instance)
	
	# 设置背包位置（在卡片右侧）
	update_bag_position()
	
	# 加载角色的背包数据
	if character_data:
		print("【角色卡片】加载角色背包数据：", character_data.character_name)
		bag_instance.load_character_bag(character_data, self)  # 传递角色卡片引用
	else:
		push_warning("【角色卡片】角色卡片没有关联的角色数据，背包将为空")
	
	# 连接背包的关闭请求信号
	if bag_instance.has_signal("close_requested"):
		bag_instance.close_requested.connect(_on_bag_close_requested)
	
	# 更新按钮状态
	_update_bag_button_state(true)
	
	print("【角色卡片】背包显示完成")

# 更新背包位置，使其跟随卡片
func update_bag_position() -> void:
	if bag_instance and is_instance_valid(bag_instance):
		# 计算背包位置（在卡片右侧）
		var bag_pos = global_position + Vector2(size.x + 5, 0)
		bag_instance.global_position = bag_pos

# 关闭背包
func close_bag() -> void:
	print("【角色卡片】关闭背包")
	if bag_instance and is_instance_valid(bag_instance):
		# 保存背包数据回角色
		if bag_instance.has_method("save_to_character"):
			bag_instance.save_to_character()
		
		# 将槽位内的卡片移到背包面板下（让 queue_free 能自动删除它们）
		if bag_instance.has_method("prepare_for_close"):
			bag_instance.prepare_for_close()
		
		# 释放背包实例（会自动删除作为子节点的槽位内卡片）
		bag_instance.queue_free()
		bag_instance = null
		
		# 更新按钮状态
		_update_bag_button_state(false)
		
		print("【角色卡片】背包已关闭")

# 更新背包按钮的状态
func _update_bag_button_state(is_open: bool) -> void:
	if not bag_button:
		return
	
	if is_open:
		# 背包打开时，改为关闭图标
		bag_button.text = "✖"
	else:
		# 背包关闭时，显示背包图标
		bag_button.text = "🎒"

# 当背包请求关闭时的回调
func _on_bag_close_requested() -> void:
	print("【角色卡片】收到背包关闭请求")
	close_bag()

# ========== 特殊效果管理 ==========

# 添加特殊效果
func add_special_effect(effect: String) -> void:
	if effect not in special_effects:
		special_effects.append(effect)
		print("【角色卡片】%s 获得特殊效果: %s" % [name, effect])

# 移除特殊效果
func remove_special_effect(effect: String) -> void:
	if effect in special_effects:
		special_effects.erase(effect)
		print("【角色卡片】%s 失去特殊效果: %s" % [name, effect])

# 检查是否拥有特殊效果
func has_special_effect(effect: String) -> bool:
	return effect in special_effects

# 获取所有特殊效果
func get_special_effects() -> Array[String]:
	return special_effects.duplicate()

# ========== 初始装备效果应用 ==========

# 应用初始装备效果（在角色卡片初始化时调用）
func apply_initial_equipment_effects() -> void:
	if not character_data:
		return
	
	print("【角色卡片】%s 开始应用初始装备效果..." % character_data.character_name)
	
	# 收集所有装备槽位的物品名称
	var equipment_slots = [
		character_data.left,   # 左手装备
		character_data.right,  # 右手装备
		character_data.bag1,   # 背包槽位1
		character_data.bag2,
		character_data.bag3,
		character_data.bag4,
		character_data.bag5,
		character_data.bag6
	]
	
	# 遍历所有装备，应用效果
	for item_name in equipment_slots:
		if item_name == "" or item_name == null:
			continue
		
		# 从 GameData 获取物品数据
		var item_data = _get_item_data_by_name(item_name)
		if item_data.is_empty():
			continue
		
		# 解析并应用装备效果
		_apply_equipment_effect_from_data(item_name, item_data)
	
	print("【角色卡片】%s 初始装备效果应用完成" % character_data.character_name)

# 从物品数据中解析并应用装备效果
func _apply_equipment_effect_from_data(item_name: String, item_data: Dictionary) -> void:
	# 注意：装备使用"效果"字段，道具使用"装备时"字段
	var effect_str = item_data.get("装备时", "")
	
	if effect_str == "" or effect_str == null:
		return
	
	print("【角色卡片】应用装备 %s 的效果: %s" % [item_name, effect_str])
	
	# 移除外层括号
	var cleaned = effect_str.strip_edges()
	if cleaned.begins_with("["):
		cleaned = cleaned.substr(1, cleaned.length() - 2)
	
	# 分割各个效果项
	var effects = cleaned.split(",")
	for effect in effects:
		effect = effect.strip_edges().replace("\"", "")
		if effect == "":
			continue
		
		# 检查是否是属性加成（格式：ATK+100, DEF+5, HP-5）
		if "+" in effect or "-" in effect:
			# 找到符号位置（从第二个字符开始找，因为第一个字符可能是负号）
			var sign_pos = -1
			for i in range(1, effect.length()):
				if effect[i] == "+" or effect[i] == "-":
					sign_pos = i
					break
			
			if sign_pos > 0:
				var stat_name = effect.substr(0, sign_pos).strip_edges()
				var value_str = effect.substr(sign_pos).strip_edges()
				
				if value_str.is_valid_int():
					var value = int(value_str)
					match stat_name:
						"ATK":
							modify_atk(value)
							print("  └─ ATK %+d (当前: %d)" % [value, atk])
						"HP":
							modify_hp(value)
							print("  └─ HP %+d (当前: %d)" % [value, hp])
						"DEF":
							modify_defense(value)
							print("  └─ DEF %+d (当前: %d)" % [value, defense])
		else:
			# 特殊效果（如 fast_fish）
			add_special_effect(effect)
			print("  └─ 特殊效果: %s" % effect)

# 从 GameData 获取物品数据（按名称）
func _get_item_data_by_name(item_name: String) -> Dictionary:
	# 先尝试从资源数据库查找
	var item_data = GameData.get_resource(item_name)
	if not item_data.is_empty():
		return item_data
	
	# 再尝试从道具数据库查找
	item_data = GameData.get_item(item_name)
	if not item_data.is_empty():
		return item_data
	
	# 最后尝试从装备数据库查找
	item_data = GameData.get_equipment(item_name)
	if not item_data.is_empty():
		return item_data
	
	return {}
