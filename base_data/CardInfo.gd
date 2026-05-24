class_name CardInfo
extends Resource

@export var name: String = ""
@export var portrait: Texture2D
@export_multiline var text: String
@export var 能被堆叠:bool=true
enum CardType {人物, 敌人, 小场景, 道具, 武器, 资源, 深度, 事件}
@export var type: CardType


func create_runtime_instance() -> CardInfo:
	# 私有化函数，默认卡牌数据作为静态模板使用；需要运行时改状态的子类自行返回副本。
	return self
