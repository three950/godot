extends Button

# 背包相关
var bag: Node = null  # 背包实例
var character_node: Character = null

func _ready() -> void:
	var parent_node = get_parent()
	if parent_node is Character:
		character_node = parent_node
	else:
		push_warning("【背包按钮】未找到 Character 节点")
		return
	bag = character_node.get_node_or_null("Bag")
	if not bag:
		push_warning("【背包按钮】未找到 Bag 节点")
		return
	pressed.connect(toggle_bag)
	print("【背包按钮】初始化完成")
# 切换背包显示状态
func toggle_bag() -> void:
	if bag.visible:
		close_bag()
	else:
		open_bag()

# 打开背包
func open_bag() -> void:
	print("【背包按钮】打开背包")
	if not bag or not is_instance_valid(bag):
		push_warning("【背包按钮】无法打开背包：未找到背包节点")
		return
	
	if bag.visible:return
	bag.show()

	_update_bag_button_state(true)
	
	print("【背包按钮】背包显示完成")

# 关闭背包
func close_bag() -> void:
	print("【背包按钮】关闭背包")
	if bag and is_instance_valid(bag) and bag.visible:
		bag.hide()
		# 更新按钮状态
		_update_bag_button_state(false)
		print("【背包按钮】背包已关闭")

# 更新背包按钮的状态
func _update_bag_button_state(is_open: bool) -> void:
	if is_open:
		text = "✖"
	else:
		text = "🎒"
