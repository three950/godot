extends Things
class_name Item

@export var item: ItemCard
	
func get_things_resource() -> ThingsCard:
	return item

func _ready() -> void:
	super._ready()
	_update_things_display()

func set_stats(value: ItemCard) -> void:
	item = value
	if is_node_ready():
		_update_things_display()
