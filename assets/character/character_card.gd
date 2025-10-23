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

# 悬停UI相关
var bag_instance: Panel = null  # 背包实例
var show_timer: Timer = null  # 显示延迟计时器
var hide_timer: Timer = null  # 隐藏延迟计时器
var is_hover_area_hovered: bool = false  # 悬停区域是否被悬停
var was_hover_area_hovered: bool = false  # 上一帧的悬停状态
var bag_scene = preload("res://bag.tscn")  # 预加载背包场景
var hover_trigger_width: float = 15.0  # 悬停触发区域宽度

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
	
	# 创建计时器
	show_timer = Timer.new()
	show_timer.wait_time = 0.5
	show_timer.one_shot = true
	show_timer.timeout.connect(_on_show_timer_timeout)
	add_child(show_timer)
	
	hide_timer = Timer.new()
	hide_timer.wait_time = 0.5
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_on_hide_timer_timeout)
	add_child(hide_timer)

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

# 每帧检测鼠标位置
func _process(_delta: float) -> void:
	# 先调用父类的 _process，保持拖拽功能
	super._process(_delta)
	
	# 计算悬停触发区域（卡片右侧）
	var hover_rect = Rect2(
		global_position + Vector2(size.x, 0),  # 从卡片右边开始
		Vector2(hover_trigger_width, size.y)    # 宽度15像素，高度与卡片相同
	)
	
	# 检测鼠标是否在悬停区域内
	var mouse_pos = get_global_mouse_position()
	is_hover_area_hovered = hover_rect.has_point(mouse_pos)
	
	# 检测状态变化
	if is_hover_area_hovered and not was_hover_area_hovered:
		# 鼠标进入悬停区域
		_on_hover_area_entered()
	elif not is_hover_area_hovered and was_hover_area_hovered:
		# 鼠标离开悬停区域
		_on_hover_area_exited()
	
	was_hover_area_hovered = is_hover_area_hovered

# 当鼠标进入悬停区域
func _on_hover_area_entered() -> void:
	print("鼠标进入悬停区域")
	# 停止隐藏计时器
	if hide_timer and hide_timer.time_left > 0:
		hide_timer.stop()
	
	# 如果背包已经显示，不需要重新启动显示计时器
	if bag_instance and is_instance_valid(bag_instance):
		return
	
	# 启动显示计时器
	if show_timer:
		print("启动显示计时器")
		show_timer.start()

# 当鼠标离开悬停区域
func _on_hover_area_exited() -> void:
	print("鼠标离开悬停区域")
	# 停止显示计时器
	if show_timer and show_timer.time_left > 0:
		show_timer.stop()
	
	# 如果背包已显示，启动隐藏计时器
	if bag_instance and is_instance_valid(bag_instance):
		print("启动隐藏计时器")
		hide_timer.start()

# 显示计时器超时 - 显示背包
func _on_show_timer_timeout() -> void:
	print("显示计时器超时")
	if not is_hover_area_hovered:
		print("鼠标已离开悬停区域，取消显示")
		return
	
	print("准备显示背包")
	show_bag()

# 隐藏计时器超时 - 隐藏背包
func _on_hide_timer_timeout() -> void:
	print("隐藏计时器超时")
	# 检查鼠标是否在背包区域内
	if bag_instance and is_instance_valid(bag_instance):
		print("检查背包鼠标状态：", bag_instance.is_mouse_over)
		if bag_instance.is_mouse_over:
			# 鼠标在背包内，不隐藏
			print("鼠标在背包内，保持显示")
			return
		print("鼠标不在背包内，准备隐藏")
		hide_bag()
	else:
		print("背包实例无效")

# 显示背包
func show_bag() -> void:
	print("show_bag 被调用")
	if bag_instance and is_instance_valid(bag_instance):
		print("背包已经显示")
		return  # 背包已经显示
	
	# 实例化背包
	print("实例化背包")
	bag_instance = bag_scene.instantiate()
	
	# 将背包添加到场景树的合适位置（通常是根节点或UI层）
	var root = get_tree().root
	print("将背包添加到根节点")
	root.add_child(bag_instance)
	
	# 设置背包位置（在卡片右侧）
	var bag_pos = global_position + Vector2(size.x + 10, 0)
	print("设置背包位置：", bag_pos)
	bag_instance.global_position = bag_pos
	
	# 加载角色的背包数据
	if character_data:
		print("加载角色背包数据：", character_data.character_name)
		bag_instance.load_character_bag(character_data)
	else:
		push_warning("角色卡片没有关联的角色数据，背包将为空")
	
	# 连接背包的鼠标事件
	bag_instance.mouse_exited_bag.connect(_on_bag_mouse_exited)
	print("背包显示完成")

# 隐藏背包
func hide_bag() -> void:
	if bag_instance and is_instance_valid(bag_instance):
		bag_instance.queue_free()
		bag_instance = null

# 当鼠标离开背包区域
func _on_bag_mouse_exited() -> void:
	print("鼠标离开背包区域")
	# 检查鼠标是否回到悬停区域
	if is_hover_area_hovered:
		print("鼠标在悬停区域，不隐藏")
		return  # 鼠标在悬停区域，不隐藏
	
	# 启动隐藏计时器
	if hide_timer:
		print("从背包离开，启动隐藏计时器")
		hide_timer.start()
