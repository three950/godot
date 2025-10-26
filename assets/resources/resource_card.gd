extends "res://baggable_card.gd"
class_name ResourceCard

# 资源卡片特有属性
# 资源卡片：包括调料和食物，可以合成，是物品
# value 和 is_relic 已在父类 BaggableCard 中定义
@export var is_food: bool = false  # 是否是食物
@export var is_seasoning: bool = false  # 是否是调料
@export var nutrition: int = 0  # 营养值（食物类）
@export var synthesis_recipes: Array[Dictionary] = []  # 合成配方

var synthesis_timer: float = 0.0
var synthesis_delay: float = 2.0  # 合成延迟时间
var is_synthesizing: bool = false

# 卡片数据
var card_data: Dictionary = {}
var card_name: String = ""

func _ready() -> void:
	super._ready()
	# 资源继承自 BaggableCard，可以放入背包、在商店出售
	
	# 添加堆叠合成检测器
	add_stack_craft_detector()

func _process(delta: float) -> void:
	super._process(delta)
	
	# 处理合成计时
	if is_synthesizing:
		synthesis_timer += delta
		if synthesis_timer >= synthesis_delay:
			complete_synthesis()

# synthesis() 函数：根据已有卡片的乘积寻找组合，如果有合成路径，生成新卡片
func synthesis() -> void:
	if stacked_cards.is_empty():
		return
	
	# 收集所有堆叠的资源卡片
	var stacked_resources: Array[ResourceCard] = []
	for card in stacked_cards:
		if card is ResourceCard:
			stacked_resources.append(card)
	
	# 检查是否满足合成配方
	var recipe = find_matching_recipe(stacked_resources)
	if recipe != null:
		start_synthesis(recipe, stacked_resources)

# 查找匹配的合成配方
func find_matching_recipe(resources: Array[ResourceCard]) -> Dictionary:
	# 这里应该根据资源组合查找配方
	# 配方格式示例: {"required": ["fish", "seasoning"], "result": "cooked_fish", "value": 10}
	for recipe in synthesis_recipes:
		if check_recipe_match(recipe, resources):
			return recipe
	return {}

# 检查配方是否匹配
func check_recipe_match(recipe: Dictionary, resources: Array[ResourceCard]) -> bool:
	if not recipe.has("required"):
		return false
	
	var required_items = recipe["required"]
	var resource_names = []
	for res in resources:
		resource_names.append(res.name)
	
	# 简单匹配逻辑，实际可能需要更复杂的判断
	for req in required_items:
		if req not in resource_names:
			return false
	
	return true

# 开始合成
func start_synthesis(recipe: Dictionary, _resources: Array[ResourceCard]) -> void:
	is_synthesizing = true
	synthesis_timer = 0.0
	print("开始合成: %s" % recipe.get("result", "未知"))

# 完成合成
func complete_synthesis() -> void:
	is_synthesizing = false
	synthesis_timer = 0.0
	print("合成完成")
	# 这里应该：
	# 1. 创建新卡片
	# 2. 删除用于合成的卡片
	# 具体实现需要配合 CardManager

# 设置资源属性
func set_resource_stats(resource_value: int, is_food_type: bool = false, nutrition_value: int = 0) -> void:
	value = resource_value
	is_food = is_food_type
	nutrition = nutrition_value

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
	print("【资源卡】已添加堆叠合成检测器: %s" % name)

## 初始化卡片数据（从GameData加载）
func init_from_data(data: Dictionary) -> void:
	card_data = data
	card_name = data.get("名称", "未知")
	
	# 设置基础属性
	value = int(data.get("value", 1))
	is_relic = data.get("是否是遗物", "FALSE") == "TRUE"
	
	# 设置资源特有属性
	var type_str = data.get("类型", "")
	is_food = (type_str == "食物")
	is_seasoning = (type_str == "调料")
	nutrition = int(data.get("food", 0))
	
	# 更新显示
	update_display()

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
	
	# 更新图片
	var texture_rect = get_node_or_null("Control/ColorRect/TextureRect")
	if texture_rect and card_data.has("地址"):
		var texture_path = card_data["地址"]
		if texture_path != "" and ResourceLoader.exists(texture_path + ".jpg"):
			var texture = load(texture_path + ".jpg")
			if texture:
				texture_rect.texture = texture

## 获取卡片名称（用于合成系统）
func get_card_name() -> String:
	return card_name
