extends Control
class_name Power2Card

## 黑色卡牌按钮参考的原始按钮场景，便于之后追踪样式来源。
const CARD_BUTTON_STYLE_REFERENCE_UID := "uid://dde8q2r1usqpa"

@onready var power_label: Label = %PowerLabel
@onready var progress_bar_hbox: HBoxContainer = %UnitProgressBarHBox
@onready var card_buttons: Array[Button] = [
	%CardButton01,
	%CardButton02,
	%CardButton03,
	%CardButton04,
	%CardButton05,
	%CardButton06,
	%CardButton07,
]
@onready var next_button: Button = %NextButton

var _progress_segments: Array[ProgressBar] = []
var _progress_total_units: int = 23
var _progress_current_units: int = 2


func _ready() -> void:
	# 尺寸、mouse_filter、step 等基础 UI 属性都放在场景里维护，避免运行时覆盖编辑器布局。
	_collect_progress_segments()
	_apply_progress_state()


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


func _collect_progress_segments() -> void:
	_progress_segments.clear()

	for child in progress_bar_hbox.get_children():
		if child is ProgressBar:
			var segment := child as ProgressBar
			_progress_segments.append(segment)

	# 场景里目前直接摆了 23 段；如果以后删减节点，总格数自动跟随实际节点数量。
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
