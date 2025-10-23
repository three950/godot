extends Panel
class_name BagSlot

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
	
	# 保存卡片的原始父节点
	var old_parent = card.get_parent()
	if old_parent:
		old_parent.remove_child(card)
	
	# 将卡片添加到卡槽
	add_child(card)
	stored_card = card
	
	# 重置卡片位置和大小以适应卡槽
	card.position = Vector2.ZERO
	card.size = size
	
	# 如果卡片有状态，设置为固定状态
	if "cardCurrentState" in card:
		card.cardCurrentState = card.cardState.fixed
	
	# 发射信号
	card_placed.emit(card)
	
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
	
	# 发射信号
	card_removed.emit(card)
	
	return card

# 获取卡槽中的卡片
func get_card() -> Control:
	return stored_card

