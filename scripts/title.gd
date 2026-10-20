extends Control

var selected := 0
var choices := ["새 게임", "이어하기", "클리어 기록", "종료"]
## 어느 슬롯을 쓸지. ←→ 로 고른다.
var slot := 0


func _ready() -> void:
	get_tree().auto_accept_quit = false
	GameState.slot = slot
	Audio.play_music("title")
	_load_clear_flag()
	# Help/Slots 문구가 터치 버튼 유무에 따라 달라지므로 _refresh() 전에 정한다.
	$TouchMenu.visible = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	_refresh()
	for index in choices.size():
		get_node("TouchMenu/Choice%d" % index).pressed.connect(_touch_activate.bind(index))
	# 터치 기기엔 ←→ 키가 없어 슬롯을 못 고른다는 감독 지적(2026-09-08) → 슬롯 목록
	# 아래 ◀▶ 버튼. 키보드 ←→와 같은 _change_slot()을 탄다.
	$TouchMenu/SlotPrev.pressed.connect(_change_slot.bind(-1))
	$TouchMenu/SlotNext.pressed.connect(_change_slot.bind(1))
	# 메뉴 왼쪽 ▲▼/확인 버튼(감독 요청 2026-09-10). 키보드 ↑↓/Enter와 같은 경로.
	$TouchMenu/MenuUp.pressed.connect(_move.bind(-1))
	$TouchMenu/MenuDown.pressed.connect(_move.bind(1))
	$TouchMenu/MenuOk.pressed.connect(_activate)


func _touch_activate(index: int) -> void:
	selected = index
	_activate()


func _load_clear_flag() -> void:
	if not GameState.has_save():
		return
	var file := FileAccess.open(GameState.save_path(), FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		GameState.game_cleared = bool(data.get("game_cleared", false))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_move(-1)
	elif event.is_action_pressed("ui_down"):
		_move(1)
	elif event.is_action_pressed("ui_left"):
		_change_slot(-1)
	elif event.is_action_pressed("ui_right"):
		_change_slot(1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("attack"):
		_activate()
	elif event is InputEventKey and (event.keycode == KEY_1 or event.physical_keycode == KEY_1):
		selected = 0
		_activate()
	elif event is InputEventKey and (event.keycode == KEY_2 or event.physical_keycode == KEY_2):
		selected = 1
		_activate()


func _move(step: int) -> void:
	selected = wrapi(selected + step, 0, choices.size())
	Audio.play_sfx("cancel")
	_refresh()


func _change_slot(step: int) -> void:
	slot = wrapi(slot + step, 0, GameState.SLOT_COUNT)
	GameState.slot = slot
	_load_clear_flag()
	Audio.play_sfx("cancel")
	_refresh()
	# 버튼이 포커스를 잡으면 이후 Enter/방향키가 버튼으로 새서 메뉴가 안 움직인다.
	get_viewport().gui_release_focus()


func _activate() -> void:
	Audio.play_sfx("accept")
	match selected:
		0:
			GameState.reset()
			GameState.pending_load = false
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		1:
			if GameState.has_save():
				GameState.pending_load = true
				get_tree().change_scene_to_file("res://scenes/main.tscn")
			else:
				$Notice.text = "저장 데이터가 없습니다."
		2:
			if GameState.game_cleared:
				get_tree().change_scene_to_file("res://scenes/ending.tscn")
			else:
				$Notice.text = "아직 클리어 기록이 없습니다."
		3:
			get_tree().quit()


func _refresh() -> void:
	var lines: Array[String] = []
	for index in choices.size():
		var disabled: bool = (index == 1 and not GameState.has_save()) or (index == 2 and not GameState.game_cleared)
		lines.append("▶ %s" % choices[index] if index == selected else "   %s" % choices[index])
		if disabled:
			lines[index] += "  (저장 없음)"
	$Menu.text = "\n".join(lines)
	# 슬롯 세 칸을 한 줄로 보여 준다. 지금 고른 칸을 대괄호로 감싼다.
	var slots: Array[String] = []
	for index in GameState.SLOT_COUNT:
		var mark := "[%d]" % (index + 1) if index == slot else " %d " % (index + 1)
		slots.append("%s %s" % [mark, GameState.slot_summary(index)])
	$Slots.text = ("◀▶" if $TouchMenu.visible else "←→") + " 슬롯 선택\n" + "\n".join(slots)
	# 터치 화면에선 키보드 안내 대신 버튼 안내(감독 2026-09-10 "가이드가 메뉴에 있어야지").
	$Help.text = "▲▼ 메뉴 선택 · 확인 · ◀▶ 슬롯 선택" if $TouchMenu.visible else "↑↓ 메뉴 · ←→ 슬롯 · Enter/J 확인"


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		$Notice.text = "종료하려면 메뉴의 ‘종료’를 선택하세요."
