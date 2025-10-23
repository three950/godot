extends Panel
class_name BagPanel

# 信号：当鼠标进入背包区域
signal mouse_entered_bag
# 信号：当鼠标离开背包区域
signal mouse_exited_bag

# 背包状态
var is_mouse_over: bool = false
var was_mouse_over: bool = false

func _ready() -> void:
	# 确保鼠标事件可以被检测
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(_delta: float) -> void:
	# 使用矩形检测代替鼠标事件，更可靠
	var mouse_pos = get_global_mouse_position()
	var bag_rect = Rect2(global_position, size)
	is_mouse_over = bag_rect.has_point(mouse_pos)
	
	# 检测状态变化并发射信号
	if is_mouse_over and not was_mouse_over:
		print("【背包】鼠标进入背包（矩形检测）")
		mouse_entered_bag.emit()
	elif not is_mouse_over and was_mouse_over:
		print("【背包】鼠标离开背包（矩形检测）")
		mouse_exited_bag.emit()
	
	was_mouse_over = is_mouse_over

