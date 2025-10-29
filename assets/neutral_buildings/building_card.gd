extends "res://card.gd"
class_name BuildingCard

# 建筑卡片特有属性
# 建筑卡片：容纳探窟者休息，固定在场景中，不同layer会出现不同建筑
@export var building_layer: int = 0  # 所在的深渊层数
@export var capacity: int = 1  # 可容纳的人物数量
@export var hp_restore_per_night: int = 5  # 每晚恢复的生命值
@export var requires_food: bool = true  # 是否需要食物补给
@export var requires_water: bool = true  # 是否需要水源补给

var resting_characters: Array[CharacterCard] = []  # 正在休息的角色

func _ready() -> void:
	super._ready()
	# 建筑卡片设置为 architecture 类型，不能拖拽
	card_type = cardType.architecture
	cardCurrentState = cardState.fixed

# rest() 函数：在夜晚结算时，食物和水补充的情况下，恢复生命
func rest() -> void:
	if stacked_cards.is_empty():
		print("建筑 %s：没有角色在休息" % name)
		return
	
	# 检查是否有足够的资源
	var has_food = not requires_food or check_has_resource("food")
	var has_water = not requires_water or check_has_resource("water")
	
	# 收集所有休息的角色
	resting_characters.clear()
	for card in stacked_cards:
		if card is CharacterCard:
			if resting_characters.size() < capacity:
				resting_characters.append(card)
	
	# 为角色恢复生命
	for character in resting_characters:
		if has_food and has_water:
			character.modify_hp(hp_restore_per_night)
			print("角色 %s 在 %s 休息，恢复了 %d HP" % [character.name, name, hp_restore_per_night])
		else:
			var partial_restore = hp_restore_per_night / 2
			character.modify_hp(partial_restore)
			print("角色 %s 在 %s 休息，但资源不足，只恢复了 %d HP" % [character.name, name, partial_restore])
	
	# 消耗资源
	if has_food:
		consume_resource("food")
	if has_water:
		consume_resource("water")

# 检查是否有指定资源
func check_has_resource(resource_type: String) -> bool:
	for card in stacked_cards:
		if card is ResourceCard:
			# 这里可以根据资源的具体属性判断
			# 简化处理，假设根据名字判断
			if resource_type in card.name.to_lower():
				return true
	return false

# 消耗资源
func consume_resource(resource_type: String) -> void:
	for card in stacked_cards:
		if card is ResourceCard:
			if resource_type in card.name.to_lower():
				# 删除该资源卡片
				stacked_cards.erase(card)
				card.queue_free()
				print("消耗了资源: %s" % card.name)
				break

# 夜晚结算（由游戏管理器调用）
func night_settlement() -> void:
	print("建筑 %s 开始夜晚结算" % name)
	rest()

# 设置建筑属性
func set_building_stats(layer: int, cap: int, hp_restore: int, need_food: bool = true, need_water: bool = true) -> void:
	building_layer = layer
	capacity = cap
	hp_restore_per_night = hp_restore
	requires_food = need_food
	requires_water = need_water

# 覆盖父类方法，建筑不能被拖拽
func _on_button_button_down() -> void:
	# 建筑卡片不响应拖拽
	pass

func _on_button_button_up() -> void:
	# 建筑卡片不响应拖拽
	pass
