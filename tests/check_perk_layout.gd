extends Node
## INBOX 지시(2026-09-06, HUD 창 13개 강화 창 기준 전수 점검) — Perk(특성 선택) 창.
## check_storage_layout.gd과 같은 패턴. Perk는 Info/Help 둘뿐이고 모바일에서는
## Close를 포함해 대부분의 버튼이 안 뜬다(mobile_controls.gd: set_modal_mode("perk")
## 에서 Close.visible = mode != "perk"). 단, Interact("결정")는 예외 - 2026-09-06
## 08:40 INBOX 결함(폰에서 이 창이 막다른 길이었다) 수정으로 목록 탭 확정과
## 함께 폰에서 넘어갈 수 있는 유일한 길이라 일부러 보인다.

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _check_no_overlap(main: Node) -> bool:
	var statbar: Control = main.get_node("HUD/StatBar")
	var statbar_rect: Rect2 = statbar.get_global_rect()
	var ok := true
	for child_name in ["Info", "Help"]:
		var node := main.get_node("HUD/Perk/%s" % child_name)
		var rect: Rect2 = node.get_global_rect()
		ok = _check("(1) HUD/Perk/%s 가 StatBar와 4px 여백 없이 안 겹침" % child_name,
			not rect.grow(4).intersects(statbar_rect)) and ok
	return ok


func _check_rects_disjoint(main: Node) -> bool:
	var info_rect: Rect2 = main.get_node("HUD/Perk/Info").get_global_rect()
	var help_rect: Rect2 = main.get_node("HUD/Perk/Help").get_global_rect()
	return _check("(b) Info ∩ Help = 4px 여백 없이 무교집합", not info_rect.grow(4).intersects(help_rect))


func _check_panel_bounds(main: Node) -> bool:
	var panel: Control = main.get_node("HUD/Perk")
	var panel_rect: Rect2 = panel.get_global_rect()
	var ok := true
	for child_name in ["Info", "Help"]:
		var node := main.get_node("HUD/Perk/%s" % child_name)
		var rect: Rect2 = node.get_global_rect()
		ok = _check("(5) HUD/Perk/%s 가 패널 밖으로 안 삐져나옴" % child_name,
			panel_rect.encloses(rect)) and ok
	return ok


func _check_label_fits_all_lines(label: Label, tag: String) -> bool:
	var line_height := label.get_line_height() + label.get_theme_constant("line_spacing")
	var fits := label.get_line_count() * line_height <= label.size.y
	var visible_ok := label.get_visible_line_count() >= label.get_line_count()
	return _check("(a) %s %d줄 안착(칸 %d, 줄높이 %d)" %
		[tag, label.get_line_count(), int(label.size.y), line_height], fits) and \
		_check("(a) %s 마지막 줄까지 실제로 보임" % tag, visible_ok)


## 최악 데이터: roll_perk_offer는 항상 정확히 3개를 뽑는다(중복 없음) - 그중
## 이름이 가장 긴 "font"(마력 순환)와 설명이 가장 긴 "focus"(치명타 확률 +4%)를
## 넣고, 셋 다 보유 스택 표기("  (보유 N)")까지 붙게 만든다.
func _fill_worst_case(main: Node) -> void:
	GameState.perks.clear()
	for key in ["font", "focus", "guard"]:
		GameState.perks[key] = 9
	GameState.perk_offer = ["font", "focus", "guard"]
	GameState.perk_picks = 1
	main.perk_index = 0


func _check_help_text_fits(main: Node) -> bool:
	var help: Label = main.get_node("HUD/Perk/Help")
	var font := help.get_theme_default_font()
	var font_size := help.get_theme_font_size("font_size")
	var w: float = font.get_string_size(help.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return _check("(4) Perk Help 문구 한 줄 안착(너비 %d, 칸 %d)" %
		[int(w), int(help.size.x)], w <= help.size.x)


func _check_area_message_hidden(main: Node) -> bool:
	var ok := true
	ok = _check("(3) 특성 창 열림 - HUD/Area 숨김", not main.get_node("HUD/Area").visible) and ok
	ok = _check("(3) 특성 창 열림 - HUD/Message 숨김", not main.get_node("HUD/Message").visible) and ok
	ok = _check("(3) 특성 창 열림 - HUD/SkillBar 숨김", not main.get_node("HUD/SkillBar").visible) and ok
	return ok


## perk 모드는 Interact("결정")과 ▲▼(Up/Down) 말고는 모바일 버튼이 하나도 안 뜬다 - 이 가정이
## 깨지면(다른 버튼이 새로 생기면) 겹침 검사가 없어 조용히 놓치므로 단언해 둔다.
## Interact는 2026-09-06 08:40 결함 수정 전까지 이 목록에 없었다(그래서
## 막다른 길이었다) - 이제는 일부러 보여야 한다.
func _check_no_mobile_buttons(main: Node) -> bool:
	var mc := main.get_node("HUD/MobileControls")
	var ok := true
	for child in mc.get_children():
		if child is Control and child.name not in ["Interact", "Up", "Down"]:
			ok = _check("(c) MobileControls/%s 가 perk 모드에서 안 보임" % child.name,
				not child.visible) and ok
	ok = _check("(c) MobileControls/Interact 는 perk 모드에서 보임(결정 확정 경로)",
		mc.get_node("Interact").visible) and ok
	return ok


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	_fill_worst_case(main)
	main._open_perk_choice()
	await get_tree().process_frame

	var ok := true
	ok = _check_no_overlap(main) and ok
	ok = _check_rects_disjoint(main) and ok
	ok = _check_panel_bounds(main) and ok
	ok = _check_label_fits_all_lines(main.get_node("HUD/Perk/Info"), "특성 Info") and ok
	ok = _check_label_fits_all_lines(main.get_node("HUD/Perk/Help"), "특성 Help") and ok
	ok = _check_help_text_fits(main) and ok
	ok = _check_area_message_hidden(main) and ok

	main.get_node("HUD/MobileControls").visible = true
	main.get_node("HUD/MobileControls").set_modal_mode("perk")
	await get_tree().process_frame
	ok = _check_no_mobile_buttons(main) and ok

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
