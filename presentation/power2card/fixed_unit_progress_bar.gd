extends Control
class_name FixedUnitProgressBar

## 分段拼接式固定单位进度条。
## 子节点不在脚本里动态生成，而是直接写在 power2card.tscn 场景中。
## 每个子节点都是一个 ProgressBar，代表一格；它的右边框就是贯穿全高的刻度。

## 当前启用的总格数。场景里已经放了 23 个子进度条，少于 23 时会隐藏后面的格子。
@export var total_units: int = 23:
	set(value):
		total_units = max(value, 1)
		current_units = clampi(current_units, 0, total_units)
		_apply_segment_state()

## 当前已经填满的格数。每个子进度条只使用空/满两种状态。
@export var current_units: int = 0:
	set(value):
		current_units = clampi(value, 0, total_units)
		_apply_segment_state()

var _segments: Array[ProgressBar] = []


func _ready() -> void:
	# 这是展示型 UI，不截获鼠标，避免挡住上方卡牌按钮。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collect_scene_segments()
	_apply_segment_state()


## 父节点用这个接口衔接玩法进度：total_value 是总格数，current_value 是当前填满格数。
func set_units(total_value: int, current_value: int) -> void:
	total_units = total_value
	current_units = current_value


## 只更新当前进度，不改变总格数。
func set_progress_units(value: int) -> void:
	current_units = value


func _collect_scene_segments() -> void:
	_segments.clear()

	for child in get_children():
		if child is ProgressBar:
			var segment := child as ProgressBar
			segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
			segment.min_value = 0.0
			segment.max_value = 1.0
			segment.step = 1.0
			segment.show_percentage = false
			_segments.append(segment)

	# 总格数不能超过场景里实际放置的子进度条数量。
	total_units = mini(total_units, _segments.size())


func _apply_segment_state() -> void:
	if _segments.is_empty():
		return

	var visible_units := mini(total_units, _segments.size())
	var filled_units := clampi(current_units, 0, visible_units)

	for index in range(_segments.size()):
		var segment := _segments[index]
		segment.visible = index < visible_units
		# 每个小进度条只负责一格：在当前进度内就是满格，否则为空格。
		segment.value = 1.0 if index < filled_units else 0.0
