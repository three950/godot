extends Node
class_name BagArea
# 信号：当卡片被放入卡槽
signal card_placed(card: Card, slot_index: int)
# 信号：当卡片被移出卡槽
signal card_removed(card: Card, slot_index: int)
signal bag_item_changed
@onready var hand_slots: Array[BagSlot] = [
	$HBoxContainer/左右手/left,
	$HBoxContainer/左右手/right,
]

@onready var backpack_slots: Array[BagSlot] = [
	$HBoxContainer/背包/Slot1,
	$HBoxContainer/背包/Slot2,
	$HBoxContainer/背包/Slot3,
	$HBoxContainer/背包/Slot4,
	$HBoxContainer/背包/Slot5,
	$HBoxContainer/背包/Slot6,
]

# 当前背包所属的角色（在编辑器或运行时注入）
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
		push_error("BagPanel 未设置 character 资源")
		return
	_load_card(character.左右手, hand_slots)
	_load_card(character.背包, backpack_slots)
	
func _load_card(卡牌:Array,卡槽:Array[BagSlot]) -> void:
	for index in range(卡槽.size()):
		var slot := 卡槽[index]
		var card_resource:ThingsCard = 卡牌[index] if index < 卡牌.size() else null
		if card_resource == null:
			continue
		if card_resource != null:
			slot.show_card.emit(card_resource)
