extends Node

## 合成管理器
## 负责处理卡片合成逻辑，类似《堆叠大陆》的合成系统

# 合成配方字典 - key: 产物名称, value: {materials: {材料名: 数量}, total_count: 总材料数}
var craft_recipes: Dictionary = {}

func _ready() -> void:
	print("CraftManager 初始化...")
	# 等待 GameData 加载完成后再构建配方
	if GameData.is_data_loaded:
		build_craft_recipes()
	else:
		# 延迟构建配方
		await get_tree().create_timer(0.1).timeout
		build_craft_recipes()

## 构建所有合成配方
func build_craft_recipes() -> void:
	craft_recipes.clear()
	
	# 从资源数据库构建配方
	for resource_name in GameData.resource_database.keys():
		var resource_data = GameData.resource_database[resource_name]
		if resource_data.has("合成配方") and resource_data["合成配方"] != "":
			var recipe = parse_recipe(resource_data["合成配方"])
			if recipe != null:
				craft_recipes[resource_name] = recipe
	
	# 从装备数据库构建配方
	for equipment_name in GameData.equipment_database.keys():
		var equipment_data = GameData.equipment_database[equipment_name]
		if equipment_data.has("合成配方") and equipment_data["合成配方"] != "":
			var recipe = parse_recipe(equipment_data["合成配方"])
			if recipe != null:
				craft_recipes[equipment_name] = recipe
	
	print("合成配方加载完成，共 %d 个配方" % craft_recipes.size())
	print_all_recipes()

## 解析合成配方字符串
## 格式: "材料1*材料2*材料3" 或 "材料1*材料2数量*材料3"
## 例如: "鱼*火" 或 "骨头*骨头*化石树的树枝*石头" 或 "稿子*太阳石4"
func parse_recipe(recipe_string: String) -> Dictionary:
	if recipe_string == "" or recipe_string == null:
		return {}
	
	var materials: Dictionary = {}  # key: 材料名, value: 数量
	var total_count: int = 0
	
	# 按 * 分割材料
	var parts = recipe_string.split("*")
	
	for part in parts:
		part = part.strip_edges()  # 去除空格
		if part == "":
			continue
		
		# 检查材料名后是否带数字（如"太阳石4"表示需要4个太阳石）
		var material_name = ""
		var material_count = 1
		
		# 尝试提取末尾的数字
		var regex = RegEx.new()
		regex.compile(r"^(.+?)(\d+)$")  # 匹配：任意字符(非贪婪) + 数字
		var result = regex.search(part)
		
		if result:
			# 找到数字后缀
			material_name = result.get_string(1).strip_edges()
			material_count = int(result.get_string(2))
		else:
			# 没有数字后缀，整个都是材料名
			material_name = part
			material_count = 1
		
		# 累加该材料的数量
		if materials.has(material_name):
			materials[material_name] += material_count
		else:
			materials[material_name] = material_count
		
		total_count += material_count
	
	return {
		"materials": materials,
		"total_count": total_count
	}

## 检查给定的卡片列表是否可以合成某个物品
## card_list: 卡片对象数组
## 返回: 如果可以合成，返回产物名称；否则返回空字符串
func check_craft(card_list: Array) -> String:
	if card_list.size() < 2:
		return ""  # 至少需要2张卡片才能合成
	
	# 统计卡片名称和数量
	var card_counts: Dictionary = {}
	for card in card_list:
		if not card.has_method("get_card_name"):
			print("  警告：卡片 %s 没有 get_card_name() 方法" % card.name)
			continue
		
		var card_name = card.get_card_name()
		print("  材料卡片: %s (节点名: %s)" % [card_name, card.name])
		
		if card_counts.has(card_name):
			card_counts[card_name] += 1
		else:
			card_counts[card_name] = 1
	
	print("  统计结果: %s" % str(card_counts))
	
	# 遍历所有配方，检查是否匹配
	for product_name in craft_recipes.keys():
		var recipe = craft_recipes[product_name]
		
		# 检查1: 卡片总数必须等于配方要求的总数
		if card_list.size() != recipe["total_count"]:
			continue
		
		# 检查2: 每种材料的数量必须完全匹配
		var materials = recipe["materials"]
		if materials.size() != card_counts.size():
			continue  # 材料种类数不匹配
		
		var is_match = true
		for material_name in materials.keys():
			if not card_counts.has(material_name):
				is_match = false
				break
			if card_counts[material_name] != materials[material_name]:
				is_match = false
				break
		
		if is_match:
			# 找到匹配的配方
			return product_name
	
	return ""  # 没有找到匹配的配方

## 执行合成
## card_list: 要合成的卡片数组
## 返回: 新生成的卡片节点，如果合成失败返回null
func execute_craft(card_list: Array) -> Node:
	# 检查是否可以合成
	var product_name = check_craft(card_list)
	if product_name == "":
		print("合成失败：没有匹配的配方")
		return null
	
	print("合成成功：将生成 %s" % product_name)
	
	# 计算合成位置（使用根卡片的位置，即第一张卡片的位置）
	# 第一张卡片通常是堆叠组的底部卡片，新卡片将在此位置生成
	var center_pos = Vector2.ZERO
	if card_list.size() > 0 and card_list[0] is Control:
		center_pos = card_list[0].global_position
	
	# 删除所有材料卡片前，先解除堆叠关系
	for card in card_list:
		if card and is_instance_valid(card):
			# 解除与父卡片的关系
			if "parent_card" in card and card.parent_card != null:
				if card.parent_card.has_method("remove_from_stack"):
					card.parent_card.remove_from_stack(card)
				card.parent_card = null
			
			# 清空子卡片列表（避免子卡片尝试访问已删除的父卡片）
			if "stacked_cards" in card:
				card.stacked_cards.clear()
			
			# 删除卡片
			card.queue_free()
	
	# 生成新卡片
	var new_card = create_card(product_name, center_pos)
	
	return new_card

## 创建指定名称的卡片
func create_card(card_name: String, position: Vector2) -> Node:
	# 检查是资源、道具还是装备
	var card_data = null
	var card_scene_path = ""
	
	if GameData.resource_database.has(card_name):
		card_data = GameData.resource_database[card_name]
		card_scene_path = "res://assets/resources/resource_card.tscn"
	elif GameData.item_database.has(card_name):
		card_data = GameData.item_database[card_name]
		card_scene_path = "res://assets/item道具/item_card.tscn"
	elif GameData.equipment_database.has(card_name):
		card_data = GameData.equipment_database[card_name]
		card_scene_path = "res://assets/equipment/equipment_card.tscn"
	else:
		push_error("未找到卡片数据: " + card_name)
		return null
	
	# 加载卡片场景
	var card_scene = load(card_scene_path)
	if not card_scene:
		push_error("无法加载卡片场景: " + card_scene_path)
		return null
	
	# 实例化卡片
	var card_instance = card_scene.instantiate()
	
	# 设置卡片数据
	if card_instance.has_method("init_from_data"):
		card_instance.init_from_data(card_data)
	
	# 设置位置（Control 节点也有 global_position 属性）
	if card_instance is Control:
		card_instance.global_position = position
	
	# 添加到场景树
	get_tree().root.add_child(card_instance)
	
	print("已生成新卡片: %s 于位置 %s" % [card_name, position])
	
	return card_instance

## 打印所有配方（调试用）
func print_all_recipes() -> void:
	print("========== 合成配方列表 ==========")
	for product_name in craft_recipes.keys():
		var recipe = craft_recipes[product_name]
		var materials = recipe["materials"]
		var material_str = ""
		for material_name in materials.keys():
			if material_str != "":
				material_str += " + "
			material_str += "%s×%d" % [material_name, materials[material_name]]
		print("  %s = %s (共%d张)" % [product_name, material_str, recipe["total_count"]])
	print("================================")

## 获取指定产物的配方信息
func get_recipe(product_name: String) -> Dictionary:
	if craft_recipes.has(product_name):
		return craft_recipes[product_name]
	return {}

## 获取所有配方
func get_all_recipes() -> Dictionary:
	return craft_recipes
