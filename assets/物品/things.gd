extends Card
class_name Things

# 通用UI元素引用 - Things 类额外的 value_label
@onready var value_label: Label = $SubViewport/ValueLabel

# 子类需要重写此方法，返回对应的 ThingsCard 资源
func get_things_resource() -> ThingsCard:
	return null

# 重写父类方法
func get_card_resource() -> CardInfo:
	return get_things_resource()

# 虚方法：获取卡片价值，子类重写
func get_value() -> int:
	var resource = get_things_resource()
	return resource.value if resource else 0

# 通用的物品卡片更新方法
func _update_things_display() -> void:
	# 调用父类通用更新（设置 name, cardname, label, texture）
	_update_card_display()
	# 更新价值标签
	var resource = get_things_resource()
	if resource and value_label:
		value_label.text = str(resource.value)
