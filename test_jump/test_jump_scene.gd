extends Node2D
## 卡牌跳跃效果测试场景脚本

@onready var card1: Card = $cardsArea/Card1
@onready var card2: Card = $cardsArea/Card2
@onready var card3: Card = $cardsArea/Card3

@onready var height_slider: HSlider = $UI/VBoxContainer/HeightControl/HeightSlider
@onready var height_label: Label = $UI/VBoxContainer/HeightControl/HeightValue

var selected_card: Card = null

func _ready() -> void:
	# 设置滑块范围
	height_slider.min_value = 0.0
	height_slider.max_value = 2.0
	height_slider.step = 0.05
	height_slider.value = 0.0
	
	# 默认选中第一张卡
	selected_card = card1
	_update_selection_visual()

func _update_selection_visual() -> void:
	# 更新选中状态的视觉反馈（简单地用 z_index 来标识）
	card1.z_index = 1 if selected_card == card1 else 0
	card2.z_index = 1 if selected_card == card2 else 0
	card3.z_index = 1 if selected_card == card3 else 0

func _on_select_card_1_pressed() -> void:
	selected_card = card1
	height_slider.value = card1.current_height
	_update_selection_visual()

func _on_select_card_2_pressed() -> void:
	selected_card = card2
	height_slider.value = card2.current_height
	_update_selection_visual()

func _on_select_card_3_pressed() -> void:
	selected_card = card3
	height_slider.value = card3.current_height
	_update_selection_visual()

func _on_height_slider_value_changed(value: float) -> void:
	if selected_card:
		selected_card.current_height = value
		height_label.text = "%.2f" % value

func _on_jump_button_pressed() -> void:
	if selected_card:
		selected_card.height_animator.play_jump_animation(1.2, 0.15, 0.25, 0.2)

func _on_high_jump_button_pressed() -> void:
	if selected_card:
		selected_card.height_animator.play_jump_animation(2.0, 0.2, 0.3, 0.25)

func _on_bounce_button_pressed() -> void:
	if selected_card:
		selected_card.height_animator.play_bounce_animation(3, 0.8, 0.5)

func _on_land_button_pressed() -> void:
	if selected_card:
		selected_card.height_animator.land_on_table(0.2)

func _on_all_jump_button_pressed() -> void:
	# 所有卡牌依次跳跃（有延迟）
	card1.height_animator.play_jump_animation(1.0)
	await get_tree().create_timer(0.1).timeout
	card2.height_animator.play_jump_animation(1.0)
	await get_tree().create_timer(0.1).timeout
	card3.height_animator.play_jump_animation(1.0)

func _on_all_bounce_button_pressed() -> void:
	# 所有卡牌同时弹跳
	card1.height_animator.play_bounce_animation(2, 0.6, 0.6)
	card2.height_animator.play_bounce_animation(2, 0.6, 0.6)
	card3.height_animator.play_bounce_animation(2, 0.6, 0.6)

#region 卡片生成翻转动画 + Shooter 方向移动
## 播放翻转动画并移动到目标位置
func _play_flip_and_shoot(target_offset: Vector2) -> void:
	if selected_card:
		# 先播放翻转动画
		selected_card.animation_player.play("卡片生成翻转")
		# 计算目标位置
		var target_pos := selected_card.global_position + target_offset
		# 使用 Shooter 移动到目标位置
		selected_card.shooter.play_card_shooter(target_pos)

func _on_flip_left_pressed() -> void:
	_play_flip_and_shoot(Vector2(-200, 0))

func _on_flip_right_pressed() -> void:
	_play_flip_and_shoot(Vector2(200, 0))

func _on_flip_up_pressed() -> void:
	_play_flip_and_shoot(Vector2(0, -150))

func _on_flip_down_pressed() -> void:
	_play_flip_and_shoot(Vector2(0, 150))

func _on_flip_near_pressed() -> void:
	# 近距离：向右上方移动一小段
	_play_flip_and_shoot(Vector2(80, -60))

func _on_flip_far_pressed() -> void:
	# 远距离：向右上方移动较长距离
	_play_flip_and_shoot(Vector2(400, -200))

func _on_flip_center_pressed() -> void:
	if selected_card:
		# 移动到屏幕中心
		var center_pos := Vector2(960, 500)  # 大约屏幕中心
		selected_card.animation_player.play("卡片生成翻转")
		selected_card.shooter.play_card_shooter(center_pos)

func _on_flip_random_pressed() -> void:
	if selected_card:
		# 随机方向和距离
		var random_offset := Vector2(
			randf_range(-300, 300),
			randf_range(-200, 200)
		)
		selected_card.animation_player.play("卡片生成翻转")
		selected_card.shooter.play_card_shooter(selected_card.global_position + random_offset)
#endregion
