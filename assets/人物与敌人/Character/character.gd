extends "res://assets/card.gd"

@export var character: CharacterCard : set = set_character_stats# 引用 characters 目录下的资源
var _needs_initial_update := false

@onready var name_label: Label = $Panel/Label
@onready var attribute_labels: AttributeLabels = $AttributeLabels
@onready var portrait_rect: TextureRect = $TextureRect


func _ready() -> void:
	super._ready()
	if _needs_initial_update:
		_needs_initial_update = false
		_update_character()


func set_character_stats(value: CharacterCard) -> void:
	character = value
	if character == null:
		return
	if not character.stats_changed.is_connected(update_stats):
		character.stats_changed.connect(update_stats)
	if is_node_ready():
		_update_character()
	else:
		_needs_initial_update = true

func _update_character() -> void:
	if character == null:
		return
	name_label.text = character.name
	portrait_rect.texture = character.portrait
	character.ATK=character.POW
	character.HP=character.MAX_HP
	update_stats()
	
func update_stats() -> void:
	if character == null:
		return
	attribute_labels.update_labels(character.HP, character.ATK, character.DEF)

func take_damage(damage:int) -> void:
	if character.HP <= 0:
		return
	character.take_damage(damage)
	if character.HP <=0:
		queue_free()
