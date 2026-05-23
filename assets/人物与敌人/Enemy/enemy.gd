class_name Enemy
extends Control

@export var _battle_started := false
# 敌人卡片资源
@export var enemy: EnemyCard : set = set_stats

# 标记是否需要在 _ready 时初始化
var _needs_initial_update := false

# 节点引用：数值直接更新到标签节点，不再经过 AttributeLabels 脚本中转。
@onready var hp_label: Label = get_node_or_null("%HPLabel") as Label
@onready var atk_label: Label = get_node_or_null("%ATKLabel") as Label
@onready var def_label: Label = get_node_or_null("%DEFLabel") as Label
@onready var card_label: Label = $CardColor/Panel/Label
@onready var card_texture: TextureRect = $TextureRect

func _ready() -> void:
	if _needs_initial_update:
		_needs_initial_update = false
		_update_enemy_display()

# 返回敌人的战斗资源
func get_battle_resource() -> BattleStates:
	return enemy

# 设置敌人属性（当通过编辑器或代码设置 enemy 时自动调用）
func set_stats(value: EnemyCard) -> void:
	enemy = value
	_connect_and_update(enemy)

# 连接信号并更新显示
func _connect_and_update(resource: EnemyCard) -> void:
	if resource == null:
		return
	
	# 连接资源的 stats_changed 信号到 update_stats 方法
	if not resource.stats_changed.is_connected(update_stats):
		resource.stats_changed.connect(update_stats)
	
	# 如果节点已准备好，立即更新；否则标记为需要更新
	if is_node_ready():
		_update_enemy_display()
	else:
		_needs_initial_update = true

# 更新敌人的显示（名称、纹理、HP等）
func _update_enemy_display() -> void:
	if enemy == null:return
	
	name = enemy.name
	card_label.text = enemy.name
	card_texture.texture = enemy.portrait	
	enemy.HP = enemy.MAX_HP
	update_stats()
	_request_subviewport_redraw()

# 更新属性标签显示（HP、ATK、DEF）
func update_stats() -> void:
	if enemy == null:return
	if hp_label == null or atk_label == null or def_label == null:return
	
	hp_label.text = str(enemy.HP)
	atk_label.text = str(enemy.ATK)
	def_label.text = str(enemy.DEF)
	_request_subviewport_redraw()


func _request_subviewport_redraw() -> void:
	if not is_inside_tree():
		return

	var viewport := get_viewport() as SubViewport
	if viewport == null:
		return

	# 敌人卡的 HP/ATK/DEF 变化时只让承载它的 SubViewport 刷新一帧，比 UPDATE_ALWAYS 更省。
	# 如果敌人卡直接显示在普通 2D 界面里，这里拿不到 SubViewport，因此不会改主窗口的刷新模式。
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

# 受到伤害
func take_damage(damage: int) -> void:
	if enemy == null:return
	if enemy.HP <= 0:return

	enemy.take_damage(damage)

	if enemy.HP <= 0:
		queue_free()

# 治疗
func heal(amount: int) -> void:
	if enemy == null:
		return
	
	enemy.heal(amount)

# 退出战斗状态
func 退出战斗状态() -> void:
	_battle_started = false
