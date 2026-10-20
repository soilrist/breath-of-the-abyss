extends Node
## INBOX 지시(2026-09-06 04:35, HUD 창 13개 강화 창 기준 전수 점검) — TowerSelect(탑
## 난이도 선택) 창. check_perk_layout.gd/check_quest_layout.gd와 같은 패턴.
## TowerSelect도 Info/Help 둘뿐이고, 모바일에서는 Close와 Interact("입장") 둘 다
## 보인다(mobile_controls.gd: Close.visible = mode != "" and mode != "perk",
## Interact.visible에 "tower_select" 포함).
##
## 최악 데이터: TOWER_TIERS 5개(쉬움/보통/어려움/헬/심연) 전부 "해금됨" 조합에서
## 가장 긴 상태문구("[99/100층]")가 나오도록 앞 단계는 클리어(100), 마지막
## 선택 칸만 99로 채운다. 잠김 Help 문구는 요구 탑 이름이 가장 긴 "어려움"이
## 나오도록 hard를 잠근 채 hell을 선택한다.

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _check_no_overlap_desktop(main: Node) -> bool:
	var statbar: Control = main.get_node("HUD/StatBar")
	var statbar_rect: Rect2 = statbar.get_global_rect().grow(4)
	var ok := true
	for child_name in ["Info", "Help"]:
		var node := main.get_node("HUD/TowerSelect/%s" % child_name)
		var rect: Rect2 = node.get_global_rect()
		ok = _check("(1) HUD/TowerSelect/%s 가 StatBar와 4px 여백 없이 안 겹침(데스크톱)" % child_name,
			not rect.intersects(statbar_rect)) and ok
	return ok


func _check_no_overlap_mobile(main: Node) -> bool:
	var mc := main.get_node("HUD/MobileControls")
	var statbar_rect: Rect2 = main.get_node("HUD/StatBar").get_global_rect().grow(4)
	var ok := true
	for btn_name in ["Close", "Interact"]:
		var btn: Control = mc.get_node(btn_name)
		if not btn.visible:
			continue
		var btn_rect: Rect2 = btn.get_global_rect().grow(4)
		for child_name in ["Info", "Help"]:
			var node := main.get_node("HUD/TowerSelect/%s" % child_name)
			var rect: Rect2 = node.get_global_rect()
			ok = _check("(c) HUD/TowerSelect/%s 가 MobileControls/%s 와 4px 여백 없이 안 겹침" %
				[child_name, btn_name], not rect.intersects(btn_rect)) and ok
	for child_name in ["Info", "Help"]:
		var node := main.get_node("HUD/TowerSelect/%s" % child_name)
		var rect: Rect2 = node.get_global_rect()
		ok = _check("(1) HUD/TowerSelect/%s 가 StatBar와 4px 여백 없이 안 겹침(모바일)" % child_name,
			not rect.intersects(statbar_rect)) and ok
	return ok


func _check_rects_disjoint(main: Node) -> bool:
	var info_rect: Rect2 = main.get_node("HUD/TowerSelect/Info").get_global_rect()
	var help_rect: Rect2 = main.get_node("HUD/TowerSelect/Help").get_global_rect()
	return _check("(b) Info ∩ Help = 4px 여백 없이 무교집합", not info_rect.grow(4).intersects(help_rect))


func _check_panel_bounds(main: Node) -> bool:
	var panel: Control = main.get_node("HUD/TowerSelect")
	var panel_rect: Rect2 = panel.get_global_rect()
	var ok := true
	for child_name in ["Info", "Help"]:
		var node := main.get_node("HUD/TowerSelect/%s" % child_name)
		var rect: Rect2 = node.get_global_rect()
		ok = _check("(5) HUD/TowerSelect/%s 가 패널 밖으로 안 삐져나옴" % child_name,
			panel_rect.encloses(rect)) and ok
	return ok


func _check_label_fits_all_lines(label: Label, tag: String) -> bool:
	var line_height := label.get_line_height() + label.get_theme_constant("line_spacing")
	var fits := label.get_line_count() * line_height <= label.size.y
	var visible_ok := label.get_visible_line_count() >= label.get_line_count()
	return _check("(a) %s %d줄 안착(칸 %d, 줄높이 %d)" %
		[tag, label.get_line_count(), int(label.size.y), line_height], fits) and \
		_check("(a) %s 마지막 줄까지 실제로 보임" % tag, visible_ok)


func _check_help_text_fits(main: Node, tag: String) -> bool:
	var help: Label = main.get_node("HUD/TowerSelect/Help")
	var font := help.get_theme_default_font()
	var font_size := help.get_theme_font_size("font_size")
	var w: float = font.get_string_size(help.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return _check("(4) TowerSelect Help(%s) 문구 한 줄 안착(너비 %d, 칸 %d)" %
		[tag, int(w), int(help.size.x)], w <= help.size.x)


func _check_area_message_hidden(main: Node) -> bool:
	var ok := true
	ok = _check("(3) 탑 선택 창 열림 - HUD/Area 숨김", not main.get_node("HUD/Area").visible) and ok
	ok = _check("(3) 탑 선택 창 열림 - HUD/Message 숨김", not main.get_node("HUD/Message").visible) and ok
	ok = _check("(3) 탑 선택 창 열림 - HUD/SkillBar 숨김", not main.get_node("HUD/SkillBar").visible) and ok
	return ok


## tower_select 모드는 Close·Interact("입장") 둘만 보인다 - 이 가정이 깨지면
## (다른 버튼이 새로 생기면) 겹침 검사가 없어 조용히 놓치므로 단언해 둔다.
func _check_mobile_buttons_visibility(main: Node) -> bool:
	var mc := main.get_node("HUD/MobileControls")
	var ok := true
	for child in mc.get_children():
		if child is Control and child.name not in ["Close", "Interact", "Up", "Down"]:
			ok = _check("(c) MobileControls/%s 가 tower_select 모드에서 안 보임" % child.name,
				not child.visible) and ok
	ok = _check("(c) MobileControls/Close 는 tower_select 모드에서 보임",
		mc.get_node("Close").visible) and ok
	ok = _check("(c) MobileControls/Interact 는 tower_select 모드에서 보임(입장 경로)",
		mc.get_node("Interact").visible) and ok
	return ok


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	var ok := true

	# 최악 데이터 A: 전부 해금(앞 단계 클리어), 마지막 칸만 "[99/100층]".
	GameState.game_cleared = true
	GameState.tower_progress = {"easy": 100, "normal": 100, "hard": 100, "hell": 100, "abyss": 99}
	main.tower_select_index = 4
	main.get_node("HUD/MobileControls").visible = false
	main._toggle_tower_select()
	await get_tree().process_frame
	ok = _check_no_overlap_desktop(main) and ok
	ok = _check_rects_disjoint(main) and ok
	ok = _check_panel_bounds(main) and ok
	ok = _check_label_fits_all_lines(main.get_node("HUD/TowerSelect/Info"), "탑선택 Info(해금)") and ok
	ok = _check_help_text_fits(main, "해금") and ok
	ok = _check_area_message_hidden(main) and ok
	main._toggle_tower_select()

	# 최악 데이터 B: hard 잠김 상태에서 hell 선택 - 요구 탑 이름이 가장 긴
	# "어려움"이 Help에 붙는다.
	GameState.tower_progress = {"easy": 100, "normal": 100, "hard": 0, "hell": 0, "abyss": 0}
	main.tower_select_index = 3
	main._toggle_tower_select()
	await get_tree().process_frame
	ok = _check_label_fits_all_lines(main.get_node("HUD/TowerSelect/Info"), "탑선택 Info(잠김)") and ok
	ok = _check_help_text_fits(main, "잠김") and ok
	main._toggle_tower_select()

	main.get_node("HUD/MobileControls").visible = true
	main.get_node("HUD/MobileControls").set_modal_mode("tower_select")
	main._toggle_tower_select()
	await get_tree().process_frame
	ok = _check_no_overlap_mobile(main) and ok
	ok = _check_panel_bounds(main) and ok
	ok = _check_mobile_buttons_visibility(main) and ok
	main._toggle_tower_select()

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
