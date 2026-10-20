extends Node
## INBOX 지시(2026-09-06 04:35, HUD 창 13개 강화 창 기준 전수 점검) — Quest(퀘스트
## 현황) 창. check_pause_layout.gd/check_storage_layout.gd와 같은 패턴. Quest는
## 자식이 Info/Help 둘뿐이지만 Info 텍스트가 [이야기](_quest_stage_text())와
## [의뢰](bounty) 두 구역을 이어붙이므로, 둘 다 가장 긴 값으로 조합해 잘림을
## 검사한다.

## check_quest_stage_text_coverage.gd의 USED_STAGES와 같은 목록(실제
## GameState.quest_stage = N 으로 대입되는 값들 - 같은 파일에서 const를 그대로
## 재사용할 수 없어 그대로 복사, 한쪽을 늘리면 다른 쪽도 같이 늘려야 한다).
const USED_STAGES: Array[int] = [
	1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 19, 20, 21, 29, 30, 31,
	39, 40, 41, 49, 50, 51, 59, 60, 61,
]

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _check_no_overlap_desktop(main: Node) -> bool:
	var statbar: Control = main.get_node("HUD/StatBar")
	var statbar_rect: Rect2 = statbar.get_global_rect().grow(4)
	var ok := true
	for child_name in ["Info", "Help"]:
		var node := main.get_node("HUD/Quest/%s" % child_name)
		var rect: Rect2 = node.get_global_rect()
		ok = _check("(1) HUD/Quest/%s 가 StatBar와 안 겹침(데스크톱)" % child_name,
			not rect.intersects(statbar_rect)) and ok
	return ok


func _check_no_overlap_mobile(main: Node) -> bool:
	var mc := main.get_node("HUD/MobileControls")
	var statbar_rect: Rect2 = main.get_node("HUD/StatBar").get_global_rect().grow(4)
	var ok := true
	for child_name in ["Info", "Help"]:
		var node := main.get_node("HUD/Quest/%s" % child_name)
		var rect: Rect2 = node.get_global_rect()
		ok = _check("(1) HUD/Quest/%s 가 StatBar와 안 겹침(모바일)" % child_name,
			not rect.intersects(statbar_rect)) and ok
	# 모바일에서 Quest 모드일 때 실제로 보이는 버튼은 Close뿐이다
	# (mobile_controls.gd set_modal_mode: quest는 playing/dialogue/inventory/
	# forge/character/perk/tower_select 어느 것도 아니라 Interact도 안 뜬다).
	var close: Control = mc.get_node("Close")
	if close.visible:
		var close_rect: Rect2 = close.get_global_rect().grow(4)
		for child_name in ["Info", "Help"]:
			var node := main.get_node("HUD/Quest/%s" % child_name)
			var rect: Rect2 = node.get_global_rect()
			ok = _check("(c) HUD/Quest/%s 가 MobileControls/Close 와 안 겹침" % child_name,
				not rect.intersects(close_rect)) and ok
	return ok


func _check_label_fits_all_lines(label: Label, tag: String) -> bool:
	var line_height := label.get_line_height() + label.get_theme_constant("line_spacing")
	var fits := label.get_line_count() * line_height <= label.size.y
	var visible_ok := label.get_visible_line_count() >= label.get_line_count()
	return _check("(a) %s %d줄 안착(칸 %d, 줄높이 %d)" %
		[tag, label.get_line_count(), int(label.size.y), line_height], fits) and \
		_check("(a) %s 마지막 줄까지 실제로 보임" % tag, visible_ok)


func _check_panel_bounds(main: Node) -> bool:
	var panel: Control = main.get_node("HUD/Quest")
	var panel_rect: Rect2 = panel.get_global_rect()
	var ok := true
	for child_name in ["Info", "Help"]:
		var node := main.get_node("HUD/Quest/%s" % child_name)
		var rect: Rect2 = node.get_global_rect()
		ok = _check("(5) HUD/Quest/%s 가 패널 밖으로 안 삐져나옴" % child_name,
			panel_rect.encloses(rect)) and ok
	return ok


func _check_area_message_hidden(main: Node) -> bool:
	var ok := true
	ok = _check("(3) 퀘스트 창 열림 - HUD/Area 숨김", not main.get_node("HUD/Area").visible) and ok
	ok = _check("(3) 퀘스트 창 열림 - HUD/Message 숨김", not main.get_node("HUD/Message").visible) and ok
	ok = _check("(3) 퀘스트 창 열림 - HUD/SkillBar 숨김", not main.get_node("HUD/SkillBar").visible) and ok
	return ok


## [이야기] 문구(모든 단계) x [의뢰] 문구(전 의뢰, 수락 전/진행 중)를 조합해
## 가장 긴 조합에서도 Info가 안 잘리는지 스윕한다.
func _check_info_fits_all_combos(main: Node) -> bool:
	var info: Label = main.get_node("HUD/Quest/Info")
	var ok := true

	GameState.kills = 0
	GameState.chapter_kills = 0
	for stage in USED_STAGES:
		GameState.quest_stage = stage
		for bounty_index in GameState.BOUNTIES.size():
			GameState.bounty_index = bounty_index
			GameState.bounty_taken = false
			main._refresh_quest()
			ok = _check_label_fits_all_lines(info,
				"stage%d 수락전 의뢰%d" % [stage, bounty_index]) and ok
			GameState.bounty_taken = true
			GameState.bounty_progress = 0
			main._refresh_quest()
			ok = _check_label_fits_all_lines(info,
				"stage%d 진행중 의뢰%d" % [stage, bounty_index]) and ok
	return ok


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	var ok := true

	main.get_node("HUD/MobileControls").visible = false
	main._toggle_quest()
	await get_tree().process_frame
	ok = _check_no_overlap_desktop(main) and ok
	ok = _check_panel_bounds(main) and ok
	ok = _check_area_message_hidden(main) and ok
	ok = _check_info_fits_all_combos(main) and ok
	main._toggle_quest()

	main.get_node("HUD/MobileControls").visible = true
	main._toggle_quest()
	await get_tree().process_frame
	ok = _check_no_overlap_mobile(main) and ok
	ok = _check_panel_bounds(main) and ok
	ok = _check_area_message_hidden(main) and ok
	main._toggle_quest()

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
