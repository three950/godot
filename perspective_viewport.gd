extends Node3D

@onready var sub_viewport: SubViewport = $SubViewport
@onready var game_plane: MeshInstance3D = $GamePlane
@onready var camera_3d: Camera3D = $Camera3D

# SubViewport 的尺寸
var viewport_size: Vector2

func _ready():
	# 等待一帧确保SubViewport已经准备好
	await get_tree().process_frame
	
	viewport_size = Vector2(sub_viewport.size)
	
	# Camera2D 保持启用，这样可以在SubViewport内拖动场景
	
	# 获取SubViewport的纹理并应用到3D平面的材质上
	var viewport_texture = sub_viewport.get_texture()
	var material = game_plane.get_surface_override_material(0) as StandardMaterial3D
	if material:
		material.albedo_texture = viewport_texture
		# 使用未着色模式以获得正确的颜色，不受光照影响
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# 确保透明度正确
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

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

