class_name CardInfo
extends Resource

@export var name: String = ""
@export var portrait: Texture2D
@export_multiline var text: String
@export var 能被堆叠:bool=true
enum CardType {人物, 敌人, 小场景, 道具, 武器, 资源, 事件}
@export var type: CardType
