extends Node2D

# 引用对话卡片场景
const DialogueCardScene = preload("res://dialogue/dialogue_card.tscn")
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
	
	# 实例化对话卡片
	var dialogue_card = DialogueCardScene.instantiate()
	
	# 设置对话内容
	dialogue_card.dialogue_content = first_dialogue.content
	dialogue_card.dialogue_type = first_dialogue.type
	
	# 设置起始位置
	dialogue_card.position = start_pos
	
	# 添加到场景中
	add_child(dialogue_card)
	
	# 初始缩放为0
	dialogue_card.scale = Vector2.ZERO
	
	# 创建动画
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 缩放动画（从中心放大）
	tween.tween_property(dialogue_card, "scale", Vector2.ONE * 0.5, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 等待缩放完成
	await tween.finished
	
	# 射出动画
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.set_trans(Tween.TRANS_CUBIC)
	tween2.set_ease(Tween.EASE_OUT)
	
	# 位置动画（快速射出）
	tween2.tween_property(dialogue_card, "position", end_pos, 0.5)
	# 同时恢复正常大小
	tween2.tween_property(dialogue_card, "scale", Vector2.ONE, 0.5)
	
	await tween2.finished
	
	# 到达目标位置后的反弹效果
	var tween3 = create_tween()
	tween3.tween_property(dialogue_card, "scale", Vector2.ONE * 1.1, 0.1)
	tween3.tween_property(dialogue_card, "scale", Vector2.ONE, 0.1)
	
	print("已生成对话卡片：", first_dialogue.content)

