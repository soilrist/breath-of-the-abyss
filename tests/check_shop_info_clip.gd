extends Node
## 상점 화면 Info 라벨(폭 142px, 폰트 9)에 구매/판매 목록 줄이 패널 폭을
## 넘는지(가로 유출) 측정한다. check_forge_info_clip.gd(폭 150px, 폰트 9 -
## 여유 확인됨)와 짝이지만 이 화면은 폭이 더 좁고 " (부족)"/" [착용]" 접미사가
## 붙어 별도로 검증한 적이 없었다.

func _measure(main: Node) -> Dictionary:
	var info: Label = main.get_node("HUD/Shop/Info")
	var font := info.get_theme_default_font()
	var font_size := info.get_theme_font_size("font_size")
	var panel_width: float = info.size.x
	var max_width := 0.0
	var widest_line := ""
	for line in info.text.split("\n"):
		var w: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if w > max_width:
			max_width = w
			widest_line = line
	return {"panel_width": panel_width, "max_width": max_width, "widest_line": widest_line}


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	main._open_shop()
	var overall_max := 0.0
	var overall_line := ""
	var panel_width := 0.0

	# 구매 탭: 살 돈이 없는 최악 폭("(부족)" 접미사 항상 붙게) + 모든 항목 순회.
	GameState.gold = 0
	main.shop_mode = "buy"
	for i in main._shop_goods().size():
		main.shop_index = i
		main._refresh_shop()
		var m := _measure(main)
		panel_width = m["panel_width"]
		if m["max_width"] > overall_max:
			overall_max = m["max_width"]
			overall_line = m["widest_line"]

	# 판매 탭: 가장 긴 장비 이름을 착용 상태로("[착용]" 접미사) 순회.
	var longest := ""
	for item_name in GameState.EQUIPMENT:
		if item_name.length() > longest.length():
			longest = item_name
	GameState.inventory.clear()
	GameState.level = 99
	GameState.add_item(longest)
	GameState.equip(longest)
	main.shop_mode = "sell"
	main.shop_index = 0
	main._refresh_shop()
	var sm := _measure(main)
	if sm["max_width"] > overall_max:
		overall_max = sm["max_width"]
		overall_line = sm["widest_line"]

	print("패널 폭(px): ", panel_width)
	print("가장 넓은 줄: '", overall_line, "' 너비(px): ", overall_max)
	var ok := overall_max <= panel_width
	print("가로 유출 없음(=", ok, ")")
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
