class_name Enemy
extends Control

@export var _battle_started := false
# 敌人卡片资源
@export var enemy: EnemyCard : set = set_stats

# 标记是否需要在 _ready 时初始化
var _needs_initial_update := false

# 节点引用
@onready var attribute_labels: AttributeLabels = $AttributeLabels
@onready var card_label: Label = $cardColor/Panel/Label
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

# 更新属性标签显示（HP、ATK、DEF）
func update_stats() -> void:
	if enemy == null:return
	if attribute_labels == null:return
	
	attribute_labels.update_labels(enemy.HP, enemy.ATK, enemy.DEF)

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
