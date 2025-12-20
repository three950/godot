class_name SellStore
extends Control
@export var game_stats:GameStats
@export var sold_sound:AudioStream
var current_card:Card
func _ready() -> void:
	Events.card_dropped.connect(_sell_card)

func _sell_card(card:Card) -> void:
	if not current_card or card != current_card:
		return
	if not card is Things:
		return
	var value = card.get_value()
	game_stats.coins += value
	print("金币: %d" % game_stats.coins)
	card.queue_free()
	SFXPlayer.play(sold_sound, false, -8)

func _on_card_stack_detector_area_area_entered(area: Area2D) -> void:
	var card = area.get_parent() as Card
	if card:
		current_card = card
		print("卡片进入商店区域: ", card.name)


func _on_card_stack_detector_area_area_exited(area: Area2D) -> void:
	var card = area.get_parent() as Card
	if card and card == current_card:
		current_card = null
		print("卡片离开商店区域: ", card.name)
