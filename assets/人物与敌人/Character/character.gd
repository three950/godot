extends "res://assets/card.gd"

@export var character: CharacterCard # 引用 characters 目录下的资源

@onready var name_label: Label = $ColorRect/Label
@onready var attribute_labels: AttributeLabels = $ColorRect/AttributeLabels
@onready var portrait_rect: TextureRect = $ColorRect/TextureRect

func _ready() -> void:
	super._ready()
	_apply_character_data()
	_connect_character_signals()

func _apply_character_data() -> void:
	if not character:
		push_warning("【CharacterCard】未分配角色资源")
		return
	_update_stats()

func _connect_character_signals() -> void:
	if character and not character.stats_changed.is_connected(_on_character_stats_changed):
		character.stats_changed.connect(_on_character_stats_changed)

func _on_character_stats_changed() -> void:
	if not is_inside_tree():
		await ready
	_update_stats()

func _update_attribute_labels() -> void:
	if not attribute_labels or not character:
		return

	attribute_labels.update_labels(character.HP, character.ATK, character.DEF)

func _update_stats() -> void:
	_update_attribute_labels()
	_update_name_label()
	_update_portrait()

func _update_name_label() -> void:
	if not name_label or not character:
		return

	var raw_name = _get_character_property("name")
	var display_name := ""

	if raw_name != null and str(raw_name).strip_edges() != "":
		display_name = str(raw_name)
	elif character.resource_name != "":
		display_name = character.resource_name
	else:
		display_name = name

	name_label.text = str(display_name)

func _update_portrait() -> void:
	if not portrait_rect or not character:
		return

	var portrait_texture: Texture2D = _get_character_property("portrait")
	if portrait_texture:
		portrait_rect.texture = portrait_texture

func _get_character_property(prop_name: String):
	if not character:
		return null

	for prop in character.get_property_list():
		if prop.has("name") and prop["name"] == prop_name:
			return character.get(prop_name)

	return null
