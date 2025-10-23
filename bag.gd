extends Panel
class_name BagPanel

# 信号：当鼠标进入背包区域
signal mouse_entered_bag
# 信号：当鼠标离开背包区域
signal mouse_exited_bag

# 背包状态
var is_mouse_over: bool = false

func _ready() -> void:
	# 确保鼠标事件可以被检测
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 连接鼠标信号
	mouse_entered.connect(_on_mouse_entered_bag)
	mouse_exited.connect(_on_mouse_exited_bag)

# 当鼠标进入背包区域
func _on_mouse_entered_bag() -> void:
	is_mouse_over = true
	mouse_entered_bag.emit()

# 当鼠标离开背包区域
func _on_mouse_exited_bag() -> void:
	is_mouse_over = false
	mouse_exited_bag.emit()

