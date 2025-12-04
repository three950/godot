extends "res://assets/card.gd"
class_name Item
@onready var label: Label = $Panel/Label
@onready var texture_rect: TextureRect = $TextureRect
@onready var value_label: Label = $ValueLabel

var _needs_initial_update := false

@export var item: ItemCard : set = set_item_stats

func set_item_stats(value: ItemCard) -> void:
	item = value
	_connect_and_update(item)
	
func _connect_and_update(resource: CardInfo) -> void:
	if resource == null:
		return
	if is_node_ready():
		_update_item_card()
	else:
		_needs_initial_update = true

func _update_item_card() -> void:
	if item == null:
		return
	label.text = item.name
	texture_rect.texture = item.portrait
	value_label.text = str(item.value)

func _ready() -> void:
	super._ready()
	if _needs_initial_update:
		_needs_initial_update = false
		_update_item_card()

# 更新属性显示
func update_stats() -> void:
	if item == null:
		return
	value_label.text = str(item.value)
