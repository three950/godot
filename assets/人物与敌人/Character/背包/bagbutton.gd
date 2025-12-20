extends Button
var bag = null
var is_open: bool = false
var original_parent
var character_node: Character = null
var bag_scene: PackedScene = null
@export var bag_sound: AudioStream
func _ready() -> void:
	original_parent = get_parent()
	if original_parent is Character:
		character_node = original_parent
	else:
		push_warning("【背包按钮】未找到 Character 节点")
		return
	# 加载背包场景但不实例化
	bag_scene = load("res://assets/人物与敌人/Character/背包/bag.tscn")
	if not bag_scene:
		push_warning("【背包按钮】无法加载背包场景")
	pressed.connect(toggle_bag)
	print("【背包按钮】初始化完成")
# 切换背包显示状态
func toggle_bag() -> void:
	if is_open:
		close_bag()
	else:
		open_bag()

# 打开背包
func open_bag() -> void:
	text = "✖"
	print("【背包按钮】打开背包")
	
	# 如果背包实例不存在，则创建一个新实例
	if not bag or not is_instance_valid(bag):
		if bag_scene:
			bag = bag_scene.instantiate()
			# 设置与原场景相同的属性
			bag.layout_mode = 0
			bag.offset_left = 94.0
			bag.offset_top = -7.0
			bag.offset_right = 282.0
			bag.offset_bottom = 123.0
			bag.mouse_filter = 2
			bag.add_to_group("Cards")
			
			# 从character节点获取character数据并传递给bag
			if character_node and character_node.character:
				print("【背包按钮】传递character数据给背包")
				bag.character = character_node.character
		else:
			push_warning("【背包按钮】无法打开背包：背包场景未加载")
			return
	
	# 将背包添加到父节点
	original_parent.add_child(bag)
	is_open = true
	print("【背包按钮】背包显示完成")
	SFXPlayer.play(bag_sound)

# 关闭背包
func close_bag() -> void:
	text = "🎒"
	print("【背包按钮】关闭背包")
	if bag and is_instance_valid(bag):
		# 移除但不删除，以便下次再使用
		original_parent.remove_child(bag)
	is_open = false
	print("【背包按钮】背包已关闭")
	SFXPlayer.play(bag_sound)
