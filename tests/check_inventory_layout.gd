extends Node
## INBOX 지시(2026-09-06, HUD 창 13개 강화 창 기준 전수 점검) — Inventory 창.
## check_forge_layout.gd과 같은 패턴: (1) 자식 라벨이 StatBar와 안 겹침
## (2) 다섯 rect가 서로 안 겹침 (3) Detail/Info가 최악 데이터에서도 안 잘림.

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _check_no_overlap(main: Node) -> bool:
	var statbar: Control = main.get_node("HUD/StatBar")
	# 메뉴 탭 창이 열리면 StatBar는 숨겨진다(main.gd _sync_modal_hud_visibility).
	if not statbar.visible:
		return _check("(1) 가방 창 열림 - StatBar 숨김(겹침 검사 생략)", true)
	var statbar_rect: Rect2 = statbar.get_global_rect()
	var ok := true
	for child_name in ["Info", "Detail", "Help", "Notice", "Icon"]:
		var node := main.get_node("HUD/Inventory/%s" % child_name)
		var rect: Rect2 = node.get_global_rect()
		var overlap := rect.grow(4).intersects(statbar_rect)
		ok = _check("(1) HUD/Inventory/%s 가 StatBar와 4px 여백 없이 안 겹침" % child_name, not overlap) and ok
	return ok


## 네 rect(Detail/Help/Notice/Info)와 StatBar가 서로 교집합이 없는지 전수 확인.
func _check_five_rects_disjoint(main: Node) -> bool:
	var names := ["Detail", "Help", "Notice", "Info"]
	var rects := {}
	for n in names:
		rects[n] = main.get_node("HUD/Inventory/%s" % n).get_global_rect()
	if main.get_node("HUD/StatBar").visible:
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


func _check_label_fits_all_lines(label: Label, tag: String) -> bool:
	var line_height := label.get_line_height() + label.get_theme_constant("line_spacing")
	var fits := label.get_line_count() * line_height <= label.size.y
	var visible_ok := label.get_visible_line_count() >= label.get_line_count()
	return _check("(a) %s %d줄 안착(칸 %d, 줄높이 %d)" %
		[tag, label.get_line_count(), int(label.size.y), line_height], fits) and \
		_check("(a) %s 마지막 줄까지 실제로 보임" % tag, visible_ok)


## GameState.EQUIPMENT 61개 전부를 인벤토리에 넣어 커서를 하나씩 옮기며 Detail이
## 잘리지 않는지 확인. 초월 등급(3소켓)에 스톤 3개를 채운 항목도 포함해 소켓
## 줄까지 나오는 최악 데이터(세트+스탯3개+소켓3/3)를 만든다.
func _check_detail_and_info_fit(main: Node) -> bool:
	GameState.gold = 999999
	GameState.materials[GameState.MATERIAL] = 999
	GameState.materials[GameState.BOSS_FRAGMENT] = 999
	GameState.enhance_wards = 9
	var info: Label = main.get_node("HUD/Inventory/Info")
	var detail: Label = main.get_node("HUD/Inventory/Detail")
	var ok := true

	var equipment_names: Array = GameState.EQUIPMENT.keys()
	var typed_inventory: Array[String] = []
	typed_inventory.assign(equipment_names)
	GameState.inventory = typed_inventory
	GameState.sync_uids()
	# "천공의 인장"(초월, atk/def/spd 3스탯 + set + 소켓 3/3)에 스톤 3개를 채워
	# item_summary가 만들 수 있는 가장 긴 형태(6줄: 헤더+스탯3+소켓+세트)로 만든다.
	var sky_seal_uid: int = GameState.uid_of("천공의 인장")
	GameState.socketed[sky_seal_uid] = ["홍옥", "벽옥", "황옥"]

	main.inventory_index = 0
	for i in equipment_names.size():
		main.inventory_index = i
		main._refresh_inventory()
		ok = _check_label_fits_all_lines(detail, "인벤토리[%s]" % equipment_names[i]) and ok
		ok = _check_label_fits_all_lines(info, "인벤토리 Info[%s]" % equipment_names[i]) and ok
	return ok


## 인벤토리 모드에서 실제로 보이는 모바일 버튼(Interact/Inventory)과
## 안 겹치는지 확인 - Close는 패널 자기 모서리에 붙는 게 정상이라 제외.
func _check_no_overlap_mobile(main: Node) -> bool:
	var mc := main.get_node("HUD/MobileControls")
	var ok := true
	for btn_name in ["Interact", "Inventory"]:
		var btn: Control = mc.get_node(btn_name)
		if not btn.visible:
			continue
		var btn_rect: Rect2 = btn.get_global_rect()
		for child_name in ["Info", "Detail", "Help", "Notice", "Icon"]:
			var node := main.get_node("HUD/Inventory/%s" % child_name)
			var rect: Rect2 = node.get_global_rect()
			ok = _check("(c) HUD/Inventory/%s 가 MobileControls/%s 와 4px 여백 없이 안 겹침" % [child_name, btn_name],
				not rect.grow(4).intersects(btn_rect)) and ok
	return ok


func _check_notice_message(main: Node) -> bool:
	GameState.gold = 999999
	GameState.inventory = ["철검"]
	GameState.sync_uids()
	main.inventory_index = 0
	main._refresh_inventory()
	main.get_node("HUD/Message").text = ""
	main.get_node("HUD/Inventory/Notice").text = ""
	main._activate_selected_inventory_item()
	var notice: String = main.get_node("HUD/Inventory/Notice").text
	var message: String = main.get_node("HUD/Message").text
	var ok := true
	ok = _check("(2) 착용 후 Inventory/Notice에 결과 메시지가 쓰임", notice != "") and ok
	ok = _check("(2) 착용 후 HUD/Message는 비어 있음", message == "") and ok
	return ok


## 결함(2026-09-06 05:45): set_modal_mode()를 실기처럼(_toggle_controls()
## 등) 한 번 더 불러도 인벤토리 라벨이 "대화"로 되돌아가면 안 된다.
func _check_interact_label(main: Node) -> bool:
	var mc := main.get_node("HUD/MobileControls")
	main.inventory_index = 0
	main._refresh_inventory()
	var ok := true
	ok = _check("(3) 착용 탭 라벨 '착용'", mc.get_node("Interact").text == "착용") and ok
	mc.set_modal_mode("inventory")
	ok = _check("(3) 착용 탭 라벨 '착용'(재호출 후)", mc.get_node("Interact").text == "착용") and ok
	return ok


## INBOX 보정(2026-09-06 05:00): 모달 패널이 열린 동안 지역 이름표·메시지를 숨긴다.
func _check_area_message_hidden(main: Node) -> bool:
	var ok := true
	ok = _check("(3) 인벤토리 창 열림 - HUD/Area 숨김", not main.get_node("HUD/Area").visible) and ok
	ok = _check("(3) 인벤토리 창 열림 - HUD/Message 숨김", not main.get_node("HUD/Message").visible) and ok
	return ok


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	GameState.inventory = ["철검"]
	main._toggle_inventory()
	await get_tree().process_frame

	var ok := true
	ok = _check_no_overlap(main) and ok
	ok = _check_five_rects_disjoint(main) and ok
	ok = _check_no_overlap_mobile(main) and ok
	ok = _check_detail_and_info_fit(main) and ok
	ok = _check_notice_message(main) and ok
	ok = _check_interact_label(main) and ok
	ok = _check_area_message_hidden(main) and ok

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
