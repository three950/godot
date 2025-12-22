extends Panel
signal new_unit_join

func _on_battle_area_area_entered(area: Area2D) -> void:
	var card = area.get_parent()
	# 只处理 Character 或 Enemy 类型
	if not (card is Character or card is Enemy):
		return
	# 检查是否已经在战斗场景中（避免重复添加）
	if card.get_parent() != null and is_ancestor_of(card):
		return
	print("【BattleScene】检测到单位进入: ", card.name)
	new_unit_join.emit(card)
