extends "res://card.gd"
class_name BaggableCard

# 可放入背包的物品卡片基类
# 所有可以放入背包、在商店出售的卡片都继承此类
# 包括：装备(EquipmentCard)、道具(ItemCard)、资源(ResourceCard)

@export var value: int = 1  # 物品价值（用于商店出售/购买）
@export var is_relic: bool = false  # 是否是遗物

func _ready() -> void:
	super._ready()
	# 可背包物品的通用初始化

# 判断是否可以放入背包
func can_put_in_bag() -> bool:
	# 只有 normal 类型的卡片可以放入背包
	# selling 和 architecture 类型不能放入背包
	return card_type == cardType.normal

# 放入背包时的回调
func on_put_in_bag(_bag_slot: Node) -> void:
	print("物品 %s 已放入背包槽位" % name)
	# 子类可以重写此方法添加额外逻辑

# 从背包取出时的回调
func on_take_out_from_bag(_bag_slot: Node) -> void:
	print("物品 %s 已从背包取出" % name)
	# 子类可以重写此方法添加额外逻辑

# 获取物品的显示信息（用于背包UI等）
func get_item_info() -> String:
	var info = "名称: %s\n" % name
	info += "价值: %d\n" % value
	if is_relic:
		info += "[遗物]"
	return info

# 出售物品（返回出售价值）
func sell_item() -> int:
	print("出售物品 %s，获得 %d 金币" % [name, value])
	queue_free()  # 出售后删除卡片
	return value

# 检查是否可以与目标物品合成/合并
func can_combine_with(_other_card: Node) -> bool:
	# 默认不能合成，子类可以重写
	return false

# ========== 商店相关功能 ==========

# 检测卡片是否在商店区域之外
func is_outside_shop_area() -> bool:
	# 尝试找到 ShopArea 节点
	var shop_area = get_tree().get_first_node_in_group("ShopArea")
	if shop_area == null:
		# 如果找不到 ShopArea 节点，尝试通过路径查找
		var root = get_tree().root
		shop_area = root.find_child("ShopArea", true, false)
	
	if shop_area == null:
		print("警告: 找不到 ShopArea 节点")
		return true  # 找不到商店区域，默认认为在外面
	
	# 获取卡片的全局矩形
	var card_rect = Rect2(global_position, size)
	
	# 获取商店区域的全局矩形
	var shop_rect = Rect2(shop_area.global_position, shop_area.size)
	
	# 检测是否有交集（如果没有交集，说明卡片在商店区域外）
	return not card_rect.intersects(shop_rect)

# 尝试购买卡片（扣除金币）
func try_purchase() -> bool:
	# 查找 ShopManager
	var shop_manager = get_tree().get_first_node_in_group("ShopManager")
	if shop_manager == null:
		# 如果找不到，通过路径查找
		var root = get_tree().root
		shop_manager = root.find_child("ShopManager", true, false)
	
	if shop_manager == null:
		print("警告: 找不到 ShopManager 节点")
		return false
	
	# 检查金币是否足够
	if shop_manager.coins < value:
		print("金币不足：需要 %d，当前 %d" % [value, shop_manager.coins])
		return false
	
	# 扣除金币
	shop_manager.coins -= value
	shop_manager.update_coin_display()
	print("购买成功：花费 %d 金币，剩余 %d 金币" % [value, shop_manager.coins])
	
	return true

# 将卡片从 slot 移动到主场景中（购买后使用）
func move_to_main_scene() -> void:
	var old_parent = get_parent()
	if old_parent == null:
		return
	
	# 先获取场景树引用（必须在 remove_child 之前）
	var tree = get_tree()
	if tree == null or tree.root == null:
		push_error("无法获取场景树")
		return
	
	# 保存当前的全局位置
	var saved_global_position = global_position
	
	# 尝试找到 CardManager 节点（人物卡片的父节点）
	var card_manager = tree.root.find_child("CardManager", true, false)
	var target_parent = card_manager
	# 从当前父节点移除
	old_parent.remove_child(self)
	
	# 添加到目标父节点
	target_parent.add_child(self)
	
	# 恢复全局位置（转换为新父节点下的相对位置）
	global_position = saved_global_position
	
	# 确保 z_index 合适，不会被遮挡
	z_index = 0
	
	print("卡片 %s 已从 %s 移动到 %s" % [name, old_parent.name, target_parent.name])

# 处理商店卡片的按钮释放逻辑（selling 类型）
func handle_shop_card_release() -> bool:
	# 只有 selling 类型才需要特殊处理
	if card_type != cardType.selling:
		return false
	
	if is_outside_shop_area():
		# 如果离开商店区域，尝试购买
		if try_purchase():
			# 购买成功，转为 normal 类型
			card_type = cardType.normal
			
			# 从 slot 节点移除，添加到主场景中
			move_to_main_scene()
			
			cardCurrentState = cardState.fixed
			original_position = position
			print("卡片 %s 购买成功，转为 normal 类型" % name)
			return true
		else:
			# 购买失败（金币不足），回到原始位置
			position = original_position
			cardCurrentState = cardState.fixed
			return true
	else:
		# 如果还在商店区域内，回到原始位置
		position = original_position
		cardCurrentState = cardState.fixed
		return true

