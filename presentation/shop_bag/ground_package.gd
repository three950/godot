extends Button#TODO 不再是按钮了，是普通的2d
class_name CardPackage

## 当卡包被成功购买时发出信号
signal package_bought()

# --- 资源引用 ---
## 3D卡牌的场景资源，用于实例化新的卡牌
const CARD_3D_SCENE: PackedScene = preload("res://card_3d.tscn")
@export var game_stats: GameStats

## 卡包的显示名称
@export_multiline var package_name: String = ""
@export var unlock_threshold_layer: int = 0
@export var package_price: int = 3

## 生成的3D卡牌落地位置的Y轴坐标（世界坐标）。默认为0（地面）。
@export var spawn_card_world_y: float = 0.0
## 本卡包能开出的卡牌信息资源（CardInfo类型）
@export var spawn_card_info: CardInfo  # TODO 现在是CardInfo类型，之后替换为专用的卡包类型
@export var coin_sound: AudioStream

# --- UI节点引用 ---
@onready var package_name_label: Label = %packagename  # 显示卡包名的Label
@onready var price_label: Label = %value              # 显示价格的Label
@onready var lock_panel: Panel = $Panel3              # 锁定状态时显示的遮罩面板

# --- 私有变量 ---
## 缓存所有3D卡牌的父节点，避免每次生成时都去场景树查找，提升性能
var _cards_3d_parent: Node = null


func _ready() -> void:
	# 缓存3D卡牌的父节点。"Cards3D"的组。
	var any_card_3d := get_tree().get_first_node_in_group("Cards3D") as Card3D
	_cards_3d_parent = any_card_3d.get_parent()

	_update_display()
	# 连接游戏状态中"最大层数改变"的信号，用于更新卡包的锁定/解锁状态
	Events.max_layer_changed.connect(_update_lock_state)
	# 初始更新一次锁定状态
	_update_lock_state()


## 更新显示卡包名称和价格的UI
func _update_display() -> void:
	package_name_label.text = package_name
	price_label.text = str(package_price)


## 根据玩家当前层数更新卡包的锁定/解锁状态
func _update_lock_state() -> void:
	# 如果游戏状态无效，直接禁用并返回
	if game_stats == null:
		return
		
	var is_locked: bool = game_stats.max_layer <= unlock_threshold_layer
	
	# 按钮的禁用状态与锁定状态同步
	set_disabled(is_locked)
	# 锁定遮罩面板的显示与锁定状态同步
	if is_locked:
		lock_panel.show()
	else:
		lock_panel.hide()


## 当鼠标（或拖拽的卡片）落在这个按钮上时，Godot会自动调用这个方法（如果按钮的`mouse_filter`设置为`MOUSE_FILTER_STOP`）。
## 我们用它来处理从外部拖拽过来的金币卡。
## 返回值: 是否成功接受并处理了这次拖拽（用于拖拽系统判断）。
func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	# 检查拖拽的数据是否是一个CoinCard3D节点
	var dragged_card: Node = data
	if not dragged_card is CoinCard3D:
		return false
	
	# 返回是否可以购买（仅检查条件，不实际购买）
	return _is_purchase_possible(dragged_card)


## 当拖拽的卡片被放下时调用。
func _drop_data(_position: Vector2, data: Variant) -> void:
	var coin_card := data as CoinCard3D
	if coin_card == null:
		return
	
	# 尝试执行购买流程
	_try_buy_package_with_coin(coin_card)


## 检查给定的金币卡是否足以购买此卡包（不执行实际扣费和生成动作）
## 用于拖拽时的有效性检查（比如鼠标图标变化）
func _is_purchase_possible(coin_card: CoinCard3D) -> bool:
	if not coin_card.can_pay_coin_count(package_price):
		return false
	
	return true


## 使用给定的金币卡执行购买流程：扣费 -> 发信号 -> 播声音 -> 生成新卡
## 返回值: 是否购买成功
func _try_buy_package_with_coin(coin_card: CoinCard3D, drop_position: Vector3 = Vector3.ZERO) -> bool:
	# 再次进行完整的购买前检查
	if not _is_purchase_possible(coin_card):
		return false
	
	# 执行金币扣除
	# 注意：这里假设spend_from_coin_stack内部会处理好金币数量的减少，并且不会因为传入drop_position而出错
	# 如果原脚本的spend_from_coin_stack需要剩余位置信息，请确保这里的drop_position是合适的。
	coin_card.spend_from_coin_stack(package_price, drop_position)
	
	# 发出购买成功信号
	package_bought.emit(self)
	
	# 播放购买音效
	if coin_sound:
		SFXPlayer.play(coin_sound)
	
	# 生成新的3D卡牌
	_spawn_3d_card(drop_position)
	
	return true


## 在指定位置生成一张新的3D卡牌
## @param fall_position: 生成位置的XZ坐标（根据传入的掉落点），Y坐标会使用spawn_card_world_y覆盖
func _spawn_3d_card(fall_position: Vector3) -> void:
	# 安全检查：确保卡牌信息和父节点有效
	if spawn_card_info == null:
		push_error("CardPackage: 无法生成3D卡牌，因为 spawn_card_info 为空。")
		return
	if _cards_3d_parent == null:
		push_error("CardPackage: 无法生成3D卡牌，因为 _cards_3d_parent 为空。")
		return
	
	# 实例化新的3D卡牌
	var new_card_3d := CARD_3D_SCENE.instantiate() as Card3D
	if new_card_3d == null:
		push_error("CardPackage: 实例化 CARD_3D_SCENE 失败，请检查路径 res://card_3d.tscn 是否正确，且根节点为 Card3D 类型。")
		return
	
	# 设置卡牌的数据
	new_card_3d.card_info = spawn_card_info
	
	# 设置卡牌的位置：XZ平面使用传入的位置，Y轴强制设置为指定的世界高度
	var spawn_position := Vector3(fall_position.x, spawn_card_world_y, fall_position.z)
	new_card_3d.global_position = spawn_position
	
	# 将新卡牌添加到缓存的父节点下
	_cards_3d_parent.add_child(new_card_3d)
	
	# 输出日志，便于调试
	print("商店卡包已购买并生成3D卡牌: 名称='%s', 位置=(%.2f, %.2f, %.2f), 父节点='%s'" % [
		spawn_card_info.name,
		spawn_position.x, spawn_position.y, spawn_position.z,
		_cards_3d_parent.name
	])


# --- 保留但修改/注释的原始接口（为了兼容外部调用）---
# 如果外部有其他脚本调用了 try_accept_card_drop，可以保留此函数
func try_accept_card_drop(dropped_card: Node, remaining_position: Variant = null) -> bool:
	var coin_card := dropped_card as CoinCard3D
	if coin_card == null:
		return false
	
	var drop_pos := Vector3.ZERO
	if remaining_position is Vector3:
		drop_pos = remaining_position
	
	return _try_buy_package_with_coin(coin_card, drop_pos)

# 调试函数，如果确实需要可以保留，但建议只在调试模式下使用
# 或者完全移除，因为 _is_purchase_possible 已经能给出足够的错误预防
