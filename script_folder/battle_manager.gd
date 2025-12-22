extends Node
# 战斗管理器 - 负责监听战斗开始信号并创建战斗场景

# 战斗场景预制体
const BATTLE_SCENE = preload("res://ui/battle_scene.tscn")

# 标记是否正在处理战斗开始（防止重复触发）
var _is_processing_battle := false

# 绑定的战斗场景实例及其容器引用
var active_battle_scene: Control = null
var enemy_container: Control = null
var character_container: Control = null

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
	
	active_battle_scene = BATTLE_SCENE.instantiate()	
	var cards_group = get_tree().get_first_node_in_group("Cards")
	if cards_group:
		cards_group.add_child(active_battle_scene)
	
	# 连接战斗场景的 new_unit_join 信号
	active_battle_scene.new_unit_join.connect(_new_unit_join)
	
	active_battle_scene.global_position = character_global_pos
	print("【BattleManager】战斗场景位置设置为人物卡位置: ", character_global_pos)
	
	# 缓存容器引用，供后续单位加入使用
	enemy_container = active_battle_scene.get_node("VBoxContainer/enemy")
	character_container = active_battle_scene.get_node("VBoxContainer/character")
	
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
func _new_unit_join(unit: Control) -> void:
	if unit is Character:
		unit.进入战斗状态()
	# 从原父节点移除
	var unit_parent = unit.get_parent()
	if unit_parent:
		unit_parent.remove_child(unit)
	
	# 根据单位类型添加到对应容器
	if unit is Character:
		character_container.add_child(unit)
		print("【BattleManager】角色 %s 加入战斗" % unit.name)
	elif unit is Enemy:
		enemy_container.add_child(unit)
		print("【BattleManager】敌人 %s 加入战斗" % unit.name)
	
	# 设置最小尺寸
	var panel = unit.get_node_or_null("Panel")
	if panel:
		unit.custom_minimum_size = panel.size
