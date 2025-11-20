extends "res://assets/card.gd"

@export var character: CharacterCard # 引用 characters 目录下的资源

@onready var name_label: Label = $ColorRect/Label
@onready var attribute_labels: AttributeLabels = $ColorRect/AttributeLabels

func _ready() -> void:
	super._ready()
	_apply_character_data()
	_connect_character_signals()

func _apply_character_data() -> void:
	if not character:
		push_warning("【CharacterCard】未分配角色资源")
		return

	_update_name_label()
	_update_attribute_labels()

func _connect_character_signals() -> void:
	if character and not character.stats_changed.is_connected(_on_character_stats_changed):
		character.stats_changed.connect(_on_character_stats_changed)

func _on_character_stats_changed() -> void:
	_update_attribute_labels()

func _update_name_label() -> void:
	if not name_label:
		return

	var display_name := ""

	if character.has_meta("display_name"):
		display_name = str(character.get_meta("display_name"))
	elif character.resource_name != "":
		display_name = character.resource_name
	elif character.resource_path != "":
		display_name = character.resource_path.get_file().get_basename()
	else:
		display_name = name

	name_label.text = display_name

func _update_attribute_labels() -> void:
	if not attribute_labels or not character:
		return

	attribute_labels.update_labels(character.HP, character.ATK, character.DEF)