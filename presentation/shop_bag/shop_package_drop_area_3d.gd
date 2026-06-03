extends Area3D
class_name ShopPackageDropArea3D

@export var package_path: NodePath


func get_package() -> CardPackage:
	return get_node_or_null(package_path) as CardPackage
