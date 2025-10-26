extends Node2D

# 卡片场景（用于建筑卡片）
@export var card_scene: PackedScene
# 卡槽容器
@export var slot_container: HBoxContainer
# 刷新按钮
@export var refresh_button: Button
# 金币显示标签
@export var coin_label: Label

# 卡槽数组，用于存储卡槽节点
var slots: Array[Control] = []

# 所有可售商品数据（从GameData获取）
var all_shop_items: Array = []

# 金币数量
var coins: int = 0

# 探窟者协会卡片引用
var association_card: Control = null

func _ready() -> void:
	if slot_container == null:
		push_error("slot_container 未设置！")
		return
	
	# 确保容器不阻挡鼠标事件和不裁剪内容
	slot_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_container.clip_contents = false
	
	# 连接刷新按钮信号
	if refresh_button:
		refresh_button.pressed.connect(_on_refresh_button_pressed)
	
	# 初始化金币显示
	update_coin_display()
	
	# 从GameData加载所有商品数据
	load_shop_items()
	
	# 生成商店
	generate_shop()

func generate_shop() -> void:
	# 清空所有卡槽
	clear_shop()
	
	# 创建8个卡槽
	for i in range(8):
		var slot = create_slot(i)
		slots.append(slot)
		slot_container.add_child(slot)
	
	# 第一个卡槽：固定的建筑卡片（architecture 类型）
	create_architecture_card(slots[0], "探窟家协会", "res://assets/neutral_buildings/Association_of_Grotters.png")
	
	# 连接探窟者协会的堆叠信号
	if association_card != null:
		association_card.card_stacked_on.connect(_on_association_card_stacked)
	
	# 从第2个卡槽开始，填满剩余的7个卡槽
	# 创建一个临时数组并打乱顺序
	var shuffled_items = all_shop_items.duplicate()
	shuffled_items.shuffle()
	
	# 填满剩余的7个卡槽
	var slots_to_fill = min(7, shuffled_items.size())
	for i in range(slots_to_fill):
		var slot_index = i + 1  # 卡槽 1-7
		var item_data = shuffled_items[i]
		create_selling_card(slots[slot_index], item_data)

# 从GameData加载所有商品数据
func load_shop_items() -> void:
	# 等待GameData加载完成
	if not GameData.is_data_loaded:
		await get_tree().create_timer(0.1).timeout
	
	# 只获取资源和装备数据（排除道具）
	all_shop_items = []
	all_shop_items.append_array(GameData.get_all_resources())
	all_shop_items.append_array(GameData.get_all_equipments())
	print("商店加载了 %d 个商品（资源+装备）" % all_shop_items.size())

# 清空商店
func clear_shop() -> void:
	# 清空所有卡槽
	for slot in slots:
		slot.queue_free()
	slots.clear()

# 刷新按钮点击事件
func _on_refresh_button_pressed() -> void:
	print("刷新商店（只刷新selling类型卡片）...")
	refresh_selling_cards()

# 刷新商店中的 selling 类型卡片
func refresh_selling_cards() -> void:
	# 遍历所有卡槽，找到并立即删除 selling 类型的卡片
	for slot in slots:
		# 获取卡槽中的所有子节点（复制数组以避免修改时出错）
		var children = slot.get_children().duplicate()
		for child in children:
			# 跳过Panel和ColorRect（卡槽的视觉效果）
			if child is Panel or child is ColorRect:
				continue
			
			# 检查是否是 selling 类型的卡片
			if "card_type" in child and child.card_type == 1:  # cardType.selling
				print("  删除 selling 卡片: " + child.name)
				slot.remove_child(child)  # 立即从父节点移除
				child.queue_free()  # 然后释放内存
	
	# 不需要等待，因为已经从场景树中移除了
	
	# 创建新的随机商品卡片
	var shuffled_items = all_shop_items.duplicate()
	shuffled_items.shuffle()
	
	# 遍历卡槽1-7，填充新的selling卡片
	var item_index = 0
	for i in range(1, 8):  # 卡槽1到7
		if i >= slots.size():
			break
		
		var slot = slots[i]
		
		# 检查该卡槽是否有architecture类型的卡片（不应该有，但以防万一）
		var has_architecture = false
		for child in slot.get_children():
			if child is Panel or child is ColorRect:
				continue
			# 只有architecture类型的卡片才跳过
			if "card_type" in child and child.card_type == 2:  # cardType.architecture
				has_architecture = true
				print("  卡槽 %d 有architecture卡片 %s，跳过" % [i, child.name])
				break
		
		# 如果卡槽没有architecture卡片且还有商品可填充，就填充
		if not has_architecture and item_index < shuffled_items.size():
			var item_data = shuffled_items[item_index]
			create_selling_card(slot, item_data)
			print("  卡槽 %d 填充新商品: %s" % [i, item_data.get("名称", "未知")])
			item_index += 1

# 创建卡槽
func create_slot(index: int) -> Control:
	var slot = Control.new()
	slot.name = "Slot_" + str(index)
	slot.custom_minimum_size = Vector2(88, 115)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 允许鼠标事件穿透
	slot.clip_contents = false  # 不裁剪超出边界的内容
	
	# 添加视觉边框
	var panel = Panel.new()
	panel.size = Vector2(88, 115)
	panel.modulate = Color(0.7, 0.7, 0.7, 0.6)  # 半透明灰色背景
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 允许鼠标事件穿透
	slot.add_child(panel)
	
	# 添加边框效果
	var border = ColorRect.new()
	border.size = Vector2(88, 115)
	border.color = Color(0.5, 0.5, 0.5, 0.8)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(border)
	
	var inner = ColorRect.new()
	inner.position = Vector2(2, 2)
	inner.size = Vector2(84, 111)
	inner.color = Color(0.2, 0.2, 0.2, 0.3)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(inner)
	
	return slot

# 创建建筑类型卡片（不可拖拽）
func create_architecture_card(slot: Control, card_name: String, texture_path: String) -> void:
	var card_instance = card_scene.instantiate()
	card_instance.name = "Card_" + card_name
	
	# 设置卡片类型为 architecture
	card_instance.card_type = 2  # cardType.architecture
	
	# 探窟者协会不接受堆叠
	if card_name == "探窟家协会":
		card_instance.can_accept_stack = true  # 允许堆叠
		card_instance.accept_value_only = true  # 只接受带 value 的卡
	
	# 设置卡片位置（相对于卡槽）
	card_instance.position = Vector2(0, 0)
	
	# 设置卡片内容
	setup_card_content(card_instance, card_name, texture_path)
	
	# 将卡片添加到卡槽
	slot.add_child(card_instance)
	
	# 如果是探窟者协会，保存引用
	if card_name == "探窟家协会":
		association_card = card_instance
	
	print("创建建筑卡片: " + card_name)

# 创建商品类型卡片（可拖拽，但会回到原位）
func create_selling_card(slot: Control, card_data: Dictionary) -> void:
	# 使用 CardFactory 统一创建卡片
	CardFactory.create_by_card_scene(card_data, slot, Vector2.ZERO, 1)

# 设置建筑卡片内容（纹理和文本）
func setup_card_content(card_instance: Control, card_name: String, texture_path: String) -> void:
	# 查找并设置子节点
	var texture_rect = card_instance.get_node("Control/ColorRect/TextureRect")
	var label = card_instance.get_node("Control/ColorRect/Label")
	
	# 加载并设置纹理
	var texture = load(texture_path)
	if texture:
		texture_rect.texture = texture
	else:
		push_warning("无法加载纹理: " + texture_path)
	
	# 设置标签文本
	label.text = card_name

# 更新金币显示
func update_coin_display() -> void:
	if coin_label:
		coin_label.text = "金币: %d" % coins

# 处理探窟者协会的堆叠事件
func _on_association_card_stacked(stacked_card: Control) -> void:
	print("有卡片堆叠到探窟者协会: " + stacked_card.name)
	
	# 获取卡片的value值
	var total_value = 0
	
	# 检查堆叠的卡片本身
	if "value" in stacked_card:
		total_value += stacked_card.value
		print("  卡片价值: %d" % stacked_card.value)
	
	# 检查堆叠卡片上的所有子卡片（递归计算）
	if "stacked_cards" in stacked_card:
		total_value += calculate_stack_value(stacked_card.stacked_cards)
	
	# 累加到金币
	coins += total_value
	print("  总价值: %d, 当前金币: %d" % [total_value, coins])
	
	# 更新显示
	update_coin_display()
	
	# 销毁卡片及其堆叠的所有子卡片
	destroy_card_with_stack(stacked_card)
	
	# 从探窟者协会的堆叠列表中移除
	if association_card and "stacked_cards" in association_card:
		if stacked_card in association_card.stacked_cards:
			association_card.stacked_cards.erase(stacked_card)

# 递归计算堆叠卡片的总价值
func calculate_stack_value(cards: Array) -> int:
	var total = 0
	for card in cards:
		if "value" in card:
			total += card.value
			print("  子卡片价值: %d" % card.value)
		# 递归计算子卡片的堆叠
		if "stacked_cards" in card:
			total += calculate_stack_value(card.stacked_cards)
	return total

# 销毁卡片及其所有堆叠的子卡片
func destroy_card_with_stack(card: Control) -> void:
	if card == null:
		return
	
	# 先销毁所有子卡片
	if "stacked_cards" in card:
		var children = card.stacked_cards.duplicate()  # 复制数组避免修改时出错
		for child_card in children:
			destroy_card_with_stack(child_card)
	
	# 销毁卡片本身
	print("  销毁卡片: " + card.name)
	card.queue_free()
