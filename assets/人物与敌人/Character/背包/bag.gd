extends Node
class_name BagArea
# 信号：当卡片被放入卡槽
signal card_placed(card: Card, slot_index: int)
# 信号：当卡片被移出卡槽
signal card_removed(card: Card, slot_index: int)
signal bag_item_changed
@onready var hand_slots: Array[BagSlot] = [
	$HBoxContainer/武器/weapon,
]

@onready var backpack_slots: Array[BagSlot] = [
	$HBoxContainer/防具/armour,
]

# 当前防具所属的角色（在编辑器或运行时注入）
@export var character: CharacterCard = null

var _cards_loaded: bool = false

func _ready() -> void:
	# 只在第一次加载卡片
	if not _cards_loaded:
		_load_all_cards()
		_cards_loaded = true

func _enter_tree() -> void:
	# 每次进入场景树时都注册
	add_to_group("BagArea")
	Events.bag_registered.emit(self)
	print("【BagArea】已注册到事件系统")

func _exit_tree() -> void:
	remove_from_group("BagArea")
	Events.bag_unregistered.emit(self)
	print("【BagArea】已从事件系统注销")
	
func _load_all_cards():
	if character == null:
		# 背包通常由角色按钮实例化后注入 character；单独预览 bag.tscn 时允许为空。
		push_warning("BagPanel 未设置 character 资源")
		return
	# 人物背包现在只有两个有效槽位：武器[0] 和 防具[0]，旧的多槽数据不再生成到 UI。
	_load_card(character.武器, hand_slots)
	_load_card(character.防具, backpack_slots)
	
func _load_card(卡牌:Array,卡槽:Array[BagSlot]) -> void:
	for index in range(卡槽.size()):
		var slot := 卡槽[index]
		var card_resource:ThingsCard = 卡牌[index] if index < 卡牌.size() else null
		if card_resource == null:
			continue
		if card_resource != null:
			slot.show_card.emit(card_resource)

func sync_character_equipment_from_slots() -> void:
	if character == null:
		return

	# 以当前两个槽位里的真实卡片为准，反写到 CharacterCard。
	# 这样拖拽换装后，角色资源、角色数值和卡面装备图标都使用同一份数据。
	character.武器 = _collect_slot_resources(hand_slots)
	character.防具 = _collect_slot_resources(backpack_slots)
	bag_item_changed.emit()

	var owner_character := _find_owner_character()
	if owner_character != null:
		owner_character.refresh_equipment_ui()

func _collect_slot_resources(slots: Array[BagSlot]) -> Array[ThingsCard]:
	var result: Array[ThingsCard] = []
	for slot in slots:
		var card := slot.get_card()
		if card == null:
			result.append(null)
			continue

		var card_resource := card.get_card_resource()
		if card_resource is ThingsCard:
			result.append(card_resource as ThingsCard)
		else:
			result.append(null)
	return result

func _find_owner_character() -> Character:
	var node: Node = self
	while node != null:
		if node is Character:
			return node as Character
		node = node.get_parent()
	return null
