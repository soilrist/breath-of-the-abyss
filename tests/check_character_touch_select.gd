extends Node
## INBOX 결함(2026-09-06 08:40) — Character 창은 확인 버튼(C/Esc 닫기)은
## 있으나 능력치·특성·전직 목록 줄을 터치로 못 옮기고, 탭(능력치/특성/전직)
## 전환도 ←→ 키뿐이라 폰에서는 목록에서 원하는 줄로 갈 방법이 없었다.
## Perk/TowerSelect(check_perk_touch_select.gd/check_tower_select_touch_select.gd)와
## 같은 원리로 목록 줄 터치+재탭 확정을, 그리고 상점이 쓰던 Sell("탭")
## 버튼을 능력치/특성/전직 탭 전환에도 재사용해 터치로 오갈 수 있는지 확인한다.
## 전직 탭은 2차 전직 목록 앞에 "2차 전직" 구분줄이 하나 끼어드는데, 그
## 구분줄을 탭하면 아무 일도 없고 그 다음 줄(2차 전직 첫 항목)을 탭하면
## 제대로 옮겨가는지가 이번 결함의 가장 까다로운 부분이라 따로 확인한다.

## main.gd의 시작 줄 상수를 값으로 복사해 두지 않고 스크립트를 프리로드해
## 직접 읽는다 - 복사본은 main.gd 값이 바뀌어도 따라가지 못한다(2026-09-06
## INBOX 결함: c87d810/FORGE_LIST_START_LINE과 같은 재발 방지).
const _Main := preload("res://scripts/main.gd")
const CHARACTER_STATS_LIST_START_LINE := _Main.CHARACTER_STATS_LIST_START_LINE
const CHARACTER_PERKS_LIST_START_LINE := _Main.CHARACTER_PERKS_LIST_START_LINE
const CHARACTER_JOB_LIST_START_LINE := _Main.CHARACTER_JOB_LIST_START_LINE


func _line_height(info: Label) -> float:
	return info.get_line_height() + info.get_theme_constant("line_spacing")


func _row_local_pos(main: Node, start_line: int, row: int) -> Vector2:
	var info: Label = main.get_node("HUD/Character/Info")
	var rect := info.get_global_rect()
	var line_height := _line_height(info)
	var line_index := start_line + row
	var y: float = rect.position.y + line_index * line_height + line_height / 2.0
	var x := rect.position.x + 10.0
	return Vector2(x, y)


func _screen_pos(main: Node, local_pos: Vector2) -> Vector2:
	return main.get_viewport().get_final_transform() * local_pos


func _touch(main: Node, local_pos: Vector2) -> void:
	var pos := _screen_pos(main, local_pos)
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = pos
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = pos
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _click_at(main: Node, local_pos: Vector2) -> void:
	var pos := _screen_pos(main, local_pos)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await get_tree().process_frame


## 버튼 노드 하나를 실제 마우스 클릭 경로(뷰포트 GUI 입력)로 누른다 -
## Sell 버튼이 능력치/강화 탭 전환에도 반응하는지는 button.pressed()를
## 직접 부르는 게 아니라 이 경로로만 검증해야 사람이 누르는 것과 같다.
func _click_button(main: Node, button: Control) -> void:
	await _click_at(main, button.get_global_rect().get_center())


func _setup_state() -> void:
	GameState.reset()
	GameState.level = 5
	GameState.stat_points = 3
	GameState.perk_picks = 1
	GameState.perk_offer.clear()


## 능력치 탭: 목록 줄 터치로 선택 이동, 재탭으로 투자(spend_stat).
func _check_stats_tab(touch: bool) -> bool:
	_setup_state()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true
	var kind := "ScreenTouch(터치)" if touch else "MouseButton(마우스)"

	main._toggle_character()
	await get_tree().process_frame
	ok = _check("[%s] 캐릭터 창이 능력치 탭으로 열림" % kind,
		main.character_open and main.character_mode == "stats") and ok
	ok = _check("[%s] 초기 선택은 0번째 능력치" % kind, main.stat_index == 0) and ok

	var points_before: int = GameState.stat_points
	var row1 := _row_local_pos(main, CHARACTER_STATS_LIST_START_LINE, 1)
	if touch:
		await _touch(main, row1)
	else:
		await _click_at(main, row1)
	ok = _check("[%s] 탭한 항목으로 선택이 옮겨감(0 -> 1)" % kind, main.stat_index == 1) and ok
	ok = _check("[%s] 첫 탭은 선택만 하고 아직 투자 안 함" % kind,
		GameState.stat_points == points_before) and ok

	if touch:
		await _touch(main, row1)
	else:
		await _click_at(main, row1)
	ok = _check("[%s] 이미 선택된 항목을 다시 탭하면 투자(stat_points 감소)" % kind,
		GameState.stat_points == points_before - 1) and ok

	main.queue_free()
	return ok


## 특성 탭: 목록 줄 터치로 선택 이동, 재탭으로 확정(take_perk).
func _check_perks_tab() -> bool:
	_setup_state()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	main._toggle_character()
	main._cycle_character_mode(1)  # stats -> perks
	await get_tree().process_frame
	ok = _check("특성 탭으로 전환됨", main.character_mode == "perks") and ok
	ok = _check("특성 제안 3개가 채워짐", GameState.perk_offer.size() == 3) and ok

	var target_row := 1
	var picks_before: int = GameState.perk_picks
	var row := _row_local_pos(main, CHARACTER_PERKS_LIST_START_LINE, target_row)
	await _touch(main, row)
	ok = _check("탭한 항목으로 선택이 옮겨감", main.perk_index == target_row) and ok
	ok = _check("첫 탭은 선택만 하고 아직 확정 안 함", GameState.perk_picks == picks_before) and ok

	await _touch(main, row)
	ok = _check("이미 선택된 항목을 다시 탭하면 확정(perk_picks 감소)",
		GameState.perk_picks == picks_before - 1) and ok

	main.queue_free()
	return ok


## 전직 탭(1차): 목록 줄 터치로 선택 이동, 재탭으로 확정(change_job).
func _check_job_tab_primary() -> bool:
	_setup_state()
	GameState.level = 15
	GameState.gold = 999999
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	main._toggle_character()
	main._cycle_character_mode(2)  # stats -> job
	await get_tree().process_frame
	ok = _check("전직 탭으로 전환됨", main.character_mode == "job") and ok

	var row_mage := _row_local_pos(main, CHARACTER_JOB_LIST_START_LINE, 1)
	await _touch(main, row_mage)
	ok = _check("탭한 1차 직업 항목으로 선택이 옮겨감", main.job_index == 1) and ok
	ok = _check("첫 탭은 선택만 하고 아직 전직 안 함", GameState.job == "") and ok
	await _touch(main, row_mage)
	ok = _check("이미 선택된 항목을 다시 탭하면 전직 확정", GameState.job == "mage") and ok

	main.queue_free()
	return ok


## 전직 탭(2차): 목록 앞의 "2차 전직" 구분줄을 탭해도 선택이 그대로인지,
## 그 다음 줄(2차 전직 첫 항목)을 탭하면 제대로 옮겨가는지 - 구분줄이
## 끼어드는 이번 결함의 가장 까다로운 부분이라 따로 확인한다.
func _check_job_tab_second_branch() -> bool:
	_setup_state()
	GameState.level = 40
	GameState.chapter = 4
	GameState.job = "warrior"
	GameState.gold = 999999
	var stone := GameState.second_job_stone_type()
	GameState.materials[stone] = GameState.SECOND_JOB_STONE_COST
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	main._toggle_character()
	main._cycle_character_mode(2)  # stats -> job
	await get_tree().process_frame
	ok = _check("전직 탭으로 전환됨", main.character_mode == "job") and ok
	ok = _check("2차 전직 목록이 보임(레벨 40, 4장, 재료 충분)",
		GameState.can_change_second_job()) and ok

	var jobs := GameState.JOB_NAMES.keys()
	# "2차 전직" 구분줄(1차 직업 목록 바로 다음 줄)을 탭해도 선택이 그대로.
	var separator_row := _row_local_pos(main, CHARACTER_JOB_LIST_START_LINE, jobs.size())
	await _touch(main, separator_row)
	ok = _check("구분줄을 탭해도 선택 그대로(0)", main.job_index == 0) and ok

	# 구분줄 다음 줄(2차 전직 첫 항목, guardian)을 탭하면 그리로 옮겨간다.
	var second_row := _row_local_pos(main, CHARACTER_JOB_LIST_START_LINE, jobs.size() + 1)
	await _touch(main, second_row)
	ok = _check("구분줄 다음 2차 전직 항목으로 선택이 옮겨감(jobs.size())",
		main.job_index == jobs.size()) and ok
	ok = _check("첫 탭은 선택만 하고 아직 2차 전직 안 함", GameState.second_job == "") and ok
	await _touch(main, second_row)
	ok = _check("재탭으로 2차 전직 확정(guardian)", GameState.second_job == "guardian") and ok

	main.queue_free()
	return ok


## 모바일 Sell("탭") 버튼으로 능력치/특성/전직 탭을, 강화 창에서는
## 강화/소켓/제작 탭을 오갈 수 있는지 - 실제 클릭 경로로만 확인한다.
func _check_tab_switch_via_mobile_button() -> bool:
	_setup_state()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true
	var mc := main.get_node("HUD/MobileControls")
	mc.force_visible = true
	mc.show()

	main._toggle_character()
	await get_tree().process_frame
	var sell: Control = mc.get_node("Sell")
	ok = _check("캐릭터 창에서 Sell(탭) 버튼이 보임", sell.visible) and ok
	ok = _check("처음엔 능력치 탭", main.character_mode == "stats") and ok

	await _click_button(main, sell)
	ok = _check("Sell 버튼 클릭으로 능력치 -> 특성 탭 전환", main.character_mode == "perks") and ok
	await _click_button(main, sell)
	ok = _check("Sell 버튼 클릭으로 특성 -> 전직 탭 전환", main.character_mode == "job") and ok

	main._toggle_character()  # 닫기
	GameState.gold = 999999
	main._toggle_forge()
	await get_tree().process_frame
	ok = _check("강화 창에서도 Sell(탭) 버튼이 보임", sell.visible) and ok
	ok = _check("처음엔 강화 탭", main.forge_mode == "enhance") and ok
	await _click_button(main, sell)
	ok = _check("Sell 버튼 클릭으로 강화 -> 소켓 탭 전환", main.forge_mode == "socket") and ok

	main.queue_free()
	return ok


func _ready() -> void:
	var ok := true
	ok = (await _check_stats_tab(true)) and ok
	ok = (await _check_stats_tab(false)) and ok
	ok = (await _check_perks_tab()) and ok
	ok = (await _check_job_tab_primary()) and ok
	ok = (await _check_job_tab_second_branch()) and ok
	ok = (await _check_tab_switch_via_mobile_button()) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
