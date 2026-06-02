extends Card
class_name CoinCard2D

@export var coin_info: CoinCardInfo


func get_card_resource() -> CardInfo:
	return coin_info


func _ready() -> void:
	super._ready()
	_update_coin_display()


func set_stats(value: CoinCardInfo) -> void:
	coin_info = value
	if is_node_ready():
		_update_coin_display()


func _update_coin_display() -> void:
	# 金币卡只展示名称和金币图标；商店结算只按 3D 金币卡数量，不读普通 value。
	_update_card_display()
