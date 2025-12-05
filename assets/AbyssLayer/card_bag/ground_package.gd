@tool
extends Button
class_name CardPackage
signal package_bought(CardPackage)
@export var game_stats:GameStats
@export_multiline var package_name: String = ""  # 可导出的名称变量
@export var mean_layer:int
@export var package_price: int = 3  # 可导出的价格变量
## 卡牌生成延迟时间（秒）
@export var spawn_delay: float = 2.0
## 卡牌生成位置偏移（相对于当前位置向下）
@export var spawn_offset: Vector2 = Vector2(0, 120)
## 指定要生成的卡牌资源（CardInfo类型），如果为空则使用默认卡牌
@export var spawn_card_info: CardInfo = null

@onready var packagename: Label = %packagename
@onready var value: Label = %value
@onready var panel_3: Panel = $Panel3

# 默认卡牌场景预加载
var default_card_scene: PackedScene = preload("res://assets/card.tscn")

func _ready() -> void:
	_update_display()
	Events.max_layer_changed.connect(_update_state)
	_update_state()


func _update_display() -> void:
	# 更新名称和价格显示
	packagename.text = package_name
	value.text = str(package_price)

func _on_pressed() -> void:
	if game_stats.coins < package_price:
		return
	game_stats.coins -= package_price
	package_bought.emit()
	# 延迟生成卡牌
	_spawn_card_delayed()

## 延迟生成卡牌
func _spawn_card_delayed() -> void:
	# 创建计时器
	var timer = get_tree().create_timer(spawn_delay)
	await timer.timeout
	
	# 计时器结束后生成卡牌
	_spawn_card()

## 生成卡牌
func _spawn_card() -> void:
	# 根据卡牌资源类型选择正确的场景并实例化
	var card_instance = _create_card_instance()
	
	# 计算生成位置（当前位置的下方）
	var spawn_position = global_position + spawn_offset
	card_instance.global_position = spawn_position
	card_instance.z_index = 1
	
	# 将卡牌添加到Cards分组的根节点
	var cards_group = get_tree().get_first_node_in_group("Cards")
	if cards_group:
		cards_group.add_child(card_instance)
	print("卡牌已生成于位置: %s, 卡牌名称: %s" % [spawn_position, spawn_card_info.name if spawn_card_info else "默认"])

## 根据卡牌资源类型创建对应的卡牌实例
func _create_card_instance() -> Node:
	var instance = spawn_card_info.card_scene.instantiate()
	instance.set_stats(spawn_card_info)

	return instance
	
func _update_state() -> void:
	if game_stats.max_layer <= mean_layer:
		panel_3.show()
		set_disabled(true)  # 禁用按钮交互
	else:
		panel_3.hide()  # 隐藏面板
		set_disabled(false)  # 启用按钮交互
