extends "res://assets/card.gd"
@export var enemy: EnemyCard : set = set_enemy_stats# 引用 enemys 目录下的资源
var _needs_initial_update := false

@onready var name_label: Label = $Panel/Label
@onready var attribute_labels: AttributeLabels = $AttributeLabels
@onready var portrait_rect: TextureRect = $TextureRect


func _ready() -> void:
	super._ready()
	if _needs_initial_update:
		_needs_initial_update = false
		_update_enemy()


func set_enemy_stats(value: EnemyCard) -> void:
	enemy = value
	if enemy == null:
		return
	if not enemy.stats_changed.is_connected(update_stats):
		enemy.stats_changed.connect(update_stats)
	if is_node_ready():
		_update_enemy()
	else:
		_needs_initial_update = true

func _update_enemy() -> void:
	if enemy == null:
		return
	name_label.text = enemy.name
	portrait_rect.texture = enemy.portrait

	update_stats()
	
func update_stats() -> void:
	if enemy == null:
		return
	attribute_labels.update_labels(enemy.MAX_HP, enemy.ATK, enemy.DEF)
