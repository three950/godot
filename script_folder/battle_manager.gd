extends Node

# 战斗管理器 - 负责监听战斗开始信号并创建战斗场景

# 战斗场景预制体
const BATTLE_SCENE = preload("res://ui/battle_scene.tscn")

func _ready() -> void:
	# 监听全局战斗开始信号
	Events.battle_start_requested.connect(_on_battle_start_requested)
	print("【BattleManager】战斗管理器已初始化")

func _on_battle_start_requested(character: Character, enemy: Enemy) -> void:
	print("【BattleManager】收到战斗开始请求: ", character.name, " vs ", enemy.name)

	# 1. 记录 character 的全局位置
	var character_global_pos = character.global_position
	print("【BattleManager】记录人物卡全局位置: ", character_global_pos)
	
	# 2. 从父节点暂时移除 character 和 enemy（不删除，只是移除）
	var character_parent = character.get_parent()
	var enemy_parent = enemy.get_parent()
	
	if character_parent:
		character_parent.remove_child(character)
		print("【BattleManager】已从父节点移除 character")
	
	if enemy_parent:
		enemy_parent.remove_child(enemy)
		print("【BattleManager】已从父节点移除 enemy")
	
	# 3. 创建新的战斗场景实例
	var active_battle_scene = BATTLE_SCENE.instantiate()
	
	# 添加到场景树（添加到Cards组或者根节点）
	var cards_group = get_tree().get_first_node_in_group("Cards")
	if cards_group:
		cards_group.add_child(active_battle_scene)
	else:
		# 如果没有Cards组，添加到根节点
		get_tree().root.add_child(active_battle_scene)
	
	# 4. 设置战斗场景的位置为人物卡的全局位置
	active_battle_scene.global_position = character_global_pos
	print("【BattleManager】战斗场景位置设置为人物卡位置: ", character_global_pos)
	
	# 5. 初始化战斗（会将 character 和 enemy 添加到对应的容器中）
	active_battle_scene.setup_battle(character, enemy)
	
	print("【BattleManager】战斗场景已创建并初始化")
