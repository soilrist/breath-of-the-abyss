extends CanvasLayer
class_name LevelRewardBox
## INBOX 지시(2026-10-20 00:10): 5레벨마다 "레벨 보상 상자" — 팝업에서 "열기"를
## 눌러야 열리고, 상자가 흔들리다 터지며 아이템이 희귀도 색 빛과 함께
## 튀어나온다. main.tscn 노드 구조는 건드리지 않고(규칙 8) 코드로만 만든다
## (LevelUpFx와 같은 패턴). 보상(골드·강화석·아이템·칭호)은 main.gd가
## 레벨업 시점에 이미 GameState에 지급했다 - 여기는 그 결과를 "터뜨려
## 보여 주기"만 한다. 그래서 자동사냥 봇이 "열기"를 안 눌러도 진행이
## 막히지 않는다(AUTO_OPEN_AFTER로 결국 저절로 열림).
## x270 너머(모바일 버튼)와 안 겹치게 폭은 x90~x230 안에 둔다.

const AUTO_OPEN_AFTER := 3.0
const AUTO_CLOSE_AFTER := 2.5
## 결함(감독, 2026-10-20 01:30): 상자가 NPC·HUD 와 겹쳐 밝은 맵 위에서
## 안 읽혔다. 레벨업 연출과 같은 반투명 어둠을 깔아 대비를 낸다.
const DIM_ALPHA := 0.45
## 결함(감독, 2026-10-20 02:28): 희귀도 색 글자가 남색·검정이라 대비 낮음.
## 희귀도 줄 외엔 이 밝은 색 + 검정 외곽선 2px 로 어떤 배경에서도 읽힌다.
const BRIGHT_COLOR := Color(1.0, 1.0, 0.92)

var _chest: Sprite2D
var _open_button: Button
var _title_label: Label
var _reward_lines: VBoxContainer
var _dim: ColorRect
var _opened := false
var _auto_open_timer: SceneTreeTimer


func _ready() -> void:
	layer = 51
	process_mode = Node.PROCESS_MODE_ALWAYS

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_title_label = Label.new()
	_title_label.text = "레벨 보상 상자!"
	_title_label.add_theme_font_size_override("font_size", 13)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_title_label.add_theme_color_override("font_outline_color", Color(0.35, 0.16, 0.0))
	_title_label.add_theme_constant_override("outline_size", 3)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# HUD/SkillBar가 y174부터 차지한다(scenes/main.tscn) - 그 위(y55~170)에만 둔다.
	_title_label.position = Vector2(90, 55)
	_title_label.size = Vector2(140, 14)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.visible = false
	add_child(_title_label)

	_chest = Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/items/chest.png")
	atlas.region = Rect2(0, 0, 16, 16)
	_chest.texture = atlas
	_chest.position = Vector2(160, 90)
	_chest.scale = Vector2(2.0, 2.0)
	_chest.visible = false
	add_child(_chest)

	_open_button = Button.new()
	_open_button.text = "열기"
	_open_button.position = Vector2(135, 108)
	_open_button.size = Vector2(50, 16)
	_open_button.visible = false
	_open_button.pressed.connect(_open)
	add_child(_open_button)

	# 결함(감독, 2026-10-20 02:28): 3줄(의뢰명·아이템·골드)일 때 글자가 뜨는
	# 높이가 y170(HUD/SkillBar 시작)을 넘어 스킬 줄 위에 얹혔다 - y160 안에서
	# 끝나게 시작점을 올리고 줄마다 Label을 따로 둬(레벨업 카드와 같은 패턴)
	# 넘치지 않는지 줄 수로 확인할 수 있게 한다.
	_reward_lines = VBoxContainer.new()
	_reward_lines.position = Vector2(70, 110)
	_reward_lines.size = Vector2(180, 48)
	_reward_lines.alignment = BoxContainer.ALIGNMENT_BEGIN
	_reward_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_lines.visible = false
	add_child(_reward_lines)


## reward: GameState._grant_level_milestone()가 돌려준 사전, 또는 의뢰(bounty)
## 완료 사전({"item","gold","quest_label"}). 보상은 이미 지급됐으므로
## 여기선 보여만 준다. title 을 바꿔 레벨 보상 상자·퀘스트 완료 배너를
## 같은 상자로 재사용한다(INBOX 2026-10-20 00:10 나머지 절반).
func show_reward(reward: Dictionary, title := "레벨 보상 상자!") -> void:
	_opened = false
	_dim.color.a = 0.0
	create_tween().tween_property(_dim, "color:a", DIM_ALPHA, 0.08)
	_title_label.text = title
	_title_label.visible = true
	_chest.visible = true
	_chest.rotation = 0.0
	_chest.modulate = Color.WHITE
	_open_button.visible = true
	_open_button.disabled = false
	_reward_lines.visible = false
	for child in _reward_lines.get_children():
		child.queue_free()
	_pending_reward = reward
	_auto_open_timer = get_tree().create_timer(AUTO_OPEN_AFTER)
	_auto_open_timer.timeout.connect(_open, CONNECT_ONE_SHOT)


var _pending_reward: Dictionary = {}

signal closed


func _open() -> void:
	if _opened:
		return
	_opened = true
	if _auto_open_timer != null and _auto_open_timer.timeout.is_connected(_open):
		_auto_open_timer.timeout.disconnect(_open)
	_open_button.disabled = true
	Audio.play_sfx("pickup")
	var shake := create_tween()
	for i in 5:
		shake.tween_property(_chest, "rotation", deg_to_rad(10.0 if i % 2 == 0 else -10.0), 0.05)
	shake.tween_property(_chest, "rotation", 0.0, 0.05)
	shake.tween_callback(_burst)


func _burst() -> void:
	_open_button.visible = false
	var item: String = str(_pending_reward.get("item", ""))
	var color := GameState.display_color(item) if item != "" else Color(1.0, 0.85, 0.3)
	_chest.modulate = color
	var pop := create_tween()
	pop.tween_property(_chest, "scale", Vector2(2.6, 2.6), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_chest, "scale", Vector2(2.0, 2.0), 0.12)

	# 결함(감독, 2026-10-20 01:30): "터질 때 희귀도 색 빛이 안 보임" - 상자
	# modulate 만으론 눈에 안 띄어서, 터지는 순간 같은 색으로 번쩍하는 빛을
	# 기존 skill_fx(heal.png) 재사용으로 더한다(새 외부 에셋 없음).
	var glow: SkillFx = preload("res://scenes/skill_fx.tscn").instantiate()
	glow.position = _chest.position
	add_child(glow)
	glow.play("res://assets/fx/heal.png", 4, 0.07, Color(color.r, color.g, color.b, 0.85), 3.2)

	# 결함(감독, 2026-10-20 02:28): 글자가 전부 아이템 희귀도 색(남색·검정
	# 등 어두운 색도 있음)에 외곽선 없이 떠서 어두운 길 위 대비가 낮았다.
	# 레벨업 카드처럼 기본 줄은 밝은 글자 + 어두운 외곽선 2px, 희귀도를
	# 보여 주는 "아이템 획득!" 줄만 희귀도 색을 쓴다(외곽선은 모두 2px).
	# 결함(감독, 2026-10-20 03:28): 어두운 희귀도 색(남색·검정 등)은 외곽선이
	# 있어도 어두운 배경 위에서 약했다 - 글자용 색만 명도를 올려 쓴다
	# (상자 modulate 는 그대로 원래 희귀도 색 유지).
	var text_color := color.lightened(0.35)
	var lines: Array[Dictionary] = []
	var quest_label := str(_pending_reward.get("quest_label", ""))
	if quest_label != "":
		lines.append({"text": "%s 완료!" % quest_label, "color": BRIGHT_COLOR})
	if item != "":
		lines.append({"text": "%s 획득!" % item, "color": text_color})
	# 의뢰 보상엔 강화석이 없다(stones==0) - 0 을 안 보여 주고 골드만 적는다.
	var gold_amt := int(_pending_reward.get("gold", 0))
	var stones_amt := int(_pending_reward.get("stones", 0))
	if stones_amt > 0:
		lines.append({"text": "골드 +%d  강화석 +%d" % [gold_amt, stones_amt], "color": BRIGHT_COLOR})
	elif gold_amt > 0:
		lines.append({"text": "골드 +%d" % gold_amt, "color": BRIGHT_COLOR})
	var title := str(_pending_reward.get("title", ""))
	if title != "":
		lines.append({"text": "칭호 [%s] 획득!" % title, "color": BRIGHT_COLOR})
	var big_reward := str(_pending_reward.get("big_reward", ""))
	if big_reward != "":
		lines.append({"text": big_reward, "color": BRIGHT_COLOR})
	for line in lines:
		var label := Label.new()
		label.text = str(line["text"])
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", line["color"])
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		label.add_theme_constant_override("outline_size", 2)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_reward_lines.add_child(label)

	# 결함(감독, 2026-10-20 03:28): 고리 빛(glow)이 사라지기 전에 글자를 같은
	# 자리에 띄워서 첫 줄이 고리에 덮여 안 읽혔다 - glow가 다 꺼진 뒤에만
	# 보상 줄을 보인다(glow 는 4프레임×0.07초 = 0.28초 뒤 스스로 queue_free).
	glow.tree_exited.connect(func() -> void: _reward_lines.visible = true, CONNECT_ONE_SHOT)

	var fade := create_tween()
	fade.tween_interval(AUTO_CLOSE_AFTER)
	fade.tween_callback(_close)


func _close() -> void:
	_title_label.visible = false
	_chest.visible = false
	_reward_lines.visible = false
	create_tween().tween_property(_dim, "color:a", 0.0, 0.2)
	closed.emit()
