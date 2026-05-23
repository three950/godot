class_name  Character
extends "res://assets/人物与敌人/battle_card.gd"

const DEFAULT_WEAPON_ICON: Texture2D = preload("res://presentation/ui/WEAPON.png")
const DEFAULT_ARMOUR_ICON: Texture2D = preload("res://presentation/ui/ARMOR.png")

# 信号：战斗开始
signal battlestart(enemy_node: Enemy, character_node: Character)
# 标记战斗是否已经开始（防止重复触发）
var _battle_started := false
@export var character: CharacterCard : set = set_character_stats# 引用 characters 目录下的资源

# 角色卡右上角的装备图标入口：武器和防具各占一个固定格子。
@onready var weapon_icon: TextureRect = get_node_or_null("CardColor/equips/weapon") as TextureRect
@onready var armour_icon: TextureRect = get_node_or_null("CardColor/equips/armour") as TextureRect

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

func update_stats() -> void:
	# 先复用战斗卡基类的生命值刷新，再补充角色专属的装备 UI。
	super.update_stats()
	refresh_equipment_ui()

func refresh_equipment_ui() -> void:
	# 背包槽位变动时会直接调用这里，确保 2D UI 和 3D 卡牌 SubViewport 同步刷新一帧。
	_update_equipment_icon()
	_request_subviewport_redraw()

func _update_equipment_icon() -> void:
	var weapon = character.武器[0] if character.武器.size() > 0 else null
	var armour = character.防具[0] if character.防具.size() > 0 else null

	if weapon_icon != null:
		# 装备拿走后，显式恢复场景默认武器图标，避免保留上一件装备的头像。
		weapon_icon.texture = weapon.portrait if weapon != null and weapon.portrait != null else DEFAULT_WEAPON_ICON

	if armour_icon != null:
		# 装备拿走后，显式恢复场景默认防具图标，避免保留上一件装备的头像。
		armour_icon.texture = armour.portrait if armour != null and armour.portrait != null else DEFAULT_ARMOUR_ICON

func _get_equipped_things_cards() -> Array[ThingsCard]:
	var result: Array[ThingsCard] = []
	if character == null:
		return result

	# 角色当前的装备来源只有两个有效位置：武器[0] 和 防具[0]。
	# 仍然返回数组，是为了复用初始化特性和装备数值的通用循环。
	var weapon_card := character.武器[0]
	if weapon_card != null:
		result.append(weapon_card)

	var armour_card := character.防具[0]
	if armour_card != null:
		result.append(armour_card)

	return result

func _update_features() -> void:
	for card in _get_equipped_things_cards():
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
	z_index=1
	print("【character】已进入战斗状态")

func 退出战斗状态() -> void:
	# 重置战斗标记
	_battle_started = false
	print("【character】已退出战斗")
