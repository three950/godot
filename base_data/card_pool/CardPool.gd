class_name CardPool
extends Resource
@export var card_pool:Array[CardInfo]#所有可获取的卡牌
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

const 场景depth可能出现的所有类型:=[CardInfo.CardType.敌人, CardInfo.CardType.小场景, CardInfo.CardType.道具, CardInfo.CardType.武器, CardInfo.CardType.资源, CardInfo.CardType.深度, CardInfo.CardType.事件]
const 场景depth可能出现的所有类型的概率:=[1,5,2,2,2,1,0]

const 物品稀有度:=[ThingsCard.稀有度.COMMON,ThingsCard.稀有度.NOTBAD,ThingsCard.稀有度.RARE,ThingsCard.稀有度.UNIQUE]
const 物品稀有度的概率:=[10,4,1,0.1]

	#卡片判断，根据深渊的层数设定卡牌类型中具体可能出现的小场景卡牌
const 深渊每层可能出现的小场景类型:=[]
const 深渊小场景类型的概率:=[]

func get_random_type_for_depth(depth:int) -> CardInfo.CardType:
	var rng = RandomNumberGenerator.new()
	var array:Array=深度卡包中出现的卡牌类型[depth]
	var weights:PackedFloat32Array=PackedFloat32Array(深度卡包中每种卡牌类型出现概率[depth])	
	return array[rng.rand_weighted(weights)]
	
func get_cards_by_type(type:CardInfo.CardType) -> CardInfo:
	#TODO：关于之后卡片可能会在不同层出现的问题，可以在tres资源里单独设置，然后在这里和layer做比较
	var cards:=card_pool.filter(func(card:CardInfo):return card.type == type)#符合类型的卡牌 
	if cards.is_empty():
		return null
	var created_card:CardInfo=cards.pick_random()#TODO 根据权重而不是纯随机
	return created_card
	
func get_random_type_in_abyss(depth:int) -> CardInfo.CardType:
	var rng = RandomNumberGenerator.new()
	var array:Array=场景depth可能出现的所有类型
	var weights:PackedFloat32Array=PackedFloat32Array(场景depth可能出现的所有类型的概率)	
	return array[rng.rand_weighted(weights)]
