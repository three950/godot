extends Panel
class_name BagSlot

## 背包卡槽 - 纯背景显示组件
## 只负责提供位置信息，不存储卡片引用，不处理逻辑

func _ready() -> void:
	# 确保可以接收鼠标事件（用于检测）
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 加入 BagSlot 组，方便查找
	add_to_group("BagSlot")

## 获取卡槽的中心全局位置（用于卡片对齐）
func get_center_global_position() -> Vector2:
	return global_position + size / 2.0

## 检测某个全局坐标是否在卡槽内
func contains_global_point(point: Vector2) -> bool:
	var rect = Rect2(global_position, size)
	return rect.has_point(point)

## 获取卡槽的尺寸（用于计算缩放）
func get_slot_size() -> Vector2:
	return size

