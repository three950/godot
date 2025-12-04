class_name SellStore
extends Control
@export var game_stats:GameStats

var current_cards:Array[Card]
func _ready() -> void:
	card.dropped.connect(_sell_card.bind(Card))
	
func _cell_card(card:Card) -> void:
	game_stats.coins+=card.
func _on_area_entered(area: Area2D) -> void:
	pass # Replace with function body.


func _on_area_exited(area: Area2D) -> void:
	pass # Replace with function body.
