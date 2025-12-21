@tool
class_name Enemy
extends Control

# 信号：战斗开始
signal battlestart(enemy_node: Enemy, character_node: Character)

# 敌人卡片资源
@export var enemy: EnemyCard : set = set_stats

# 标记是否需要在 _ready 时初始化
var _needs_initial_update := false

# 标记战斗是否已经开始（防止重复触发）
var _battle_started := false

# 节点引用
@onready var attribute_labels: AttributeLabels = $AttributeLabels
@onready var card_label: Label = $Panel/Label
@onready var card_texture: TextureRect = $TextureRect
@onready var battle_start_area: Area2D = $BattleStartArea

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


func _on_battle_start_area_area_entered(area: Area2D) -> void:
	# 检测到碰撞时，发出战斗开始信号
	var other_node = area.get_parent()
	if other_node is Character:
		# 检查战斗是否已经开始，避免重复触发
		if _battle_started:
			return
		
		print("【Enemy】检测到与角色碰撞，发出全局战斗开始请求")
		# 标记战斗已开始
		_battle_started = true
		# 先禁用碰撞检测，防止重复触发
		battle_start_area.monitoring = false
		battle_start_area.monitorable = false
		Events.battle_start_requested.emit(other_node, self)
		
