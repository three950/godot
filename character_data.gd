extends Resource
class_name CharacterData

## 角色数据资源类
## 用于存储单个角色的所有属性信息

# 基础信息
@export var character_name: String = ""
@export_multiline var description: String = ""

# 属性
@export_group("属性")
@export var max_hp: int = 10
@export var atk: int = 1
@export var defense: int = 0

# 装备
@export_group("装备")
@export var equipment: String = ""

# 视觉
@export_group("视觉")
@export var character_texture: Texture2D
@export var texture_path: String = ""

# 可选：扩展属性
@export_group("扩展属性")
@export var character_type: String = "character"
@export var rarity: int = 1  # 稀有度：1-普通, 2-稀有, 3-史诗, 4-传说
@export var cost: int = 0  # 使用成本

## 从字典创建角色数据（用于从CSV加载）
static func from_dict(data: Dictionary) -> CharacterData:
	var char_data = CharacterData.new()
	char_data.character_name = data.get("name", "")
	char_data.max_hp = data.get("hp", 10)
	char_data.atk = data.get("atk", 1)
	char_data.defense = data.get("defense", 0)
	char_data.equipment = data.get("equipment", "")
	char_data.texture_path = data.get("texture_path", "")
	char_data.character_type = data.get("type", "character")
	
	# 加载纹理
	if char_data.texture_path != "":
		var texture = load(char_data.texture_path)
		if texture:
			char_data.character_texture = texture
	
	return char_data

## 转换为字典（用于保存或网络传输）
func to_dict() -> Dictionary:
	return {
		"name": character_name,
		"hp": max_hp,
		"atk": atk,
		"defense": defense,
		"equipment": equipment,
		"texture_path": texture_path,
		"type": character_type,
		"rarity": rarity,
		"cost": cost
	}

