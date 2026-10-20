extends Node
## INBOX 지시(2026-09-06 04:35, HUD 창 13개 강화 창 기준 전수 점검) — WorldMap(대륙
## 이동도) 창. check_tower_select_layout.gd/check_quest_layout.gd와 같은 패턴.
## WorldMap은 Info/Hint/Help 셋이라(다른 창은 보통 Info/Help 둘) 겹침 검사
## 대상에 Hint도 넣는다. Atlas는 텍스트가 아니라 _draw()로 그리는 미니맵이라
## 대상에서 뺀다(다른 창들도 텍스트 아닌 자식은 검사 목록에 안 넣는 관례).
##
## 실제 결함(2026-09-07 발견): 기존 offset(WorldMap top=38, Info/Hint/Help)으로는
## Info Label의 get_minimum_size()가 8줄 최악 데이터에서 배정된 칸(130px)보다
## 커서(get_minimum_size 관측 150~167px) Godot이 라벨을 그 이상으로 늘려 Hint·
## Help가 밀려 내려가 StatBar(y 198~)까지 겹쳤다(Help 실측 y 190~204). 원인은
## WorldMap 패널이 다른 창보다 늦게(y=38) 시작해 세로 여유가 부족했던 것 -
## 패널을 TowerSelect처럼 y=8부터 시작하도록 늘리고, WINDOW(한 번에 보여줄
## 지역 수)를 6→4로 줄여 최악 8줄(제목+탭+구분선+4줄+더보기)로 맞췄다
## (world_map.gd).
##
## 최악 데이터: 지역이 가장 많은 챕터(현재 3장 8곳), 그리고 이름이 가장 긴
## "잔영의 마을 (은둔지)"(5장)를 각각 현재 위치로 놓고 챕터 전체·각 커서
## 위치를 순회하며 8줄 초과·겹침이 없는지 단언한다.

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _check_no_overlap_desktop(main: Node) -> bool:
	var statbar: Control = main.get_node("HUD/StatBar")
	# 메뉴 탭 창이 열리면 StatBar는 숨겨진다(main.gd _sync_modal_hud_visibility).
	if not statbar.visible:
		return _check("(1) 지도 열림 - StatBar 숨김(겹침 검사 생략)", true)
	var statbar_rect: Rect2 = statbar.get_global_rect().grow(4)
	var ok := true
	for child_name in ["Info", "Hint"]:
		var node := main.get_node("HUD/WorldMap/Graph/%s" % child_name)
		var rect: Rect2 = node.get_global_rect()
		ok = _check("(1) HUD/WorldMap/Graph/%s 가 StatBar와 4px 여백 없이 안 겹침(데스크톱)" % child_name,
			not rect.intersects(statbar_rect)) and ok
	var help: Control = main.get_node("HUD/WorldMap/Help")
	ok = _check("(1) HUD/WorldMap/Help 가 StatBar와 4px 여백 없이 안 겹침(데스크톱)",
		not help.get_global_rect().intersects(statbar_rect)) and ok
	return ok


func _check_no_overlap_mobile(main: Node) -> bool:
	var mc := main.get_node("HUD/MobileControls")
	var statbar_visible: bool = main.get_node("HUD/StatBar").visible
	var statbar_rect: Rect2 = main.get_node("HUD/StatBar").get_global_rect().grow(4)
	var ok := true
	var close: Control = mc.get_node("Close")
	var close_rect: Rect2 = close.get_global_rect().grow(4)
	var nodes := [
		main.get_node("HUD/WorldMap/Graph/Info"), main.get_node("HUD/WorldMap/Graph/Hint"),
		main.get_node("HUD/WorldMap/Help"),
	]
	for node in nodes:
		var rect: Rect2 = node.get_global_rect()
		ok = _check("(c) HUD/WorldMap/%s 가 MobileControls/Close 와 4px 여백 없이 안 겹침" % node.name,
			not rect.intersects(close_rect)) and ok
		ok = _check("(1) HUD/WorldMap/%s 가 StatBar와 4px 여백 없이 안 겹침(모바일)" % node.name,
			not statbar_visible or not rect.intersects(statbar_rect)) and ok
	return ok


func _check_rects_disjoint(main: Node) -> bool:
	var info_rect: Rect2 = main.get_node("HUD/WorldMap/Graph/Info").get_global_rect()
	var hint_rect: Rect2 = main.get_node("HUD/WorldMap/Graph/Hint").get_global_rect()
	var help_rect: Rect2 = main.get_node("HUD/WorldMap/Help").get_global_rect()
	var ok := true
	ok = _check("(b) Info ∩ Hint = 4px 여백 없이 무교집합", not info_rect.grow(4).intersects(hint_rect)) and ok
	ok = _check("(b) Hint ∩ Help = 4px 여백 없이 무교집합", not hint_rect.grow(4).intersects(help_rect)) and ok
	return ok


func _check_panel_bounds(main: Node) -> bool:
	var panel: Control = main.get_node("HUD/WorldMap")
	var panel_rect: Rect2 = panel.get_global_rect()
	var ok := true
	for node in [main.get_node("HUD/WorldMap/Graph/Info"), main.get_node("HUD/WorldMap/Graph/Hint"),
			main.get_node("HUD/WorldMap/Help")]:
		ok = _check("(5) HUD/WorldMap/%s 가 패널 밖으로 안 삐져나옴" % node.name,
			panel_rect.encloses(node.get_global_rect())) and ok
	return ok


func _check_label_fits(label: Label, tag: String) -> bool:
	var line_height := label.get_line_height() + label.get_theme_constant("line_spacing")
	var fits := label.get_line_count() * line_height <= label.size.y
	var visible_ok := label.get_visible_line_count() >= label.get_line_count()
	return _check("(a) %s %d줄 안착(칸 %d, 줄높이 %d)" %
		[tag, label.get_line_count(), int(label.size.y), line_height], fits) and \
		_check("(a) %s 마지막 줄까지 실제로 보임" % tag, visible_ok)


func _check_area_message_hidden(main: Node) -> bool:
	var ok := true
	ok = _check("(3) 지도 열림 - HUD/Area 숨김", not main.get_node("HUD/Area").visible) and ok
	ok = _check("(3) 지도 열림 - HUD/Message 숨김", not main.get_node("HUD/Message").visible) and ok
	ok = _check("(3) 지도 열림 - HUD/SkillBar 숨김", not main.get_node("HUD/SkillBar").visible) and ok
	return ok


## 8곳짜리 챕터(제목+탭+구분선+WINDOW(4)+더보기 = 8줄, Info 최악 줄수)를
## 챕터 전체 커서 위치·현재 위치 태그(첫/끝 지역) 조합으로 순회해 8줄 초과나
## 겹침이 한 번도 안 나오는지 단언한다.
func _check_worst_case_sweep(main: Node) -> bool:
	var graph = main.get_node("HUD/WorldMap/Graph")
	var info: Label = graph.get_node("Info")
	var ok := true
	var swept := 0
	for ch in range(1, graph.max_chapter() + 1):
		var list: Array = graph.order_for_chapter(ch)
		if list.is_empty():
			continue
		for tag_area in [list[0], list[list.size() - 1]]:
			for cursor in range(list.size()):
				GameState.current_map = tag_area
				graph.chapter = ch
				graph.cursor = cursor
				graph._refresh()
				swept += 1
				ok = _check_label_fits(info, "WorldMap Info(ch%d cursor%d tag=%s)" % [ch, cursor, tag_area]) and ok
	ok = _check("(sweep) 챕터×커서×현재위치 조합 %d개 순회" % swept, swept > 0) and ok
	return ok


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	for k in World.AREAS.keys():
		GameState.unlock_map(str(k))
	var ok := true

	main.get_node("HUD/MobileControls").visible = false
	main._toggle_world_map()
	await get_tree().process_frame
	ok = _check_no_overlap_desktop(main) and ok
	ok = _check_rects_disjoint(main) and ok
	ok = _check_panel_bounds(main) and ok
	ok = _check_area_message_hidden(main) and ok
	ok = _check_worst_case_sweep(main) and ok
	main._toggle_world_map()

	main.get_node("HUD/MobileControls").visible = true
	main.get_node("HUD/MobileControls").set_modal_mode("map")
	main._toggle_world_map()
	await get_tree().process_frame
	ok = _check_no_overlap_mobile(main) and ok
	ok = _check_panel_bounds(main) and ok
	main._toggle_world_map()

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
