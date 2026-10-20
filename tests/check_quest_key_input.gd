extends Node
## STATUS.md "다음 후보"가 남긴 것: quest(B 키, project.godot에서 물리
## 키코드 66에 바인딩 — 이름과 달리 Q가 아니다)는 main.gd:_unhandled_input이
## "quest" 액션을 받아 _toggle_quest()를 부르는데, 기존 검사들은
## main._toggle_quest()를 코드로 직접 호출할 뿐 실제 B 키 입력 경로를
## 태운 적이 없었다. check_inventory_key_input.gd와 동일하게
## main._unhandled_input()에 진짜 InputEventKey를 넣어 B 키 입력 ->
## _toggle_quest() 전체 경로를 확인한다.

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _ready() -> void:
	var ok := true
	ok = (await _check_opens_and_closes()) and ok
	ok = (await _check_pauses_tree_and_refreshes()) and ok
	ok = (await _check_quest_travel_home_unpauses()) and ok
	ok = (await _check_quest_mode_leaves_town_when_stage_says_go()) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


## INBOX 보정(감독, 2026-09-05 21:17) 결함 (1): 지도를 연 적 없이
## `_quest_travel_home(home)`을 부르면 예전 코드는 `_travel_to()`의
## `_toggle_world_map()` 토글이 지도를 거꾸로 "열고" `paused=true`인 채로
## 끝나 게임이 멈췄다(3c18b54가 지도를 먼저 여는 방식으로 고침). 지도가
## 닫힌 상태에서 호출한 뒤에도 지도가 닫히고 트리가 멈추지 않아야 한다.
func _check_quest_travel_home_unpauses() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var ok := _check("귀환 호출 전 지도 닫힘", not main.world_map_open)
	main._quest_travel_home("village")
	await get_tree().process_frame
	ok = _check("귀환 호출 뒤 지도 다시 닫힘", not main.world_map_open) and ok
	ok = _check("귀환 호출 뒤 트리 정지 해제", not get_tree().paused) and ok

	get_tree().paused = false
	main.queue_free()
	return ok


## INBOX 보정 결함 (2): 사냥 목표를 채우면 `_quest_stage_text()`가
## "…처치"에서 "…가자"로 바뀌는데, 예전 코드는 마을 분기에서 "처치"만
## 찾아 그 뒤로 촌장에게 헛되이 계속 말을 걸려던 정체 버그였다(3c18b54가
## "가자"도 함께 찾도록 고침). kills를 채워 안내가 "…가자"인 상태에서
## 마을 분기가 촌장 대화 대신 지역을 벗어나는 이동을 택해야 한다.
func _check_quest_mode_leaves_town_when_stage_says_go() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	GameState.reset()
	GameState.current_map = "village"
	GameState.quest_stage = 1
	GameState.kills = 6
	var ok := _check("kills 채운 뒤 안내가 '가자'", main._quest_stage_text().contains("가자"))

	main.quest_mode = true
	player.auto_walk_active = false
	player.auto_hunt = true
	main._quest_mode_tick()
	ok = _check("마을 분기가 촌장 대화 대신 이동을 택함", player.auto_walk_active == true) and ok
	ok = _check("이동 중에는 오토사냥 꺼짐", player.auto_hunt == false) and ok

	main.quest_mode = false
	get_tree().paused = false
	main.queue_free()
	return ok


func _check_opens_and_closes() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	_send_key(main, KEY_B)
	await get_tree().process_frame
	var ok := _check("B 키 입력만으로 퀘스트 화면 열림", main.quest_open)
	ok = _check("퀘스트 패널 보임", main.get_node("HUD/Quest").visible) and ok

	_send_key(main, KEY_B)
	await get_tree().process_frame
	ok = _check("B 키 재입력만으로 퀘스트 화면 닫힘(토글)", not main.quest_open) and ok
	ok = _check("퀘스트 패널 숨김", not main.get_node("HUD/Quest").visible) and ok

	get_tree().paused = false
	main.queue_free()
	return ok


func _check_pauses_tree_and_refreshes() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	_send_key(main, KEY_B)
	await get_tree().process_frame
	var ok := _check("B 키 입력으로 퀘스트 화면 연 동안 트리 일시정지", get_tree().paused)
	ok = _check("퀘스트 정보 텍스트 채워짐", main.get_node("HUD/Quest/Info").text != "") and ok

	_send_key(main, KEY_B)
	await get_tree().process_frame
	ok = _check("B 키 재입력으로 트리 일시정지 해제", not get_tree().paused) and ok

	get_tree().paused = false
	main.queue_free()
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
