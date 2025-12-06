class_name CardPool
extends Resource

var type_pool:Array[CardInfo.CardType]=[CardInfo.CardType.人物,CardInfo.CardType.武器,CardInfo.CardType.资源,CardInfo.CardType.敌人,CardInfo.CardType.道具]#获取生成的卡牌类型
@export var card_pool:Array[CardInfo]#所有可获取的卡牌
func get_cards_by_type(type:CardInfo.CardType) -> CardInfo:#根据卡牌类型获取卡牌
	var cards:=card_pool.filter(func(card:CardInfo):return card.type == type)#符合类型的卡牌
	if cards.is_empty():
		return null
	var created_card:CardInfo=cards.pick_random()#TODO 根据权重而不是纯随机
	return created_card
