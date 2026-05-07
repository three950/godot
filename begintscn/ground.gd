extends Node2D
#已废弃，仅作对话系统的参考代码，本身无法允许
# 引用对话资源
const BeginDialogue = preload("res://dialogue/begin.tres")

func _ready() -> void:
	# 不再自动生成，等待点击事件
	pass

func _input(event: InputEvent) -> void:
	# 检测鼠标左键点击
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# 点击后生成对话卡片
			generate_first_dialogue()

# 生成第一句对话卡片（带射出动画）
func generate_first_dialogue() -> void:
	# 获取对话资源
	var dialogue_group: DialogueGroup = BeginDialogue
	if dialogue_group == null or dialogue_group.dialogue_list.is_empty():
		push_error("未找到对话资源或对话列表为空")
		return
	
	# 获取第一句对话
	var first_dialogue: Dialogue = dialogue_group.dialogue_list[0]
	
	# 计算两个角色卡片的中间偏上位置作为目标位置
	var card1 = get_node_or_null("Card_莉可")
	var card2 = get_node_or_null("Card_莉可2")
	
	var end_pos: Vector2
	var start_pos: Vector2
	
	if card1 and card2:
		# 计算中间位置
		var middle_x = (card1.position.x + card2.position.x) / 2.0
		var middle_y = (card1.position.y + card2.position.y) / 2.0
		# 目标位置：中间偏上120像素
		end_pos = Vector2(middle_x, middle_y - 80)
		# 起始位置：从右边角色位置射出
		start_pos = card2.position
	else:
		# 如果找不到角色卡片，使用默认位置
		end_pos = Vector2(868, 340)
		start_pos = Vector2(984, 459)
	
	# 使用 CardShooter 生成对话卡片（传入 Dialogue 对象即可）
	var dialogue_card = await CardShooter.shoot_card(
		first_dialogue as Variant,  # 传入 Dialogue 对象
		start_pos,
		end_pos,
		self  # 使用当前节点作为容器
	)
	
	if dialogue_card:
		print("已生成对话卡片：", first_dialogue.content)
