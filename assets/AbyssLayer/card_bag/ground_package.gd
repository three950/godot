extends Button
class_name CardPackage
signal package_bought(CardPackage)
@export var game_stats:GameStats
@onready var packagename: Label = %packagename
@onready var value: Label = %value

func _on_pressed() -> void:
	if game_stats.coins < int(value.text):
		return
	game_stats.coins-=int(value.text)
	package_bought.emit()
