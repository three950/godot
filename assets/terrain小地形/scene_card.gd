extends "res://card.gd"
class_name SceneCard

# 场景卡片特有属性
# 场景卡片：获取资源的途径，固定在地图上，只有人物能堆叠，堆叠后每过五秒会根据概率出现一个产物
@export var produce_interval: float = 5.0  # 产出间隔（秒）
@export var produce_items: Array[String] = []  # 可生成的卡片类型数组
@export var produce_probabilities: Array[float] = []  # 对应的生成概率数组

var time_since_last_produce: float = 0.0
var can_produce: bool = false  # 是否可以产出（需要有人物堆叠）

func _ready() -> void:
	super._ready()
	# 场景卡片默认不是物品，不能放入背包
	time_since_last_produce = 0.0

func _process(delta: float) -> void:
	super._process(delta)
	
	# 检查是否有人物卡片堆叠
	check_character_stacked()
	
	# 如果有人物堆叠，进行产出计时
	if can_produce and cardCurrentState == cardState.fixed:
		time_since_last_produce += delta
		if time_since_last_produce >= produce_interval:
			find()  # 触发产出
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
	if produce_items.is_empty() or produce_probabilities.is_empty():
		return
	
	if produce_items.size() != produce_probabilities.size():
		print("错误：产物数组和概率数组长度不匹配")
		return
	
	# 根据概率随机选择一个产物
	var random_value = randf()
	var cumulative_prob = 0.0
	
	for i in range(produce_probabilities.size()):
		cumulative_prob += produce_probabilities[i]
		if random_value <= cumulative_prob:
			spawn_item(produce_items[i])
			print("场景 %s 产出了 %s" % [name, produce_items[i]])
			break

# 生成新卡片（需要配合 CardManager 使用）
func spawn_item(item_name: String) -> void:
	# 这里应该调用 CardManager 来实例化新卡片
	# 暂时只打印信息，具体实现需要配合你的 CardManager
	print("在场景 %s 生成产物: %s" % [name, item_name])
	# 示例：CardManager.create_card(item_name, position + Vector2(0, 100))

# 设置产出配置
func set_produce_config(items: Array[String], probabilities: Array[float]) -> void:
	produce_items = items
	produce_probabilities = probabilities
