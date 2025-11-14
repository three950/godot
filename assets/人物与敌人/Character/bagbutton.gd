extends Button

# 背包相关
var bag_instance: Panel = null  # 背包实例
var bag_scene = preload("res://bag.tscn")  # 预加载背包场景

# 角色卡片引用（父节点）
var character_card: CharacterCard = null

func _ready() -> void:
	# 获取父节点（CharacterCard）引用
	character_card = get_parent() as CharacterCard
	
	if not character_card:
		push_warning("【背包按钮】未找到父节点 CharacterCard")
		return
	
	# 连接按钮点击信号
	pressed.connect(toggle_bag)
	
	# 初始化按钮文本
	text = "🎒"
	
	print("【背包按钮】初始化完成")

func _process(delta: float) -> void:
	# 更新背包位置，使其跟随角色卡片
	update_bag_position()

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
	print("【背包按钮】打开背包")
	if bag_instance and is_instance_valid(bag_instance):
		print("【背包按钮】背包已经显示")
		return  # 背包已经显示
	
	if not character_card:
		push_warning("【背包按钮】无法打开背包：未找到角色卡片引用")
		return
	
	# 实例化背包
	bag_instance = bag_scene.instantiate()
	
	# 将背包添加到场景树的根节点
	var root = get_tree().root
	root.add_child(bag_instance)
	
	# 设置背包位置（在卡片右侧）
	update_bag_position()
	
	# 加载角色的背包数据
	if character_card.character_data:
		print("【背包按钮】加载角色背包数据：", character_card.character_data.character_name)
		bag_instance.load_character_bag(character_card.character_data, character_card)  # 传递角色卡片引用
	else:
		push_warning("【背包按钮】角色卡片没有关联的角色数据，背包将为空")
	
	# 连接背包的关闭请求信号
	if bag_instance.has_signal("close_requested"):
		bag_instance.close_requested.connect(_on_bag_close_requested)
	
	# 更新按钮状态
	_update_bag_button_state(true)
	
	print("【背包按钮】背包显示完成")

# 更新背包位置，使其跟随卡片
func update_bag_position() -> void:
	if bag_instance and is_instance_valid(bag_instance) and character_card:
		# 计算背包位置（在卡片右侧）
		var bag_pos = character_card.global_position + Vector2(character_card.size.x + 5, 0)
		bag_instance.global_position = bag_pos

# 关闭背包
func close_bag() -> void:
	print("【背包按钮】关闭背包")
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
		
		print("【背包按钮】背包已关闭")

# 更新背包按钮的状态
func _update_bag_button_state(is_open: bool) -> void:
	if is_open:
		# 背包打开时，改为关闭图标
		text = "✖"
	else:
		# 背包关闭时，显示背包图标
		text = "🎒"

# 当背包请求关闭时的回调
func _on_bag_close_requested() -> void:
	print("【背包按钮】收到背包关闭请求")
	close_bag()
