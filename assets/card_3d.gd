extends MeshInstance3D
class_name Card3D

## 3D 平面卡牌 - 用于在3D场景中显示卡牌
## 
## 键盘控制：
## - 空格: 腾空/落下
## - Q/E: Y轴旋转（左右翻转）
## - W/S: X轴旋转（前后倾斜）
## - A/D: Z轴旋转（侧倾）
## - 方向键: 位移
## - R: 重置位置和旋转
## - Tab: 切换选中的卡牌

signal card_clicked
signal card_hovered
signal card_unhovered
signal card_selected(card: Card3D)

@export var card_name: String = "卡牌名称"
@export var card_texture: Texture2D

@onready var sub_viewport: SubViewport = $SubViewport
@onready var card_panel: Panel = $SubViewport/CardPanel
@onready var label: Label = $SubViewport/Panel/Label
@onready var texture_rect: TextureRect = $SubViewport/TextureRect

# 卡牌尺寸（与2D卡牌一致）
const CARD_WIDTH: float = 264.0
const CARD_HEIGHT: float = 345.0

# 3D空间中的缩放因子（用于调整卡牌在3D场景中的大小）
@export var scale_factor: float = 1.0

# 悬停效果
var is_hovered: bool = false
var target_rotation: Vector3 = Vector3.ZERO
var hover_lift: float = 0.0
const HOVER_LIFT_AMOUNT: float = 20.0
const ROTATION_SPEED: float = 8.0

# 键盘控制相关
var is_selected: bool = false  # 是否被选中（用于键盘控制）
var is_floating: bool = false  # 是否处于腾空状态
var target_position: Vector3 = Vector3.ZERO  # 目标位置
var base_z_position: float = 50.0  # 基础Z位置

# 控制参数
const FLOAT_HEIGHT: float = 150.0  # 腾空高度
const MOVE_SPEED: float = 300.0  # 位移速度
const ROTATE_SPEED: float = 2.0  # 旋转速度（弧度/秒）
const SMOOTH_SPEED: float = 10.0  # 平滑过渡速度

# 原始位置和旋转（用于重置）
var original_position: Vector3 = Vector3.ZERO
var original_rotation: Vector3 = Vector3.ZERO

func _ready() -> void:
	# 保存原始位置
	original_position = position
	original_rotation = rotation
	target_position = position
	base_z_position = position.z
	
	# 设置网格尺寸
	var quad_mesh = mesh as QuadMesh
	if quad_mesh:
		quad_mesh.size = Vector2(CARD_WIDTH, CARD_HEIGHT) * scale_factor
	
	# 启用阴影投射
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	
	# 创建材质
	_setup_material()
	
	# 更新卡牌显示
	_update_card_display()

func _setup_material() -> void:
	await get_tree().process_frame
	
	var material = StandardMaterial3D.new()
	material.albedo_texture = sub_viewport.get_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	# 使用 PER_PIXEL 着色以支持光照和阴影
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	# 双面渲染
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# 设置一些基础光照参数
	material.metallic = 0.0
	material.roughness = 0.8
	
	material_override = material

func _update_card_display() -> void:
	if label:
		label.text = card_name
	if texture_rect and card_texture:
		texture_rect.texture = card_texture

func _process(delta: float) -> void:
	if is_selected:
		_handle_keyboard_input(delta)
	
	# 平滑旋转效果
	rotation = rotation.lerp(target_rotation, delta * SMOOTH_SPEED)
	
	# 平滑位移效果
	position = position.lerp(target_position, delta * SMOOTH_SPEED)
	
	# 更新选中状态的视觉反馈
	_update_selection_visual()

func _handle_keyboard_input(delta: float) -> void:
	# 腾空控制 - 空格键
	if Input.is_action_just_pressed("ui_accept"):  # 空格键
		is_floating = !is_floating
		if is_floating:
			target_position.z = base_z_position + FLOAT_HEIGHT
		else:
			target_position.z = base_z_position
	
	# 旋转控制
	if Input.is_key_pressed(KEY_Q):
		target_rotation.y -= ROTATE_SPEED * delta
	if Input.is_key_pressed(KEY_E):
		target_rotation.y += ROTATE_SPEED * delta
	if Input.is_key_pressed(KEY_W):
		target_rotation.x -= ROTATE_SPEED * delta
	if Input.is_key_pressed(KEY_S):
		target_rotation.x += ROTATE_SPEED * delta
	if Input.is_key_pressed(KEY_A):
		target_rotation.z += ROTATE_SPEED * delta
	if Input.is_key_pressed(KEY_D):
		target_rotation.z -= ROTATE_SPEED * delta
	
	# 位移控制 - 方向键
	if Input.is_action_pressed("ui_left"):
		target_position.x -= MOVE_SPEED * delta
	if Input.is_action_pressed("ui_right"):
		target_position.x += MOVE_SPEED * delta
	if Input.is_action_pressed("ui_up"):
		target_position.y += MOVE_SPEED * delta
	if Input.is_action_pressed("ui_down"):
		target_position.y -= MOVE_SPEED * delta
	
	# 重置 - R键
	if Input.is_key_pressed(KEY_R):
		reset_transform()

func _update_selection_visual() -> void:
	# 选中时添加轻微的发光效果或缩放
	if is_selected:
		scale = scale.lerp(Vector3(1.05, 1.05, 1.05), 0.1)
	else:
		scale = scale.lerp(Vector3.ONE, 0.1)

## 设置选中状态
func set_selected(selected: bool) -> void:
	is_selected = selected
	if selected:
		card_selected.emit(self)

## 重置位置和旋转
func reset_transform() -> void:
	target_position = original_position
	target_rotation = original_rotation
	is_floating = false

## 设置卡牌信息
func set_card_info(p_name: String, p_texture: Texture2D = null) -> void:
	card_name = p_name
	card_texture = p_texture
	if is_inside_tree():
		_update_card_display()

## 播放翻转动画
func flip_card(to_back: bool = false, duration: float = 0.3) -> void:
	var tween = create_tween()
	var target_y = PI if to_back else 0.0
	tween.tween_property(self, "target_rotation:y", target_y, duration)

## 腾空
func float_up() -> void:
	is_floating = true
	target_position.z = base_z_position + FLOAT_HEIGHT

## 落下
func float_down() -> void:
	is_floating = false
	target_position.z = base_z_position

## 处理鼠标进入
func on_mouse_enter() -> void:
	is_hovered = true
	if not is_selected:
		target_rotation.x = deg_to_rad(-5)
	card_hovered.emit()

## 处理鼠标离开
func on_mouse_exit() -> void:
	is_hovered = false
	if not is_selected:
		target_rotation.x = 0.0
	card_unhovered.emit()

## 处理点击
func on_click() -> void:
	card_clicked.emit()

