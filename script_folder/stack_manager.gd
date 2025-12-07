extends Node
class_name StackManager

## 堆叠管理器：记录所有堆叠的卡牌名称数组和头卡实例

# 信号：当堆叠变化时触发
signal stack_changed()

# 所有堆叠数据：{ stack_id: { "names": Array[String], "head": Card } }
var stacks: Dictionary = {}
# 卡片到堆叠ID的映射
var _card_to_stack: Dictionary = {}
# 下一个堆叠ID
var _next_stack_id: int = 0

func _ready() -> void:
	Events.card_dropped.connect(_on_card_dropped)

func _on_card_dropped(card: Card) -> void:
	await get_tree().process_frame
	_check_stack(card)

func _check_stack(card: Card) -> void:
	if card in _card_to_stack:
		return
	
	if card.stack_state & CardState.STACK_STATE_STACKING and card.follow_target != null:
		var target = card.follow_target
		
		if target in _card_to_stack:
			# 加入现有堆叠
			var stack_id = _card_to_stack[target]
			stacks[stack_id]["names"].append(card.name)
			_card_to_stack[card] = stack_id
		else:
			# 创建新堆叠
			var stack_id = _next_stack_id
			_next_stack_id += 1
			stacks[stack_id] = {
				"names": [target.name, card.name] as Array[String],
				"head": target
			}
			_card_to_stack[target] = stack_id
			_card_to_stack[card] = stack_id
			target.stop_stacking_on_you.connect(_on_unstacked.bind(target))
		
		card.stop_stacking_on_you.connect(_on_unstacked.bind(card))
		stack_changed.emit()

func _on_unstacked(card: Card) -> void:
	if card not in _card_to_stack:
		return
	
	var stack_id = _card_to_stack[card]
	var names: Array = stacks[stack_id]["names"]
	var idx = names.find(card.name)
	
	if idx == -1 or idx >= names.size() - 1:
		return
	
	# 移除该卡片之后的所有卡片
	var to_remove = names.slice(idx + 1)
	for n in to_remove:
		names.erase(n)
	
	# 从映射中移除
	for c in _card_to_stack.keys():
		if c.name in to_remove:
			_card_to_stack.erase(c)
	
	# 如果只剩一张卡，解散堆叠
	if names.size() <= 1:
		var head = stacks[stack_id]["head"]
		if head in _card_to_stack:
			_card_to_stack.erase(head)
		stacks.erase(stack_id)
	
	stack_changed.emit()

# ==================== 查询接口 ====================

## 获取所有堆叠的卡牌名称数组
func get_all_stack_names() -> Array:
	var result: Array = []
	for stack_id in stacks:
		result.append(stacks[stack_id]["names"].duplicate())
	return result

## 获取所有堆叠的头卡实例
func get_all_head_cards() -> Array[Card]:
	var result: Array[Card] = []
	for stack_id in stacks:
		result.append(stacks[stack_id]["head"])
	return result

## 获取堆叠数量
func get_stack_count() -> int:
	return stacks.size()

## 打印所有堆叠（调试用）
func print_all_stacks() -> void:
	print("===== 堆叠信息 =====")
	for stack_id in stacks:
		print("#%d: %s (头卡: %s)" % [stack_id, stacks[stack_id]["names"], stacks[stack_id]["head"].name])
	print("====================")
