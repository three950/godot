extends Card
class_name Small_Scene

@onready var label: Label = $Panel/Label
@onready var texture_rect: TextureRect = $TextureRect

@export var scene: SceneCard
@export var spawn_offset: Vector2 = Vector2(0, 360)
@export var cardpool: CardPool

var spawn_card_info: CardInfo


func set_stats(value: SceneCard) -> void:
	scene = value
	if is_node_ready():
		_update_item_card()


func _ready() -> void:
	super._ready()
	_update_item_card()


func _update_item_card() -> void:
	if scene == null:
		return
	label.text = scene.name
	texture_rect.texture = scene.portrait


func _spawn_card() -> void:
	var card_instance = _create_card_instance()
	var spawn_position = global_position + spawn_offset
	card_instance.z_index = 1

	var cards_group = get_tree().get_first_node_in_group("Cards")
	if cards_group:
		cards_group.add_child(card_instance)
	card_instance.global_position = global_position
	if card_instance.shooter:
		card_instance.shooter.play_card_shooter(spawn_position)
	print("卡牌已生成于位置: %s, 卡牌名称: %s" % [spawn_position, spawn_card_info.name if spawn_card_info else "默认"])


func _create_card_instance() -> Node:
	var instance = spawn_card_info.card_scene.instantiate()
	instance.set_stats(spawn_card_info)
	return instance
