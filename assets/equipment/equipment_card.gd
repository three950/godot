extends "res://baggable_card.gd"
class_name EquipmentCard

# 装备卡片特有属性
# 装备卡片：有防具和武器，可以和遗物合成新的装备，本身可以是遗物
enum EquipmentType { WEAPON, ARMOR, RELIC }
@export var equipment_type: EquipmentType = EquipmentType.WEAPON
# value 和 is_relic 已在父类 BaggableCard 中定义
@export var atk_bonus: int = 0  # 攻击力加成
@export var def_bonus: int = 0  # 防御力加成
@export var hp_bonus: int = 0  # 生命值加成
@export var special_effect: String = ""  # 特殊效果描述

# 装备时效果（从CSV的"装备时"列解析）
var equip_effects: Dictionary = {}  # {"ATK": 100, "DEF": 5, "HP": -5, "special": "fast_fish"}

# 装备标签引用
var stats_label: Label = null
var equipped_character: CharacterCard = null  # 装备在哪个角色上

# 卡片数据
var card_data: Dictionary = {}
var card_name: String = ""

# 信号：装备到角色时
signal equipment_equipped(character: CharacterCard, equipment: EquipmentCard)
# 信号：从角色卸下时
signal equipment_unequipped(character: CharacterCard, equipment: EquipmentCard)

func _ready() -> void:
	super._ready()
	# 装备继承自 BaggableCard，可以放入背包、在商店出售
	var stats_lbl = get_node_or_null("Control/ColorRect/StatsLabel")
	if stats_lbl:
		stats_label = stats_lbl
		update_stats_label()
	
	# 添加堆叠合成检测器
	add_stack_craft_detector()

# 更新属性标签显示
func update_stats_label() -> void:
	if not stats_label:
		return
	
	var stats_text = ""
	if atk_bonus > 0:
		stats_text += "ATK +%d " % atk_bonus
	if def_bonus > 0:
		stats_text += "DEF +%d " % def_bonus
	if hp_bonus > 0:
		stats_text += "HP +%d" % hp_bonus
	
	stats_label.text = stats_text.strip_edges()

# synthesis() 函数：和遗物合成新的装备
func synthesis() -> void:
	if stacked_cards.is_empty():
		return
	
	# 检查堆叠的卡片中是否有遗物或装备
	var has_relic = false
	var has_equipment = false
	
	for card in stacked_cards:
		if card is EquipmentCard:
			if card.is_relic:
				has_relic = true
			else:
				has_equipment = true
	
	# 如果同时有遗物和装备，可以合成
	if has_relic or (is_relic and has_equipment):
		start_synthesis()

# 开始合成
func start_synthesis() -> void:
	print("装备合成开始: %s" % name)
	# 这里应该调用 CardManager 来创建新装备
	# 具体实现需要配合你的 CardManager

# 装备到角色
func equip_to_character(character: CharacterCard) -> bool:
	if character == null:
		return false
	
	# 如果已经装备在其他角色上，先卸下
	if equipped_character != null:
		unequip()
	
	equipped_character = character
	
	# 应用装备加成
	if atk_bonus > 0:
		character.modify_atk(atk_bonus)
	if def_bonus > 0:
		character.modify_defense(def_bonus)
	if hp_bonus > 0:
		character.modify_hp(hp_bonus)
	
	print("装备 %s 已装备到 %s" % [name, character.name])
	return true

# 卸下装备
func unequip() -> void:
	if equipped_character == null:
		return
	
	# 移除装备加成
	if atk_bonus > 0:
		equipped_character.modify_atk(-atk_bonus)
	if def_bonus > 0:
		equipped_character.modify_defense(-def_bonus)
	if hp_bonus > 0:
		equipped_character.modify_hp(-hp_bonus)
	
	print("装备 %s 已从 %s 卸下" % [name, equipped_character.name])
	equipped_character = null

# 设置装备属性
func set_equipment_stats(eq_type: EquipmentType, equipment_value: int, atk: int = 0, def: int = 0, hp: int = 0, relic: bool = false) -> void:
	equipment_type = eq_type
	value = equipment_value
	atk_bonus = atk
	def_bonus = def
	hp_bonus = hp
	is_relic = relic
	update_stats_label()

# 添加堆叠合成检测器
func add_stack_craft_detector() -> void:
	# 检查是否已经添加过
	if has_node("StackCraftDetector"):
		return
	
	# 加载检测器脚本
	var detector_script = load("res://script_folder/stack_craft_detector.gd")
	if detector_script == null:
		push_error("无法加载 StackCraftDetector 脚本")
		return
	
	# 创建检测器节点
	var detector = Node.new()
	detector.name = "StackCraftDetector"
	detector.set_script(detector_script)
	
	# 添加为子节点
	add_child(detector)
	print("【装备卡】已添加堆叠合成检测器: %s" % name)

## 初始化卡片数据（从GameData加载）
func init_from_data(data: Dictionary) -> void:
	card_data = data
	card_name = data.get("名称", "未知")
	
	print("【装备卡片】init_from_data 被调用，数据: %s" % str(data.keys()))
	
	# 设置基础属性
	value = int(data.get("value", 1))
	is_relic = data.get("是否是遗物", "FALSE") == "TRUE"
	
	# 解析装备时效果
	if data.has("装备时"):
		var equip_str = str(data["装备时"])
		print("【装备卡片】找到'装备时'字段: '%s'" % equip_str)
		if not equip_str.is_empty():
			# 使用统一的装备效果解析（支持 ATK+10, DEF+5 等格式）
			parse_equip_effects(equip_str)
			# 同时更新旧的 bonus 字段（用于显示）
			if equip_effects.has("ATK"):
				atk_bonus = equip_effects["ATK"]
			if equip_effects.has("DEF"):
				def_bonus = equip_effects["DEF"]
			if equip_effects.has("HP"):
				hp_bonus = equip_effects["HP"]
		else:
			print("【装备卡片】警告：'装备时'字段为空")
	else:
		print("【装备卡片】警告：数据中没有'装备时'字段")
	
	# 设置装备类型
	var type_str = data.get("类型", "")
	if type_str == "武器":
		equipment_type = EquipmentType.WEAPON
	elif type_str == "防具":
		equipment_type = EquipmentType.ARMOR
	elif is_relic:
		equipment_type = EquipmentType.RELIC
	
	# 更新显示
	update_display()

## 解析效果字符串（如 "ATK+10" 或 "DEF+5"）
func parse_effect(effect_str: String) -> void:
	if "ATK" in effect_str:
		var regex = RegEx.new()
		regex.compile(r"ATK\+(\d+)")
		var result = regex.search(effect_str)
		if result:
			atk_bonus = int(result.get_string(1))
	
	if "DEF" in effect_str:
		var regex = RegEx.new()
		regex.compile(r"DEF\+(\d+)")
		var result = regex.search(effect_str)
		if result:
			def_bonus = int(result.get_string(1))
	
	if "HP" in effect_str:
		var regex = RegEx.new()
		regex.compile(r"HP\+(\d+)")
		var result = regex.search(effect_str)
		if result:
			hp_bonus = int(result.get_string(1))

## 更新卡片显示
func update_display() -> void:
	# 更新名称标签
	var label = get_node_or_null("Control/ColorRect/Label")
	if label:
		label.text = card_name
	
	# 更新价值标签
	var value_label = get_node_or_null("Control/ColorRect/ValueLabel")
	if value_label:
		value_label.text = "价值: %d" % value
	
	# 更新属性标签
	update_stats_label()
	
	# 更新图片
	var texture_rect = get_node_or_null("Control/ColorRect/TextureRect")
	if texture_rect and card_data.has("地址"):
		var texture_path = card_data["地址"]
		if texture_path != "" and ResourceLoader.exists(texture_path + ".jpg"):
			var texture = load(texture_path + ".jpg")
			if texture:
				texture_rect.texture = texture
		elif texture_path != "" and ResourceLoader.exists(texture_path + ".png"):
			var texture = load(texture_path + ".png")
			if texture:
				texture_rect.texture = texture

## 获取卡片名称（用于合成系统）
func get_card_name() -> String:
	return card_name

# ========== 装备效果系统 ==========

# 解析装备时效果（从CSV的"装备时"列）
# 格式: "ATK+100,DEF+5.一次性:HP-5" 或 "为角色添加fast_fish属性"
func parse_equip_effects(effect_string: String) -> void:
	if effect_string.is_empty():
		return
	
	equip_effects.clear()
	
	# 检查是否是特殊效果（如 fast_fish）
	if "fast_fish" in effect_string:
		equip_effects["special"] = "fast_fish"
		print("装备 %s 解析特殊效果: fast_fish" % name)
		return
	
	# 解析属性修改效果
	# 先移除"一次性:"前缀，然后分割
	var cleaned = effect_string.replace("一次性:", "")
	# 分割主要部分（用逗号和句号分隔）
	var parts = cleaned.replace(".", ",").split(",")
	
	for part in parts:
		part = part.strip_edges()
		
		if part.is_empty():
			continue
		
		# 解析 ATK+100, DEF+5, HP-5 格式
		if "ATK" in part:
			var value_str = part.replace("ATK", "").strip_edges()
			if value_str.is_valid_int():
				equip_effects["ATK"] = int(value_str)
		elif "DEF" in part:
			var value_str = part.replace("DEF", "").strip_edges()
			if value_str.is_valid_int():
				equip_effects["DEF"] = int(value_str)
		elif "HP" in part:
			var value_str = part.replace("HP", "").strip_edges()
			if value_str.is_valid_int():
				equip_effects["HP"] = int(value_str)
	
	print("装备 %s 解析装备效果: %s" % [name, str(equip_effects)])

# 应用装备效果到角色
func apply_equip_effects(character: CharacterCard) -> void:
	if character == null:
		return
	
	print("装备 %s 装备到角色 %s" % [name, character.name])
	print("  当前装备效果字典: %s" % str(equip_effects))
	
	# 应用属性修改
	if equip_effects.has("ATK"):
		character.modify_atk(equip_effects["ATK"])
		print("  ATK %+d" % equip_effects["ATK"])
	
	if equip_effects.has("DEF"):
		character.modify_defense(equip_effects["DEF"])
		print("  DEF %+d" % equip_effects["DEF"])
	
	if equip_effects.has("HP"):
		character.modify_hp(equip_effects["HP"])
		print("  HP %+d" % equip_effects["HP"])
	
	# 应用特殊效果
	if equip_effects.has("special"):
		var special_effect_str = equip_effects["special"]
		if character.has_method("add_special_effect"):
			character.add_special_effect(special_effect_str)
			print("  添加特殊效果: %s" % special_effect_str)
	
	# 更新装备角色引用
	equipped_character = character
	
	# 发射装备信号
	equipment_equipped.emit(character, self)

# 移除装备效果
func remove_equip_effects(character: CharacterCard) -> void:
	if character == null:
		return
	
	print("装备 %s 从角色 %s 卸下" % [name, character.name])
	
	# 移除属性修改（反向应用）
	if equip_effects.has("ATK"):
		character.modify_atk(-equip_effects["ATK"])
		print("  ATK %+d" % (-equip_effects["ATK"]))
	
	if equip_effects.has("DEF"):
		character.modify_defense(-equip_effects["DEF"])
		print("  DEF %+d" % (-equip_effects["DEF"]))
	
	if equip_effects.has("HP"):
		character.modify_hp(-equip_effects["HP"])
		print("  HP %+d" % (-equip_effects["HP"]))
	
	# 移除特殊效果
	if equip_effects.has("special"):
		var special_effect_str = equip_effects["special"]
		if character.has_method("remove_special_effect"):
			character.remove_special_effect(special_effect_str)
			print("  移除特殊效果: %s" % special_effect_str)
	
	# 清空装备角色引用
	equipped_character = null
	
	# 发射卸下信号
	equipment_unequipped.emit(character, self)
