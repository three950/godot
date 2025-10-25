extends "res://card.gd"
class_name CharacterCard

# 角色卡片特有属性
@export var hp: int = 10
@export var atk: int = 1
@export var defense: int = 0
@export var equipment: String = ""

# 角色数据引用
var character_data: CharacterData = null

# 属性标签引用
var hp_label: Label = null
var atk_label: Label = null
var defense_label: Label = null

# 背包相关
var bag_instance: Panel = null  # 背包实例
var bag_scene = preload("res://bag.tscn")  # 预加载背包场景
var bag_button: Button = null  # 背包按钮

func _ready() -> void:
	super._ready()
	# 自动获取标签引用
	var stats_container = get_node_or_null("Control/ColorRect/StatsContainer")
	if stats_container:
		hp_label = stats_container.get_node_or_null("HPLabel")
		var right_stats = stats_container.get_node_or_null("RightStats")
		if right_stats:
			atk_label = right_stats.get_node_or_null("ATKLabel")
			defense_label = right_stats.get_node_or_null("DEFLabel")
	update_stat_labels()
	
	# 创建背包按钮
	_create_bag_button()

# 更新属性标签显示（使用Label动态显示，值可以随时改变）
func update_stat_labels() -> void:
	if hp_label:
		hp_label.text = "%d" % hp
	if atk_label:
		atk_label.text = "%d" % atk
	if defense_label:
		defense_label.text = "%d" % defense

# 设置角色属性
func set_character_stats(char_hp: int, char_atk: int, char_defense: int, char_equipment: String = "") -> void:
	hp = char_hp
	atk = char_atk
	defense = char_defense
	equipment = char_equipment
	update_stat_labels()

# 修改HP（可以用于战斗等场景）
func modify_hp(amount: int) -> void:
	hp += amount
	if hp < 0:
		hp = 0
	update_stat_labels()

# 修改ATK
func modify_atk(amount: int) -> void:
	atk += amount
	if atk < 0:
		atk = 0
	update_stat_labels()

# 修改防御
func modify_defense(amount: int) -> void:
	defense += amount
	if defense < 0:
		defense = 0
	update_stat_labels()

# 设置标签引用（手动设置）
func set_stat_labels(hp_lbl: Label, atk_lbl: Label, def_lbl: Label) -> void:
	hp_label = hp_lbl
	atk_label = atk_lbl
	defense_label = def_lbl
	update_stat_labels()

# 创建背包按钮
func _create_bag_button() -> void:
	# 创建按钮
	bag_button = Button.new()
	bag_button.text = "🎒"  # 使用背包emoji作为图标
	bag_button.custom_minimum_size = Vector2(30, 30)
	
	# 设置按钮样式
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.3, 0.4, 0.8)  # 深蓝色背景
	style_normal.corner_radius_top_left = 5
	style_normal.corner_radius_top_right = 5
	style_normal.corner_radius_bottom_left = 5
	style_normal.corner_radius_bottom_right = 5
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.3, 0.4, 0.5, 0.9)  # 悬停时稍亮
	style_hover.corner_radius_top_left = 5
	style_hover.corner_radius_top_right = 5
	style_hover.corner_radius_bottom_left = 5
	style_hover.corner_radius_bottom_right = 5
	
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.1, 0.2, 0.3, 1.0)  # 按下时更深
	style_pressed.corner_radius_top_left = 5
	style_pressed.corner_radius_top_right = 5
	style_pressed.corner_radius_bottom_left = 5
	style_pressed.corner_radius_bottom_right = 5
	
	bag_button.add_theme_stylebox_override("normal", style_normal)
	bag_button.add_theme_stylebox_override("hover", style_hover)
	bag_button.add_theme_stylebox_override("pressed", style_pressed)
	
	# 设置按钮位置（在卡片右侧）
	bag_button.position = Vector2(size.x + 5, 0)
	
	# 设置高层级，确保按钮在最上面
	bag_button.z_index = 100
	
	# 添加到卡片
	add_child(bag_button)
	
	# 连接按钮点击信号
	bag_button.pressed.connect(toggle_bag)
	
	print("【角色卡片】背包按钮已创建")

# 切换背包显示状态
func toggle_bag() -> void:
	if bag_instance and is_instance_valid(bag_instance):
		# 如果背包已显示，则关闭
		close_bag()
	else:
		# 如果背包未显示，则打开
		open_bag()

# 打开背包
func open_bag() -> void:
	print("【角色卡片】打开背包")
	if bag_instance and is_instance_valid(bag_instance):
		print("【角色卡片】背包已经显示")
		return  # 背包已经显示
	
	# 实例化背包
	bag_instance = bag_scene.instantiate()
	
	# 将背包添加到场景树的根节点
	var root = get_tree().root
	root.add_child(bag_instance)
	
	# 设置背包位置（在卡片右侧）
	var bag_pos = global_position + Vector2(size.x + 10, 0)
	bag_instance.global_position = bag_pos
	
	# 加载角色的背包数据
	if character_data:
		print("【角色卡片】加载角色背包数据：", character_data.character_name)
		bag_instance.load_character_bag(character_data)
	else:
		push_warning("【角色卡片】角色卡片没有关联的角色数据，背包将为空")
	
	# 连接背包的关闭请求信号
	if bag_instance.has_signal("close_requested"):
		bag_instance.close_requested.connect(_on_bag_close_requested)
	
	# 更新按钮状态
	_update_bag_button_state(true)
	
	print("【角色卡片】背包显示完成")

# 关闭背包
func close_bag() -> void:
	print("【角色卡片】关闭背包")
	if bag_instance and is_instance_valid(bag_instance):
		# 保存背包数据回角色
		if bag_instance.has_method("save_to_character"):
			bag_instance.save_to_character()
		
		# 将槽位内的卡片移到背包面板下（让 queue_free 能自动删除它们）
		if bag_instance.has_method("prepare_for_close"):
			bag_instance.prepare_for_close()
		
		# 释放背包实例（会自动删除作为子节点的槽位内卡片）
		bag_instance.queue_free()
		bag_instance = null
		
		# 更新按钮状态
		_update_bag_button_state(false)
		
		print("【角色卡片】背包已关闭")

# 更新背包按钮的状态
func _update_bag_button_state(is_open: bool) -> void:
	if not bag_button:
		return
	
	if is_open:
		# 背包打开时的样式
		bag_button.text = "✖"  # 改为关闭图标
		var style_active = StyleBoxFlat.new()
		style_active.bg_color = Color(0.8, 0.5, 0.2, 0.9)  # 橙色表示激活
		style_active.corner_radius_top_left = 5
		style_active.corner_radius_top_right = 5
		style_active.corner_radius_bottom_left = 5
		style_active.corner_radius_bottom_right = 5
		bag_button.add_theme_stylebox_override("normal", style_active)
	else:
		# 背包关闭时的样式
		bag_button.text = "🎒"  # 背包图标
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.2, 0.3, 0.4, 0.8)  # 深蓝色背景
		style_normal.corner_radius_top_left = 5
		style_normal.corner_radius_top_right = 5
		style_normal.corner_radius_bottom_left = 5
		style_normal.corner_radius_bottom_right = 5
		bag_button.add_theme_stylebox_override("normal", style_normal)

# 当背包请求关闭时的回调
func _on_bag_close_requested() -> void:
	print("【角色卡片】收到背包关闭请求")
	close_bag()
