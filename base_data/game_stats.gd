class_name GameStats
extends Resource
#记录游戏除卡牌外的所有通用信息
@export_range(0,5) var time: int:set=set_time#每天的时间
@export var days:int:set = set_days#总天数

@export var coins:int:set = set_coins #金币

@export var food_need:int:set = set_food_need#总共需要的食物
@export var food_have:int:set = set_food_have#现有的食物

@export_range(0,7) var layer:int:set = set_layer#当前所在的层数
@export var max_layer:int:set = set_max_layer#最深探索到第几层
func set_time(value:int) -> void:
	time = value
	emit_changed()
	
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


	
