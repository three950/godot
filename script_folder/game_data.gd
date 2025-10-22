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
		
		if line[0] == "character":
			var char_dict = {
				"type": line[0],
				"name": line[1],
				"hp": int(line[2]) if line.size() > 2 and line[2] != "" else 10,
				"atk": int(line[3]) if line.size() > 3 and line[3] != "" else 1,
				"defense": int(line[4]) if line.size() > 4 and line[4] != "" else 0,
				"equipment": line[5] if line.size() > 5 else "",
				"texture_path": line[7] if line.size() > 6 else ""
			}
			
			# 使用 CharacterData 的静态方法创建资源
			var char_data = CharacterData.from_dict(char_dict)
			
			# 存储到数据库
			character_database[char_data.character_name] = char_data
			loaded_count += 1
			
			print("  加载角色: %s (HP:%d ATK:%d DEF:%d)" % [
				char_data.character_name, 
				char_data.max_hp, 
				char_data.atk, 
				char_data.defense
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
			"产物": line[4] if line.size() > 4 else ""
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

## 打印数据库摘要信息
func print_database_summary() -> void:
	print("========== 游戏数据摘要 ==========")
	print("角色总数: %d" % character_database.size())
	print("角色列表: %s" % str(get_all_character_names()))
	print("遗物总数: %d" % remains_database.size())
	print("场景总数: %d" % scene_database.size())
	print("================================")

## 可选：重新加载数据（开发调试用）
func reload_data() -> void:
	character_database.clear()
	remains_database.clear()
	scene_database.clear()
	is_data_loaded = false
	load_all_game_data()
