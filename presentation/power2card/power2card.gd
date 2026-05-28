extends Control
class_name Power2Card

## 黑色卡牌按钮参考的原始按钮场景，便于之后追踪样式来源。
const CARD_BUTTON_STYLE_REFERENCE_UID := "uid://dde8q2r1usqpa"
const CARD_BUTTON_STYLE_NAMES := ["normal", "pressed", "hover", "hover_pressed", "focus", "disabled"]

@onready var power_label: Label = %PowerLabel
@onready var explorer_icon: TextureRect = $ExplorerIcon
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
## 当前进度对应卡牌时，卡牌按钮外框的白色描边宽度。
@export var active_card_border_width: int = 4
## 当前进度对应卡牌时，卡牌按钮外框的描边颜色。
@export var active_card_border_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## 扣除成功后，ExplorerIcon 向上跳起的高度。
@export var explorer_success_jump_height: float = 18.0
## ExplorerIcon 向上跳起并水平翻转半圈的时长。
@export var explorer_success_jump_up_duration: float = 0.16
## ExplorerIcon 中心点相对进度条前沿的偏移；负数表示落后于进度前沿。
@export var explorer_progress_back_offset: float = -16.0

var _progress_segments: Array[ProgressBar] = []
var _progress_total_units: int = 21
var _progress_current_units: int = 0
var _held_progress_units: float = 0.0
var _is_progress_button_held := false
var _timers_paused := false
var _card_button_base_styles: Dictionary = {}
var _highlighted_card_button: Button = null
var _explorer_base_position := Vector2.ZERO
var _explorer_base_scale := Vector2.ONE
var _explorer_feedback_tween: Tween = null


func _ready() -> void:
	# 尺寸、mouse_filter、step 等基础 UI 属性都放在场景里维护，避免运行时覆盖编辑器布局。
	_collect_progress_segments()
	_cache_card_button_styles()
	_cache_explorer_transform()
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
	_move_explorer_icon_to_progress(_held_progress_units)


## 更新左上角数字。数字节点使用 Label，保留方法给外部玩法逻辑调用。
func set_power(value: int) -> void:
	power_label.text = str(value)


## 更新底部固定单位进度。参考图默认未填充，所以场景里初始值为 0。
func set_progress_units(value: int, update_explorer: bool = true) -> void:
	_progress_current_units = clampi(value, 0, _progress_total_units)
	_apply_progress_state(update_explorer)


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


func _cache_card_button_styles() -> void:
	_card_button_base_styles.clear()

	for button in card_buttons:
		var styles := {}
		for style_name in CARD_BUTTON_STYLE_NAMES:
			# 缓存场景原本配置的 StyleBox，后续高亮取消时完整恢复原样。
			styles[style_name] = button.get_theme_stylebox(style_name)
		_card_button_base_styles[button] = styles


func _cache_explorer_transform() -> void:
	_explorer_base_position = explorer_icon.position
	_explorer_base_scale = explorer_icon.scale
	# 水平翻转动画需要围绕头像中心点执行，否则会从左上角翻转导致位置偏移。
	explorer_icon.pivot_offset = explorer_icon.size * 0.5


func _collect_progress_segments() -> void:
	_progress_segments.clear()

	for child in progress_bar_hbox.get_children():
		if child is ProgressBar:
			var segment := child as ProgressBar
			_progress_segments.append(segment)

	# 场景里目前直接摆了 21 段；如果以后删减节点，总格数自动跟随实际节点数量。
	if not _progress_segments.is_empty():
		_progress_total_units = mini(_progress_total_units, _progress_segments.size())


func _apply_progress_state(update_explorer: bool = true) -> void:
	if _progress_segments.is_empty():
		return

	var visible_units := mini(_progress_total_units, _progress_segments.size())
	var filled_units := clampi(_progress_current_units, 0, visible_units)

	for index in range(_progress_segments.size()):
		var segment := _progress_segments[index]
		segment.visible = index < visible_units
		# 每个小进度条只负责一格：在当前进度内就是满格，否则为空格。
		segment.value = 1.0 if index < filled_units else 0.0

	_apply_card_button_highlight()
	if update_explorer:
		_move_explorer_icon_to_progress(float(_progress_current_units))


func _on_progress_button_down() -> void:
	_stop_explorer_feedback_animation()
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

	if not released_on_progress_button or card_button == null:
		_reset_hold_progress()
		return

	var is_paid := _try_pay_power_for_card_button(card_button)
	# 扣除成功时头像会从当前进度位置起跳，因此只重置进度和边框，不立刻移动头像。
	_reset_hold_progress(not is_paid)


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
	_play_explorer_success_animation()
	return true


func _get_power_value() -> int:
	# PowerLabel 是当前 UI 上的权威数值来源，外部系统也可以继续通过 set_power 更新它。
	return power_label.text.to_int()


func _reset_hold_progress(update_explorer: bool = true) -> void:
	_held_progress_units = 0.0
	set_progress_units(0, update_explorer)


func _is_mouse_inside_control(control: Control) -> bool:
	# Button 的 button_up 会在拖出按钮后松开时触发；这里用全局矩形过滤掉取消操作。
	return control.get_global_rect().has_point(control.get_global_mouse_position())


func _apply_card_button_highlight() -> void:
	var target_button := _get_card_button_for_highlight(_progress_current_units)
	if target_button == _highlighted_card_button:
		return

	if _highlighted_card_button != null:
		_restore_card_button_style(_highlighted_card_button)

	_highlighted_card_button = target_button
	if _highlighted_card_button != null:
		_apply_highlight_style_to_card_button(_highlighted_card_button)


func _get_card_button_for_highlight(progress_units: int) -> Button:
	# 初始 0 格时不高亮第一张卡；只有进度真正进入第一格后才显示白色边框。
	if progress_units <= 0:
		return null
	return _get_card_button_for_progress(progress_units)


func _apply_highlight_style_to_card_button(card_button: Button) -> void:
	for style_name in CARD_BUTTON_STYLE_NAMES:
		var highlighted_style := card_button.get_theme_stylebox(style_name).duplicate(true)
		if highlighted_style is StyleBoxFlat:
			var flat_style := highlighted_style as StyleBoxFlat
			flat_style.border_width_left = active_card_border_width
			flat_style.border_width_top = active_card_border_width
			flat_style.border_width_right = active_card_border_width
			flat_style.border_width_bottom = active_card_border_width
			flat_style.border_color = active_card_border_color
		card_button.add_theme_stylebox_override(style_name, highlighted_style)


func _restore_card_button_style(card_button: Button) -> void:
	var styles: Dictionary = _card_button_base_styles.get(card_button, {})
	for style_name in styles.keys():
		card_button.add_theme_stylebox_override(style_name, styles[style_name])


func _move_explorer_icon_to_progress(progress_units: float) -> void:
	if _explorer_feedback_tween != null and _explorer_feedback_tween.is_valid():
		return

	var visible_units := mini(_progress_total_units, _progress_segments.size())
	if progress_units <= 0.0 or visible_units <= 0:
		explorer_icon.position = _explorer_base_position
		return

	var clamped_units := clampf(progress_units, 0.0, float(visible_units))
	var whole_units := floori(clamped_units)
	var segment_fraction := clamped_units - float(whole_units)
	var segment_index := clampi(whole_units, 0, visible_units - 1)

	# 整数格表示前一个小进度条的右边缘；小数格表示当前小进度条内部的填充前沿。
	if is_zero_approx(segment_fraction) and whole_units > 0:
		segment_index = clampi(whole_units - 1, 0, visible_units - 1)
		segment_fraction = 1.0

	var segment := _progress_segments[segment_index]
	var progress_front_x := progress_bar_hbox.position.x + segment.position.x + segment.size.x * segment_fraction
	var explorer_center_x := progress_front_x + explorer_progress_back_offset
	explorer_icon.position = Vector2(explorer_center_x - explorer_icon.size.x * 0.5, _explorer_base_position.y)


func _play_explorer_success_animation() -> void:
	_stop_explorer_feedback_animation(false)
	explorer_icon.pivot_offset = explorer_icon.size * 0.5

	var jump_position := explorer_icon.position + Vector2(0.0, -explorer_success_jump_height)
	_explorer_feedback_tween = create_tween()
	# 这是纯 UI 成功反馈，不参与玩法计时，所以不跟随 Events.timers_paused 暂停。
	_explorer_feedback_tween.tween_property(explorer_icon, "position", jump_position, explorer_success_jump_up_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_explorer_feedback_tween.parallel().tween_property(explorer_icon, "scale:x", -_explorer_base_scale.x, explorer_success_jump_up_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_explorer_feedback_tween.tween_callback(Callable(self, "_restore_explorer_icon_transform"))


func _stop_explorer_feedback_animation(reset_to_base: bool = true) -> void:
	if _explorer_feedback_tween != null and _explorer_feedback_tween.is_valid():
		_explorer_feedback_tween.kill()
	_explorer_feedback_tween = null
	_restore_explorer_icon_transform(reset_to_base)


func _restore_explorer_icon_transform(reset_to_base: bool = true) -> void:
	explorer_icon.scale = _explorer_base_scale
	explorer_icon.pivot_offset = explorer_icon.size * 0.5
	if reset_to_base:
		explorer_icon.position = _explorer_base_position
