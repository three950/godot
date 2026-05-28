extends Control
class_name Power2Card

## 图片稿还原用的固定基准尺寸，和用户提供的参考图一致。
const DESIGN_SIZE := Vector2(594, 132)
## 黑色卡牌按钮参考的原始按钮场景，便于之后追踪样式来源。
const CARD_BUTTON_STYLE_REFERENCE_UID := "uid://dde8q2r1usqpa"

@onready var power_label: Label = %PowerLabel
@onready var progress_bar: FixedUnitProgressBar = %FixedUnitProgressBar
@onready var card_buttons: Array[Button] = [
	%CardButton01,
	%CardButton02,
	%CardButton03,
	%CardButton04,
	%CardButton05,
	%CardButton06,
	%CardButton07,
]
@onready var next_button: Button = %NextButton


func _ready() -> void:
	# 当前界面是独立 2D UI 还原，不依赖父容器布局；固定尺寸方便后续放进 SubViewport 或 CanvasLayer。
	custom_minimum_size = DESIGN_SIZE
	size = DESIGN_SIZE


## 更新左上角数字。数字节点使用 Label，保留方法给外部玩法逻辑调用。
func set_power(value: int) -> void:
	power_label.text = str(value)


## 更新底部固定单位进度。参考图默认未填充，所以场景里初始值为 0。
func set_progress_units(value: int) -> void:
	progress_bar.filled_units = value


## 批量控制黑色卡牌按钮是否可点，方便之后和抽牌/能量逻辑连接。
func set_cards_enabled(is_enabled: bool) -> void:
	for button in card_buttons:
		button.disabled = not is_enabled
