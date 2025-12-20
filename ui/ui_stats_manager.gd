extends CanvasLayer

@export var game_stats: GameStats
@onready var coin_label: Label = $TopRightUI/HBoxContainer/game_stats/HBoxContainer/moneystate/CoinLabel
@onready var food_label: Label = $TopRightUI/HBoxContainer/game_stats/HBoxContainer/foodstate/Label
@onready var layer_label: Label = $TopRightUI/HBoxContainer/game_stats/HBoxContainer/layerstate
@onready var progress_bar: ProgressBar = $TopRightUI/HBoxContainer/ProgressBar
@onready var days_label: Label = $TopRightUI/HBoxContainer/ProgressBar/HBoxContainer/Label
@export var bgm:AudioStream
var elapsed_time: float = 0.0

func _ready() -> void:
	game_stats.changed.connect(_update_stats)
	Events.food_need_update.connect(_on_food_need_update)
	Events.food_have_update.connect(_on_food_have_update)
	_update_stats()
	MusicPlayer.play(bgm)

func _on_food_need_update(amount: int) -> void:
	game_stats.food_need += amount
func _on_food_have_update(amount: int) -> void:
	game_stats.food_have += amount
	
func _process(delta: float) -> void:
	if game_stats.time <= 0:
		return
	var day_duration_seconds: float = game_stats.time * 60.0  # time分钟转换为秒
	elapsed_time += delta
	progress_bar.max_value = day_duration_seconds
	progress_bar.value = elapsed_time
	if elapsed_time >= day_duration_seconds:
		elapsed_time = 0.0
		game_stats.days += 1

func _update_stats() -> void:
	coin_label.text = "%d" % game_stats.coins
	food_label.text = "%d/%d" % [game_stats.food_have, game_stats.food_need]
	layer_label.text = "深渊%d层" % game_stats.layer
	days_label.text = "%d天" % game_stats.days
