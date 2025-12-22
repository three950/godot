extends Panel
signal new_unit_join

# 更新面板UI尺寸，使其适应内容
func update_panel_size() -> void:
	var enemy_container = $VBoxContainer/enemy
	var character_container = $VBoxContainer/character
	var collision_shape = $BattleArea/CollisionShape2D
	# 等待一帧让布局更新
	await get_tree().process_frame
	
	# 获取两个HBoxContainer中较宽的那个
	var max_width = max(enemy_container.size.x, character_container.size.x)
	
	# Panel的宽度为最长的容器宽度加12像素
	custom_minimum_size.x = max_width + 12
	size.x = max_width + 30
	print("【BattleScene】更新Panel尺寸: ", size)
	
	collision_shape.shape.size = size
	collision_shape.position = size / 2
	print("【BattleScene】更新BattleArea尺寸: ", size)

func _on_battle_area_area_entered(area: Area2D) -> void:
	var card = area.get_parent()
	# 只处理 Character 或 Enemy 类型
	if not (card is Character or card is Enemy):
		return
	# 检查是否已经在战斗场景中（避免重复添加）
	if card.get_parent() != null and is_ancestor_of(card):
		print("已经在战斗场景中")
		return
	print("【BattleScene】检测到单位进入: ", card.name)
	new_unit_join.emit(card)
