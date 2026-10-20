extends Node
## STATUS.md "다음에 할 것" 103번: check_safe_perk_picking.gd는 InputEventAction을
## 직접 넣어(`ev.action = "move_right"`) 물리 키코드→액션 매핑(project.godot의
## InputMap)을 건너뛴다. check_forge_storage_key_input.gd와 같은 패턴으로
## 실제 InputEventKey(C→D→E)가 능력치 화면을 열고 특성 탭으로 넘어가
## 특성을 고르는 전체 경로를 태우는지 확인한다. move_right 액션은
## project.godot에서 물리키코드 68(D)에 매여 있다 — STATUS.md 103번이 적은
## "또는 4194313"은 실제로는 Pause 키였다(`OS.get_keycode_string(4194313)`로
## 확인, KEY_RIGHT 상수값 4194321과 다름). 기존 검사들(check_tower_select_key_input.gd
## 등)도 전부 KEY_D를 쓴다.

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	GameState.perk_picks = 1
	GameState.perk_offer = []

	_send_key(main, KEY_C)
	await get_tree().process_frame
	ok = _check("C 키 입력만으로 능력치 화면 열림", main.character_open) and ok
	ok = _check("여는 동안 트리 일시정지", get_tree().paused) and ok
	ok = _check("처음엔 능력치 탭", main.character_mode == "stats") and ok

	_send_key(main, KEY_D)
	await get_tree().process_frame
	ok = _check("D 키(move_right 액션)로 특성 탭 전환", main.character_mode == "perks") and ok

	main.perk_index = 0
	var picks_before: int = GameState.perk_picks
	_send_key(main, KEY_E)
	await get_tree().process_frame
	ok = _check("E 키(interact 액션)로 특성 고르면 선택권이 줄어듦", GameState.perk_picks == picks_before - 1) and ok
	ok = _check("특성 탭에서 골라도 예전 강제 창은 안 뜸", not main.perk_open) and ok

	_send_key(main, KEY_C)
	await get_tree().process_frame
	ok = _check("C 키로 능력치 화면 닫힘", not main.character_open) and ok
	ok = _check("닫히며 트리 일시정지 해제", not get_tree().paused) and ok

	get_tree().paused = false
	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
