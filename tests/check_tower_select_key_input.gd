extends Node
## STATUS.md "다음에 할 것" 101번이 남긴 것: tower_select 패널
## (main.gd:1674 _toggle_tower_select())은 check_tower_select.gd에서
## main._toggle_world_map()/main._travel_to("tower")/main._confirm_tower_select()를
## 코드로 직접 호출해서만 검증됐을 뿐, 사람이 실제로 누르는 경로(M 키로
## 세계지도 열기 -> 방향키로 4장 "심연의 탑" 노드까지 이동 -> attack/ui_accept로
## 이동 확정 -> tower_select 패널이 뜸 -> 방향키로 난이도 고르고 attack으로
## 확정 -> 실제 입장)는 한 번도 InputEventKey로 태운 적이 없었다.
## check_world_map_key_input.gd와 같은 패턴으로 main._unhandled_input()에
## 진짜 InputEventKey를 넣어 전체 경로를 확인한다.

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _ready() -> void:
	GameState.reset()
	GameState.unlock_map("tower")
	GameState.game_cleared = true  # 쉬움 난이도 잠금 해제(check_tower_select.gd와 동일 조건)

	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var ok := true

	_send_key(main, KEY_M)
	await get_tree().process_frame
	ok = _check("M 키 입력만으로 세계지도 열림", main.world_map_open) and ok

	var graph: Node = main.get_node("HUD/WorldMap/Graph")
	# 탑은 장 탭·목록에 없다(개관도 표식). 키보드는 T 한 번으로 간다.
	for ch in range(1, graph.max_chapter() + 1):
		ok = _check("%d장 목록에 탑 없음" % ch, graph.order_for_chapter(ch).find("tower") < 0) and ok
	_send_key(main, KEY_T)
	await get_tree().process_frame
	ok = _check("T 키 입력만으로 세계지도가 닫힘", not main.world_map_open) and ok
	ok = _check("T 키 입력만으로 탑 선택 화면이 뜸", main.tower_select_open) and ok
	ok = _check("탑 선택 화면 패널 보임", main.get_node("HUD/TowerSelect").visible) and ok
	ok = _check("아직 탑에 들어간 건 아님", GameState.current_map != "tower") and ok

	main.tower_select_index = 1  # 다른 항목에 있다가 시작할 수 있으니 강제로 옮겨 둠
	_send_key(main, KEY_W)  # move_up -> tower_select_index 감소
	await get_tree().process_frame
	ok = _check("방향키(W)로 탑 선택 화면 커서 이동", main.tower_select_index == 0) and ok

	_send_key(main, KEY_J)  # attack -> _confirm_tower_select()
	await get_tree().process_frame
	ok = _check("attack(J) 키 입력만으로 쉬움 난이도 확정 -> 실제 입장", GameState.tower_active) and ok
	ok = _check("입장하면 탑 선택 화면은 닫힘", not main.tower_select_open) and ok
	ok = _check("현재 지역이 탑으로 바뀜", GameState.current_map == "tower") and ok
	ok = _check("고른 난이도(쉬움)로 들어감", GameState.tower_difficulty == "easy") and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
