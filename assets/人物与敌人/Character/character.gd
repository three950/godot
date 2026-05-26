class_name  Character
extends "res://assets/人物与敌人/biology.gd"

const DEFAULT_WEAPON_ICON: Texture2D = preload("res://presentation/ui/WEAPON.png")
const DEFAULT_armor_ICON: Texture2D = preload("res://presentation/ui/ARMOR.png")

# 信号：战斗开始
signal battlestart(enemy_node: Enemy, character_node: Character)
# 标记战斗是否已经开始（防止重复触发）
var _battle_started := false
@export var character: CharacterCard : set = set_character_stats# 引用 characters 目录下的资源

# 角色卡右上角的装备图标入口：武器和防具各占一个固定格子。
@onready var weapon_icon: TextureRect = get_node_or_null("CardColor/equips/weapon") as TextureRect
@onready var armor_icon: TextureRect = get_node_or_null("CardColor/equips/armor") as TextureRect

func _ready() -> void:
	super._ready()
	# 角色生成时发送食物需求更新信号
	if not Engine.is_editor_hint():
		Events.food_need_update.emit(2)

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

func get_battle_resource() -> BiologyCard:
	return character

func set_character_stats(value: CharacterCard) -> void:
	character = _create_runtime_character_card(value)
	if character != null:
		# 2D 人物卡是角色数据进入场景后的初始化入口；这里统一结算初始装备，保证独立 2D 卡和 3D SubViewport 卡一致。
		character.initialize_initial_equipment_state()
	_connect_and_update(character)

func _create_runtime_character_card(value: CharacterCard) -> CharacterCard:
	if value == null:
		return null
	if Engine.is_editor_hint():
		return value

	# 独立 2D 人物卡不会经过 Card3D._get_runtime_card_data()，所以这里也要确保不直接改原始 .tres。
	var runtime_character := value.create_runtime_instance() as CharacterCard
	if runtime_character == null:
		return value
	return runtime_character

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
	var weapon := character.武器
	var armor := character.防具

	if weapon_icon != null:
		# 装备拿走后，显式恢复场景默认武器图标，避免保留上一件装备的头像。
		weapon_icon.texture = weapon.portrait if weapon != null and weapon.portrait != null else DEFAULT_WEAPON_ICON

	if armor_icon != null:
		# 装备拿走后，显式恢复场景默认防具图标，避免保留上一件装备的头像。
		armor_icon.texture = armor.portrait if armor != null and armor.portrait != null else DEFAULT_armor_ICON

func 进入战斗状态() -> void:
	# 标记战斗已开始
	_battle_started = true
	z_index=1
	print("【character】已进入战斗状态")

func 退出战斗状态() -> void:
	# 重置战斗标记
	_battle_started = false
	print("【character】已退出战斗")
