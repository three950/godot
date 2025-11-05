extends ProgressBar
class_name CardProgressBar

## 进度条组件
## current: 当前已经过的时间
## total: 总时间
func update_progress(current: float, total: float) -> void:
	max_value = total
	value = current
	visible = current > 0 and total > 0

