class_name CardInfo
extends Resource

const RUNTIME_UNIQUE_RESOURCE_META := "_card3d_runtime_unique_resource"

@export var name: String = ""
@export var portrait: Texture2D
@export_multiline var text: String
@export var 能被堆叠:bool=true
enum CardType {人物, 敌人, 小场景, 道具, 武器, 资源, 深度, 事件}
@export var type: CardType


func create_runtime_instance() -> CardInfo:
	if get_meta(RUNTIME_UNIQUE_RESOURCE_META, false):
		return self

	# 每张 3D 卡运行时都应持有独立数据，避免同一个 .tres 模板被多张卡共享状态。
	var instance := duplicate() as CardInfo
	if instance == null:
		return self
	instance.set_meta(RUNTIME_UNIQUE_RESOURCE_META, true)
	return instance
