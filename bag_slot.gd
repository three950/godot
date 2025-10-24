extends Panel
class_name BagSlot

# 预加载 BaggableCard 类以支持类型检查
const BaggableCardScript = preload("res://baggable_card.gd")

# 信号：当卡片被放入卡槽
signal card_placed(card: Control)
# 信号：当卡片被移出卡槽
signal card_removed(card: Control)

# 卡槽状态
var stored_card: Control = null  # 当前存储的卡片

func _ready() -> void:
	# 确保可以接收鼠标事件
	mouse_filter = Control.MOUSE_FILTER_STOP

# 判断卡槽是否为空
func is_empty() -> bool:
	return stored_card == null

# 将卡片放入卡槽
func place_card(card: Control) -> bool:
	# 如果卡槽已有卡片，不能接收
	if not is_empty():
		return false
	
	# 检查是否是可背包物品（BaggableCard）
	var is_baggable = card.get_script() != null and (card.get_script() == BaggableCardScript or card.get_script().get_base_script() == BaggableCardScript or _is_derived_from_baggable(card.get_script()))
	
	if not is_baggable:
		print("【卡槽】只能放入可背包物品（装备、道具、资源）")
		return false
	
	# 检查卡片是否可以放入背包
	if card.has_method("can_put_in_bag") and not card.can_put_in_bag():
		print("【卡槽】该卡片当前状态不能放入背包")
		return false
	
	# 保存卡片的原始父节点
	var old_parent = card.get_parent()
	if old_parent:
		old_parent.remove_child(card)
	
	# 将卡片添加到卡槽
	add_child(card)
	stored_card = card
	
	# 【等比缩放】计算缩放比例以适应卡槽
	var card_size = card.size
	var slot_size = size
	
	# 计算宽度和高度的缩放比例，取较小值以确保卡片完全适应
	var scale_x = slot_size.x / card_size.x if card_size.x > 0 else 1.0
	var scale_y = slot_size.y / card_size.y if card_size.y > 0 else 1.0
	var scale_factor = min(scale_x, scale_y)
	
	# 应用等比缩放
	card.scale = Vector2(scale_factor, scale_factor)
	
	# 计算居中位置（考虑缩放后的实际大小）
	var scaled_card_size = card_size * scale_factor
	card.position = (slot_size - scaled_card_size) / 2.0
	
	# 【关键修复】设置卡片的 z_index，确保比背景的 ColorRect 高
	# 卡槽下的 ColorRect 默认 z_index 是 0，所以卡片设置为 1
	card.z_index = 1
	
	# 确保卡片在场景树中排在 ColorRect 之后（后添加的节点会在上层渲染）
	move_child(card, -1)
	
	# 如果卡片有状态，设置为固定状态
	if "cardCurrentState" in card:
		card.cardCurrentState = card.cardState.fixed
	
	# 调用卡片的放入背包回调
	if card.has_method("on_put_in_bag"):
		card.on_put_in_bag(self)
	
	# 发射信号
	card_placed.emit(card)
	
	print("【卡槽】卡片已放入，z_index=%d, 节点索引=%d" % [card.z_index, card.get_index()])
	
	return true

# 从卡槽移除卡片
func remove_card() -> Control:
	if is_empty():
		return null
	
	var card = stored_card
	stored_card = null
	
	# 从卡槽移除卡片节点
	if card.get_parent() == self:
		remove_child(card)
	
	# 【重置缩放】恢复卡片的原始大小
	card.scale = Vector2(1.0, 1.0)
	
	# 调用卡片的从背包取出回调
	if card.has_method("on_take_out_from_bag"):
		card.on_take_out_from_bag(self)
	
	# 发射信号
	card_removed.emit(card)
	
	return card

# 检查脚本是否继承自 BaggableCard
func _is_derived_from_baggable(script: Script) -> bool:
	if script == null:
		return false
	
	var base = script.get_base_script()
	while base != null:
		if base == BaggableCardScript:
			return true
		base = base.get_base_script()
	
	return false

# 获取卡槽中的卡片
func get_card() -> Control:
	return stored_card

