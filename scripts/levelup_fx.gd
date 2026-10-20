extends CanvasLayer
class_name LevelUpFx
## INBOX 지시(2026-10-20 00:09): "누가 봐도 레벨업했구나" 뽕 차는 연출.
## main.tscn 노드 구조를 손대지 않도록(규칙 8) 필요한 UI는 전부 코드로 만든다.
## hitstop·빛기둥·적 밀쳐내기·회복·사운드는 main.gd 쪽에서, 배너·플래시·
## 증가치 카드는 여기서 맡는다.

const CARD_STEP := 0.15
const BANNER_HOLD := 1.0
## 결함(감독, 2026-10-20 01:30): 밝은 맵 위에서 배너·카드가 안 읽힌다.
## 화면 전체를 이 알파로 어둡게 깔고 그 위에 올려야 밝은 배경에서도 대비가 난다.
const DIM_ALPHA := 0.45

var _flash: ColorRect
var _dim: ColorRect
var _banner: Label
var _cards: VBoxContainer

## 연출이 끝나면 쏜다 - main.gd 가 이 신호로 숨겨 둔 HUD 상단 문구를 되살린다.
signal finished


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	# x80~x240: x270 너머 모바일 버튼 줄과 안 겹친다.
	_banner = Label.new()
	_banner.text = "LEVEL UP!"
	_banner.add_theme_font_size_override("font_size", 22)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_banner.add_theme_color_override("font_outline_color", Color(0.35, 0.16, 0.0))
	_banner.add_theme_constant_override("outline_size", 4)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = Vector2(80, 14)
	_banner.size = Vector2(160, 24)
	_banner.pivot_offset = Vector2(80, 12)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	add_child(_banner)

	_cards = VBoxContainer.new()
	_cards.position = Vector2(100, 42)
	_cards.size = Vector2(120, 60)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.visible = false
	add_child(_cards)


## lines: "HP 120→135" 식 증가치 줄. 배너·플래시·카드만 재생하고 끝낸다 -
## hitstop·빛기둥·적 밀쳐내기·회복·사운드는 호출한 쪽(main.gd)이 이미 했다.
func play(lines: Array[String]) -> void:
	_flash.color.a = 0.6
	create_tween().tween_property(_flash, "color:a", 0.0, 0.3)

	var total_time := CARD_STEP * lines.size() + BANNER_HOLD
	_dim.color.a = 0.0
	var dim_tween := create_tween()
	dim_tween.tween_property(_dim, "color:a", DIM_ALPHA, 0.08)
	dim_tween.tween_interval(total_time)
	dim_tween.tween_property(_dim, "color:a", 0.0, 0.2)
	dim_tween.tween_callback(finished.emit)

	for child in _cards.get_children():
		child.queue_free()
	_cards.modulate.a = 1.0

	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner.scale = Vector2.ZERO
	var banner_tween := create_tween()
	banner_tween.tween_property(_banner, "scale", Vector2(1.3, 1.3), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.1)
	banner_tween.tween_interval(BANNER_HOLD)
	banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.2)
	banner_tween.tween_callback(func() -> void: _banner.visible = false)

	_cards.visible = true
	for i in lines.size():
		var label := Label.new()
		label.text = lines[i]
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.2, 0.0))
		label.add_theme_constant_override("outline_size", 2)
		label.modulate.a = 0.0
		_cards.add_child(label)
		var card_tween := create_tween()
		card_tween.tween_interval(CARD_STEP * i)
		card_tween.tween_property(label, "modulate:a", 1.0, 0.1)

	var fade := create_tween()
	fade.tween_interval(CARD_STEP * lines.size() + BANNER_HOLD)
	fade.tween_property(_cards, "modulate:a", 0.0, 0.2)
	fade.tween_callback(func() -> void: _cards.visible = false)
