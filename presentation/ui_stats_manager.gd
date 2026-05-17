extends CanvasLayer

@export var game_stats: GameStats
@onready var food_label: Label = %FoodLabel
@onready var coin_label: Label = %CoinLabel
@onready var layer_label: Label = %layerstate
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var days_label: Label = %Label
@onready var play_icon: Label = $UIContainer/TopRightUI/HBoxContainer/ProgressBar/HBoxContainer/PlayIcon
@onready var pause_overlay: Control = $UIContainer/PauseOverlay
@onready var pause_label: Label = $UIContainer/PauseOverlay/PauseLabel
@export var bgm:AudioStream
var elapsed_time: float = 0.0
var _pause_tween: Tween

func _ready() -> void:
	game_stats.changed.connect(_update_stats)
	Events.food_need_update.connect(_on_food_need_update)
	Events.food_have_update.connect(_on_food_have_update)
	Events.timers_pause_changed.connect(_on_timers_pause_changed)
	play_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	play_icon.gui_input.connect(_on_play_icon_gui_input)
	_on_timers_pause_changed(Events.timers_paused)
	_update_stats()
	MusicPlayer.play(bgm)

func _on_food_need_update(amount: int) -> void:
	game_stats.food_need += amount
func _on_food_have_update(amount: int) -> void:
	game_stats.food_have += amount
	
func _process(delta: float) -> void:
	if game_stats.time <= 0:
		return
	if Events.timers_paused:
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

func _on_play_icon_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Events.toggle_timers_paused()
		play_icon.accept_event()

func _on_timers_pause_changed(is_paused: bool) -> void:
	play_icon.text = "▶" if is_paused else "❚❚"
	pause_overlay.visible = is_paused
	if is_paused:
		_start_pause_bounce()
	else:
		_stop_pause_bounce()

func _start_pause_bounce() -> void:
	_stop_pause_bounce()
	pause_label.pivot_offset = pause_label.size * 0.5
	pause_label.scale = Vector2.ONE
	_pause_tween = create_tween()
	_pause_tween.set_loops()
	_pause_tween.set_trans(Tween.TRANS_SINE)
	_pause_tween.set_ease(Tween.EASE_IN_OUT)

func _stop_pause_bounce() -> void:
	if _pause_tween != null:
		_pause_tween.kill()
		_pause_tween = null
	if is_node_ready():
		pause_label.scale = Vector2.ONE
