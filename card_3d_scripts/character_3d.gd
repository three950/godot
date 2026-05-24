@tool
class_name Character3D
extends Card3D

const CARD_3D_SCENE: PackedScene = preload("res://card_3d.tscn")
const CARD_THROW_PHYSICS_SCRIPT: GDScript = preload("res://script_folder/card_reveal_spawner.gd")
const EQUIPMENT_HOVER_PREVIEW_NAME := "EquipmentHoverPreview"
const EQUIPMENT_HOVER_AREA_NAME := "EquipmentHoverPreviewArea"
const EQUIPMENT_HOVER_AREA_PADDING := Vector2(0.2, 0.2)
const EQUIPMENT_HOVER_AREA_HEIGHT := 0.8

@onready var bottom_left_hover_timer: Timer = get_node_or_null("BottomLeftHoverArea/BottomLeftHoverTimer") as Timer
@onready var equipment_weapon_template: Card3D = get_node_or_null("石块") as Card3D
@onready var equipment_armor_template: Card3D = get_node_or_null("树枝") as Card3D

var _is_bottom_left_hovered: bool = false
var _equipment_hover_preview: Node3D = null
var _bottom_left_hover_area_disabled_by_stack: bool = false


func _ready() -> void:
	super._ready()

	if Engine.is_editor_hint():
		return

	_prepare_equipment_preview_template(equipment_weapon_template)
	_prepare_equipment_preview_template(equipment_armor_template)

	# character_3d 专属的左下角悬停检测，不影响通用 Card3D。
	if bottom_left_hover_timer:
		bottom_left_hover_timer.one_shot = true
		bottom_left_hover_timer.wait_time = 0.6
		if not bottom_left_hover_timer.timeout.is_connected(_on_bottom_left_hover_timer_timeout):
			bottom_left_hover_timer.timeout.connect(_on_bottom_left_hover_timer_timeout)


func bestacked_on_me(children: Card3D) -> void:
	if _try_equip_stacked_equipment(children):
		_update_bottom_left_hover_area_for_stack()
		return

	super.bestacked_on_me(children)
	_update_bottom_left_hover_area_for_stack()


func stop_stacking_on_me() -> void:
	super.stop_stacking_on_me()
	_update_bottom_left_hover_area_for_stack()


func _on_mouse_exited() -> void:
	super._on_mouse_exited()
	_set_bottom_left_hovered(false)


func _on_bottom_left_hover_area_mouse_entered() -> void:
	_set_bottom_left_hovered(true)


func _on_bottom_left_hover_area_mouse_exited() -> void:
	_set_bottom_left_hovered(false)


func _set_bottom_left_hovered(is_hovered_now: bool) -> void:
	if _bottom_left_hover_area_disabled_by_stack:
		is_hovered_now = false

	if _is_bottom_left_hovered == is_hovered_now:
		return

	_is_bottom_left_hovered = is_hovered_now
	if bottom_left_hover_timer == null:
		return

	if _is_bottom_left_hovered:
		# 鼠标进入左下区域后重新计时，停留到计时结束才触发打印。
		bottom_left_hover_timer.start()
	else:
		# 离开区域就取消本次悬停检测，避免短暂停留也触发。
		bottom_left_hover_timer.stop()


func _on_bottom_left_hover_timer_timeout() -> void:
	if not _is_bottom_left_hovered:
		return
	if _bottom_left_hover_area_disabled_by_stack:
		return

	_show_equipment_hover_preview()


func _exit_tree() -> void:
	# 角色被释放时主动清理悬停预览，避免 Area3D 信号滞留到下一帧。
	_hide_equipment_hover_preview()


func _prepare_equipment_preview_template(template: Card3D) -> void:
	if template == null:
		return

	# 场景里的两张卡只作为布局参考；运行时隐藏并关闭交互，避免它们参与堆叠和拖拽。
	template.visible = false
	template.ray_interaction_enabled = false
	template.can_stack = false
	template.remove_from_group("Cards3D")
	_set_preview_card_collision_enabled(template, false)


func _show_equipment_hover_preview() -> void:
	var character_card := card_info as CharacterCard
	if character_card == null:
		return

	var weapon_card := character_card.武器
	var armor_card := character_card.防具
	if weapon_card == null and armor_card == null:
		return

	_hide_equipment_hover_preview()

	var preview_root := Node3D.new()
	preview_root.name = EQUIPMENT_HOVER_PREVIEW_NAME
	add_child(preview_root)
	_equipment_hover_preview = preview_root

	# 左边使用武器参考位，右边使用防具参考位；没有对应装备时保留空位但不生成卡。
	if weapon_card != null:
		_add_equipment_preview_card(preview_root, weapon_card, equipment_weapon_template, "HoverWeapon")
	if armor_card != null:
		_add_equipment_preview_card(preview_root, armor_card, equipment_armor_template, "Hoverarmor")

	_add_equipment_hover_area(preview_root)


func _hide_equipment_hover_preview() -> void:
	if _equipment_hover_preview == null:
		return
	if not is_instance_valid(_equipment_hover_preview):
		_equipment_hover_preview = null
		return

	_equipment_hover_preview.queue_free()
	_equipment_hover_preview = null


func _add_equipment_preview_card(parent: Node3D, equipment_card: ThingsCard, template: Card3D, node_name: String) -> void:
	if template == null:
		push_warning("Character3D: missing equipment preview template %s." % node_name)
		return

	var preview_card := CARD_3D_SCENE.instantiate() as Card3D
	if preview_card == null:
		push_warning("Character3D: failed to instantiate equipment preview card.")
		return

	preview_card.name = node_name
	preview_card.card_info = equipment_card
	preview_card.cardname = equipment_card.name
	preview_card.battle = battle
	preview_card.transform = template.transform
	parent.add_child(preview_card)

	# 预览卡被拖起时，Character3D 只负责把它变成场景里的普通卡并卸下装备数据。
	var drag_started_callable := _on_equipment_preview_card_drag_started.bind(preview_card)
	if not preview_card.drag_started.is_connected(drag_started_callable):
		preview_card.drag_started.connect(drag_started_callable)


func _add_equipment_hover_area(parent: Node3D) -> void:
	var bounds := _calculate_equipment_hover_bounds()
	if bounds.is_empty():
		return

	var center: Vector3 = bounds["center"]
	var size: Vector3 = bounds["size"]

	var hover_area := Area3D.new()
	hover_area.name = EQUIPMENT_HOVER_AREA_NAME
	hover_area.collision_layer = 2
	hover_area.collision_mask = 0
	hover_area.input_ray_pickable = true
	hover_area.position = center
	parent.add_child(hover_area)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	hover_area.add_child(shape)

	if not hover_area.mouse_exited.is_connected(_on_equipment_hover_area_mouse_exited):
		hover_area.mouse_exited.connect(_on_equipment_hover_area_mouse_exited)


func _calculate_equipment_hover_bounds() -> Dictionary:
	var templates: Array[Card3D] = []
	if equipment_weapon_template != null:
		templates.append(equipment_weapon_template)
	if equipment_armor_template != null:
		templates.append(equipment_armor_template)
	if templates.is_empty():
		return {}

	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	var center_y := 0.0

	# 根据两张参考卡的真实 transform 计算覆盖范围，后续调角度/缩放时无需同步改代码。
	for template in templates:
		var half_size := template.face_size * 0.5
		var corners: Array[Vector2] = [
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y),
		]

		center_y += template.position.y
		for corner in corners:
			var local_corner: Vector3 = template.position \
					+ template.transform.basis.x * corner.x \
					+ template.transform.basis.z * corner.y
			min_x = minf(min_x, local_corner.x)
			max_x = maxf(max_x, local_corner.x)
			min_z = minf(min_z, local_corner.z)
			max_z = maxf(max_z, local_corner.z)

	center_y /= float(templates.size())
	var center := Vector3((min_x + max_x) * 0.5, center_y, (min_z + max_z) * 0.5)
	var size := Vector3(
			max_x - min_x + EQUIPMENT_HOVER_AREA_PADDING.x,
			EQUIPMENT_HOVER_AREA_HEIGHT,
			max_z - min_z + EQUIPMENT_HOVER_AREA_PADDING.y
	)
	return {"center": center, "size": size}


func _set_preview_card_collision_enabled(node: Node, enabled: bool) -> void:
	if node is CollisionShape3D:
		var shape := node as CollisionShape3D
		shape.disabled = not enabled

	if node is Area3D:
		var area := node as Area3D
		area.monitoring = enabled
		area.monitorable = enabled
		area.input_ray_pickable = enabled

	for child in node.get_children():
		_set_preview_card_collision_enabled(child, enabled)


func _on_equipment_hover_area_mouse_exited() -> void:
	_hide_equipment_hover_preview()


func _on_equipment_preview_card_drag_started(preview_card: Card3D) -> void:
	if preview_card == null or not is_instance_valid(preview_card):
		return

	var target_parent := get_parent() as Node
	if target_parent != null and preview_card.get_parent() != target_parent:
		var world_transform := preview_card.global_transform
		preview_card.reparent(target_parent, true)
		preview_card.global_transform = world_transform
		preview_card.scale = Vector3.ONE

	release_equipment_preview_card(preview_card)

	var drag_started_callable := _on_equipment_preview_card_drag_started.bind(preview_card)
	if preview_card.drag_started.is_connected(drag_started_callable):
		preview_card.drag_started.disconnect(drag_started_callable)


func release_equipment_preview_card(preview_card: Card3D) -> void:
	var character_card := card_info as CharacterCard
	var equipment_card := preview_card.card_info as ThingsCard if preview_card != null else null
	if character_card == null or equipment_card == null:
		return

	# 从角色装备字段里移除，避免下一次左下悬停又从同一件装备重复生成卡牌。
	var did_clear := false
	if equipment_card is WeaponCard:
		did_clear = character_card.unequip_weapon(equipment_card)
	elif equipment_card is ArmorCard:
		did_clear = character_card.unequip_armor(equipment_card)

	if did_clear:
		_refresh_character_equipment_view()


func _try_equip_stacked_equipment(stacked_card: Card3D) -> bool:
	if stacked_card == null or not is_instance_valid(stacked_card):
		return false

	var equipment_card := stacked_card.card_info as EquipmentCard
	var character_card := card_info as CharacterCard
	if equipment_card == null or character_card == null:
		return false
	if not (equipment_card is WeaponCard) and not (equipment_card is ArmorCard):
		return false

	# EquipmentCard 堆到人物卡时不进入普通堆叠队列，而是把这张 3D 卡消费成装备槽数据。
	# stack_on_card() 在发信号前已经把 follow_target 指向人物卡，所以这里要先手动断开。
	var spawn_position := stacked_card.global_position
	_release_children_from_consumed_equipment(stacked_card)
	_detach_consumed_equipment_from_character(stacked_card)

	var previous_equipment: ThingsCard = null
	if equipment_card is WeaponCard:
		previous_equipment = character_card.replace_weapon(equipment_card as WeaponCard)
	elif equipment_card is ArmorCard:
		previous_equipment = character_card.replace_armor(equipment_card as ArmorCard)
	if previous_equipment != null and previous_equipment != equipment_card:
		# 旧装备离槽后以普通 3D 卡形式抛回主场景；数值和特性变化已由 CharacterCard 统一处理。
		_spawn_replaced_equipment_card(previous_equipment, spawn_position)

	_refresh_character_equipment_view()

	# 新装备已经进入 CharacterCard 的单件武器/防具字段，原来的堆叠卡节点不再留在桌面。
	stacked_card.queue_free()

	# 换装后直接展示装备预览，让玩家能立即看到两个槽位的当前结果。
	_hide_equipment_hover_preview()
	_show_equipment_hover_preview()
	return true


func _release_children_from_consumed_equipment(equipment_card_3d: Card3D) -> void:
	if equipment_card_3d.children_card == null:
		return

	var child_head := equipment_card_3d.children_card
	var release_parent := get_parent()
	var child_transform := child_head.global_transform

	# 被消费的装备卡上面可能还叠着其他卡；先拆出整条子堆，避免 queue_free 装备时带走它们。
	child_head.detach_from_follow_target()
	if release_parent != null and child_head.get_parent() != release_parent:
		child_head.reparent(release_parent, true)
	child_head.global_transform = child_transform
	child_head.snap_to_base_plane()
	child_head.update_stack_chain_position()
	_force_card_fixed(child_head)


func _detach_consumed_equipment_from_character(stacked_card: Card3D) -> void:
	if stacked_card.follow_target == self:
		stacked_card.follow_target = null
	stacked_card.stack_state &= ~Card3DState.STACK_STATE_STACKING
	stacked_card.end_drag()
	_force_card_fixed(stacked_card)


func _spawn_replaced_equipment_card(equipment_card: ThingsCard, spawn_position: Vector3) -> void:
	var spawn_parent := get_parent()
	if spawn_parent == null and is_inside_tree():
		spawn_parent = get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = self

	var spawned_card := CARD_THROW_PHYSICS_SCRIPT.spawn_revealed_card(equipment_card, spawn_position, spawn_parent) as Card3D
	if spawned_card == null:
		push_warning("Character3D: failed to spawn replaced equipment card %s." % equipment_card.name)


func _force_card_fixed(card: Card3D) -> void:
	if card == null or not is_instance_valid(card):
		return
	if card.card_state_machine == null:
		return
	card.card_state_machine.force_transition(Card3DState.State.fixed)


func _refresh_character_equipment_view() -> void:
	# 2D 人物卡在 SubViewport 里，装备数据变更后主动刷新卡面和 viewport。
	if card_2d != null and card_2d.has_method("refresh_equipment_ui"):
		card_2d.call("refresh_equipment_ui")
	else:
		_request_card_viewport_redraw()


func _update_bottom_left_hover_area_for_stack() -> void:
	var should_disable := children_card != null
	if _bottom_left_hover_area_disabled_by_stack == should_disable:
		return

	_bottom_left_hover_area_disabled_by_stack = should_disable
	_set_bottom_left_hovered(false)
	if should_disable:
		_hide_equipment_hover_preview()

	var hover_area := get_node_or_null("BottomLeftHoverArea") as Area3D
	if hover_area == null:
		return

	# 只有当前人物卡被其他卡堆在上面时禁用，避免堆叠状态触发展示整套装备预览。
	hover_area.monitoring = not should_disable
	hover_area.monitorable = not should_disable
	hover_area.input_ray_pickable = not should_disable

	for child in hover_area.get_children():
		var collision_shape := child as CollisionShape3D
		if collision_shape != null:
			collision_shape.disabled = should_disable


func _update_ray_hover(mouse_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	var hit := _get_top_card_hit(mouse_position, camera)
	var is_hit: bool = not hit.is_empty() and hit.get("card") == self
	var is_bottom_left_hit := false

	if is_hit and not _bottom_left_hover_area_disabled_by_stack:
		# PlaneMesh 卡面以 X/Z 表示宽高；这里取左下四分之一区域。
		var local_position: Vector3 = hit["local_position"]
		var half_size := face_size * 0.5
		is_bottom_left_hit = local_position.x >= -half_size.x and local_position.x <= 0.0 \
				and local_position.z >= 0.0 and local_position.z <= half_size.y
	_set_bottom_left_hovered(is_bottom_left_hit)

	if is_hit and not _ray_hovered:
		_ray_hovered = true
		_on_mouse_entered()
	elif not is_hit and _ray_hovered:
		_ray_hovered = false
		_on_mouse_exited()
