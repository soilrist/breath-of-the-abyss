extends Node
## INBOX 결함(2026-09-05, 강화 창 캡처 겹침 3건) 검증.
## (1) Forge 자식 라벨 rect가 StatBar rect와 겹치지 않는다.
## (2) 강화 성공 메시지가 HUD/Forge/Notice에 쓰이고 HUD/Message는 비어 있다.
## (3) 모바일 확인 버튼 라벨이 탭별로 "강화"/"제작"이고 소켓 탭에선 숨는다.

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


## 감독 보정(2026-09-06 09:10): 1px 차이로 통과하는 "붙어 있음"은 육안으로는
## 겹침이다. rect를 4px 부풀려 교집합을 검사해 여백 없는 인접도 잡는다.
func _check_no_overlap(main: Node) -> bool:
	var statbar: Control = main.get_node("HUD/StatBar")
	var statbar_rect: Rect2 = statbar.get_global_rect()
	var ok := true
	for child_name in ["Info", "Detail", "Help", "Notice", "Icon"]:
		var node := main.get_node("HUD/Forge/%s" % child_name)
		var rect: Rect2 = node.get_global_rect()
		var overlap := rect.grow(4).intersects(statbar_rect)
		ok = _check("(1) HUD/Forge/%s 가 StatBar와 4px 여백 없이 안 겹침" % child_name, not overlap) and ok
	return ok


## 다섯 rect(Detail/Help/Notice/Info/StatBar)가 서로 4px 여백 없이 교집합이 없는지 전수 확인.
func _check_five_rects_disjoint(main: Node) -> bool:
	var names := ["Detail", "Help", "Notice", "Info"]
	var rects := {}
	for n in names:
		rects[n] = main.get_node("HUD/Forge/%s" % n).get_global_rect()
	rects["StatBar"] = main.get_node("HUD/StatBar").get_global_rect()
	var keys: Array = rects.keys()
	var ok := true
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: String = keys[i]
			var b: String = keys[j]
			ok = _check("(b) %s ∩ %s = 4px 여백 없이 무교집합" % [a, b],
				not rects[a].grow(4).intersects(rects[b])) and ok
	return ok


## 모바일 버튼(Interact/Sell/Close)이 보이는 상태에서 Detail/Info 오른쪽 끝이
## 버튼 왼쪽 가장자리보다 4px 이상 안쪽에 있는지 확인.
func _check_no_overlap_mobile_buttons(main: Node) -> bool:
	var mc := main.get_node("HUD/MobileControls")
	var ok := true
	for btn_name in ["Interact", "Sell", "Close"]:
		var btn: Control = mc.get_node(btn_name)
		if not btn.visible:
			continue
		var btn_rect: Rect2 = btn.get_global_rect()
		for child_name in ["Info", "Detail"]:
			var node := main.get_node("HUD/Forge/%s" % child_name)
			var rect: Rect2 = node.get_global_rect()
			ok = _check("(1) HUD/Forge/%s 가 MobileControls/%s 와 4px 여백 없이 안 겹침" %
				[child_name, btn_name], not rect.grow(4).intersects(btn_rect)) and ok
	return ok


## Detail 라벨이 마지막 줄(비용 줄)까지 실제로 보이는지 - get_visible_line_count()가
## get_line_count()보다 작으면 clip_text 때문에 아래쪽이 잘려 안 보인다는 뜻이다.
func _check_detail_fits_all_lines(detail: Label, tag: String) -> bool:
	var line_height := detail.get_line_height() + detail.get_theme_constant("line_spacing")
	var fits := detail.get_line_count() * line_height <= detail.size.y
	var visible_ok := detail.get_visible_line_count() >= detail.get_line_count()
	return _check("(a) %s Detail %d줄 안착(칸 %d, 줄높이 %d)" %
		[tag, detail.get_line_count(), int(detail.size.y), line_height], fits) and \
		_check("(a) %s Detail 마지막 줄까지 실제로 보임" % tag, visible_ok)


## GameState.EQUIPMENT 61개 전부를 강화 탭에 올려 가장 긴 것(정령의 부적/용린 갑주 등)도
## 잘리지 않는지 확인. 제작 탭도 레시피 전부 같은 방식으로 확인.
func _check_detail_no_overlap_and_fits(main: Node) -> bool:
	GameState.materials[GameState.MATERIAL] = 999
	GameState.gold = 999999
	var detail: Label = main.get_node("HUD/Forge/Detail")
	var ok := true

	var equipment_names: Array = GameState.EQUIPMENT.keys()
	var typed_inventory: Array[String] = []
	typed_inventory.assign(equipment_names)
	GameState.inventory = typed_inventory
	main.forge_mode = "enhance"
	for i in equipment_names.size():
		main.forge_index = i
		main._refresh_forge()
		ok = _check_detail_fits_all_lines(detail, "강화[%s]" % equipment_names[i]) and ok

	var recipes: Array = main._craft_recipe_list()
	main.forge_mode = "craft"
	for i in recipes.size():
		main.craft_index = i
		main._refresh_forge()
		ok = _check_detail_fits_all_lines(detail, "제작[%s]" % recipes[i]) and ok

	GameState.inventory = ["철검"]
	main.forge_mode = "enhance"
	main.forge_index = 0
	main._refresh_forge()
	ok = _check_five_rects_disjoint(main) and ok
	return ok


## 감독 보정(2026-09-06 07:55): 목록이 FORGE_WINDOW(5)칸을 넘으면 Info
## 마지막 줄에 "… N개 더"가 붙고, 그 줄까지 잘리지 않아야 한다.
func _check_info_fits_and_more(main: Node) -> bool:
	GameState.materials[GameState.MATERIAL] = 999
	GameState.gold = 999999
	var info: Label = main.get_node("HUD/Forge/Info")
	var ok := true

	var equipment_names: Array = GameState.EQUIPMENT.keys()
	var typed_inventory: Array[String] = []
	typed_inventory.assign(equipment_names)
	GameState.inventory = typed_inventory
	main.forge_mode = "enhance"
	main.forge_index = 0
	main._refresh_forge()
	ok = _check_detail_fits_all_lines(info, "강화 Info(넘침)") and ok
	ok = _check("(5) 강화 Info 넘침 표기 '개 더' 포함(장비 %d개)" %
		equipment_names.size(), info.text.contains("개 더")) and ok

	main.forge_mode = "craft"
	main.craft_index = 0
	main._refresh_forge()
	var recipes: Array = main._craft_recipe_list()
	ok = _check_detail_fits_all_lines(info, "제작 Info(넘침)") and ok
	ok = _check("(5) 제작 Info 넘침 표기 '개 더' 포함(레시피 %d개)" %
		recipes.size(), info.text.contains("개 더")) and ok
	return ok


func _check_notice_message(main: Node) -> bool:
	GameState.materials[GameState.MATERIAL] = 999
	GameState.gold = 999999
	GameState.inventory = ["철검"]
	main.forge_mode = "enhance"
	main.forge_index = 0
	main._refresh_forge()
	main.get_node("HUD/Message").text = ""
	main.get_node("HUD/Forge/Notice").text = ""
	main._do_enhance()
	var notice: String = main.get_node("HUD/Forge/Notice").text
	var message: String = main.get_node("HUD/Message").text
	var ok := true
	ok = _check("(2) 강화 후 Forge/Notice에 결과 메시지가 쓰임", notice != "") and ok
	ok = _check("(2) 강화 후 HUD/Message는 비어 있음", message == "") and ok
	return ok


## INBOX 보정(2026-09-06 05:00): 모달 패널이 열린 동안 지역 이름표·메시지를 숨긴다.
func _check_area_message_hidden(main: Node) -> bool:
	var ok := true
	ok = _check("(4) 강화 창 열림 - HUD/Area 숨김", not main.get_node("HUD/Area").visible) and ok
	ok = _check("(4) 강화 창 열림 - HUD/Message 숨김", not main.get_node("HUD/Message").visible) and ok
	return ok


func _check_interact_label(main: Node) -> bool:
	var mc := main.get_node("HUD/MobileControls")
	var ok := true

	main.forge_mode = "enhance"
	main._refresh_forge()
	ok = _check("(3) 강화 탭 라벨 '강화'", mc.get_node("Interact").text == "강화") and ok
	ok = _check("(3) 강화 탭 확인 버튼 보임", mc.get_node("Interact").visible) and ok
	# 결함(2026-09-06 05:45): set_modal_mode()를 실기처럼 한 번 더 불러도
	# 라벨이 "대화"로 되돌아가면 안 된다.
	mc.set_modal_mode("forge")
	ok = _check("(3) 강화 탭 라벨 '강화'(재호출 후)", mc.get_node("Interact").text == "강화") and ok

	main.forge_mode = "socket"
	main._refresh_forge()
	ok = _check("(3) 소켓 탭 확인 버튼 숨김", not mc.get_node("Interact").visible) and ok

	main.forge_mode = "craft"
	main._refresh_forge()
	ok = _check("(3) 제작 탭 라벨 '제작'", mc.get_node("Interact").text == "제작") and ok
	ok = _check("(3) 제작 탭 확인 버튼 보임", mc.get_node("Interact").visible) and ok
	return ok


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	GameState.inventory = ["철검"]
	# 겹침 검사는 화면 크기 조절(HUD_SCALE) 기본값(1.0, 축소 전 최대 크기)
	# 기준으로 해야 한다 - 로컬 user://ui_settings.json 에 남은 조절값을
	# 그대로 쓰면 StatBar가 작아져 실제로는 겹치는 레이아웃도 통과해버린다.
	main.hud_stat_scale = 1.0
	main._apply_hud_scale()
	main.get_node("HUD/MobileControls").force_visible = true
	main._toggle_forge()
	await get_tree().process_frame

	var ok := true
	ok = _check_no_overlap(main) and ok
	ok = _check_no_overlap_mobile_buttons(main) and ok
	ok = _check_detail_no_overlap_and_fits(main) and ok
	ok = _check_info_fits_and_more(main) and ok
	ok = _check_notice_message(main) and ok
	ok = _check_interact_label(main) and ok
	ok = _check_area_message_hidden(main) and ok

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
