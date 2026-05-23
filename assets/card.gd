extends Control
class_name Card

@onready var card_label: Label = $CardColor/Panel/Label
@onready var card_texture: TextureRect = $TextureRect

func _ready() -> void:
	# 多个子类会调用 super._ready()；Card 基类目前只保留这个稳定入口。
	pass


func get_card_resource() -> CardInfo:
	return null


func _update_card_display() -> void:
	var resource := get_card_resource()
	if resource == null:
		return

	name = resource.name

	if card_label:
		card_label.text = resource.name
	if card_texture:
		card_texture.texture = resource.portrait
