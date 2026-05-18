extends Control
class_name Card

@export var cardname: String
@export var battle: BattleState

@onready var shooter: Shooter = get_node_or_null("Shooter") as Shooter
@onready var card_label: Label = _find_card_label()
@onready var card_texture: TextureRect = _find_card_texture()
@onready var surface: TextureRect = get_node_or_null("surface") as TextureRect
@onready var shadow: TextureRect = get_node_or_null("shadow") as TextureRect
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer


func _ready() -> void:
	_make_materials_unique()


func _make_materials_unique() -> void:
	if surface and surface.material:
		surface.material = surface.material.duplicate()
	if shadow and shadow.material:
		shadow.material = shadow.material.duplicate()


func get_card_resource() -> CardInfo:
	return null


func _update_card_display() -> void:
	var resource := get_card_resource()
	if resource == null:
		return

	name = resource.name
	cardname = resource.name

	if card_label:
		card_label.text = resource.name
	if card_texture:
		card_texture.texture = resource.portrait


func _find_card_label() -> Label:
	var label := get_node_or_null("CardColor/Panel/Label") as Label
	if label:
		return label
	label = get_node_or_null("cardColor/Panel/Label") as Label
	if label:
		return label
	return find_child("Label", true, false) as Label


func _find_card_texture() -> TextureRect:
	return find_child("TextureRect", true, false) as TextureRect
