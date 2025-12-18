@tool
extends Scene
class_name Small_Scene

## 计时完成回调
func _on_spawn_timer_completed() -> void:
	# 如果任务已被取消，直接返回
	if not _is_timing:
		return
	
	# 生成卡牌
	spawn_card_info=scene.card_pool.pick_random()
	print("spawn_card_info: ", spawn_card_info)
	_spawn_card()
	
	# 生成卡牌后，如果仍有子卡堆叠，则继续按平均速度重新计时
	if is_instance_valid(children_card):
		print("卡牌仍在堆叠，继续计时生成下一张卡牌")
		_start_timing()
		return

	# 没有子卡堆叠，停止计时
	_cancel_timing()
