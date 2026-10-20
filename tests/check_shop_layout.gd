extends Node
## INBOX 지시(2026-09-06, HUD 창 13개 강화 창 기준 전수 점검) — Shop 창.
## check_forge_layout.gd/check_inventory_layout.gd과 같은 패턴. Shop 패널을
## Inventory와 같은 크기(6,8)-(276,206)로 넓히고 HUD/Shop/Notice를 새로 둬
## 구매/판매 결과 메시지가 HUD/Message(패널 열림 중 숨김, _sync_modal_hud_
## visibility())로 가서 안 보이던 문제를 Forge/Inventory와 같은 방식으로 고침.

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _check_no_overlap(main: Node) -> bool:
	var statbar: Control = main.get_node("HUD/StatBar")
	var statbar_rect: Rect2 = statbar.get_global_rect()
	var ok := true
	for child_name in ["Info", "Detail", "Help", "Notice", "Icon"]:
		var node := main.get_node("HUD/Shop/%s" % child_name)
		var rect: Rect2 = node.get_global_rect()
		var overlap := rect.grow(4).intersects(statbar_rect)
		ok = _check("(1) HUD/Shop/%s 가 StatBar와 4px 여백 없이 안 겹침" % child_name, not overlap) and ok
	return ok


func _check_five_rects_disjoint(main: Node) -> bool:
	var names := ["Detail", "Help", "Notice", "Info"]
	var rects := {}
	for n in names:
		rects[n] = main.get_node("HUD/Shop/%s" % n).get_global_rect()
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


## 구매 탭 전체 목록(SHOP_STOCK, 챕터 최대)을 커서로 훑고, 판매 탭은
## GameState.EQUIPMENT 61개 전부(초월 소켓 3/3 채운 최악 항목 포함)를
## 인벤토리에 넣어 Detail/Info가 잘리지 않는지 확인.
func _check_detail_and_info_fit(main: Node) -> bool:
	GameState.chapter = 99
	GameState.gold = 0
	var info: Label = main.get_node("HUD/Shop/Info")
	var detail: Label = main.get_node("HUD/Shop/Detail")
	var ok := true

	main.shop_mode = "buy"
	var goods: Array = main._shop_goods()
	for i in goods.size():
		main.shop_index = i
		main._refresh_shop()
		ok = _check_label_fits_all_lines(detail, "구매[%s]" % goods[i]["item"]) and ok
		ok = _check_label_fits_all_lines(info, "구매 Info[%s]" % goods[i]["item"]) and ok

	GameState.gold = 999999
	var equipment_names: Array = GameState.EQUIPMENT.keys()
	var typed_inventory: Array[String] = []
	typed_inventory.assign(equipment_names)
	GameState.inventory = typed_inventory
	GameState.sync_uids()
	var sky_seal_uid: int = GameState.uid_of("천공의 인장")
	GameState.socketed[sky_seal_uid] = ["홍옥", "벽옥", "황옥"]

	main.shop_mode = "sell"
	for i in equipment_names.size():
		main.shop_index = i
		main._refresh_shop()
		ok = _check_label_fits_all_lines(detail, "판매[%s]" % equipment_names[i]) and ok
		ok = _check_label_fits_all_lines(info, "판매 Info[%s]" % equipment_names[i]) and ok
	return ok


## 감독 보정(2026-09-06 07:55): 목록이 SHOP_WINDOW(5)칸을 넘으면 Info
## 마지막 줄에 "… N개 더"가 붙어야 한다.
func _check_more_suffix(main: Node) -> bool:
	GameState.chapter = 99
	GameState.gold = 999999
	var info: Label = main.get_node("HUD/Shop/Info")
	var ok := true

	main.shop_mode = "buy"
	main.shop_index = 0
	main._refresh_shop()
	var goods_count: int = main._shop_goods().size()
	ok = _check("(5) 구매 Info 넘침 표기 '개 더' 포함(상품 %d개)" % goods_count,
		info.text.contains("개 더")) and ok

	var equipment_names: Array = GameState.EQUIPMENT.keys()
	var typed_inventory: Array[String] = []
	typed_inventory.assign(equipment_names)
	GameState.inventory = typed_inventory
	GameState.sync_uids()
	main.shop_mode = "sell"
	main.shop_index = 0
	main._refresh_shop()
	ok = _check("(5) 판매 Info 넘침 표기 '개 더' 포함(보유 %d개)" % equipment_names.size(),
		info.text.contains("개 더")) and ok
	return ok


## Sell/Close만 확인 - Buy1~5는 목록 줄 위에 얹히는 투명 터치 오버레이라
## Info와 의도적으로 겹친다(_place_buy_buttons 주석 참고).
func _check_no_overlap_mobile(main: Node) -> bool:
	var mc := main.get_node("HUD/MobileControls")
	var ok := true
	for btn_name in ["Sell", "Close"]:
		var btn: Control = mc.get_node(btn_name)
		if not btn.visible:
			continue
		var btn_rect: Rect2 = btn.get_global_rect()
		for child_name in ["Info", "Detail", "Help", "Notice", "Icon"]:
			var node := main.get_node("HUD/Shop/%s" % child_name)
			var rect: Rect2 = node.get_global_rect()
			ok = _check("(c) HUD/Shop/%s 가 MobileControls/%s 와 4px 여백 없이 안 겹침" % [child_name, btn_name],
				not rect.grow(4).intersects(btn_rect)) and ok
	return ok


func _check_notice_message(main: Node) -> bool:
	GameState.chapter = 99
	GameState.gold = 999999
	main.shop_mode = "buy"
	main.shop_index = 0
	main._refresh_shop()
	main.get_node("HUD/Message").text = ""
	main.get_node("HUD/Shop/Notice").text = ""
	main._activate_selected_shop_item()
	var notice: String = main.get_node("HUD/Shop/Notice").text
	var message: String = main.get_node("HUD/Message").text
	var ok := true
	ok = _check("(2) 구매 후 Shop/Notice에 결과 메시지가 쓰임", notice != "") and ok
	ok = _check("(2) 구매 후 HUD/Message는 비어 있음", message == "") and ok
	return ok


## 감독 보정(2026-09-06 06:55): Notice에 실제로 뜰 수 있는 문구 중
## 가장 긴 것(구매 완료 - 가장 긴 상품명, 판매 완료 - 최대 가격)이
## Notice.size.x 안에 한 줄로 들어가는지 확인한다.
func _check_notice_fits(main: Node) -> bool:
	var notice: Label = main.get_node("HUD/Shop/Notice")
	var font := notice.get_theme_default_font()
	var font_size := notice.get_theme_font_size("font_size")
	var box_width: float = notice.size.x

	GameState.chapter = 99
	var goods: Array = main._shop_goods()
	var longest_item := ""
	for entry in goods:
		if str(entry["item"]).length() > longest_item.length():
			longest_item = str(entry["item"])
	for name in GameState.EQUIPMENT.keys():
		if str(name).length() > longest_item.length():
			longest_item = str(name)

	var texts := [
		"%s 구매 완료" % longest_item,
		"999999G에 판매했다.",
		"골드가 부족하다.",
		"착용 중인 장비는 팔 수 없다.",
	]
	var ok := true
	for text in texts:
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		ok = _check("(4) Notice 문구 한 줄 안착 '%s'(너비 %d, 칸 %d)" % [text, int(w), int(box_width)],
			w <= box_width) and ok
	return ok


func _check_area_message_hidden(main: Node) -> bool:
	var ok := true
	ok = _check("(3) 상점 창 열림 - HUD/Area 숨김", not main.get_node("HUD/Area").visible) and ok
	ok = _check("(3) 상점 창 열림 - HUD/Message 숨김", not main.get_node("HUD/Message").visible) and ok
	return ok


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	main._open_shop()
	await get_tree().process_frame

	var ok := true
	ok = _check_no_overlap(main) and ok
	ok = _check_five_rects_disjoint(main) and ok
	ok = _check_no_overlap_mobile(main) and ok
	ok = _check_detail_and_info_fit(main) and ok
	ok = _check_more_suffix(main) and ok
	ok = _check_notice_message(main) and ok
	ok = _check_notice_fits(main) and ok
	ok = _check_area_message_hidden(main) and ok

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
