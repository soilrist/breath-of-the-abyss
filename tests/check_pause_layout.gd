extends Node
## INBOX 지시(2026-09-06, HUD 창 13개 강화 창 기준 전수 점검) — Pause(일시정지) 창.
## check_shop_layout.gd과 같은 패턴. Pause는 자식이 Info 하나뿐이라 겹침
## 대상은 StatBar/MobileControls 버튼들뿐이지만, 데스크톱 텍스트(9줄, 단축키
## 안내 전부)와 모바일 텍스트(4줄, 상태 요약) 둘 다 최악값으로 잘림을 검사한다.

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _check_no_overlap_desktop(main: Node) -> bool:
	var statbar: Control = main.get_node("HUD/StatBar")
	var statbar_rect: Rect2 = statbar.get_global_rect()
	var info: Control = main.get_node("HUD/Pause/Info")
	var info_rect: Rect2 = info.get_global_rect()
	return _check("(1) HUD/Pause/Info 가 StatBar와 4px 여백 없이 안 겹침(데스크톱)",
		not info_rect.grow(4).intersects(statbar_rect))


func _check_no_overlap_mobile(main: Node) -> bool:
	var mc := main.get_node("HUD/MobileControls")
	var info: Control = main.get_node("HUD/Pause/Info")
	var info_rect: Rect2 = info.get_global_rect()
	var ok := true
	var statbar_rect: Rect2 = main.get_node("HUD/StatBar").get_global_rect()
	ok = _check("(1) HUD/Pause/Info 가 StatBar와 4px 여백 없이 안 겹침(모바일)",
		not info_rect.grow(4).intersects(statbar_rect)) and ok
	for btn_name in ["Save", "Title", "ToggleControls", "MusicMute", "SfxMute", "Quit"]:
		var btn: Control = mc.get_node(btn_name)
		if not btn.visible:
			continue
		var btn_rect: Rect2 = btn.get_global_rect()
		ok = _check("(1) HUD/Pause/Info 가 MobileControls/%s 와 4px 여백 없이 안 겹침" % btn_name,
			not info_rect.grow(4).intersects(btn_rect)) and ok
	return ok


func _check_label_fits_all_lines(label: Label, tag: String) -> bool:
	var line_height := label.get_line_height() + label.get_theme_constant("line_spacing")
	var fits := label.get_line_count() * line_height <= label.size.y
	var visible_ok := label.get_visible_line_count() >= label.get_line_count()
	return _check("(a) %s %d줄 안착(칸 %d, 줄높이 %d)" %
		[tag, label.get_line_count(), int(label.size.y), line_height], fits) and \
		_check("(a) %s 마지막 줄까지 실제로 보임" % tag, visible_ok)


func _check_panel_bounds(main: Node) -> bool:
	var panel: Control = main.get_node("HUD/Pause")
	var info: Control = main.get_node("HUD/Pause/Info")
	var panel_rect: Rect2 = panel.get_global_rect()
	var info_rect: Rect2 = info.get_global_rect()
	return _check("(5) HUD/Pause/Info 가 패널 밖으로 안 삐져나옴",
		panel_rect.encloses(info_rect))


func _check_area_message_hidden(main: Node) -> bool:
	var ok := true
	ok = _check("(3) 일시정지 창 열림 - HUD/Area 숨김", not main.get_node("HUD/Area").visible) and ok
	ok = _check("(3) 일시정지 창 열림 - HUD/Message 숨김", not main.get_node("HUD/Message").visible) and ok
	ok = _check("(3) 일시정지 창 열림 - HUD/SkillBar 숨김", not main.get_node("HUD/SkillBar").visible) and ok
	return ok


## 결함(감독, 2026-09-06 07:20): 일시정지 모바일 버튼(Save/Title/ToggleControls/
## MusicMute/SfxMute/Quit)이 HUD/Pause 자식이 아니라 HUD/MobileControls 아래에
## 있어 앞의 두 함수(Info만 검사)로는 못 잡았다 - Quit가 패널 바닥(212)보다
## 아래(207~231)까지 내려가 StatBar(198~238)와 겹쳤다. 보이는 버튼마다 StatBar
## 와 무교집합 + Pause 패널 안에 포함되는지 직접 검사한다.
func _check_mobile_buttons_vs_statbar_and_panel(main: Node) -> bool:
	var mc := main.get_node("HUD/MobileControls")
	var panel: Control = main.get_node("HUD/Pause")
	var panel_rect: Rect2 = panel.get_global_rect()
	var statbar_rect: Rect2 = main.get_node("HUD/StatBar").get_global_rect()
	var ok := true
	for btn_name in ["Save", "Title", "ToggleControls", "MusicMute", "SfxMute", "Quit"]:
		var btn: Control = mc.get_node(btn_name)
		if not btn.visible:
			continue
		var btn_rect: Rect2 = btn.get_global_rect()
		ok = _check("(6) MobileControls/%s 가 StatBar와 4px 여백 없이 안 겹침" % btn_name,
			not btn_rect.grow(4).intersects(statbar_rect)) and ok
		ok = _check("(6) MobileControls/%s 가 Pause 패널 안에 있음" % btn_name,
			panel_rect.encloses(btn_rect)) and ok
	return ok


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	var info: Label = main.get_node("HUD/Pause/Info")
	var ok := true

	# 데스크톱: 단축키 안내 9줄 전부(가장 긴 케이스)
	main.get_node("HUD/MobileControls").visible = false
	main.set_pause_open(true)
	await get_tree().process_frame
	ok = _check_no_overlap_desktop(main) and ok
	ok = _check_label_fits_all_lines(info, "일시정지 Info(데스크톱)") and ok
	ok = _check_panel_bounds(main) and ok
	ok = _check_area_message_hidden(main) and ok
	main.set_pause_open(false)

	# 모바일: 상태 요약 4줄(버튼과 겹침 여부가 핵심)
	main.get_node("HUD/MobileControls").visible = true
	main.set_pause_open(true)
	await get_tree().process_frame
	ok = _check_no_overlap_mobile(main) and ok
	ok = _check_label_fits_all_lines(info, "일시정지 Info(모바일)") and ok
	ok = _check_panel_bounds(main) and ok
	ok = _check_area_message_hidden(main) and ok
	ok = _check_mobile_buttons_vs_statbar_and_panel(main) and ok
	main.set_pause_open(false)

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
