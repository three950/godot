extends Camera2D

# 相机拖动相关
var is_dragging: bool = false
var last_mouse_position: Vector2 = Vector2.ZERO

# 相机缩放相关
@export var min_zoom: float = 0.8  # 最小缩放（放大）
@export var max_zoom: float = 2.0  # 最大缩放（缩小）
@export var zoom_step: float = 0.2  # 每次滚轮滚动的缩放步长
@export var zoom_smoothing: float = 0.2  # 缩放平滑度
@export var initial_zoom: float = 1.5  # 初始缩放值

var target_zoom: Vector2 = Vector2.ONE

func _ready() -> void:
	# 设置初始缩放
	zoom = Vector2(initial_zoom, initial_zoom)
	target_zoom = zoom

func _unhandled_input(event: InputEvent) -> void:
	# 处理鼠标滚轮缩放
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# 向上滚动，放大
			zoom_camera(-zoom_step)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# 向下滚动，缩小
			zoom_camera(zoom_step)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 开始拖动
				is_dragging = true
				last_mouse_position = get_viewport().get_mouse_position()
				get_viewport().set_input_as_handled()
			else:
				# 停止拖动
				is_dragging = false
	
	# 处理鼠标移动
	if event is InputEventMouseMotion and is_dragging:
		var current_mouse_position = get_viewport().get_mouse_position()
		var delta = current_mouse_position - last_mouse_position
		# 根据当前缩放级别调整移动速度，缩放越小（放大），移动越慢
		global_position -= delta / zoom.x
		last_mouse_position = current_mouse_position
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# 平滑缩放
	zoom = zoom.lerp(target_zoom, zoom_smoothing)

func zoom_camera(delta_zoom: float) -> void:
	# 计算新的缩放值
	var new_zoom_value = target_zoom.x + delta_zoom
	# 限制缩放范围
	new_zoom_value = clamp(new_zoom_value, min_zoom, max_zoom)
	target_zoom = Vector2(new_zoom_value, new_zoom_value)
