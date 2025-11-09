extends "res://card.gd"
class_name BaggableCard

# 所有可以放入背包、在商店出售的卡片都继承此类
# 包括：装备(EquipmentCard)、道具(ItemCard)、资源(ResourceCard)

@export var value: int = 1  # 物品价值（用于商店出售/购买）
@export var is_relic: bool = false  # 是否是遗物

# ========== 装备效果系统 ==========
# 装备时效果（从CSV的"装备时"列解析）
var equip_effects: Dictionary = {}  # {"ATK": 100, "DEF": 5, "HP": -5, "special": "fast_fish"}

# 信号：装备到角色时
signal equipment_equipped(character: CharacterCard, item: BaggableCard)
# 信号：从角色卸下时
signal equipment_unequipped(character: CharacterCard, item: BaggableCard)

func _ready() -> void:
	super._ready()
	# 可背包物品的通用初始化

# 重写按钮按下逻辑，添加背包槽位相关处理
func _on_button_button_down() -> void:
	# 先调用父类逻辑
	super._on_button_button_down()
	
	# 如果卡片在背包槽位中，立即从槽位中移除引用和效果
	var current_info = _find_current_slot_info()
	if current_info.has("bag_panel") and current_info.has("slot_index"):
		var bag_panel = current_info.bag_panel
		var slot_index = current_info.slot_index
		
		# 从槽位中清除引用（但不删除卡片）
		bag_panel.cards[slot_index] = null
		
		# 【装备系统】移除装备效果（如果有装备效果）
		if has_method("remove_equip_effects") and bag_panel.current_character_card != null:
			print("【卡片】从背包拖出 %s，移除装备效果" % name)
			remove_equip_effects(bag_panel.current_character_card)
		
		# 重置缩放
		scale = Vector2(1.0, 1.0)
		z_index = 100  # 拖拽时提升 z_index，确保在最上层
		
		var slot = bag_panel.get_slot_by_index(slot_index)
		print("【卡片】从背包槽位 %s（索引 %d）拖出，清除引用并重置缩放" % [slot.name if slot else "未知", slot_index])

# 重写按钮释放逻辑，添加商店和背包卡槽相关处理
func _on_button_button_up() -> void:
	z_index = 0
	# 恢复所有子卡片的 z_index 与位置
	update_stacked_cards()
	
	# selling 类型拖动后检测是否离开商店区域
	if card_type == cardType.selling:
		if handle_shop_card_release():
			return
	
	# 【新增】检测是否拖到背包卡槽上
	if try_snap_to_bag_slot():
		return
	
	# 调用父类的堆叠检测逻辑
	var closest_card = find_closest_card()
	if closest_card != null:
		stack_on_card(closest_card)
	else:
		# 如果没有找到可堆叠的卡片，检查是否与背包区域重叠
		push_card_outside_bag_if_overlapping()
		
		# 【关键修复】如果卡片在背包外，且父节点是背包面板，立即移到主场景
		_move_to_main_scene_if_outside_bag()
		
		# 设置为固定状态
		cardCurrentState = cardState.fixed
		original_position = position

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

# 从商店管理器的追踪数组中移除
func remove_from_shop_tracking() -> void:
	var shop_manager = get_tree().get_first_node_in_group("ShopManager")
	if shop_manager == null:
		var root = get_tree().root
		shop_manager = root.find_child("ShopManager", true, false)
	
	if shop_manager and "shop_selling_cards" in shop_manager:
		if self in shop_manager.shop_selling_cards:
			shop_manager.shop_selling_cards.erase(self)
			print("【商店】卡片 %s 已从商店追踪中移除" % name)

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
			
			# 从商店管理器的追踪数组中移除（已经在主场景中，无需移动）
			remove_from_shop_tracking()
			
			print("卡片 %s 购买成功，转为 normal 类型，继续检测堆叠" % name)
			
			# 购买成功后，继续执行 normal 卡片的释放逻辑
			# 不直接设为 fixed，而是让卡片继续寻找堆叠和背包卡槽
			return false  # 返回 false，让后续的 normal 卡片逻辑继续执行
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

# ========== 背包卡槽相关功能 ==========

# 尝试将卡片吸附到背包卡槽
func try_snap_to_bag_slot() -> bool:
	# 只有 normal 类型的可背包物品才能放入卡槽
	if not can_put_in_bag():
		return false
	
	# 查找所有背包面板
	var bag_panels = get_tree().get_nodes_in_group("BagPanel")
	if bag_panels.is_empty():
		return false
	
	var card_center = global_position + size / 2.0
	
	# 遍历所有背包面板，查找其中的卡槽
	for bag_panel in bag_panels:
		if not is_instance_valid(bag_panel) or not bag_panel is BagPanel:
			continue
		
		# 获取背包面板中的所有 BagSlot
		var slots = _find_all_bag_slots(bag_panel)
		
		for slot in slots:
			if not is_instance_valid(slot) or not slot is BagSlot:
				continue
			
			# 检测卡片中心是否在卡槽内
			if slot.contains_global_point(card_center):
				# 获取槽位索引
				var slot_index = bag_panel.get_index_by_slot(slot)
				if slot_index == -1:
					continue
				
				# 尝试放入槽位
				# （注意：旧引用已在 _on_button_button_down 中清除）
				if bag_panel.place_card_at_slot(self, slot_index):
					print("【卡片】成功吸附到卡槽: %s（索引 %d）" % [slot.name, slot_index])
					return true
				else:
					# 如果放入失败（卡槽已满），保持在当前位置
					cardCurrentState = cardState.fixed
					original_position = position
					print("【卡片】槽位 %d 已满，无法放入" % slot_index)
					return true
	
	# 如果没有找到合适的卡槽，卡片保持在新位置
	# （引用已在拖动开始时清除，无需额外处理）
	return false

# 查找背包面板下的所有卡槽
func _find_all_bag_slots(parent: Node) -> Array:
	var slots = []
	for child in parent.get_children():
		if child is BagSlot:
			slots.append(child)
		# 递归查找子节点
		slots.append_array(_find_all_bag_slots(child))
	return slots

# 查找当前卡片所在的背包面板和槽位索引
func _find_current_slot_info() -> Dictionary:
	# 遍历所有背包面板
	var bag_panels = get_tree().get_nodes_in_group("BagPanel")
	for bag_panel in bag_panels:
		if not is_instance_valid(bag_panel) or not bag_panel is BagPanel:
			continue
		
		# 查找卡片在该背包中的索引
		var slot_index = bag_panel._find_card_index(self)
		if slot_index != -1:
			return {
				"bag_panel": bag_panel,
				"slot_index": slot_index
			}
	
	return {}

# 查找当前卡片所在的卡槽（向后兼容）
func _find_current_bag_slot() -> BagSlot:
	var info = _find_current_slot_info()
	if info.has("bag_panel") and info.has("slot_index"):
		return info.bag_panel.get_slot_by_index(info.slot_index)
	return null

# 如果卡片在背包外，且父节点是背包面板，立即移到主场景
func _move_to_main_scene_if_outside_bag() -> void:
	var parent = get_parent()
	if parent == null or not parent is BagPanel:
		return
	
	# 检查卡片是否在背包外
	var bag_rect = Rect2(parent.global_position, parent.size)
	var card_rect = Rect2(global_position, size)
	
	if not card_rect.intersects(bag_rect):
		# 在背包外，移到主场景
		move_to_main_scene()
		print("【卡片】已从背包移到主场景")

# ========== 装备效果系统方法 ==========

# 解析装备时效果（从CSV的"装备时"列）
# 格式: "ATK+100,DEF+5.一次性:HP-5" 或 "为角色添加fast_fish属性"
func parse_equip_effects(effect_string: String) -> void:
	if effect_string.is_empty():
		return
	
	equip_effects.clear()
	
	# 检查是否是特殊效果（如 fast_fish）
	if "fast_fish" in effect_string:
		equip_effects["special"] = "fast_fish"
		print("【装备效果】%s 解析特殊效果: fast_fish" % name)
		return
	
	# 解析属性修改效果
	# 先移除"一次性:"前缀，然后分割
	var cleaned = effect_string.replace("一次性:", "")
	# 分割主要部分（用逗号和句号分隔）
	var parts = cleaned.replace(".", ",").split(",")
	
	for part in parts:
		part = part.strip_edges()
		
		if part.is_empty():
			continue
		
		# 解析 ATK+100, DEF+5, HP-5 格式
		if "ATK" in part:
			var value_str = part.replace("ATK", "").strip_edges()
			if value_str.is_valid_int():
				equip_effects["ATK"] = int(value_str)
		elif "DEF" in part:
			var value_str = part.replace("DEF", "").strip_edges()
			if value_str.is_valid_int():
				equip_effects["DEF"] = int(value_str)
		elif "HP" in part:
			var value_str = part.replace("HP", "").strip_edges()
			if value_str.is_valid_int():
				equip_effects["HP"] = int(value_str)
	
	print("【装备效果】%s 解析装备效果: %s" % [name, str(equip_effects)])

# 应用装备效果到角色
func apply_equip_effects(character: CharacterCard) -> void:
	if character == null:
		return
	
	print("【装备效果】%s 装备到角色 %s" % [name, character.name])
	print("  当前装备效果字典: %s" % str(equip_effects))
	
	# 应用属性修改
	if equip_effects.has("ATK"):
		character.modify_atk(equip_effects["ATK"])
		print("  ATK %+d" % equip_effects["ATK"])
	
	if equip_effects.has("DEF"):
		character.modify_defense(equip_effects["DEF"])
		print("  DEF %+d" % equip_effects["DEF"])
	
	if equip_effects.has("HP"):
		character.modify_hp(equip_effects["HP"])
		print("  HP %+d" % equip_effects["HP"])
	
	# 应用特殊效果
	if equip_effects.has("special"):
		var special_effect_str = equip_effects["special"]
		if character.has_method("add_special_effect"):
			character.add_special_effect(special_effect_str)
			print("  添加特殊效果: %s" % special_effect_str)
	
	# 发射装备信号
	equipment_equipped.emit(character, self)

# 移除装备效果
func remove_equip_effects(character: CharacterCard) -> void:
	if character == null:
		return
	
	print("【装备效果】%s 从角色 %s 卸下" % [name, character.name])
	
	# 移除属性修改（反向应用）
	if equip_effects.has("ATK"):
		character.modify_atk(-equip_effects["ATK"])
		print("  ATK %+d" % (-equip_effects["ATK"]))
	
	if equip_effects.has("DEF"):
		character.modify_defense(-equip_effects["DEF"])
		print("  DEF %+d" % (-equip_effects["DEF"]))
	
	if equip_effects.has("HP"):
		character.modify_hp(-equip_effects["HP"])
		print("  HP %+d" % (-equip_effects["HP"]))
	
	# 移除特殊效果
	if equip_effects.has("special"):
		var special_effect_str = equip_effects["special"]
		if character.has_method("remove_special_effect"):
			character.remove_special_effect(special_effect_str)
			print("  移除特殊效果: %s" % special_effect_str)
	
	# 发射卸下信号
	equipment_unequipped.emit(character, self)

# 判断是否有"装备时"字段
# 资源卡没有"装备时"字段，所以需要检查
func has_equip_field(data: Dictionary) -> bool:
	return data.has("装备时")

# 从数据初始化装备效果（子类在init_from_data中调用）
func init_equip_effects_from_data(data: Dictionary) -> void:
	# 只有包含"装备时"字段的卡片才解析（资源卡没有此字段）
	if not has_equip_field(data):
		print("【装备效果】%s 没有'装备时'字段，跳过解析" % name)
		return
	
	var equip_str = str(data["装备时"])
	print("【装备效果】%s 找到'装备时'字段: '%s'" % [name, equip_str])
	
	if not equip_str.is_empty():
		parse_equip_effects(equip_str)
	else:
		print("【装备效果】警告：%s 的'装备时'字段为空" % name)
