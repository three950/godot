extends Things
class_name Recource

@onready var food_label: Label = %FoodLabel

@export var recource: ResourceCard

func get_things_resource() -> ThingsCard:
	return recource
	
func _ready() -> void:
	super._ready()
	_update_resource_display()
	# 角色生成时发送食物需求更新信号
	if not Engine.is_editor_hint():
		Events.food_have_update.emit(recource.nutrition)
func _update_resource_display() -> void:
	# 调用父类通用更新（设置 name, label, texture, value）
	_update_things_display()
	food_label.text = str(recource.nutrition)

func set_stats(value: ResourceCard) -> void:
	recource = value
	if is_node_ready():
		_update_resource_display()
