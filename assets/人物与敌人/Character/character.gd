extends "res://assets/card.gd"
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

# 属性标签组件引用
var attribute_labels: AttributeLabels = null

func _ready() -> void:
	super._ready()
	# 自动获取属性标签组件引用
	attribute_labels = get_node_or_null("Control/ColorRect/AttributeLabels")
	update_stat_labels()

func _process(delta: float) -> void:
	super._process(delta)

# 更新属性标签显示（使用Label动态显示，值可以随时改变）
func update_stat_labels() -> void:
	if attribute_labels:
		attribute_labels.update_labels(hp, atk, defense)

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

# 设置属性标签组件引用（手动设置）
func set_attribute_labels(labels: AttributeLabels) -> void:
	attribute_labels = labels
	update_stat_labels()

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
