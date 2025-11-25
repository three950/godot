extends Button
@onready var bag: bag_slot = $"../Bag"
var is_open: bool = false
var original_parent
var character_node: Character = null
var bag_scene: PackedScene = null
func _ready() -> void:
	if bag:
		print("有bag")
		original_parent=bag.get_parent()
	if original_parent is Character:
		character_node = original_parent
	else:
		push_warning("【背包按钮】未找到 Character 节点")
		return
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
	if not bag or not is_instance_valid(bag):
		push_warning("【背包按钮】无法打开背包：未找到背包节点")
		return
	
	original_parent.add_child(bag)
	is_open = true
	print("【背包按钮】背包显示完成")

# 关闭背包
func close_bag() -> void:
	text = "🎒"
	print("【背包按钮】关闭背包")
	if bag and is_instance_valid(bag) and bag.visible:
		original_parent.remove_child(bag)
	is_open = false
	print("【背包按钮】背包已关闭")
