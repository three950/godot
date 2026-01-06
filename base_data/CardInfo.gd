class_name CardInfo
extends Resource

@export var name: String = ""
@export var portrait: Texture2D
@export_multiline var text: String
@export var 能被堆叠:bool=true
enum CardType {人物, 敌人, 小场景, 道具, 武器, 资源, 深度, 事件}
@export var type: CardType
## 卡牌的基础高度（用于伪3D效果，高度越高阴影偏离越远）
@export_range(0.0, 5.0, 0.1) var base_height: float = 0.0
