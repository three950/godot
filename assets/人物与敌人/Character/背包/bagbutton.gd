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
		push_warning("【防具按钮】未找到 Character 节点")
		return
	# 加载防具场景但不实例化
	bag_scene = load("res://assets/人物与敌人/Character/防具/bag.tscn")
	if not bag_scene:
		push_warning("【防具按钮】无法加载防具场景")
	pressed.connect(toggle_bag)
	print("【防具按钮】初始化完成")
# 切换防具显示状态
func toggle_bag() -> void:
	if is_open:
		close_bag()
	else:
		open_bag()

# 打开防具
func open_bag() -> void:
	text = "✖"
	print("【防具按钮】打开防具")
	
	# 如果防具实例不存在，则创建一个新实例
	if not bag or not is_instance_valid(bag):
		if bag_scene:
			bag = bag_scene.instantiate()
			# 设置与原场景相同的属性
			bag.layout_mode = 0
			bag.offset_left = 94.0*3
			bag.offset_top = -7.0*3
			bag.offset_right = 282.0*3
			bag.offset_bottom = 123.0*3
			bag.mouse_filter = 2
			bag.add_to_group("Cards")
			
			# 从character节点获取character数据并传递给bag
			if character_node and character_node.character:
				print("【防具按钮】传递character数据给防具")
				bag.character = character_node.character
		else:
			push_warning("【防具按钮】无法打开防具：防具场景未加载")
			return
	
	# 将防具添加到父节点
	original_parent.add_child(bag)
	is_open = true
	print("【防具按钮】防具显示完成")
	SFXPlayer.play(bag_sound)

# 关闭防具
func close_bag() -> void:
	text = "🎒"
	print("【防具按钮】关闭防具")
	if bag and is_instance_valid(bag):
		# 移除但不删除，以便下次再使用
		original_parent.remove_child(bag)
	is_open = false
	print("【防具按钮】防具已关闭")
	SFXPlayer.play(bag_sound)
