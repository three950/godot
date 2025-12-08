extends ProgressBar
class_name CardProgressBar

## 进度条组件
## 当进度完成时发出信号
signal progress_completed

var _total_time: float = 0.0
var _elapsed_time: float = 0.0
var _is_running: bool = false

func _ready() -> void:
	visible = false

func _process(delta: float) -> void:
	if not _is_running:
		return
	
	_elapsed_time += delta
	value = _elapsed_time
	
	if _elapsed_time >= _total_time:
		_stop()
		progress_completed.emit()

## 启动进度条，传入总时间（秒）
## duration: 进度条完成所需的总时间
func start(duration: float) -> void:
	if duration <= 0:
		return
	
	_total_time = duration
	_elapsed_time = 0.0
	max_value = duration
	value = 0.0
	visible = true
	_is_running = true

## 停止进度条
func stop() -> void:
	_stop()

func _stop() -> void:
	_is_running = false
	visible = false
	_elapsed_time = 0.0
	value = 0.0

## 暂停进度条
func pause() -> void:
	_is_running = false

## 恢复进度条
func resume() -> void:
	if _elapsed_time < _total_time and _total_time > 0:
		_is_running = true
		visible = true

## 获取当前进度（0.0 - 1.0）
func get_progress_ratio() -> float:
	if _total_time <= 0:
		return 0.0
	return clampf(_elapsed_time / _total_time, 0.0, 1.0)

## 手动更新进度（兼容旧接口）
## current: 当前已经过的时间
## total: 总时间
func update_progress(current: float, total: float) -> void:
	max_value = total
	value = current
	visible = current > 0 and total > 0
