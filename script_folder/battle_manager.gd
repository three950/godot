extends Node

# 战斗管理器 - 负责监听战斗开始信号并创建战斗场景

# 战斗场景预制体
const BATTLE_SCENE = preload("res://ui/battle_scene.tscn")

# 标记是否正在处理战斗开始（防止重复触发）
var _is_processing_battle := false

func _ready() -> void:
	# 监听全局战斗开始信号
	Events.battle_start_requested.connect(_on_battle_start_requested)
	print("【BattleManager】战斗管理器已初始化")

func _on_battle_start_requested(character: Character, enemy: Enemy) -> void:
	# 检查是否已经在处理战斗，避免重复创建战斗场景
	if _is_processing_battle:
		print("【BattleManager】战斗正在处理中，忽略重复请求")
		return
	
	_is_processing_battle = true
	print("【BattleManager】收到战斗开始请求: ", character.name, " vs ", enemy.name)

	# 0. 立即将 character 状态切换为 fixed，停止拖拽
	if character.has_node("CardStateMachine"):
		var state_machine = character.get_node("CardStateMachine")
		if state_machine.states.has(CardState.State.fixed):
			var fixed_state = state_machine.states[CardState.State.fixed]
			if state_machine.current_state:
				state_machine.current_state.exit()
			fixed_state.enter()
			state_machine.current_state = fixed_state
			print("【BattleManager】已强制 character 切换到 fixed 状态")
	
	if character.has_node("BattleStartArea"):
		var char_area = character.get_node("BattleStartArea")
		char_area.monitoring = false
		char_area.monitorable = false
		print("【BattleManager】已禁用 character 的战斗检测区域")
	
	if enemy.has_node("BattleStartArea"):
		var enemy_area = enemy.get_node("BattleStartArea")
		enemy_area.monitoring = false
		enemy_area.monitorable = false
		print("【BattleManager】已禁用 enemy 的战斗检测区域")

	# 2. 记录 character 的全局位置
	var character_global_pos = character.global_position
	print("【BattleManager】记录人物卡全局位置: ", character_global_pos)
	
	# 3. 从父节点暂时移除 character 和 enemy（不删除，只是移除）
	var character_parent = character.get_parent()
	var enemy_parent = enemy.get_parent()
	
	if character_parent:
		character_parent.remove_child(character)
		print("【BattleManager】已从父节点移除 character")
	
	if enemy_parent:
		enemy_parent.remove_child(enemy)
		print("【BattleManager】已从父节点移除 enemy")
	
	# 4. 创建新的战斗场景实例
	var active_battle_scene = BATTLE_SCENE.instantiate()
	
	# 添加到场景树（添加到Cards组或者根节点）
	var cards_group = get_tree().get_first_node_in_group("Cards")
	if cards_group:
		cards_group.add_child(active_battle_scene)
	else:
		# 如果没有Cards组，添加到根节点
		get_tree().root.add_child(active_battle_scene)
	
	# 5. 设置战斗场景的位置为人物卡的全局位置
	active_battle_scene.global_position = character_global_pos
	print("【BattleManager】战斗场景位置设置为人物卡位置: ", character_global_pos)
	
	# 6. 将 character 和 enemy 添加到战斗场景的对应容器中
	var enemy_container = active_battle_scene.get_node("VBoxContainer/enemy")
	var character_container = active_battle_scene.get_node("VBoxContainer/character")
	
	enemy_container.add_child(enemy)
	character_container.add_child(character)
	print("【BattleManager】已将 character 和 enemy 添加到战斗场景")
	
	# 7. 设置卡牌的最小尺寸以确保能接受鼠标事件
	# 为 enemy 设置最小尺寸
	if enemy.has_node("Panel"):
		var enemy_panel = enemy.get_node("Panel")
		var enemy_size = enemy_panel.size
		if enemy is Control:
			enemy.custom_minimum_size = enemy_size
			print("【BattleManager】已设置 enemy 最小尺寸: ", enemy_size)
	
	# 为 character 设置最小尺寸
	if character.has_node("Panel"):
		var character_panel = character.get_node("Panel")
		var character_size = character_panel.size
		if character is Control:
			character.custom_minimum_size = character_size
			print("【BattleManager】已设置 character 最小尺寸: ", character_size)
	
	print("【BattleManager】战斗场景已创建并初始化")
	
	# 处理完成后，等待一帧再重置标志（确保所有物理碰撞检测都已处理完）
	await get_tree().process_frame
	_is_processing_battle = false
