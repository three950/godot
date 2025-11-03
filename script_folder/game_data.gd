extends Node

## 全局数据管理单例
## 负责加载和管理所有游戏数据
## 在项目设置中配置为 Autoload，名称为 GameData

# 角色数据库 - key: 角色名称, value: CharacterData
var character_database: Dictionary = {}

# 遗物数据库 - key: 遗物名称, value: Dictionary
var remains_database: Dictionary = {}

# 场景数据库 - key: 场景名称, value: Dictionary
var scene_database: Dictionary = {}

# 资源数据库 - key: 资源名称, value: Dictionary
var resource_database: Dictionary = {}

# 道具数据库 - key: 道具名称, value: Dictionary
var item_database: Dictionary = {}

# 装备数据库 - key: 装备名称, value: Dictionary
var equipment_database: Dictionary = {}

# 数据是否已加载
var is_data_loaded: bool = false

func _ready() -> void:
	print("GameData 单例初始化...")
	load_all_game_data()

## 加载所有游戏数据
func load_all_game_data() -> void:
	load_character_data_from_csv()
	load_remains_data_from_csv()
	load_scene_data_from_csv()
	load_resource_data_from_csv()
	load_item_data_from_csv()
	load_equipment_data_from_csv()
	is_data_loaded = true
	print("游戏数据加载完成！")
	print_database_summary()

## 从CSV文件加载角色数据
func load_character_data_from_csv() -> void:
	var csv_path = "res://assets/character/card_data-人物.csv"
	var file = FileAccess.open(csv_path, FileAccess.READ)
	
	if not file:
		push_error("无法打开CSV文件: " + csv_path)
		return
	
	# 跳过标题行
	var header = file.get_csv_line()
	
	# 读取数据行
	var loaded_count = 0
	while not file.eof_reached():
		var line = file.get_csv_line()
		
		# 跳过空行
		if line.size() < 2 or line[0] == "":
			continue
		
		# 新的CSV格式：name,HP,ATK,DEF,left,right,bag1,bag2,bag3,bag4,bag5,bag6,picture_path
		var char_dict = {
			"type": "character",
			"name": line[0],  # name
			"hp": int(line[1]) if line.size() > 1 and line[1] != "" else 10,  # HP
			"atk": int(line[2]) if line.size() > 2 and line[2] != "" else 1,  # ATK
			"defense": int(line[3]) if line.size() > 3 and line[3] != "" else 0,  # DEF
			"left": line[4] if line.size() > 4 and line[4] != "" else "",  # left
			"right": line[5] if line.size() > 5 and line[5] != "" else "",  # right
			"bag1": line[6] if line.size() > 6 and line[6] != "" else "",  # bag1
			"bag2": line[7] if line.size() > 7 and line[7] != "" else "",  # bag2
			"bag3": line[8] if line.size() > 8 and line[8] != "" else "",  # bag3
			"bag4": line[9] if line.size() > 9 and line[9] != "" else "",  # bag4
			"bag5": line[10] if line.size() > 10 and line[10] != "" else "",  # bag5
			"bag6": line[11] if line.size() > 11 and line[11] != "" else "",  # bag6
			"texture_path": line[12] if line.size() > 12 and line[12] != "" else ""  # picture_path
		}
		
		# 使用 CharacterData 的静态方法创建资源
		var char_data = CharacterData.from_dict(char_dict)
		
		# 存储到数据库
		character_database[char_data.character_name] = char_data
		loaded_count += 1
		
		print("  加载角色: %s (HP:%d ATK:%d DEF:%d 左手:%s 右手:%s)" % [
			char_data.character_name, 
			char_data.max_hp, 
			char_data.atk, 
			char_data.defense,
			char_data.left,
			char_data.right
		])
	
	file.close()
	print("从CSV加载了 %d 个角色" % loaded_count)

## 获取指定角色数据
func get_character(char_name: String) -> CharacterData:
	if not character_database.has(char_name):
		push_warning("未找到角色数据: " + char_name)
		return null
	return character_database[char_name]

## 获取所有角色数据
func get_all_characters() -> Array[CharacterData]:
	var characters: Array[CharacterData] = []
	for char_data in character_database.values():
		characters.append(char_data)
	return characters

## 获取所有角色名称
func get_all_character_names() -> Array:
	return character_database.keys()

## 检查角色是否存在
func has_character(char_name: String) -> bool:
	return character_database.has(char_name)

## 从CSV文件加载遗物数据
func load_remains_data_from_csv() -> void:
	var csv_path = "res://assets/remains/card_data-遗物.csv"
	var file = FileAccess.open(csv_path, FileAccess.READ)
	
	if not file:
		push_error("无法打开CSV文件: " + csv_path)
		return
	
	# 跳过标题行
	var header = file.get_csv_line()
	
	# 读取数据行
	var loaded_count = 0
	while not file.eof_reached():
		var line = file.get_csv_line()
		
		# 跳过空行
		if line.size() < 2 or line[0] == "":
			continue
		
		var remains_dict = {
			"名称": line[0],
			"等级": line[1] if line.size() > 1 else "",
			"效果": line[2] if line.size() > 2 else "",
			"属性": line[3] if line.size() > 3 else "",
			"value": line[4] if line.size() > 4 else "0"
		}
		
		# 存储到数据库
		remains_database[remains_dict["名称"]] = remains_dict
		loaded_count += 1
		
		print("  加载遗物: %s (等级:%s 价值:%s)" % [
			remains_dict["名称"], 
			remains_dict["等级"], 
			remains_dict["value"]
		])
	
	file.close()
	print("从CSV加载了 %d 个遗物" % loaded_count)

## 从CSV文件加载场景数据
func load_scene_data_from_csv() -> void:
	var csv_path = "res://assets/terrain小地形/card_data-场景.csv"
	var file = FileAccess.open(csv_path, FileAccess.READ)
	
	if not file:
		push_error("无法打开CSV文件: " + csv_path)
		return
	
	# 跳过标题行
	var header = file.get_csv_line()
	
	# 读取数据行
	var loaded_count = 0
	while not file.eof_reached():
		var line = file.get_csv_line()
		
		# 跳过空行
		if line.size() < 2 or line[0] == "":
			continue
		
		var scene_dict = {
			"名称": line[0],
			"picture_path": line[1] if line.size() > 1 else "",
			"产物名": line[2] if line.size() > 2 else "",
			"出现概率": line[3] if line.size() > 3 else "",
			"产物": line[4] if line.size() > 4 else "",
			"地址": line[1] if line.size() > 1 else "",  # 图片路径（用于CardFactory）
			"card_scene": "res://assets/terrain小地形/scene_card.tscn"  # 场景卡片场景路径
		}
		
		# 存储到数据库
		scene_database[scene_dict["名称"]] = scene_dict
		loaded_count += 1
		
		print("  加载场景: %s (产物:%s)" % [
			scene_dict["名称"], 
			scene_dict["产物名"]
		])
	
	file.close()
	print("从CSV加载了 %d 个场景" % loaded_count)

## 获取指定遗物数据
func get_remains(remains_name: String) -> Dictionary:
	if not remains_database.has(remains_name):
		push_warning("未找到遗物数据: " + remains_name)
		return {}
	return remains_database[remains_name]

## 获取指定场景数据
func get_scene(scene_name: String) -> Dictionary:
	if not scene_database.has(scene_name):
		push_warning("未找到场景数据: " + scene_name)
		return {}
	return scene_database[scene_name]

## 从CSV文件加载资源数据
func load_resource_data_from_csv() -> void:
	var csv_path = "res://assets/resources/card_data-资源.csv"
	var file = FileAccess.open(csv_path, FileAccess.READ)
	
	if not file:
		push_error("无法打开CSV文件: " + csv_path)
		return
	
	# 跳过标题行
	var header = file.get_csv_line()
	
	# 读取数据行
	var loaded_count = 0
	while not file.eof_reached():
		var line = file.get_csv_line()
		
		# 跳过空行
		if line.size() < 2 or line[0] == "":
			continue
		
		var resource_dict = {
			"名称": line[0],
			"类型": line[1] if line.size() > 1 else "",
			"food": line[2] if line.size() > 2 else "0",
			"water": line[3] if line.size() > 3 else "0",
			"effect": line[4] if line.size() > 4 else "",
			"合成配方": line[5] if line.size() > 5 else "",
			"索引值": line[6] if line.size() > 6 else "",
			"value": line[7] if line.size() > 7 else "0",
			"是否是遗物": line[8] if line.size() > 8 else "FALSE",
			"地址": line[9] if line.size() > 9 else "",  # picture_path
			"card_scene": "res://assets/resources/resource_card.tscn"
		}
		
		# 存储到数据库
		resource_database[resource_dict["名称"]] = resource_dict
		loaded_count += 1
		
		print("  加载资源: %s (类型:%s 价值:%s)" % [
			resource_dict["名称"], 
			resource_dict["类型"], 
			resource_dict["value"]
		])
	
	file.close()
	print("从CSV加载了 %d 个资源" % loaded_count)

## 从CSV文件加载道具数据
func load_item_data_from_csv() -> void:
	var csv_path = "res://assets/item道具/card_data-道具.csv"
	var file = FileAccess.open(csv_path, FileAccess.READ)
	
	if not file:
		push_error("无法打开CSV文件: " + csv_path)
		return
	
	# 跳过标题行
	var header = file.get_csv_line()
	
	# 读取数据行
	var loaded_count = 0
	while not file.eof_reached():
		var line = file.get_csv_line()
		
		# 跳过空行
		if line.size() < 2 or line[0] == "":
			continue
		
		# CSV列顺序: 名称,描述文本,使用次数限制,是否是遗物,VALUE,picture_path,装备时,战斗中使用,使用效果,使用对象
		var item_dict = {
			"名称": line[0],
			"描述文本": line[1] if line.size() > 1 else "",
			"使用次数限制": line[2] if line.size() > 2 else "",
			"是否是遗物": line[3] if line.size() > 3 else "FALSE",
			"VALUE": line[4] if line.size() > 4 else "0",
			"地址": line[5] if line.size() > 5 else "",  # picture_path
			"装备时": line[6] if line.size() > 6 else "",
			"战斗中使用": line[7] if line.size() > 7 else "",
			"使用效果": line[8] if line.size() > 8 else "",
			"使用对象": line[9] if line.size() > 9 else "",
			"card_scene": "res://assets/item道具/item_card.tscn"
		}
		
		# 存储到数据库
		item_database[item_dict["名称"]] = item_dict
		loaded_count += 1
		
		print("  加载道具: %s (价值:%s 装备时:%s)" % [
			item_dict["名称"], 
			item_dict["VALUE"],
			item_dict["装备时"]
		])
	
	file.close()
	print("从CSV加载了 %d 个道具" % loaded_count)

## 从CSV文件加载装备数据
func load_equipment_data_from_csv() -> void:
	var csv_path = "res://assets/equipment/card_data-装备.csv"
	var file = FileAccess.open(csv_path, FileAccess.READ)
	
	if not file:
		push_error("无法打开CSV文件: " + csv_path)
		return
	
	# 跳过标题行
	var header = file.get_csv_line()
	
	# 读取数据行
	var loaded_count = 0
	while not file.eof_reached():
		var line = file.get_csv_line()
		
		# 跳过空行
		if line.size() < 2 or line[0] == "":
			continue
		
		var equipment_dict = {
			"名称": line[0],
			"类型": line[1] if line.size() > 1 else "",
			"效果": line[2] if line.size() > 2 else "",
			"索引值": line[3] if line.size() > 3 else "",
			"合成配方": line[4] if line.size() > 4 else "",
			"value": line[5] if line.size() > 5 else "0",
			"是否是遗物": line[6] if line.size() > 6 else "FALSE",
			"地址": line[7] if line.size() > 7 else "",  # picture_path
			"card_scene": "res://assets/equipment/equipment_card.tscn"
		}
		
		# 存储到数据库
		equipment_database[equipment_dict["名称"]] = equipment_dict
		loaded_count += 1
		
		print("  加载装备: %s (类型:%s 价值:%s)" % [
			equipment_dict["名称"], 
			equipment_dict["类型"], 
			equipment_dict["value"]
		])
	
	file.close()
	print("从CSV加载了 %d 个装备" % loaded_count)

## 获取指定资源数据
func get_resource(resource_name: String) -> Dictionary:
	if not resource_database.has(resource_name):
		push_warning("未找到资源数据: " + resource_name)
		return {}
	return resource_database[resource_name]

## 获取所有资源数据
func get_all_resources() -> Array:
	return resource_database.values()

## 获取指定道具数据
func get_item(item_name: String) -> Dictionary:
	if not item_database.has(item_name):
		push_warning("未找到道具数据: " + item_name)
		return {}
	return item_database[item_name]

## 获取所有道具数据
func get_all_items() -> Array:
	return item_database.values()

## 获取指定装备数据
func get_equipment(equipment_name: String) -> Dictionary:
	if not equipment_database.has(equipment_name):
		push_warning("未找到装备数据: " + equipment_name)
		return {}
	return equipment_database[equipment_name]

## 获取所有装备数据
func get_all_equipments() -> Array:
	return equipment_database.values()

## 获取所有商品数据（资源+道具+装备）
func get_all_shop_items() -> Array:
	var all_items = []
	all_items.append_array(get_all_resources())
	all_items.append_array(get_all_items())
	all_items.append_array(get_all_equipments())
	return all_items

## 打印数据库摘要信息
func print_database_summary() -> void:
	print("========== 游戏数据摘要 ==========")
	print("角色总数: %d" % character_database.size())
	print("角色列表: %s" % str(get_all_character_names()))
	print("遗物总数: %d" % remains_database.size())
	print("场景总数: %d" % scene_database.size())
	print("资源总数: %d" % resource_database.size())
	print("道具总数: %d" % item_database.size())
	print("装备总数: %d" % equipment_database.size())
	print("================================")

## 可选：重新加载数据（开发调试用）
func reload_data() -> void:
	character_database.clear()
	remains_database.clear()
	scene_database.clear()
	resource_database.clear()
	item_database.clear()
	equipment_database.clear()
	is_data_loaded = false
	load_all_game_data()

## 通用查找方法：在所有数据库中查找卡片数据
## 返回: {"data": 数据, "type": 类型字符串} 或空字典
func find_card_data(card_name: String) -> Dictionary:
	# 优先级顺序：遗物 > 资源 > 装备 > 场景 > 道具 > 角色
	
	# 1. 查找遗物
	if remains_database.has(card_name):
		return {"data": remains_database[card_name], "type": "remains"}
	
	# 2. 查找资源
	if resource_database.has(card_name):
		return {"data": resource_database[card_name], "type": "resource"}
	
	# 3. 查找装备
	if equipment_database.has(card_name):
		return {"data": equipment_database[card_name], "type": "equipment"}
	
	# 4. 查找场景
	if scene_database.has(card_name):
		return {"data": scene_database[card_name], "type": "scene"}
	
	# 5. 查找道具
	if item_database.has(card_name):
		return {"data": item_database[card_name], "type": "item"}
	
	# 6. 查找角色
	if character_database.has(card_name):
		return {"data": character_database[card_name], "type": "character"}
	
	# 未找到
	return {}
