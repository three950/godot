class_name SceneCardPool
extends SceneCard
@export var 需要的参数:String
func speed_change(特性:Array[String]) -> int:#默认返回1
	if 特性.has(需要的参数):
		print("是的有参数！")
		return 2
	return 1
