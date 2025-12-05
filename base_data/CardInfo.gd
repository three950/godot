class_name CardInfo
extends Resource

@export var name: String = ""
@export var portrait: Texture2D
@export_multiline var text: String
@export var 能被堆叠:bool=true
## 卡牌对应的场景，子类应该覆盖此属性
@export var card_scene: PackedScene
