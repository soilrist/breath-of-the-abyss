extends Node
## STATUS.md "다음 후보"가 남긴 마지막 하나: interact(E 키, NPC 대화)는
## project.godot에서 물리 키코드 69(E)에 바인딩돼 있고 main.gd:_unhandled_input이
## "interact" 액션을 받아 _interact_npc()를 부르는데, 기존 검사
## (check_town_npc_names.gd/integration_test.gd/shot_chapter*_ending.gd 등)는
## 전부 main._interact_npc()를 코드로 직접 호출해서만 검증하고 실제 E 키
## 입력 경로를 태운 적이 없었다(⑥ 규칙이 경고하는 패턴). world_map/character/
## guide 검사와 같은 패턴으로 main._unhandled_input(InputEventKey)에 진짜
## E 키를 넣어 대화 열기/넘기기/닫기 전체 경로를 확인한다.

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _ready() -> void:
	var ok := true
	ok = (await _check_no_target()) and ok
	ok = (await _check_opens_advances_closes()) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check_no_target() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var player: CharacterBody2D = main.get_node("Player")
	player.global_position = Vector2(-2000, -2000)
	main.get_node("HUD/Message").text = ""
	_send_key(main, KEY_E)
	await get_tree().process_frame
	var ok := _check("먼 곳에서 E 키는 대화를 안 연다", not main.dialogue_open)
	ok = _check("먼 곳에서 E 키 안내 문구", main.get_node("HUD/Message").text == "상호작용할 대상이 없다.") and ok

	get_tree().paused = false
	main.queue_free()
	return ok


func _check_opens_advances_closes() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.quest_stage = 0
	var player: CharacterBody2D = main.get_node("Player")
	player.global_position = World.town_npc_position(GameState.current_map, "elder")

	_send_key(main, KEY_E)
	await get_tree().process_frame
	var ok := _check("E 키 입력만으로 대화 열림", main.dialogue_open)
	ok = _check("대화 패널 보임", main.get_node("HUD/Dialogue").visible) and ok
	ok = _check("화자 이름이 촌장 로한", main.get_node("HUD/Dialogue/Speaker").text == "촌장 로한") and ok
	ok = _check("대화 여는 동안 트리 일시정지", get_tree().paused) and ok

	_send_key(main, KEY_E)
	await get_tree().process_frame
	ok = _check("E 키 재입력으로 다음 대사로 넘어감", main.dialogue_page == 1) and ok
	ok = _check("두 번째 대사도 화자는 촌장 로한", main.get_node("HUD/Dialogue/Speaker").text == "촌장 로한") and ok

	_send_key(main, KEY_E)
	await get_tree().process_frame
	ok = _check("세 번째 대사로 넘어감", main.dialogue_page == 2) and ok
	ok = _check("세 번째 대사는 화자가 카일", main.get_node("HUD/Dialogue/Speaker").text == "카일") and ok

	_send_key(main, KEY_E)
	await get_tree().process_frame
	ok = _check("마지막 대사에서 E 키로 대화 닫힘", not main.dialogue_open) and ok
	ok = _check("대화 패널 숨김", not main.get_node("HUD/Dialogue").visible) and ok
	ok = _check("대화 닫히며 트리 일시정지 해제", not get_tree().paused) and ok

	get_tree().paused = false
	main.queue_free()
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
