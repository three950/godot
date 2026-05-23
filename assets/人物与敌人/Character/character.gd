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
	# 角色被删除时发送食物需求减少信号。
	# 3D 化后 Character 常作为 Card3D/SubViewport 的子节点存在，战斗死亡释放的是外层 Card3D。
	# 这里只关心父级链路被释放的情况；普通拖拽 reparent 不会命中这个条件。
	if _is_parent_deleting():
		Events.food_need_update.emit(-2)

func _is_parent_deleting() -> bool:
	var node: Node = get_parent()
	while node != null:
		if node.is_queued_for_deletion():
			return true
		node = node.get_parent()
	return false

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


func 进入战斗状态() -> void:
	# 标记战斗已开始
	_battle_started = true
	battle_start_area.monitoring = false
	battle_start_area.monitorable = false
	z_index=1
	print("【character】已进入战斗状态")

func 退出战斗状态() -> void:
	# 重置战斗标记
	_battle_started = false
	battle_start_area.monitoring = true
	battle_start_area.monitorable = true
	print("【character】已退出战斗")
