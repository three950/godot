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

func _ready() -> void:
	super._ready()
	# 资源继承自 BaggableCard，可以放入背包、在商店出售

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
