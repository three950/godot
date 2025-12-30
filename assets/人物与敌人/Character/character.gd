class_name  Character
extends "res://assets/人物与敌人/battle_card.gd"

# 信号：战斗开始
signal battlestart(enemy_node: Enemy, character_node: Character)
@onready var battle_start_area: Area2D = $BattleStartArea
# 标记战斗是否已经开始（防止重复触发）
var _battle_started := false
@export var character: CharacterCard : set = set_character_stats# 引用 characters 目录下的资源

func _ready() -> void:
	super._ready()
	# 角色生成时发送食物需求更新信号
	if not Engine.is_editor_hint():
		Events.food_need_update.emit(2)
		_update_features()
	battle = battle.duplicate()

func _exit_tree() -> void:
	# 角色被删除时发送食物需求减少信号（排除拖拽时的 reparent 情况）
	if is_queued_for_deletion():
		Events.food_need_update.emit(-2)

func get_battle_resource() -> BattleStates:
	return character

func set_character_stats(value: CharacterCard) -> void:
	character = value
	_connect_and_update(character)

func _update_battle_card() -> void:
	if character == null:
		return
	super._update_battle_card()
	character.HP = character.MAX_HP
	update_stats()

func _update_features() -> void:
	for card in character.左右手:
		if card is ThingsCard:
			if card.添加特性 != "" and not character.特性.has(card.添加特性):
				character.特性.append(card.添加特性)
				print("【Character】初始化添加特性：", card.添加特性, " 当前特性：", character.特性)

		if card is EquipmentCard:
			print("【Character】初始化添加装备效果：", card.equip_type, " 当前装备效果：", card.equip_effect)
			if card.need_power < character.POW:
				print("【Character】力量足够，添加装备效果：", card.equip_type, " 当前装备效果：", card.equip_effect)
				match card.equip_type:
					0:character.ATK += card.equip_effect
					1:character.DEF += card.equip_effect
					
func _on_battle_start_area_area_entered(area: Area2D) -> void:
	# 检测到碰撞时，发出战斗开始信号
	var enemy = area.get_parent()
	if _battle_started or enemy._battle_started:return
	print("【character】检测到与角色碰撞，发出全局战斗开始请求")
	enemy._battle_started = true
	进入战斗状态()
	Events.battle_start_requested.emit(self, enemy)

func 进入战斗状态() -> void:
	# 标记战斗已开始
	_battle_started = true
	battle_start_area.monitoring = false
	battle_start_area.monitorable = false
	#切换到fixed状态
	var state_machine = get_node("CardStateMachine")
	var fixed_state = state_machine.states[CardState.State.fixed]
	if state_machine.current_state:
		state_machine.current_state.exit()
	if follow_target:
		follow_target.children_card=null
		follow_target=null
	fixed_state.enter()
	z_index=1
	state_machine.current_state = fixed_state
	print("【character】已强制切换到 fixed 状态")

func 退出战斗状态() -> void:
	# 重置战斗标记
	_battle_started = false
	battle_start_area.monitoring = true
	battle_start_area.monitorable = true
	# 切换回 fixed 状态（默认空闲状态）
	var state_machine = get_node("CardStateMachine")
	var fixed_state = state_machine.states[CardState.State.fixed]
	if state_machine.current_state:
		state_machine.current_state.exit()
	fixed_state.enter()
	state_machine.current_state = fixed_state
	print("【character】已退出战斗，恢复为 fixed 状态")
