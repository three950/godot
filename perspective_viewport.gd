extends Node3D

@onready var sub_viewport: SubViewport = $SubViewport
@onready var game_plane: MeshInstance3D = $GamePlane
@onready var camera_3d: Camera3D = $Camera3D

# SubViewport 的尺寸
var viewport_size: Vector2

func _ready():
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

func _update_viewport_size():
	# 获取主窗口尺寸
	var window_size = get_viewport().get_visible_rect().size
	
	# 更新SubViewport尺寸
	sub_viewport.size = Vector2i(window_size)
	viewport_size = Vector2(window_size)
	
	# 调整GamePlane的网格尺寸以匹配窗口比例
	var mesh = game_plane.mesh as QuadMesh
	if mesh:
		mesh.size = Vector2(window_size.x, window_size.y)
	
	# 调整相机位置，确保完整看到平面
	var fov_rad = deg_to_rad(camera_3d.fov)
	var distance = (window_size.y / 2.0) / tan(fov_rad / 2.0)
	# 将距离缩小，让相机更靠近，填满整个视口（即使部分超出也没关系）
	distance *= 0.95  # 可以调整这个系数来控制缩放程度
	# 保持倾斜角度，稍微往下偏移
	camera_3d.position = Vector3(0, -window_size.y * 0.1, distance)

func _unhandled_input(event):
	# 键盘事件和动作事件直接转发
	if event is InputEventKey or event is InputEventAction:
		sub_viewport.push_input(event)
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
