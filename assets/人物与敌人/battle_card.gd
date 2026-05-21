extends Card
class_name BattleCard
# 战斗卡片的基类，包含 enemy 和 character 的共同功能

var _needs_initial_update := false

@onready var attribute_labels: AttributeLabels = $AttributeLabels

# 子类需要重写这个方法，返回 BattleStates 类型的资源
func get_battle_resource() -> BattleStates:
	return null

# 重写父类方法，返回战斗资源
func get_card_resource() -> CardInfo:
	return get_battle_resource()

# 子类需要重写这个方法，执行具体的更新逻辑（设置 HP 等战斗属性）
func _update_battle_card() -> void:
	# 调用父类通用更新方法（设置 name, cardname, label, texture）
	_update_card_display()
	_request_subviewport_redraw()

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
	if attribute_labels == null:
		return
	attribute_labels.update_labels(resource.HP, resource.ATK, resource.DEF)
	_request_subviewport_redraw()


func _request_subviewport_redraw() -> void:
	if not is_inside_tree():
		return

	var viewport := get_viewport() as SubViewport
	if viewport == null:
		return

	# 这张 2D 战斗卡如果被塞进 Card3D 的 SubViewport，数据变动时只要求刷新一帧。
	# 普通 2D 界面里的卡牌拿到的是主 Viewport，不会进入这里，避免影响主界面刷新策略。
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func take_damage(damage: int) -> void:
	var resource = get_battle_resource()
	if resource == null:
		return
	if resource.HP <= 0:
		return
	resource.take_damage(damage)
	if resource.HP <= 0:
		queue_free()
