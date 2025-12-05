@tool
extends Button
class_name CardPackage
signal package_bought(CardPackage)
@export var game_stats:GameStats
@export_multiline var package_name: String = ""  # 可导出的名称变量
@export var mean_layer:int
@export var package_price: int = 3  # 可导出的价格变量
@onready var packagename: Label = %packagename
@onready var value: Label = %value
@onready var panel_3: Panel = $Panel3
func _ready() -> void:
	_update_display()
	Events.max_layer_changed.connect(_update_state)
	_update_state()


func _update_display() -> void:
	# 更新名称和价格显示
	packagename.text = package_name
	value.text = str(package_price)

func _on_pressed() -> void:
	if game_stats.coins < package_price:
		return
	game_stats.coins -= package_price
	package_bought.emit()
	
func _update_state() -> void:
	if game_stats.max_layer <= mean_layer:
		panel_3.show()
		set_disabled(true)  # 禁用按钮交互
	else:
		panel_3.hide()  # 隐藏面板
		set_disabled(false)  # 启用按钮交互
