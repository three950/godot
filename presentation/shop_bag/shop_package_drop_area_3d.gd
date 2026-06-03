extends Area3D
class_name ShopPackageDropArea3D

@export var package_path: NodePath


func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not area_exited.is_connected(_on_area_exited):
		area_exited.connect(_on_area_exited)


func get_package() -> CardPackage:
	return get_node_or_null(package_path) as CardPackage


func _on_area_entered(area: Area3D) -> void:
	var card := _get_card_from_area(area)
	if card == null:
		return

	if not card.dropped.is_connected(_on_card_dropped):
		card.dropped.connect(_on_card_dropped)


func _on_area_exited(area: Area3D) -> void:
	var card := _get_card_from_area(area)
	if card == null:
		return

	if card.dropped.is_connected(_on_card_dropped):
		card.dropped.disconnect(_on_card_dropped)


func _on_card_dropped(_source_state: Card3DState, card: Card3D) -> void:
	if card == null or not is_instance_valid(card):
		return

	var shop_controller := _get_shop_area_controller()
	if shop_controller == null or not shop_controller.has_method("apply_card_drop_rules"):
		return

	shop_controller.call("apply_card_drop_rules", card)


func _get_card_from_area(area: Area3D) -> Card3D:
	if area == null or not is_instance_valid(area):
		return null
	return area.get_parent() as Card3D


func _get_shop_area_controller() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("ShopArea3D")
