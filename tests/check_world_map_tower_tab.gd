extends Node
## (감독 2026-09-10) 심연의 탑은 장 탭·목록 어디에도 없고("10장 뒤에 넣지
## 말고"), 오른쪽 대륙 개관도 아래 빈자리의 탑 표식을 눌러 바로 간다.
## 표식은 지도 사각형 안·대륙과 안 겹치고, 잠기면 거절 문구, 열리면 탭
## 한 번에 난이도 선택창. 키보드는 T.

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _tap(main: Node, graph: Control, atlas_local: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = graph.atlas.position + atlas_local
	main._on_world_map_gui_input(ev)


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	GameState.reset()
	var graph: Control = main.get_node("HUD/WorldMap/Graph")
	var atlas: Control = graph.atlas
	var info: Label = graph.get_node("Info")
	var hint: Label = graph.get_node("Hint")
	var ok := true

	var top: int = graph.max_chapter()
	for ch in range(1, top + 1):
		ok = _check("%d장 목록에 탑 없음" % ch, graph.order_for_chapter(ch).find("tower") < 0) and ok

	# 표식 자리: 지도 사각형 안, 어느 대륙 윤곽(선택 시 최대 반지름)과도 안 겹침.
	ok = _check("탑 표식이 지도 사각형 안", atlas.MAP_RECT.encloses(atlas.TOWER_RECT)) and ok
	ok = _check("탑 표식 아래가 범례 위", atlas.TOWER_RECT.end.y <= atlas.MAP_RECT.end.y) and ok
	for i in range(atlas.CONTINENTS.size()):
		var shape: PackedVector2Array = atlas._blob_shape(i, atlas._continent_position(i), 8.0)
		var clear := true
		for v in shape:
			if atlas.TOWER_RECT.has_point(v):
				clear = false
		ok = _check("%d대륙 윤곽이 탑 표식과 안 겹침" % (i + 1), clear) and ok
	var font := ThemeDB.fallback_font
	var label_w: float = font.get_string_size("심연의 탑", HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
	ok = _check("탑 이름이 표식 사각형 안(폭 %d)" % int(label_w), atlas.TOWER_POS.x + 7 + label_w <= atlas.TOWER_RECT.end.x) and ok
	ok = _check("tower_hit(표식 중심)", atlas.tower_hit(atlas.TOWER_POS)) and ok
	ok = _check("area_at(표식 중심)은 탑 아님", atlas.area_at(atlas.TOWER_POS) != "tower") and ok

	# 잠김: 탭 수 = 장 수, 1장에서 왼쪽 넘기면 마지막 장, 표식 탭은 거절 문구.
	GameState.current_map = "village"
	main._toggle_world_map()
	await get_tree().process_frame
	ok = _check("마을에서 열면 1장 탭", graph.chapter == 1) and ok
	ok = _check("탭 줄에 탑 없음", not info.text.contains("심연의 탑")) and ok
	graph.change_chapter(-1)
	ok = _check("잠김 - 1장에서 왼쪽 넘기면 마지막 장(%d)" % top, graph.chapter == top) and ok
	graph.change_chapter(1)
	ok = _check("마지막 장에서 오른쪽 넘기면 1장", graph.chapter == 1) and ok
	_tap(main, graph, atlas.TOWER_POS)
	ok = _check("잠김 - 표식 탭하면 지도 그대로", main.world_map_open and not main.tower_select_open) and ok
	ok = _check("잠김 - 거절 문구", hint.text.contains("아직 열리지 않았다")) and ok
	main._toggle_world_map()

	# 열림: 표식 한 번 탭 → 지도 닫히고 난이도 선택창.
	GameState.unlock_map("tower")
	main._toggle_world_map()
	await get_tree().process_frame
	ok = _check("열림 - 탭 수 그대로(장 수)", graph.chapter == 1 and not info.text.contains("심연의 탑")) and ok
	for ch in range(1, top + 1):
		ok = _check("열림 - %d장 목록에도 탑 없음" % ch, graph.order_for_chapter(ch).find("tower") < 0) and ok
	_tap(main, graph, atlas.TOWER_RECT.position + Vector2(2, 2))
	ok = _check("열림 - 표식 모서리 탭 한 번에 난이도 선택창", main.tower_select_open and not main.world_map_open) and ok
	ok = _check("아직 탑에 들어간 건 아님", GameState.current_map != "tower") and ok
	main._toggle_tower_select()

	# 키보드 T.
	main._toggle_world_map()
	await get_tree().process_frame
	ok = _check("T 키 - 지도 열림 확인", main.world_map_open) and ok
	ok = _check("데스크톱 도움줄에 T 탑", str(main.get_node("HUD/WorldMap/Help").text).contains("T 탑") or main.get_node("HUD/MobileControls").visible) and ok
	ok = _check("try_travel_tower 수락", graph.try_travel_tower() == "") and ok
	ok = _check("난이도 선택창 열림", main.tower_select_open and not main.world_map_open) and ok
	main._toggle_tower_select()

	# 탑 안에서 지도를 열면 장 탭은 유효하고, 표식에 현재 위치 표시.
	GameState.current_map = "tower"
	main._toggle_world_map()
	await get_tree().process_frame
	ok = _check("탑 안에서 열면 탭 1~%d 안" % top, graph.chapter >= 1 and graph.chapter <= top) and ok
	ok = _check("탑 안에서 현재 위치점 = 표식", atlas._area_position("tower") == atlas.TOWER_POS) and ok
	_tap(main, graph, atlas.TOWER_POS)
	ok = _check("탑 안에서 표식 탭하면 '이미 이곳'", hint.text.contains("이미 이곳")) and ok
	main._toggle_world_map()

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
