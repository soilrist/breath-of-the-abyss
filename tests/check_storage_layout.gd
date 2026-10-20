extends Node
## INBOX 지시(2026-09-06, HUD 창 13개 강화 창 기준 전수 점검) — Storage(창고) 창.
## check_shop_layout.gd/check_pause_layout.gd과 같은 패턴. 창고도 Shop/Forge와
## 같은 결함이 있었다: _move_storage()의 실패 메시지가 HUD/Message(패널 열림
## 중 _sync_modal_hud_visibility()가 숨김)로 갔다 - HUD/Storage/Notice를 새로
## 둬 고쳤다.

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _check_no_overlap(main: Node) -> bool:
	var statbar: Control = main.get_node("HUD/StatBar")
	var statbar_rect: Rect2 = statbar.get_global_rect()
	var ok := true
	for child_name in ["Info", "Notice", "Help"]:
		var node := main.get_node("HUD/Storage/%s" % child_name)
		var rect: Rect2 = node.get_global_rect()
		ok = _check("(1) HUD/Storage/%s 가 StatBar와 4px 여백 없이 안 겹침" % child_name,
			not rect.grow(4).intersects(statbar_rect)) and ok
	return ok


func _check_rects_disjoint(main: Node) -> bool:
	var names := ["Info", "Notice", "Help"]
	var rects := {}
	for n in names:
		rects[n] = main.get_node("HUD/Storage/%s" % n).get_global_rect()
	var keys: Array = rects.keys()
	var ok := true
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: String = keys[i]
			var b: String = keys[j]
			ok = _check("(b) %s ∩ %s = 4px 여백 없이 무교집합" % [a, b],
				not rects[a].grow(4).intersects(rects[b])) and ok
	return ok


func _check_panel_bounds(main: Node) -> bool:
	var panel: Control = main.get_node("HUD/Storage")
	var panel_rect: Rect2 = panel.get_global_rect()
	var ok := true
	for child_name in ["Info", "Notice", "Help"]:
		var node := main.get_node("HUD/Storage/%s" % child_name)
		var rect: Rect2 = node.get_global_rect()
		ok = _check("(5) HUD/Storage/%s 가 패널 밖으로 안 삐져나옴" % child_name,
			panel_rect.encloses(rect)) and ok
	return ok


func _check_label_fits_all_lines(label: Label, tag: String) -> bool:
	var line_height := label.get_line_height() + label.get_theme_constant("line_spacing")
	var fits := label.get_line_count() * line_height <= label.size.y
	var visible_ok := label.get_visible_line_count() >= label.get_line_count()
	return _check("(a) %s %d줄 안착(칸 %d, 줄높이 %d)" %
		[tag, label.get_line_count(), int(label.size.y), line_height], fits) and \
		_check("(a) %s 마지막 줄까지 실제로 보임" % tag, visible_ok)


## 최악 데이터: 가방·창고 둘 다 EQUIPMENT 중 가장 긴 이름으로 WINDOW(6)칸을
## 채우고, 가방 쪽은 그중 하나를 착용해 " [착용]" 접미사까지 붙인다.
func _fill_worst_case(main: Node) -> void:
	var longest := ""
	for item_name in GameState.EQUIPMENT:
		if item_name.length() > longest.length():
			longest = item_name

	GameState.inventory.clear()
	GameState.storage.clear()
	GameState.level = 99
	for i in 8:
		GameState.add_item(longest)
	GameState.equip(longest)
	GameState.enhance_levels[GameState.item_uid[0]] = 10
	for i in 8:
		GameState.storage.append(longest)
	GameState.sync_uids()


func _check_info_help_fit(main: Node) -> bool:
	var info: Label = main.get_node("HUD/Storage/Info")
	var help: Label = main.get_node("HUD/Storage/Help")
	var ok := true
	for side in ["bag", "box"]:
		main.storage_side = side
		main.storage_index = 0
		main._refresh_storage()
		ok = _check_label_fits_all_lines(info, "창고 Info[%s]" % side) and ok
		ok = _check_label_fits_all_lines(help, "창고 Help[%s]" % side) and ok
	return ok


## 감독 보정(2026-09-06 07:55): 목록이 WINDOW(6)칸을 넘으면 마지막 줄에
## "… N개 더"가 붙어야 한다 - 8개를 넣어 6칸만 보이던 걸 놓치지 않게 한다.
func _check_more_suffix(main: Node) -> bool:
	var info: Label = main.get_node("HUD/Storage/Info")
	var ok := true
	for side in ["bag", "box"]:
		main.storage_side = side
		main.storage_index = 0
		main._refresh_storage()
		ok = _check("(5) 창고 Info[%s] 넘침 표기 '개 더' 포함" % side,
			info.text.contains("개 더")) and ok
	return ok


## Close만 확인 - Storage 모드에서 모바일에 보이는 버튼은 Close뿐이다
## (mobile_controls.gd set_modal_mode: storage는 playing/dialogue/inventory/
## forge/character가 아니라 Interact도 안 뜬다).
func _check_no_overlap_mobile(main: Node) -> bool:
	var mc := main.get_node("HUD/MobileControls")
	var ok := true
	var close: Control = mc.get_node("Close")
	if close.visible:
		var close_rect: Rect2 = close.get_global_rect()
		for child_name in ["Info", "Notice", "Help"]:
			var node := main.get_node("HUD/Storage/%s" % child_name)
			var rect: Rect2 = node.get_global_rect()
			ok = _check("(c) HUD/Storage/%s 가 MobileControls/Close 와 4px 여백 없이 안 겹침" % child_name,
				not rect.grow(4).intersects(close_rect)) and ok
	return ok


## 창고가 가득 찬 상태에서 넣기를 시도해 실패 메시지가 Storage/Notice로
## 가는지, HUD/Message(모달 중 숨김)로 새지 않는지 확인한다.
func _check_notice_message(main: Node) -> bool:
	main.storage_side = "bag"
	main.storage_index = 0
	GameState.storage.clear()
	for i in GameState.STORAGE_MAX:
		GameState.storage.append("가죽 갑옷")
	GameState.sync_uids()
	main._refresh_storage()
	main.get_node("HUD/Message").text = ""
	main.get_node("HUD/Storage/Notice").text = ""
	main._move_storage()
	var notice: String = main.get_node("HUD/Storage/Notice").text
	var message: String = main.get_node("HUD/Message").text
	var ok := true
	ok = _check("(2) 창고 가득 참 - Storage/Notice에 실패 메시지가 쓰임", notice != "") and ok
	ok = _check("(2) 창고 가득 참 - HUD/Message는 비어 있음", message == "") and ok
	return ok


func _check_notice_fits(main: Node) -> bool:
	var notice: Label = main.get_node("HUD/Storage/Notice")
	var font := notice.get_theme_default_font()
	var font_size := notice.get_theme_font_size("font_size")
	var box_width: float = notice.size.x
	var text := "착용 중이거나 창고가 가득 찼다."
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return _check("(4) Notice 문구 한 줄 안착 '%s'(너비 %d, 칸 %d)" % [text, int(w), int(box_width)],
		w <= box_width)


func _check_area_message_hidden(main: Node) -> bool:
	var ok := true
	ok = _check("(3) 창고 창 열림 - HUD/Area 숨김", not main.get_node("HUD/Area").visible) and ok
	ok = _check("(3) 창고 창 열림 - HUD/Message 숨김", not main.get_node("HUD/Message").visible) and ok
	ok = _check("(3) 창고 창 열림 - HUD/SkillBar 숨김", not main.get_node("HUD/SkillBar").visible) and ok
	return ok


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	_fill_worst_case(main)
	main._toggle_storage()
	await get_tree().process_frame

	var ok := true
	ok = _check_no_overlap(main) and ok
	ok = _check_rects_disjoint(main) and ok
	ok = _check_panel_bounds(main) and ok
	ok = _check_info_help_fit(main) and ok
	ok = _check_more_suffix(main) and ok
	ok = _check_area_message_hidden(main) and ok
	ok = _check_notice_fits(main) and ok
	ok = _check_notice_message(main) and ok

	main.get_node("HUD/MobileControls").visible = true
	main.get_node("HUD/MobileControls").set_modal_mode("storage")
	await get_tree().process_frame
	ok = _check_no_overlap_mobile(main) and ok

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
