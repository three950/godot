extends Node3D

@onready var sub_viewport: SubViewport = $SubViewport
@onready var game_plane: MeshInstance3D = $GamePlane
@onready var camera_3d: Camera3D = $Camera3D

# SubViewport 的尺寸（固定为2D场景的设计尺寸）
@export var design_size: Vector2 = Vector2(3471, 2136)
var viewport_size: Vector2

# 相机拖动相关
var is_dragging: bool = false
var last_mouse_position: Vector2 = Vector2.ZERO

# 相机缩放相关
@export var min_distance: float = 200.0  # 最近距离（放大）
@export var max_distance: float = 2000.0  # 最远距离（缩小）
@export var zoom_step: float = 50.0  # 每次滚轮滚动的缩放步长
@export var zoom_smoothing: float = 0.1  # 缩放平滑度
@export var drag_speed: float = 2.0  # 拖动速度

var target_distance: float = 0.0
var base_distance: float = 0.0

# 3D卡牌管理
var card_3d_list: Array[Card3D] = []
var selected_card_index: int = -1

func _ready():
	# 延迟一帧确保窗口尺寸正确
	await get_tree().process_frame
	
	# 初始化设置
	_update_viewport_size()
	
	# 创建材质并应用SubViewport的纹理
	var material = StandardMaterial3D.new()
	material.albedo_texture = sub_viewport.get_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	# 将材质应用到GamePlane
	game_plane.material_override = material
	
	# 监听窗口尺寸变化
	get_viewport().size_changed.connect(_update_viewport_size)
	
	# 收集所有3D卡牌
	_collect_cards()
	
	# 默认选中第一张卡牌
	if card_3d_list.size() > 0:
		_select_card(0)

## 收集场景中的所有3D卡牌
func _collect_cards() -> void:
	card_3d_list.clear()
	for child in get_children():
		if child is Card3D:
			card_3d_list.append(child)
	print("找到 %d 张3D卡牌" % card_3d_list.size())

## 选中指定索引的卡牌
func _select_card(index: int) -> void:
	# 取消之前的选中
	if selected_card_index >= 0 and selected_card_index < card_3d_list.size():
		card_3d_list[selected_card_index].set_selected(false)
	
	# 选中新卡牌
	selected_card_index = index
	if selected_card_index >= 0 and selected_card_index < card_3d_list.size():
		card_3d_list[selected_card_index].set_selected(true)
		print("选中卡牌: %s (索引 %d)" % [card_3d_list[selected_card_index].card_name, index])

## 切换到下一张卡牌
func _select_next_card() -> void:
	if card_3d_list.size() == 0:
		return
	var next_index = (selected_card_index + 1) % card_3d_list.size()
	_select_card(next_index)

## 切换到上一张卡牌
func _select_prev_card() -> void:
	if card_3d_list.size() == 0:
		return
	var prev_index = selected_card_index - 1
	if prev_index < 0:
		prev_index = card_3d_list.size() - 1
	_select_card(prev_index)

func _update_viewport_size():
	# 使用固定的设计尺寸
	viewport_size = design_size
	
	# 更新SubViewport尺寸为设计尺寸
	sub_viewport.size = Vector2i(design_size)
	
	# 调整GamePlane的网格尺寸以匹配设计尺寸
	var mesh = game_plane.mesh as QuadMesh
	if mesh:
		mesh.size = design_size
	
	# 调整相机位置，确保完整看到平面
	var fov_rad = deg_to_rad(camera_3d.fov)
	var distance = (design_size.y / 2.0) / tan(fov_rad / 2.0)
	base_distance = distance
	
	# 初始化目标距离（只在第一次时设置）
	if target_distance == 0.0:
		target_distance = distance
	
	# 相机位置居中
	camera_3d.position.z = target_distance
	camera_3d.position.y = 0

func _process(delta: float) -> void:
	# 平滑缩放
	camera_3d.position.z = lerp(camera_3d.position.z, target_distance, zoom_smoothing)

func _unhandled_input(event):
	# 处理Tab键切换卡牌
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_TAB:
			if event.shift_pressed:
				_select_prev_card()
			else:
				_select_next_card()
			get_viewport().set_input_as_handled()
			return
		# 处理数字键快速选择卡牌 (1-9)
		if event.pressed and event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var card_index = event.keycode - KEY_1
			if card_index < card_3d_list.size():
				_select_card(card_index)
			get_viewport().set_input_as_handled()
			return
	
	# 键盘事件和动作事件直接转发
	if event is InputEventKey or event is InputEventAction:
		sub_viewport.push_input(event)
		return
	
	# 处理鼠标滚轮缩放
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# 向上滚动，放大（靠近）
			target_distance = clamp(target_distance - zoom_step, min_distance, max_distance)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# 向下滚动，缩小（远离）
			target_distance = clamp(target_distance + zoom_step, min_distance, max_distance)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 左键开始拖动
				is_dragging = true
				last_mouse_position = get_viewport().get_mouse_position()
			else:
				is_dragging = false
			get_viewport().set_input_as_handled()
			return
	
	# 处理鼠标拖动移动视角
	if event is InputEventMouseMotion and is_dragging:
		var current_mouse_position = get_viewport().get_mouse_position()
		var delta_mouse = current_mouse_position - last_mouse_position
		# 根据当前距离调整移动速度
		var speed_factor = camera_3d.position.z / base_distance * drag_speed
		camera_3d.position.x -= delta_mouse.x * speed_factor
		camera_3d.position.y += delta_mouse.y * speed_factor
		last_mouse_position = current_mouse_position
		get_viewport().set_input_as_handled()
		return
	
	# 处理鼠标和触摸事件
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		var mouse_pos = get_viewport().get_mouse_position()
		
		# 从3D相机发射射线
		var from = camera_3d.project_ray_origin(mouse_pos)
		var to = from + camera_3d.project_ray_normal(mouse_pos) * 1000
		
		# 检测与平面的交点
		var plane = Plane(Vector3(0, 0, 1), 0)  # XY平面
		var intersection = plane.intersects_ray(from, to - from)
		
		if intersection:
			# 将3D坐标转换为SubViewport的2D坐标
			var mesh_size = game_plane.mesh.size
			var local_pos = Vector2(
				(intersection.x / mesh_size.x + 0.5) * viewport_size.x,
				(-intersection.y / mesh_size.y + 0.5) * viewport_size.y
			)
			
			# 创建新的事件副本并修改位置
			var new_event = event.duplicate()
			if new_event is InputEventMouse:
				new_event.position = local_pos
				new_event.global_position = local_pos
			elif new_event is InputEventScreenTouch or new_event is InputEventScreenDrag:
				new_event.position = local_pos
			
			# 将事件推送到SubViewport
			sub_viewport.push_input(new_event)
