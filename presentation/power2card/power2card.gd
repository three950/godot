extends Control
class_name Power2Card

## 黑色卡牌按钮参考的原始按钮场景，便于之后追踪样式来源。
const CARD_BUTTON_STYLE_REFERENCE_UID := "uid://dde8q2r1usqpa"

@onready var power_label: Label = %PowerLabel
@onready var progress_bar_hbox: HBoxContainer = %UnitProgressBarHBox
@onready var progress_button: Button = %ProgressButton
@onready var card_buttons: Array[Button] = [
	%CardButton01,
	%CardButton02,
	%CardButton03,
	%CardButton04,
	%CardButton05,
	%CardButton06,
	%CardButton07,
]

## 按住 ProgressButton 时每秒增长多少个小进度格；数值作为玩法/手感参数留给编辑器调整。
@export var hold_units_per_second: float = 8.0
## 一个 CardButton 对应几个底部小进度格。目前 21 个格子 / 7 个按钮 = 每个按钮 3 格。
@export var progress_units_per_card_button: int = 3

var _progress_segments: Array[ProgressBar] = []
var _progress_total_units: int = 21
var _progress_current_units: int = 0
var _held_progress_units: float = 0.0
var _is_progress_button_held := false
var _timers_paused := false


func _ready() -> void:
	# 尺寸、mouse_filter、step 等基础 UI 属性都放在场景里维护，避免运行时覆盖编辑器布局。
	_collect_progress_segments()
	_apply_progress_state()
	_connect_progress_button()
	_connect_card_buttons()
	_connect_global_timer_pause()


func _process(delta: float) -> void:
	if not _is_progress_button_held:
		return
	if _timers_paused:
		return

	# 按住时从最小值持续累加，底部每个 ProgressBar 仍只显示空/满两种状态。
	_held_progress_units = minf(_held_progress_units + hold_units_per_second * delta, float(_progress_total_units))
	set_progress_units(floori(_held_progress_units))


## 更新左上角数字。数字节点使用 Label，保留方法给外部玩法逻辑调用。
func set_power(value: int) -> void:
	power_label.text = str(value)


## 更新底部固定单位进度。参考图默认未填充，所以场景里初始值为 0。
func set_progress_units(value: int) -> void:
	_progress_current_units = clampi(value, 0, _progress_total_units)
	_apply_progress_state()


## 设置底部总格数和当前格数。每一格就是进度条的一个 step。
func set_progress_unit_range(total_units: int, current_units: int = 0) -> void:
	var max_units := maxi(_progress_segments.size(), 1)
	_progress_total_units = clampi(total_units, 1, max_units)
	_progress_current_units = clampi(current_units, 0, _progress_total_units)
	_apply_progress_state()


## 批量控制黑色卡牌按钮是否可点，方便之后和抽牌/能量逻辑连接。
func set_cards_enabled(is_enabled: bool) -> void:
	for button in card_buttons:
		button.disabled = not is_enabled


func _connect_progress_button() -> void:
	if not progress_button.button_down.is_connected(_on_progress_button_down):
		progress_button.button_down.connect(_on_progress_button_down)
	if not progress_button.button_up.is_connected(_on_progress_button_up):
		progress_button.button_up.connect(_on_progress_button_up)


func _connect_card_buttons() -> void:
	for button in card_buttons:
		var callable := _on_card_button_pressed.bind(button)
		if not button.pressed.is_connected(callable):
			button.pressed.connect(callable)


func _connect_global_timer_pause() -> void:
	_timers_paused = Events.timers_paused
	if not Events.timers_pause_changed.is_connected(_on_timers_pause_changed):
		Events.timers_pause_changed.connect(_on_timers_pause_changed)


func _collect_progress_segments() -> void:
	_progress_segments.clear()

	for child in progress_bar_hbox.get_children():
		if child is ProgressBar:
			var segment := child as ProgressBar
			_progress_segments.append(segment)

	# 场景里目前直接摆了 21 段；如果以后删减节点，总格数自动跟随实际节点数量。
	if not _progress_segments.is_empty():
		_progress_total_units = mini(_progress_total_units, _progress_segments.size())


func _apply_progress_state() -> void:
	if _progress_segments.is_empty():
		return

	var visible_units := mini(_progress_total_units, _progress_segments.size())
	var filled_units := clampi(_progress_current_units, 0, visible_units)

	for index in range(_progress_segments.size()):
		var segment := _progress_segments[index]
		segment.visible = index < visible_units
		# 每个小进度条只负责一格：在当前进度内就是满格，否则为空格。
		segment.value = 1.0 if index < filled_units else 0.0


func _on_progress_button_down() -> void:
	_is_progress_button_held = true
	_held_progress_units = 0.0
	# 每次重新按住都从最小进度开始蓄力。
	set_progress_units(0)


func _on_progress_button_up() -> void:
	if not _is_progress_button_held:
		return

	_is_progress_button_held = false
	var card_button := _get_card_button_for_progress(_progress_current_units)
	var released_on_progress_button := _is_mouse_inside_control(progress_button)
	_reset_hold_progress()

	if not released_on_progress_button or card_button == null:
		return
	_try_pay_power_for_card_button(card_button)


func _on_card_button_pressed(card_button: Button) -> void:
	_try_pay_power_for_card_button(card_button)


func _on_timers_pause_changed(is_paused: bool) -> void:
	_timers_paused = is_paused


func _get_card_button_for_progress(progress_units: int) -> Button:
	if card_buttons.is_empty():
		return null

	var units_per_button := maxi(progress_units_per_card_button, 1)
	# 0 格是第一张卡的起点；1-3 格也对应第一张，4-6 格对应第二张，以此类推。
	var active_units := maxi(progress_units, 1)
	var button_index := ceili(float(active_units) / float(units_per_button)) - 1
	button_index = clampi(button_index, 0, card_buttons.size() - 1)
	return card_buttons[button_index]


func _try_pay_power_for_card_button(card_button: Button) -> bool:
	var button_index := card_buttons.find(card_button)
	if button_index == -1:
		return false

	var button_number := button_index + 1
	var power_cost := (button_number - 1) * 3
	var current_power := _get_power_value()
	var remaining_power := current_power - power_cost

	# 能量不足时直接失败；进度条已经在松开按钮时重置为初始状态。
	if remaining_power < 0:
		return false

	set_power(remaining_power)
	return true


func _get_power_value() -> int:
	# PowerLabel 是当前 UI 上的权威数值来源，外部系统也可以继续通过 set_power 更新它。
	return power_label.text.to_int()


func _reset_hold_progress() -> void:
	_held_progress_units = 0.0
	set_progress_units(0)


func _is_mouse_inside_control(control: Control) -> bool:
	# Button 的 button_up 会在拖出按钮后松开时触发；这里用全局矩形过滤掉取消操作。
	return control.get_global_rect().has_point(control.get_global_mouse_position())
