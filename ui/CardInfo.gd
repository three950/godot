class_name CardInfo
extends Resource

@export_group("基本信息")
@export var name: String = ""
@export var portrait: Texture2D
@export_multiline var text: String
@export var 能被堆叠:bool=true
