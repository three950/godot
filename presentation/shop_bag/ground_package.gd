extends Button
class_name CardPackage
signal package_bought(CardPackage)

const CARD_3D_SCENE: PackedScene = preload("res://card_3d.tscn")

@export var game_stats:GameStats
@export_multiline var package_name: String = ""  # 可导出的名称变量
@export var mean_layer:int
@export var package_price: int = 3  # 可导出的价格变量
## 商店买出的 3D 卡固定落在桌面普通卡牌平面，默认 y = 0。
@export var spawn_card_world_y: float = 0.0
@export var spawn_card_info: Resource
@onready var packagename: Label = %packagename
@onready var value: Label = %value
@onready var panel_3: Panel = $Panel3
@export var coin_sound:AudioStream


func _ready() -> void:
	_update_display()
	Events.max_layer_changed.connect(_update_state)
	_update_state()


func _update_display() -> void:
	# 更新名称和价格显示
	packagename.text = package_name
	value.text = str(package_price)

func _on_pressed() -> void:
	# 购买现在只由 3D 金币卡落到 GroundPackage 上触发，按钮点击只保留视觉按钮状态。
	pass


func try_accept_card_drop(dropped_card: Node, remaining_position: Variant = null) -> bool:
	var coin_stack := dropped_card as CoinCard3D
	if coin_stack == null:
		return false
	return _buy_package_with_coin_stack(coin_stack, remaining_position)


func get_coin_purchase_debug_status(dropped_card: Node) -> String:
	var coin_stack := dropped_card as CoinCard3D
	if coin_stack == null:
		return "not_coin_card"
	if disabled:
		return "package_disabled"
	if game_stats == null:
		return "missing_game_stats"
	if spawn_card_info == null:
		return "missing_spawn_card_info"
	if _get_spawn_card_info() == null:
		return "spawn_resource_not_card_info"
	if _get_spawn_card_scene() == null:
		return "missing_spawn_card_scene"
	if _get_cards_3d_spawn_parent() == null:
		return "missing_cards3d_parent"

	var coin_count := coin_stack.get_coin_stack_count()
	if coin_count < package_price:
		return "not_enough_coins_%d_of_%d" % [coin_count, package_price]

	return "ready"


func _buy_package_with_coin_stack(coin_stack: CoinCard3D, remaining_position: Variant) -> bool:
	if disabled \
			or game_stats == null \
			or _get_spawn_card_info() == null \
			or _get_spawn_card_scene() == null \
			or _get_cards_3d_spawn_parent() == null:
		return false
	if not coin_stack.can_pay_coin_count(package_price):
		return false
	var spawn_position := _get_3d_spawn_position(remaining_position)
	package_bought.emit(self)
	coin_stack.spend_from_coin_stack(package_price, remaining_position)
	# 购买成功后立即生成 3D 卡，不再做延迟等待。
	_spawn_card(spawn_position)
	if coin_sound:
		SFXPlayer.play(coin_sound)
	return true

## 生成卡牌
func _spawn_card(spawn_position: Vector3) -> void:
	var card_info := _get_spawn_card_info()
	var spawn_parent := _get_cards_3d_spawn_parent()
	if card_info == null or spawn_parent == null:
		push_warning("CardPackage: cannot spawn 3D card because card_info or Cards3D parent is missing.")
		return

	# 商店奖励统一生成真正的 Card3D，挂到桌面 Card3D 同级父节点下，避免落在 SubViewport/2D Cards 分组里看不见。
	var spawned_card := CARD_3D_SCENE.instantiate() as Card3D
	if spawned_card == null:
		push_error("CardPackage: failed to spawn 3D card for %s." % card_info.name)
		return

	spawned_card.card_info = card_info
	spawn_parent.add_child(spawned_card)
	spawned_card.global_position = spawn_position

	print("商店3D卡牌已生成: %s 位置: %s 父节点: %s" % [
		card_info.name,
		spawned_card.global_position,
		spawn_parent.name,
	])

	
func _update_state() -> void:
	if game_stats.max_layer <= mean_layer:
		panel_3.show()
		set_disabled(true)  # 禁用按钮交互
	else:
		panel_3.hide()  # 隐藏面板
		set_disabled(false)  # 启用按钮交互


func _get_spawn_card_scene() -> PackedScene:
	var card_info := _get_spawn_card_info()
	if card_info == null:
		return null
	return card_info.get("card_scene") as PackedScene


func _get_spawn_card_info() -> CardInfo:
	return spawn_card_info as CardInfo


func _get_3d_spawn_position(remaining_position: Variant) -> Vector3:
	var spawn_position := Vector3.ZERO
	if remaining_position is Vector3:
		spawn_position = remaining_position
	spawn_position.y = spawn_card_world_y
	return spawn_position


func _get_cards_3d_spawn_parent() -> Node:
	var existing_card := get_tree().get_first_node_in_group("Cards3D") as Card3D
	if existing_card != null and is_instance_valid(existing_card):
		return existing_card.get_parent()
	return get_tree().current_scene
