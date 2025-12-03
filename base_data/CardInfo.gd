class_name CardInfo
extends Resource
#所有卡片的最基础的信息
@export_group("基本信息")
@export var name: String = ""
@export var portrait: Texture2D
@export_multiline var text: String
@export var 能被堆叠:bool=true
