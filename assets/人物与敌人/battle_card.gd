extends "res://assets/card.gd"
# 战斗卡片的基类，包含 enemy 和 character 的共同功能

var _needs_initial_update := false

@onready var name_label: Label = $Panel/Label
@onready var attribute_labels: AttributeLabels = $AttributeLabels
@onready var portrait_rect: TextureRect = $TextureRect

# 子类需要重写这个方法，返回 BattleStates 类型的资源
func get_battle_resource() -> BattleStates:
	return null

# 子类需要重写这个方法，执行具体的更新逻辑（设置 name, portrait, HP 等）
func _update_battle_card() -> void:
	pass

func _ready() -> void:
	super._ready()
	if _needs_initial_update:
		_needs_initial_update = false
		_update_battle_card()

func _connect_and_update(resource: BattleStates) -> void:
	if resource == null:
		return
	if not resource.stats_changed.is_connected(update_stats):
		resource.stats_changed.connect(update_stats)
	if is_node_ready():
		_update_battle_card()
	else:
		_needs_initial_update = true

func update_stats() -> void:
	var resource = get_battle_resource()
	if resource == null:
		return
	attribute_labels.update_labels(resource.HP, resource.ATK, resource.DEF)

func take_damage(damage: int) -> void:
	var resource = get_battle_resource()
	if resource == null:
		return
	if resource.HP <= 0:
		return
	resource.take_damage(damage)
	if resource.HP <= 0:
		queue_free()
