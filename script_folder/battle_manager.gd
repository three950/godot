extends Node

# 战斗管理器 - 负责监听战斗开始信号并创建战斗场景

# 战斗场景预制体
const BATTLE_SCENE = preload("res://ui/battle_scene.tscn")

# 标记是否正在处理战斗开始（防止重复触发）
var _is_processing_battle := false

func _ready() -> void:
	# 监听全局战斗开始信号
	Events.battle_start_requested.connect(_battle_scene_prepare)
	print("【BattleManager】战斗管理器已初始化")

func _battle_scene_prepare(character: Character, enemy: Enemy) -> void:
	if _is_processing_battle:return
	
	_is_processing_battle = true
	print( character.name, " vs ", enemy.name)

	# 2. 记录 character 的全局位置
	var character_global_pos = character.global_position
	
	# 3. 从父节点暂时移除 character 和 enemy（不删除，只是移除）
	var character_parent = character.get_parent()
	var enemy_parent = enemy.get_parent()
	if character_parent:
		character_parent.remove_child(character)
	if enemy_parent:
		enemy_parent.remove_child(enemy)
	
	var active_battle_scene = BATTLE_SCENE.instantiate()	
	var cards_group = get_tree().get_first_node_in_group("Cards")
	if cards_group:
		cards_group.add_child(active_battle_scene)
	
	active_battle_scene.global_position = character_global_pos
	print("【BattleManager】战斗场景位置设置为人物卡位置: ", character_global_pos)
	
	var enemy_container = active_battle_scene.get_node("VBoxContainer/enemy")
	var character_container = active_battle_scene.get_node("VBoxContainer/character")
	
	enemy_container.add_child(enemy)
	character_container.add_child(character)
	print("【BattleManager】已将 character 和 enemy 添加到战斗场景")
	
	var card_size = (enemy.get_node("Panel")).size
	enemy.custom_minimum_size = card_size
	character.custom_minimum_size = card_size
	print("【BattleManager】已设置最小尺寸: ", card_size)
	
	_is_processing_battle = false
	_battle_start()
func _battle_start():
	pass
