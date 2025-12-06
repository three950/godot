class_name GameStats
extends Resource
#记录游戏除卡牌外的所有通用信息
@export_range(0,5) var time: float#每天的时间
@export var days:int:set = set_days#总天数

@export var coins:int:set = set_coins #金币

@export var food_need:int:set = set_food_need#总共需要的食物
@export var food_have:int:set = set_food_have#现有的食物

@export_range(0,7) var layer:int:set = set_layer#当前所在的层数
@export var max_layer:int:set = set_max_layer#最深探索到第几层
func set_days(value: int) -> void:
	days = value
	emit_changed()

func set_coins(value: int) -> void:
	coins = value
	emit_changed()

func set_food_need(value: int) -> void:
	food_need = value
	emit_changed()

func set_food_have(value: int) -> void:
	food_have = value
	emit_changed()

func set_layer(value: int) -> void:
	layer = value
	emit_changed()
	
func set_max_layer(value:int)-> void:
	max_layer=value
	emit_changed()

	#类型判断，根据卡包设置出现的卡牌类型及概率
const 深度卡包中出现的卡牌类型:={
	500:[CardInfo.CardType.敌人,CardInfo.CardType.道具],
	1000:[CardInfo.CardType.人物,CardInfo.CardType.武器,CardInfo.CardType.资源]
}
const 深度卡包中每种卡牌类型出现概率:={
	500:[1,0],
	1000:[0,1,1]
}
const 协会卡包中出现的卡牌类型:=[CardInfo.CardType.道具,CardInfo.CardType.武器,CardInfo.CardType.资源]
const 协会卡包中每种卡牌类型出现概率:=[1,1,1]

	#卡片判断，根据深渊的层数设定卡牌类型中具体可能出现的小场景卡牌
const 深渊每层可能出现的小场景类型:=[]
const 深渊小场景类型的概率:=[]

func get_random_type_for_depth(depth:int) -> CardInfo.CardType:
	var rng = RandomNumberGenerator.new()
	var array:Array=深度卡包中出现的卡牌类型[depth]
	var weights:PackedFloat32Array=PackedFloat32Array(深度卡包中每种卡牌类型出现概率[depth])
	
	return array[rng.rand_weighted(weights)]
	
