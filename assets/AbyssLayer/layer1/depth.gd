@tool
extends Card
class_name Depth
@onready var label: Label = $Panel/Label
@onready var texture_rect: TextureRect = $TextureRect
@onready var card_progress_bar: CardProgressBar = $CardProgressBar
var spawn_card_info:CardInfo
@export var depthcard: DepthCard
#生成卡牌相关
@export var spawn_offset: Vector2 = Vector2(0, 120)
@export var cardpool:CardPool
@export var gamestats:GameStats
func _ready() -> void:
	super._ready()
	_update_item_card()

func _update_item_card() -> void:
	if depthcard == null:
		return
	label.text = depthcard.name
	texture_rect.texture = depthcard.portrait

func bestacked_on_me(children: Card) -> void:
	super.bestacked_on_me(children)
	var type=gamestats.get_random_type_for_depth(depthcard.depth)
	spawn_card_info=cardpool.get_cards_by_type(type)
	_spawn_card()

## 生成卡牌
func _spawn_card() -> void:
	# 根据卡牌资源类型选择正确的场景并实例化
	var card_instance = _create_card_instance()
	
	# 计算生成位置（当前位置的下方）
	var spawn_position = global_position + spawn_offset
	card_instance.global_position = spawn_position
	card_instance.z_index = 1
	
	# 将卡牌添加到Cards分组的根节点
	var cards_group = get_tree().get_first_node_in_group("Cards")
	if cards_group:
		cards_group.add_child(card_instance)
	print("卡牌已生成于位置: %s, 卡牌名称: %s" % [spawn_position, spawn_card_info.name if spawn_card_info else "默认"])

## 根据卡牌资源类型创建对应的卡牌实例
func _create_card_instance() -> Node:
	var instance = spawn_card_info.card_scene.instantiate()
	instance.set_stats(spawn_card_info)
	return instance
