extends Node
## 감독 지시(2026-09-09): "모든 창에 위아래 화살표". 인벤토리/캐릭터/특성/탑
## 난이도/지도/선택지 대화까지 ▲▼가 보이고 실제로 한 칸씩 옮기는지, 창고
## 탭 버튼이 가방↔창고를 오가는지, 대화 선택지를 손가락으로 골라 결정할 수
## 있는지, 버튼이 패널 내용과 안 겹치는지, 모바일 안내문이 키 이름 대신
## 버튼 이름으로 나오는지 한 번에 본다.


func _touch_at(viewport: Viewport, pos: Vector2) -> void:
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.device = InputEvent.DEVICE_ID_EMULATION
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = pos
		mb.global_position = pos
		viewport.push_input(mb, true)
		var st := InputEventScreenTouch.new()
		st.index = 0
		st.pressed = pressed
		st.position = pos
		viewport.push_input(st, true)
		await get_tree().process_frame
	await get_tree().process_frame


func _touch(button: Button) -> void:
	await _touch_at(button.get_viewport(), button.get_global_rect().get_center())


func _ready() -> void:
	var ok := true
	var game := get_parent().get_node("Main")
	await get_tree().process_frame
	var guard := 0
	while game.dialogue_open and guard < 40:
		game._advance_dialogue()
		guard += 1
	var mobile := game.get_node("HUD/MobileControls")
	mobile.force_visible = true
	mobile.show()
	var up: Button = mobile.get_node("Up")
	var down: Button = mobile.get_node("Down")
	var interact: Button = mobile.get_node("Interact")
	var close: Button = mobile.get_node("Close")
	var tab: Button = mobile.get_node("Sell")

	# 인벤토리
	GameState.reset()
	GameState.inventory = ["회복약", "철검", "가죽 갑옷"] as Array[String]
	GameState.sync_uids()
	game._toggle_inventory()
	await get_tree().process_frame
	ok = _check("인벤토리 ▲/▼ 보임", up.visible and down.visible) and ok
	ok = _check("인벤토리 안내문 모바일판", game.get_node("HUD/Inventory/Help").text.begins_with("▲▼")) and ok
	await _touch(down)
	ok = _check("인벤토리 ▼ 탭 → 0→1", game.inventory_index == 1) and ok
	await _touch(up)
	ok = _check("인벤토리 ▲ 탭 → 1→0", game.inventory_index == 0) and ok
	ok = _no_overlap("인벤토리", [up, down, interact], game.get_node("HUD/Inventory")) and ok
	game._toggle_inventory()
	await get_tree().process_frame

	# 캐릭터(능력치 탭) - 점수는 안 쓴다, 커서만 옮긴다.
	game._toggle_character()
	await get_tree().process_frame
	ok = _check("캐릭터 ▲/▼ 보임", up.visible and down.visible) and ok
	ok = _check("캐릭터 탭 버튼 보임", tab.visible) and ok
	ok = _check("캐릭터 안내문 모바일판", game.get_node("HUD/Character/Help").text.begins_with("▲▼")) and ok
	var stat_before: int = game.stat_index
	await _touch(down)
	ok = _check("캐릭터 ▼ 탭 → 한 칸", game.stat_index == stat_before + 1) and ok
	await _touch(up)
	ok = _check("캐릭터 ▲ 탭 → 되돌아옴", game.stat_index == stat_before) and ok
	ok = _no_overlap("캐릭터", [up, down, interact, tab], game.get_node("HUD/Character")) and ok
	game._toggle_character()
	await get_tree().process_frame

	# 특성 고르기 - X 없음, ▲▼ 있음.
	GameState.perk_picks = 1
	GameState.roll_perk_offer()
	game._open_perk_choice()
	await get_tree().process_frame
	ok = _check("특성 ▲/▼ 보임", up.visible and down.visible) and ok
	ok = _check("특성 X 숨김(골라야 넘어감)", not close.visible) and ok
	ok = _check("특성 안내문 모바일판", game.get_node("HUD/Perk/Help").text.begins_with("▲▼")) and ok
	await _touch(down)
	ok = _check("특성 ▼ 탭 → 0→1", game.perk_index == 1) and ok
	await _touch(up)
	ok = _check("특성 ▲ 탭 → 1→0", game.perk_index == 0) and ok
	ok = _no_overlap("특성", [up, down, interact], game.get_node("HUD/Perk")) and ok
	game._take_perk()
	await get_tree().process_frame
	ok = _check("특성 고른 뒤 ▲/▼ 숨김", not up.visible and not game.perk_open) and ok

	# 탑 난이도
	game._toggle_tower_select()
	await get_tree().process_frame
	ok = _check("탑 난이도 ▲/▼ 보임", up.visible and down.visible) and ok
	ok = _check("탑 난이도 입장 버튼", interact.visible and interact.text == "입장") and ok
	await _touch(down)
	ok = _check("탑 난이도 ▼ 탭 → 0→1", game.tower_select_index == 1) and ok
	await _touch(up)
	ok = _check("탑 난이도 ▲ 탭 → 1→0", game.tower_select_index == 0) and ok
	game._toggle_tower_select()
	await get_tree().process_frame

	# 지도 - 메인화면(다른 창)과 같은 자리의 ▲▼/이동(감독 2026-09-10). Atlas는
	# 패널이 x284에서 끝나 오른쪽 버튼 열(288~)과 안 겹친다.
	game._toggle_world_map()
	await get_tree().process_frame
	var graph := game.get_node("HUD/WorldMap/Graph")
	ok = _check("지도 ▲/▼ 보임", up.visible and down.visible) and ok
	ok = _check("지도 이동 버튼", interact.visible and interact.text == "이동") and ok
	ok = _check("지도 안내문 모바일판", game.get_node("HUD/WorldMap/Help").text.begins_with("▲▼")) and ok
	ok = _no_overlap("지도(대륙 그림)", [up, down, interact], game.get_node("HUD/WorldMap/Graph/Atlas")) and ok
	ok = _check("지도 ▲▼ 위치 y46/78 (다른 창과 같은 자리)", up.offset_top == 46.0 and down.offset_top == 78.0) and ok
	var cursor_before: int = graph.cursor
	var count: int = graph.order_for_chapter(graph.chapter).size()
	await _touch(down)
	ok = _check("지도 ▼ 탭 → 커서 한 칸(%d개 중)" % count, graph.cursor == wrapi(cursor_before + 1, 0, count)) and ok
	await _touch(up)
	ok = _check("지도 ▲ 탭 → 되돌아옴", graph.cursor == cursor_before) and ok
	# 탭 줄 "≪ N장 / M장 ≫": ≫ 글자를 누르면 다음 장, ≪ 글자를 누르면 이전 장.
	# 예전엔 라벨 폭 절반(74px)이 기준이라 58px짜리 글자의 ≫(x≈55)도 이전 장으로 갔다.
	var info: Label = graph.get_node("Info")
	var tab_line: String = info.text.get_slice("\n", 1)
	var tab_width: float = info.get_theme_default_font().get_string_size(
		tab_line, HORIZONTAL_ALIGNMENT_LEFT, -1, info.get_theme_font_size("font_size")).x
	var tab_lh: float = info.get_line_height() + info.get_theme_constant("line_spacing")
	var tab_origin: Vector2 = game.get_node("HUD/WorldMap").global_position + info.position + Vector2(0, tab_lh * 1.5)
	var chapter_before: int = graph.chapter
	ok = _check("지도 탭 줄 폭이 라벨 절반보다 좁음(재현 조건, %dpx)" % int(tab_width), tab_width < info.size.x / 2.0) and ok
	await _touch_at(game.get_viewport(), tab_origin + Vector2(tab_width - 3.0, 0))
	ok = _check("지도 ≫ 글자 탭 → 다음 장(%d→%d)" % [chapter_before, graph.chapter], graph.chapter == chapter_before + 1) and ok
	await _touch_at(game.get_viewport(), tab_origin + Vector2(3.0, 0))
	ok = _check("지도 ≪ 글자 탭 → 이전 장으로 복귀", graph.chapter == chapter_before) and ok
	game._toggle_world_map()
	await get_tree().process_frame
	ok = _check("지도 닫으면 ▲▼ 기본 자리로 복귀", up.offset_top == 46.0 and interact.offset_top == 138.0) and ok

	# 창고 - 탭 버튼으로 가방↔창고.
	GameState.inventory = ["회복약", "철검"] as Array[String]
	GameState.sync_uids()
	game._toggle_storage()
	await get_tree().process_frame
	ok = _check("창고 탭 버튼 보임", tab.visible) and ok
	ok = _check("창고 안내문 모바일판", game.get_node("HUD/Storage/Help").text.begins_with("탭")) and ok
	await _touch(tab)
	ok = _check("창고 탭 탭 → 창고 칸", game.storage_side == "box" and game.storage_index == 0) and ok
	ok = _check("창고 칸에서 버튼 글자 꺼내기", interact.text == "꺼내기") and ok
	await _touch(tab)
	ok = _check("창고 탭 다시 → 가방 칸", game.storage_side == "bag" and interact.text == "넣기") and ok
	game._toggle_storage()
	await get_tree().process_frame

	# 선택지 대화 - ▲▼ 보임, X 숨김, 줄 터치로 고르고 다시 터치로 결정.
	game._play_dialogue([["", "어느 쪽?", [["첫째 길", "a"], ["둘째 길", "b"], ["셋째 길", "c"]]]])
	await get_tree().process_frame
	ok = _check("선택지 대화 ▲/▼ 보임", up.visible and down.visible) and ok
	ok = _check("선택지 대화 X 숨김", not close.visible) and ok
	ok = _check("선택지 안내문 모바일판", game.get_node("HUD/Dialogue/More").text.begins_with("▲▼")) and ok
	await _touch(down)
	ok = _check("선택지 ▼ 탭 → 0→1", game.dialogue_choice == 1) and ok
	await _touch(down)
	ok = _check("선택지 ▼ 탭 → 1→2", game.dialogue_choice == 2) and ok
	await _touch(up)
	ok = _check("선택지 ▲ 탭 → 2→1", game.dialogue_choice == 1) and ok
	var choices: Label = game.get_node("HUD/Dialogue/Choices")
	var line_height: float = choices.get_line_height() + choices.get_theme_constant("line_spacing")
	var row0: Vector2 = choices.get_global_rect().position + Vector2(6.0, 3.0)
	await _touch_at(game.get_viewport(), row0)
	ok = _check("선택지 첫 줄 터치 → 고르기 1→0", game.dialogue_choice == 0 and game.dialogue_open) and ok
	await _touch_at(game.get_viewport(), row0 + Vector2(0.0, line_height * 2.0))
	ok = _check("선택지 셋째 줄 터치 → 고르기 0→2", game.dialogue_choice == 2 and game.dialogue_open) and ok
	await _touch_at(game.get_viewport(), row0 + Vector2(0.0, line_height * 2.0))
	ok = _check("고른 줄 다시 터치 → 결정(c)", GameState.choices.has("c") if "choices" in GameState else not game.dialogue_open or game.dialogue_choices.is_empty()) and ok
	guard = 0
	while game.dialogue_open and guard < 10:
		game._advance_dialogue()
		guard += 1
	await get_tree().process_frame
	ok = _check("대화 끝 → ▲▼/X 숨김", not up.visible and not close.visible) and ok

	# 선택지 없는 대화 - X 보임, ▲▼ 숨김.
	game._open_dialogue("그냥 말")
	await get_tree().process_frame
	ok = _check("일반 대화 X 보임·▲▼ 숨김", close.visible and not up.visible) and ok
	ok = _check("일반 대화 안내문 모바일판", game.get_node("HUD/Dialogue/More").text.begins_with("대화 버튼")) and ok
	game._close_dialogue()
	await get_tree().process_frame

	# 키 이름 → 버튼 이름
	ok = _check("퀘스트 안내 키 이름 치환", game._mob("M키 지도로 마을에") == "이동주문서로 마을에") and ok
	game.get_node("HUD/Guide").visible = true
	game.guide_page = 17
	game._refresh_guide()
	var guide_text: String = game.get_node("HUD/Guide/Info").text
	ok = _check("가이드 조작 쪽에 키 이름 없음", not guide_text.contains("K:") and guide_text.contains("캐릭 탭")) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _no_overlap(label: String, buttons: Array, panel: Control) -> bool:
	var ok := true
	for button in buttons:
		if not button.visible:
			continue
		ok = _check("%s: %s 버튼이 내용과 안 겹침" % [label, button.name],
			not button.get_global_rect().intersects(panel.get_global_rect())) and ok
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
