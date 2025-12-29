extends Node2D
class_name LayerCardBag
@export var bagresource:BagResource
var CardMember = 4
@onready var layername_label: Label = $Panel/layername
@onready var texture_rect: TextureRect = $Panel/TextureRect
@onready var panel: Panel = $Panel

## 层级名称映射表
const LAYER_NAMES: Dictionary = {
	0: "巨穴之口",
	1: "阿比斯之渊",
	2: "诱惑之森",
	3: "大断层",
	4: "巨人之杯",
	5: "亡骸之海",
	6: "来无回之都"
}

var _pending_layer: int = 0

## 拖拽相关变量
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _original_z_index: int = 0
var _press_time: int = 0
const CLICK_THRESHOLD_MS: int = 200  # 点击判定阈值（毫秒）

func _ready() -> void:
	_update_display()

## 根据层级设置层级名称
func set_layer(mean_layer: int) -> void:
	_pending_layer = mean_layer
	if is_node_ready():
		_update_display()

func _update_display() -> void:
	layername_label.text = LAYER_NAMES.get(_pending_layer, "未知深度")

func _on_panel_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("LMB"):
		_is_dragging = true
		_drag_offset = get_global_mouse_position() - global_position
		_original_z_index = z_index
		z_index = 100
		_press_time = Time.get_ticks_msec()
	elif event.is_action_released("LMB"):
		if _is_dragging:
			_is_dragging = false
			z_index = _original_z_index
			# 判断是否为点击（按下到释放时间短）
			var elapsed_time = Time.get_ticks_msec() - _press_time
			if elapsed_time < CLICK_THRESHOLD_MS:
				create_card()

func _process(_delta: float) -> void:
	if _is_dragging:
		global_position = get_global_mouse_position() - _drag_offset

## 生成卡牌相关
@export var spawn_offset: Vector2 = Vector2(0, 360)
var spawn_card_info: CardInfo

func create_card() -> void:
	# 从卡池获取随机卡牌（使用协会卡包类型）
	var type = bagresource.cardpool.get_random_type_in_guild()
	spawn_card_info = bagresource.cardpool.get_cards_by_type(type)
	
	# 生成卡牌
	_spawn_card()
	
	# 减少卡牌数量
	CardMember -= 1
	
	# 如果卡牌数量为0，销毁自己
	if CardMember <= 0:
		queue_free()

## 生成卡牌
func _spawn_card() -> void:
	# 根据卡牌资源类型选择正确的场景并实例化
	var card_instance = _create_card_instance()
	
	# 计算目标位置（当前位置的下方）
	var target_position = global_position + spawn_offset
	card_instance.z_index = 1
	
	# 将卡牌添加到Cards分组的根节点
	var cards_group = get_tree().get_first_node_in_group("Cards")
	if cards_group:
		cards_group.add_child(card_instance)
	
	# 设置初始位置为卡包位置
	card_instance.global_position = global_position
	
	# 播放生成翻转动画
	card_instance.play_spawn_flip()
	
	# 使用 tween 移动到目标位置，持续1秒
	var tween = create_tween()
	tween.tween_property(card_instance, "global_position", target_position, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	print("卡牌已生成于位置: %s, 卡牌名称: %s" % [target_position, spawn_card_info.name if spawn_card_info else "默认"])

## 根据卡牌资源类型创建对应的卡牌实例
func _create_card_instance() -> Node:
	var instance = spawn_card_info.card_scene.instantiate()
	instance.set_stats(spawn_card_info)
	return instance
