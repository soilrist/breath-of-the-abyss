extends Node
## INBOX 지시(2026-09-06 04:35, HUD 창 13개 강화 창 기준 전수 점검) — Skills(스킬
## 목록) 창. check_perk_layout.gd/check_quest_layout.gd와 같은 패턴. Skills는
## 순수 읽기 전용(08:40 결함 audit 확인 - _tapped_list_row 미연결)이라 터치 선택
## 검사는 없다. Row0~5 여섯 칸을 잡히는 모든 직업×2차 전직 조합(및 무직)으로
## 스윕해 Title/Row Text가 안 잘리는지 확인한다.

## GameState.SECOND_JOB_BRANCHES 그대로: job -> 2차 전직 두 갈래.
const JOB_SECOND_JOB_COMBOS := [
	["", ""], ["warrior", ""], ["mage", ""], ["rogue", ""],
	["warrior", "guardian"], ["warrior", "berserker"],
	["mage", "elementalist"], ["mage", "necromancer"],
	["rogue", "assassin"], ["rogue", "shadow_dancer"],
]

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _check_no_overlap(main: Node) -> bool:
	var statbar: Control = main.get_node("HUD/StatBar")
	# Skills 창이 열려 있으면 StatBar는 숨겨진다(가이드와 같은 방식, main.gd
	# _sync_modal_hud_visibility) - 숨은 동안은 겹침을 안 따진다.
	if not statbar.visible:
		return true
	var statbar_rect: Rect2 = statbar.get_global_rect().grow(4)
	var ok := true
	var names := ["Title", "Help"]
	for index in 6:
		if main.get_node("HUD/Skills").has_node("Row%d" % index):
			names.append("Row%d" % index)
	for child_name in names:
		var node := main.get_node("HUD/Skills/%s" % child_name)
		if not node.visible:
			continue
		var rect: Rect2 = node.get_global_rect()
		ok = _check("(1) HUD/Skills/%s 가 StatBar와 안 겹침" % child_name,
			not rect.intersects(statbar_rect)) and ok
	return ok


func _check_rows_disjoint(main: Node) -> bool:
	var rects := {}
	var names := ["Title", "Help"]
	for index in 6:
		var row_name := "Row%d" % index
		if main.get_node("HUD/Skills").has_node(row_name) and main.get_node("HUD/Skills/%s" % row_name).visible:
			names.append(row_name)
	for n in names:
		rects[n] = main.get_node("HUD/Skills/%s" % n).get_global_rect()
	var ok := true
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: String = names[i]
			var b: String = names[j]
			ok = _check("(b) %s ∩ %s = 무교집합" % [a, b],
				not rects[a].intersects(rects[b])) and ok
	return ok


func _check_panel_bounds(main: Node) -> bool:
	var panel: Control = main.get_node("HUD/Skills")
	var panel_rect: Rect2 = panel.get_global_rect()
	var ok := true
	var names := ["Title", "Help"]
	for index in 6:
		var row_name := "Row%d" % index
		if panel.has_node(row_name) and panel.get_node(row_name).visible:
			names.append(row_name)
	for child_name in names:
		var rect: Rect2 = main.get_node("HUD/Skills/%s" % child_name).get_global_rect()
		ok = _check("(5) HUD/Skills/%s 가 패널 밖으로 안 삐져나옴" % child_name,
			panel_rect.encloses(rect)) and ok
	return ok


func _check_label_fits_all_lines(label: Label, tag: String) -> bool:
	var line_height := label.get_line_height() + label.get_theme_constant("line_spacing")
	var fits := label.get_line_count() * line_height <= label.size.y
	var visible_ok := label.get_visible_line_count() >= label.get_line_count()
	return _check("(a) %s %d줄 안착(칸 %d, 줄높이 %d)" %
		[tag, label.get_line_count(), int(label.size.y), line_height], fits) and \
		_check("(a) %s 마지막 줄까지 실제로 보임" % tag, visible_ok)


func _check_title_fits(main: Node) -> bool:
	var title: Label = main.get_node("HUD/Skills/Title")
	var font := title.get_theme_default_font()
	var font_size := title.get_theme_font_size("font_size")
	var w: float = font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return _check("(4) Skills Title 한 줄 안착(너비 %d, 칸 %d) [%s]" %
		[int(w), int(title.size.x), title.text], w <= title.size.x)


func _check_help_text_fits(main: Node) -> bool:
	var help: Label = main.get_node("HUD/Skills/Help")
	var font := help.get_theme_default_font()
	var font_size := help.get_theme_font_size("font_size")
	var w: float = font.get_string_size(help.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return _check("(4) Skills Help 문구 한 줄 안착(너비 %d, 칸 %d) [%s]" %
		[int(w), int(help.size.x), help.text], w <= help.size.x)


func _check_area_message_hidden(main: Node) -> bool:
	var ok := true
	ok = _check("(3) 스킬 창 열림 - HUD/Area 숨김", not main.get_node("HUD/Area").visible) and ok
	ok = _check("(3) 스킬 창 열림 - HUD/Message 숨김", not main.get_node("HUD/Message").visible) and ok
	ok = _check("(3) 스킬 창 열림 - HUD/SkillBar 숨김", not main.get_node("HUD/SkillBar").visible) and ok
	return ok


## 무직/1차 3개/2차 6개 조합 전부에서 레벨 99(전부 해금)로 Row0~5 Text가
## 안 잘리는지, 레벨 1(전부 미해금, "(레벨 N 필요)" 짧은 문구 경로)에서도
## 안 잘리는지 스윕한다.
func _check_rows_fit_all_combos(main: Node) -> bool:
	var ok := true
	for combo in JOB_SECOND_JOB_COMBOS:
		var job: String = combo[0]
		var second_job: String = combo[1]
		for level in [99, 1]:
			GameState.job = job
			GameState.second_job = second_job
			GameState.level = level
			main._refresh_skills()
			ok = _check_title_fits(main) and ok
			var total: int = GameState.active_skills().size()
			for index in total:
				var row := main.get_node("HUD/Skills/Row%d" % index)
				ok = _check_label_fits_all_lines(row.get_node("Text"),
					"job=%s second=%s lv=%d Row%d" % [job, second_job, level, index]) and ok
	return ok


## skills 모드는 mobile_controls.gd set_modal_mode()에서 Close와 Sell("탭",
## 캐릭터 창으로 돌아가는 탭 버튼 — 2026-09-08 "스킬탭도 없네")만 보인다
## (playing 전용 버튼, Interact 허용 목록 둘 다 "skills" 미포함) - 이 가정이
## 깨지면 겹침 검사가 없어 조용히 놓치므로 단언해 둔다.
func _check_no_mobile_buttons(main: Node) -> bool:
	var mc := main.get_node("HUD/MobileControls")
	var ok := true
	for child in mc.get_children():
		if child is Control and child.name != "Close" and child.name != "Sell":
			ok = _check("(c) MobileControls/%s 가 skills 모드에서 안 보임" % child.name,
				not child.visible) and ok
	for shown in ["Close", "Sell"]:
		ok = _check("(c) MobileControls/%s 는 skills 모드에서 보임" % shown,
			mc.get_node(shown).visible) and ok
	ok = _check("(c) MobileControls/Sell 이 Skills 창과 안 겹침",
		not mc.get_node("Sell").get_global_rect().intersects(main.get_node("HUD/Skills").get_global_rect())) and ok
	return ok


func _check_no_overlap_mobile_close(main: Node) -> bool:
	var mc := main.get_node("HUD/MobileControls")
	var close: Control = mc.get_node("Close")
	if not close.visible:
		return true
	var close_rect: Rect2 = close.get_global_rect().grow(4)
	var ok := true
	var names := ["Title", "Help"]
	for index in 6:
		var row_name := "Row%d" % index
		if main.get_node("HUD/Skills").has_node(row_name) and main.get_node("HUD/Skills/%s" % row_name).visible:
			names.append(row_name)
	for child_name in names:
		var rect: Rect2 = main.get_node("HUD/Skills/%s" % child_name).get_global_rect()
		ok = _check("(c) HUD/Skills/%s 가 MobileControls/Close 와 안 겹침" % child_name,
			not rect.intersects(close_rect)) and ok
	return ok


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	var ok := true

	main.get_node("HUD/MobileControls").visible = false
	main._toggle_skills()
	await get_tree().process_frame
	ok = _check_rows_fit_all_combos(main) and ok
	ok = _check_no_overlap(main) and ok
	ok = _check_rows_disjoint(main) and ok
	ok = _check_panel_bounds(main) and ok
	ok = _check_help_text_fits(main) and ok
	ok = _check_area_message_hidden(main) and ok
	main._toggle_skills()

	main.get_node("HUD/MobileControls").visible = true
	main._toggle_skills()
	await get_tree().process_frame
	ok = _check_no_mobile_buttons(main) and ok
	ok = _check_no_overlap_mobile_close(main) and ok
	main._toggle_skills()

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
