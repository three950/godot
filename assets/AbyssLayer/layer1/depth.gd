@tool
extends Card
class_name Depth
@onready var label: Label = $Panel/Label
@onready var texture_rect: TextureRect = $TextureRect
@onready var card_progress_bar: CardProgressBar = $CardProgressBar

@export var depth: DepthCard
	
func _ready() -> void:
	super._ready()
	_update_item_card()

func _update_item_card() -> void:
	if depth == null:
		return
	label.text = depth.name
	texture_rect.texture = depth.portrait

func bestacked_on_me(children: Card) -> void:
	super.bestacked_on_me(children)
	
