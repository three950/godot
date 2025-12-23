extends Node
# 战斗管理器 - 负责监听战斗开始信号并创建战斗场景
# 实现类似堆叠大陆(Stacklands)的实时战斗系统

# 战斗场景预制体
const BATTLE_SCENE = preload("res://ui/battle_scene.tscn")
# 子弹预制体
const BULLET_SCENE = preload("res://ui/bullet.tscn")

# 标记是否正在处理战斗开始（防止重复触发）
var _is_processing_battle := false

# 绑定的战斗场景实例及其容器引用
var active_battle_scene: Control = null
var enemy_container: Control = null
var character_container: Control = null

# ========== 战斗系统变量 ==========
# 战斗是否正在进行
var is_battle_active := false
# 所有参战单位的攻击定时器字典 {unit: timer}
var unit_timers: Dictionary = {}
# 基础攻击间隔（秒），会被speed属性修正
const BASE_ATTACK_INTERVAL := 2.0
# 最小攻击间隔
const MIN_ATTACK_INTERVAL := 0.3

func _ready() -> void:
	# 监听全局战斗开始信号
	Events.battle_start_requested.connect(_battle_scene_prepare)
	print("【BattleManager】战斗管理器已初始化")

func _battle_scene_prepare(character: Character, enemy: Enemy) -> void:
	if _is_processing_battle:return
	
	_is_processing_battle = true
	print( character.name, " vs ", enemy.name)

	# 2. 记录 character 的全局位置
	var character_global_pos = character.global_position
	
	# 3. 从父节点暂时移除 character 和 enemy（不删除，只是移除）
	var character_parent = character.get_parent()
	var enemy_parent = enemy.get_parent()
	if character_parent:
		character_parent.remove_child(character)
	if enemy_parent:
		enemy_parent.remove_child(enemy)
	
	active_battle_scene = BATTLE_SCENE.instantiate()	
	var cards_group = get_tree().get_first_node_in_group("Cards")
	if cards_group:
		cards_group.add_child(active_battle_scene)
	
	# 连接战斗场景的 new_unit_join 信号
	active_battle_scene.new_unit_join.connect(_new_unit_join)
	
	active_battle_scene.global_position = character_global_pos
	print("【BattleManager】战斗场景位置设置为人物卡位置: ", character_global_pos)
	
	# 缓存容器引用，供后续单位加入使用
	enemy_container = active_battle_scene.get_node("VBoxContainer/enemy")
	character_container = active_battle_scene.get_node("VBoxContainer/character")
	
	enemy_container.add_child(enemy)
	character_container.add_child(character)
	print("【BattleManager】已将 character 和 enemy 添加到战斗场景")
	
	var card_size = (enemy.get_node("Panel")).size
	enemy.custom_minimum_size = card_size
	character.custom_minimum_size = card_size
	print("【BattleManager】已设置最小尺寸: ", card_size)
	
	# 更新战斗场景的UI尺寸
	active_battle_scene.update_panel_size()
	
	_is_processing_battle = false
	_battle_start()

# ========== 战斗核心逻辑 ==========
func _battle_start() -> void:
	if is_battle_active:
		return
	
	is_battle_active = true
	print("【BattleManager】⚔️ 战斗开始！")
	
	# 为所有参战单位创建攻击定时器
	_setup_unit_timers()

# 为所有单位设置攻击定时器
func _setup_unit_timers() -> void:
	# 清理旧定时器
	_clear_all_timers()
	
	# 为角色创建定时器
	for character in character_container.get_children():
		_create_timer_for_unit(character)
	
	# 为敌人创建定时器
	for enemy in enemy_container.get_children():
		_create_timer_for_unit(enemy)

# 为单个单位创建攻击定时器
func _create_timer_for_unit(unit: Control) -> void:
	var resource: BattleStates = unit.get_battle_resource()

	# 根据speed计算攻击间隔：speed越高，攻击越快
	var attack_interval := _calculate_attack_interval(resource.speed)
	
	var timer := Timer.new()
	timer.wait_time = attack_interval
	timer.one_shot = false
	timer.autostart = true
	add_child(timer)
	
	# 连接定时器信号到攻击函数
	timer.timeout.connect(_on_unit_attack.bind(unit))
	unit_timers[unit] = timer
	
	print("【BattleManager】为 %s 创建定时器，攻击间隔: %.2f秒" % [unit.name, attack_interval])

# 根据speed计算攻击间隔
func _calculate_attack_interval(speed: int) -> float:
	# speed为0时使用基础间隔，speed每增加1减少0.15秒
	var interval := BASE_ATTACK_INTERVAL - (speed/50.0)
	return maxf(interval, MIN_ATTACK_INTERVAL)

# 单位攻击回调
func _on_unit_attack(attacker: Control) -> void:
	if not is_battle_active:
		return
	
	# 检查攻击者是否还存活
	if not is_instance_valid(attacker) or attacker.is_queued_for_deletion():
		_remove_unit_timer(attacker)
		return
	
	var attacker_resource: BattleStates = attacker.get_battle_resource()
	if attacker_resource == null or attacker_resource.HP <= 0:
		_remove_unit_timer(attacker)
		return
	
	# 获取攻击目标（敌方阵营的第一个存活单位）
	var target := _get_attack_target(attacker)
	if target == null:
		# 没有目标，检查战斗是否结束
		_check_battle_end()
		return
	
	# 执行攻击
	_perform_attack(attacker, target)
	
	# 检查战斗是否结束
	_check_battle_end()

# 获取攻击目标（返回敌方阵营第一个存活单位）
func _get_attack_target(attacker: Control) -> Control:
	var target_container: Control
	
	if attacker is Character:
		target_container = enemy_container
	elif attacker is Enemy:
		target_container = character_container
	else:
		return null
	
	# 返回第一个存活的敌方单位
	for unit in target_container.get_children():
		var resource: BattleStates = unit.get_battle_resource()
		if resource != null and resource.HP > 0:
			return unit
	
	return null
# 执行攻击
func _perform_attack(attacker: Control, target: Control) -> void:
	var attacker_resource: BattleStates = attacker.get_battle_resource()
	var damage := attacker_resource.ATK
	
	print("【BattleManager】%s 攻击 %s，造成 %d 点伤害" % [attacker.name, target.name, damage])
	
	# 播放远程攻击动画
	_play_remote_attack_animation(attacker, target, damage)
	
	# 造成伤害
	target.take_damage(damage)
#远程攻击动画
func _play_remote_attack_animation(attacker: Control, target: Control, damage: int) -> void:
	# 获取attacker和target的中心位置
	var attacker_center := attacker.global_position + attacker.size / 2.0
	var target_center := target.global_position + target.size / 2.0
	
	# 创建子弹实例
	var bullet := BULLET_SCENE.instantiate()
	bullet.z_index=5
	# 将子弹添加到战斗场景
	active_battle_scene.add_child(bullet)
	# 设置子弹的初始位置为attacker中心
	bullet.global_position = attacker_center
	
	# 创建tween动画
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	
	# 子弹移动到target中心（0.3秒）
	tween.tween_property(bullet, "global_position", target_center, 0.3)
	
	# 等待动画完成
	await tween.finished
		
	# 检查目标是否仍然有效（可能在动画期间被击败）
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		# 播放受击效果
		_play_hit_effect(target, damage)
	
	# 移除子弹
	bullet.queue_free()


# 播放受击效果
# 让被攻击的卡面一瞬间变白，然后恢复，同时添加剧烈抖动
func _play_hit_effect(target: Control, damage: int) -> void:
	# 获取白色遮罩节点
	var white_panel = target.get_node("white")
	# 获取伤害数字标签并显示伤害值
	var attack_label = white_panel.get_node("attackLabel")
	attack_label.text = str(damage)
	attack_label.modulate.a = 1.0  # 重置标签透明度
	# 保存原始位置用于抖动恢复
	var original_position := target.position

	# 显示白色遮罩和伤害数字
	white_panel.visible = true
	white_panel.self_modulate.a = 1.0  # 重置遮罩透明度
	
	# 创建抖动效果的 tween
	var shake_tween := create_tween()
	shake_tween.set_parallel(true)  # 允许同时执行多个动画
	
	# 剧烈抖动参数
	var shake_intensity := 7.0  # 抖动强度（像素）
	var shake_duration := 0.05  # 单次抖动时间
	var shake_count := 4  # 抖动次数
	
	# 创建连续抖动动画
	for i in range(shake_count):
		var offset := Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		shake_tween.chain().tween_property(target, "position", original_position + offset, shake_duration)
	
	# 最后恢复原位
	shake_tween.chain().tween_property(target, "position", original_position, shake_duration)
	
	# 等待一小段时间后隐藏白色遮罩（使用 self_modulate 只影响 Panel 本身，不影响子节点）
	await get_tree().create_timer(0.1).timeout
	white_panel.self_modulate.a = 0.0  # 白色遮罩消失，但 attackLabel 仍然显示
	
	# 等待抖动动画完成
	await shake_tween.finished
	
	# 伤害数字淡出动画
	var fade_tween := create_tween()
	fade_tween.tween_property(attack_label, "modulate:a", 0.0, 0.1)
	await fade_tween.finished
	
	# 完全隐藏 white 节点
	white_panel.visible = false


# 近战攻击动画
# 创建一个简单的冲刺动画效果：攻击者向目标方向快速移动一小段距离，然后返回原位
func _play_close_attack_animation(attacker: Control, target: Control, damage: int) -> void:
	# 保存攻击者的原始位置，用于动画结束后恢复
	var original_pos := attacker.position
	
	# 计算从攻击者指向目标的向量
	var attack_vector := target.global_position - attacker.global_position
	
	# 创建补间动画对象，用于平滑地改变攻击者的位置
	var tween := create_tween()
	# 设置缓动效果：EASE_OUT（先快后慢）和 CUBIC（三次方曲线），使动画更自然
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# 第一阶段：向目标方向冲刺（0.1秒）
	tween.tween_property(attacker, "position", original_pos + attack_vector, 0.1)
	# 播放受击效果（卡面变白）
	_play_hit_effect(target, damage)
	# 第二阶段：返回原位（0.15秒）
	tween.tween_property(attacker, "position", original_pos, 0.15)

# 检查战斗是否结束
func _check_battle_end() -> void:
	if not is_battle_active:
		return
	
	var characters_alive := _count_alive_units(character_container)
	var enemies_alive := _count_alive_units(enemy_container)
	
	if characters_alive == 0:
		_end_battle(false)  # 角色全灭，战斗失败
	elif enemies_alive == 0:
		_end_battle(true)   # 敌人全灭，战斗胜利

# 统计存活单位数量
func _count_alive_units(container: Control) -> int:
	var count := 0
	for unit in container.get_children():
		var resource: BattleStates = unit.get_battle_resource()
		if resource != null and resource.HP > 0:
			count += 1
	return count

# 结束战斗
func _end_battle(victory: bool) -> void:
	is_battle_active = false
	_clear_all_timers()
	
	if victory:
		print("【BattleManager】🎉 战斗胜利！")
		_handle_victory()
	else:
		print("【BattleManager】💀 战斗失败...")
		_handle_defeat()

# 处理胜利
func _handle_victory() -> void:
	# 延迟一小段时间后清理战斗场景
	await get_tree().create_timer(0.5).timeout
	
	# 将存活的角色移出战斗场景
	var surviving_characters: Array[Control] = []
	var character_positions: Array[Vector2] = []
	for character in character_container.get_children() as Array[Character]:
		if character.character.HP>0:
			surviving_characters.append(character)
			# 保存当前全局位置
			character_positions.append(character.global_position)
	
	# 从容器中移除角色
	for character in surviving_characters:
		character_container.remove_child(character)
	
	# 销毁战斗场景
	if active_battle_scene:
		print("准备删除")
		active_battle_scene.free()
	
	# 将角色移回Cards层
	var cards_group = get_tree().get_first_node_in_group("Cards")
	if cards_group:
		for i in range(surviving_characters.size()):
			var character: Control = surviving_characters[i]
			cards_group.add_child(character)
			# 保持当前全局位置
			character.global_position = character_positions[i]
			
			# 恢复角色状态（如果有这个方法的话）
			if character.has_method("退出战斗状态"):
				character.退出战斗状态()
	
	print("【BattleManager】战斗场景已清理，角色已恢复")

# 处理失败
func _handle_defeat() -> void:
	# 延迟一小段时间后清理战斗场景
	await get_tree().create_timer(0.5).timeout
	
	# 将存活的敌人移出战斗场景
	var surviving_enemies: Array[Control] = []
	var enemy_positions: Array[Vector2] = []
	for enemy in enemy_container.get_children() as Array[Enemy]:
		if enemy.enemy.HP > 0:
			surviving_enemies.append(enemy)
			# 保存当前全局位置
			enemy_positions.append(enemy.global_position)
	
	# 从容器中移除敌人
	for enemy in surviving_enemies:
		enemy_container.remove_child(enemy)
	
	# 销毁战斗场景
	if active_battle_scene:
		print("准备删除")
		active_battle_scene.free()
	
	# 将敌人移回Cards层
	var cards_group = get_tree().get_first_node_in_group("Cards")
	if cards_group:
		for i in range(surviving_enemies.size()):
			var enemy: Control = surviving_enemies[i]
			cards_group.add_child(enemy)
			# 保持当前全局位置
			enemy.global_position = enemy_positions[i]
			
			# 恢复敌人状态（如果有这个方法的话）
			if enemy.has_method("退出战斗状态"):
				enemy.退出战斗状态()
	
	print("【BattleManager】战斗场景已清理，敌人已恢复")

# 移除单个单位的定时器
func _remove_unit_timer(unit: Control) -> void:
	if unit_timers.has(unit):
		var timer: Timer = unit_timers[unit]
		timer.stop()
		timer.queue_free()
		unit_timers.erase(unit)

# 清理所有定时器
func _clear_all_timers() -> void:
	for unit in unit_timers.keys():
		var timer: Timer = unit_timers[unit]
		if is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
	unit_timers.clear()
func _new_unit_join(unit: Control) -> void:
	if unit is Character:
		unit.进入战斗状态()
	# 从原父节点移除
	var unit_parent = unit.get_parent()
	if unit_parent:
		unit_parent.remove_child(unit)
	
	# 根据单位类型添加到对应容器
	if unit is Character:
		character_container.add_child(unit)
		print("【BattleManager】角色 %s 加入战斗" % unit.name)
	elif unit is Enemy:
		enemy_container.add_child(unit)
		print("【BattleManager】敌人 %s 加入战斗" % unit.name)
	
	# 设置最小尺寸
	var panel = unit.get_node_or_null("Panel")
	if panel:
		unit.custom_minimum_size = panel.size
	
	# 更新战斗场景的UI尺寸
	if active_battle_scene:
		active_battle_scene.update_panel_size()
	
	# 如果战斗正在进行，为新加入的单位创建攻击定时器
	if is_battle_active:
		_create_timer_for_unit(unit)
		print("【BattleManager】新单位 %s 已加入战斗并获得攻击定时器" % unit.name)
