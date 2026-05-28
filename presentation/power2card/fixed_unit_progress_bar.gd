extends Control
class_name FixedUnitProgressBar

## 固定单位长度进度条。
## 这里只负责绘制底部黑色横线和等距刻度，方便后续把“单位长度”作为玩法参数接入。
@export var unit_count: int = 23:
	set(value):
		unit_count = max(value, 1)
		queue_redraw()

## 每个单位在 UI 中占用的像素长度，默认匹配参考图底部的短刻度间距。
@export var unit_width: float = 24.0:
	set(value):
		unit_width = max(value, 1.0)
		queue_redraw()

## 已完成的单位数。当前参考图没有明显填充值，所以默认是 0，仅保留接口。
@export var filled_units: int = 0:
	set(value):
		filled_units = clampi(value, 0, unit_count)
		queue_redraw()

## 每隔几个小单位画一个长刻度，用来对齐上方卡牌按钮的分组感。
@export var major_tick_interval: int = 3:
	set(value):
		major_tick_interval = max(value, 1)
		queue_redraw()

@export var track_color: Color = Color.BLACK
@export var fill_color: Color = Color(0.92, 0.88, 0.7, 1.0)
@export var line_width: float = 2.0
@export var minor_tick_height: float = 5.0
@export var major_tick_height: float = 8.0


func _ready() -> void:
	# 进度条是纯展示层，不需要截获鼠标事件，避免挡住卡牌按钮点击。
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var total_width := unit_count * unit_width
	var baseline_y := major_tick_height

	# 如果后续需要显示进度，先画一段浅色填充，再覆盖黑色刻度线。
	if filled_units > 0:
		var fill_width := filled_units * unit_width
		draw_line(Vector2(0, baseline_y), Vector2(fill_width, baseline_y), fill_color, line_width)

	draw_line(Vector2(0, baseline_y), Vector2(total_width, baseline_y), track_color, line_width)

	for index in range(unit_count + 1):
		var tick_x := index * unit_width
		var is_major_tick := index % major_tick_interval == 0
		var tick_height := major_tick_height if is_major_tick else minor_tick_height
		draw_line(
			Vector2(tick_x, baseline_y),
			Vector2(tick_x, baseline_y + tick_height),
			track_color,
			line_width
		)
