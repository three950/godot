extends Node2D

@export var game_stats: GameStats
@onready var coin_label: Label = $CoinLabel

func _ready() -> void:
	game_stats.changed.connect(_update_coin_label)
	_update_coin_label()

func _update_coin_label() -> void:
	coin_label.text = "金币: %d" % game_stats.coins
