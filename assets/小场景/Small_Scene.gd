@tool
extends Scene
class_name Small_Scene

## 计算所有堆叠人物卡的速度（重写父类方法，每个人物卡使用相同的默认速度，速度累加）
func _calculate_average_speed() -> float:
	var character_cards = _collect_all_character_cards(children_card)
	if character_cards.size() == 0:
		return 1.0

	const DEFAULT_SPEED = 20.0
	var total_speed := 0.0
	
	for card in character_cards:
		var card_resource = card.get_card_resource()
		if card_resource is CharacterCard:
			var character_card = card_resource as CharacterCard
			var 特性数组 = character_card.特性
			
			# 如果 scene 是 SceneCardPool 类型，调用 speed_change 获取速度倍数；否则默认为1
			var speed_multiplier = 1
			if scene is SceneCardPool:
				var scene_card_pool = scene as SceneCardPool
				speed_multiplier = scene_card_pool.speed_change(特性数组)
			
			# 每个人物卡的基础速度乘以倍数后累加
			total_speed += DEFAULT_SPEED * float(speed_multiplier)
	
	# 返回累加的总速度（父类会用 100.0 / average_speed 计算时间）
	return total_speed

## 计时完成回调
func _on_spawn_timer_completed() -> void:#TODO 目前没有设置具体的概率，所以使用pick_random重写
	# 如果任务已被取消，直接返回
	if not _is_timing:return

	spawn_card_info=scene.card_pool.pick_random()
	print("spawn_card_info: ", spawn_card_info)
	_spawn_card()
	
	if is_instance_valid(children_card):
		print("卡牌仍在堆叠，继续计时生成下一张卡牌")
		_start_timing()
		return

	_cancel_timing()
