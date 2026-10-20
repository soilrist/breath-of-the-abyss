extends Node
## 탑 Phase 2 - 난이도 선택 화면과 잠금 해제 로직을 확인한다.
## 지도(M)에서 "탑"을 고르면 바로 입장하는 대신 선택 화면이 먼저 뜨고,
## 잠긴 난이도는 확정해도 입장이 막혀야 한다.

func _ready() -> void:
	GameState.reset()
	GameState.unlock_map("tower")
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	main._toggle_world_map()
	main._travel_to("tower")
	ok = _check("탑을 고르면 바로 입장 안 하고 선택 화면이 뜸", main.tower_select_open) and ok
	ok = _check("선택 화면 뜨면 지도는 닫힘", not main.world_map_open) and ok
	ok = _check("아직 탑에 들어간 건 아님", GameState.current_map != "tower") and ok
	ok = _check("스토리 클리어 전엔 쉬움도 잠김 표시", main.get_node("HUD/TowerSelect/Info").text.contains("[잠김]")) and ok

	main.tower_select_index = 0  # 쉬움
	main._confirm_tower_select()
	ok = _check("잠긴 난이도는 확정해도 입장 안 됨", not GameState.tower_active and main.tower_select_open) and ok

	GameState.game_cleared = true
	main._refresh_tower_select()
	ok = _check("스토리 클리어하면 쉬움 잠금 표시가 없어짐",
		not main.get_node("HUD/TowerSelect/Info").text.split("\n")[2].contains("[잠김]")) and ok

	main._confirm_tower_select()
	ok = _check("해금된 난이도는 확정하면 실제로 입장됨", GameState.tower_active) and ok
	ok = _check("입장하면 선택 화면은 닫힘", not main.tower_select_open) and ok
	ok = _check("현재 지역이 탑으로 바뀜", GameState.current_map == "tower") and ok
	ok = _check("고른 난이도(쉬움)로 들어감", GameState.tower_difficulty == "easy") and ok

	# 다시 나가서, 아직 안 푼 다음 난이도(보통)를 고르면 막히는지.
	main._change_map("village", false)
	main._toggle_world_map()
	main._travel_to("tower")
	main.tower_select_index = 1  # 보통 - 쉬움 100층 전엔 잠김
	main._confirm_tower_select()
	ok = _check("보통은 쉬움 100층 클리어 전엔 여전히 잠김", main.tower_select_open) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
