extends Node
class_name ShopAreaController3D

# 无效视口位置的标记常量
const INVALID_VIEWPORT_POSITION := Vector2(INF, INF)

# 导出变量 - 场景引用路径
@export var ground_path: NodePath           # 地面3D节点路径
@export var shop_bag_path: NodePath         # 商店背包UI节点路径
@export var ground_node_name: String = "Ground"      # 地面节点名称（备用查找）
@export var shop_bag_node_name: String = "ShopBag"  # 背包节点名称（备用查找）

# 地面纹理映射配置组
@export_group("Ground Texture Mapping")
@export var viewport_size: Vector2 = Vector2(3840, 2160)  # 视口尺寸（像素）
@export var ground_size: Vector2 = Vector2(34.71, 21.36)  # 地面实际尺寸（世界单位）
@export var texture_top_is_negative_z: bool = true        # 纹理顶部是否对应-Z方向

# 商店区域配置组
@export_group("Shop Area")
@export var shop_area_rect: Rect2 = Rect2(0, 0, 3840, 397)     # 商店区域矩形（视口坐标系）
@export var package_hit_margin_px: float = 18.0                # 商品命中盒边距（像素）
@export var shop_exit_padding_px: float = 220.0                # 商店出口偏移量（像素）
@export var package_hitbox_y: float = 0.04                     # 商品命中盒Y轴位置
@export var package_hitbox_height: float = 0.8                 # 商品命中盒高度
@export var nearest_package_x_acceptance: float = 1.45         # 最近商品X轴接受范围

# 调试配置组
@export_group("Debug")
@export var debug_drop_logs: bool = true   # 是否输出掉落调试日志

# 运行时节点引用（使用 @onready 自动初始化）
@onready var _ground: Node3D = _resolve_node(ground_path, ground_node_name) as Node3D
@onready var _shop_bag: Control = _resolve_node(shop_bag_path, shop_bag_node_name) as Control

# 私有变量
var _package_hitboxes: Array[Dictionary] = []  # 3D商品命中盒列表


# ======================== 生命周期函数 ========================

func _ready() -> void:
	add_to_group("ShopArea3D")
	_build_package_hitboxes()
	_debug_ready_log()


# ======================== 核心公共接口 ========================

# 应用卡牌掉落规则
# @param card: 要掉落的3D卡牌
# @return: 是否被商品成功接收
func apply_card_drop_rules(card: Card3D) -> bool:
	if not _is_valid(card):
		return false
	
	var viewport_pos := world_to_ground_viewport(card.global_position)
	if viewport_pos == INVALID_VIEWPORT_POSITION:
		_debug_drop_log(card, viewport_pos, null, false, _get_mapping_failure_status())
		return false
	
	var package := _find_package_from_3d_hitbox(card)
	var package_handled := false
	var safe_world_pos := _get_shop_exit_position(card, viewport_pos)
	
	if package and package.has_method("try_accept_card_drop"):
		# 3D卡只负责"落到哪里"；具体买包、扣钱、生成卡由GroundPackage处理
		package_handled = bool(package.call("try_accept_card_drop", card, safe_world_pos))
	
	if shop_area_rect.has_point(viewport_pos) and not card.is_queued_for_deletion():
		_move_card_chain_out_of_shop(card, safe_world_pos)
	
	_debug_drop_log(card, viewport_pos, package, package_handled)
	return package_handled


# 将世界坐标转换为地面视口坐标
# @param world_position: 3D世界坐标
# @return: 2D视口坐标，无效时返回INVALID_VIEWPORT_POSITION
func world_to_ground_viewport(world_position: Vector3) -> Vector2:
	if not _is_valid(_ground) or ground_size.x <= 0.0 or ground_size.y <= 0.0:
		return INVALID_VIEWPORT_POSITION
	
	var local_pos := _ground.to_local(world_position)
	var normalized_x := local_pos.x / ground_size.x + 0.5
	var normalized_y := local_pos.z / ground_size.y + 0.5
	
	if not texture_top_is_negative_z:
		normalized_y = 1.0 - normalized_y
	
	return Vector2(normalized_x * viewport_size.x, normalized_y * viewport_size.y)


# 将地面视口坐标转换为世界坐标
# @param viewport_position: 2D视口坐标
# @param world_y: 目标世界Y轴高度
# @return: 3D世界坐标
func ground_viewport_to_world(viewport_position: Vector2, world_y: float) -> Vector3:
	var normalized_x := viewport_position.x / viewport_size.x
	var normalized_y := viewport_position.y / viewport_size.y
	
	if not texture_top_is_negative_z:
		normalized_y = 1.0 - normalized_y
	
	var local_pos := Vector3(
		(normalized_x - 0.5) * ground_size.x,
		0.0,
		(normalized_y - 0.5) * ground_size.y
	)
	
	var world_pos := _ground.to_global(local_pos)
	world_pos.y = world_y
	return world_pos


# ======================== 场景引用管理 ========================

# 解析节点引用
# @param configured_path: 配置的节点路径
# @param fallback_name: 备选节点名称
# @return: 找到的节点，未找到返回null
func _resolve_node(configured_path: NodePath, fallback_name: String) -> Node:
	if not str(configured_path).is_empty():
		var configured_node := get_node_or_null(configured_path)
		if _is_valid(configured_node):
			return configured_node
	return get_tree().root.find_child(fallback_name, true, false)

# 检查节点是否有效（非空且未被销毁）
func _is_valid(node: Node) -> bool:
	return node != null and is_instance_valid(node)


# ======================== 商品命中盒管理 ========================

# 从3D碰撞盒查找卡牌命中的商品
# @param card: 3D卡牌
# @return: 命中的商品控件，未命中返回null
func _find_package_from_3d_hitbox(card: Card3D) -> Control:
	if not _is_valid(card):
		return null
	
	var card_pos := card.global_position
	for hitbox in _package_hitboxes:
		var area: Area3D = hitbox.area
		if not _is_valid(area):
			continue
		
		var local_pos := area.to_local(card_pos)
		var size: Vector3 = hitbox.size
		
		if absf(local_pos.x) <= size.x * 0.5 \
		and absf(local_pos.y) <= size.y * 0.5 \
		and absf(local_pos.z) <= size.z * 0.5:
			return hitbox.package
	
	return null


# 建所有商品的3D碰撞盒
func _build_package_hitboxes() -> void:
	if not _is_valid(_ground) or not _is_valid(_shop_bag):
		return
	
	for package in _collect_card_packages(_shop_bag):
		_add_package_hitbox(package)


## 为单个商品添加3D碰撞盒#TODO area3d还是在场景中建号比较好
## @param package: 商品控件
func _add_package_hitbox(package: Control) -> void:
	var rect := Rect2(package.global_position, package.size).grow(package_hit_margin_px)
	
	var center := _ground_viewport_to_ground_local(rect.get_center())
	var size := Vector3(
		rect.size.x / viewport_size.x * ground_size.x,
		package_hitbox_height,
		rect.size.y / viewport_size.y * ground_size.y
	)
	
	var area := Area3D.new()
	area.name = "%sShopDropArea3D" % package.name
	area.collision_mask = 2
	area.position = Vector3(center.x, package_hitbox_y, center.z)
	_ground.add_child(area)
	
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	area.add_child(shape)
	
	_package_hitboxes.append({"area": area, "package": package, "size": size})


# 递归收集所有支持卡牌掉落的商品控件
# @param root: 搜索起始节点
# @return: 商品控件数组
func _collect_card_packages(root: Node) -> Array[CardPackage]:
	var result: Array[CardPackage] = []
	for child in root.get_children():
		if child is CardPackage:
			result.append(child)
	return result


# ======================== 辅助函数 ========================

# 获取卡牌移出商店的安全位置
# @param card: 卡牌对象
# @param viewport_position: 当前视口坐标
# @return: 移出后的世界坐标
func _get_shop_exit_position(card: Card3D, viewport_position: Vector2) -> Vector3:
	var safe_viewport_pos := viewport_position
	safe_viewport_pos.y = shop_area_rect.position.y + shop_area_rect.size.y + shop_exit_padding_px
	return ground_viewport_to_world(safe_viewport_pos, card.global_position.y)


# 将视口坐标转换为地面局部坐标
# @param viewport_position: 视口坐标
# @return: 地面局部3D坐标（Y轴为0）
func _ground_viewport_to_ground_local(viewport_position: Vector2) -> Vector3:
	var normalized_x := viewport_position.x / viewport_size.x
	var normalized_y := viewport_position.y / viewport_size.y
	
	if not texture_top_is_negative_z:
		normalized_y = 1.0 - normalized_y
	
	return Vector3(
		(normalized_x - 0.5) * ground_size.x,
		0.0,
		(normalized_y - 0.5) * ground_size.y
	)


# 将卡牌链移出商店区域
# @param card: 主卡牌
# @param safe_world_position: 安全的世界坐标位置
func _move_card_chain_out_of_shop(card: Card3D, safe_world_position: Vector3) -> void:
	card.global_position = safe_world_position
	if card.children_card != null:
		card.update_children_position()


# ======================== 调试辅助函数 ========================

# 获取映射失败的原因描述
func _get_mapping_failure_status() -> String:
	if not _is_valid(_ground):
		var parent_name = get_parent().name if get_parent() != null else "none"
		return "invalid_ground_mapping_ground_missing path=%s fallback=%s parent=%s" % [
			str(ground_path), ground_node_name, parent_name
		]
	if ground_size.x <= 0.0 or ground_size.y <= 0.0:
		return "invalid_ground_mapping_bad_ground_size"
	return "invalid_ground_mapping"


# 获取掉落调试状态信息
func _get_drop_debug_status(card: Card3D, package: Control, viewport_position: Vector2) -> String:
	if package != null and package.has_method("get_coin_purchase_debug_status"):
		return str(package.call("get_coin_purchase_debug_status", card))
	if package == null and shop_area_rect.has_point(viewport_position):
		return "inside_shop_no_package"
	if package == null:
		return "outside_shop"
	return "package_has_no_drop_debug"


# 获取卡牌的金币数量（仅对金币卡牌有效）
func _get_coin_count(card: Card3D) -> int:
	var coin_card := card as CoinCard3D
	if not _is_valid(coin_card):
		return 0
	return coin_card.get_coin_stack_count()


# 输出掉落调试日志
func _debug_drop_log(
		card: Card3D,
		viewport_position: Vector2,
		package: Control,
		handled: bool,
		status: String = ""
) -> void:
	if not debug_drop_logs:
		return
	
	var should_log := card is CoinCard3D \
			or package != null \
			or shop_area_rect.has_point(viewport_position)
	if not should_log:
		return
	
	var card_name := "null"
	if _is_valid(card):
		card_name = card.name
	
	var package_name := "none"
	if _is_valid(package):
		package_name = package.name
	
	var final_status := status
	if final_status.is_empty():
		final_status = _get_drop_debug_status(card, package, viewport_position)
	
	var coin_count := _get_coin_count(card)
	
	print("[ShopArea3D] drop card=%s viewport=%s package=%s coins=%d handled=%s status=%s" % [
		card_name, viewport_position, package_name, coin_count, str(handled), final_status
	])


# 输出就绪调试日志
func _debug_ready_log() -> void:
	if not debug_drop_logs:
		return
	
	var ground_name := "none"
	if _is_valid(_ground):
		ground_name = _ground.name
	
	var shop_name := "none"
	if _is_valid(_shop_bag):
		shop_name = _shop_bag.name
	
	print("[ShopArea3D] ready ground=%s shop=%s package_hitboxes=%d" % [
		ground_name, shop_name, _package_hitboxes.size()
	])
