extends Node
## 창고 목록에 가장 긴 장비 이름(+강화 수치, [착용] 표기까지 붙은 줄)을 넣고
## 렌더된 줄 너비가 Storage/Info 패널 폭을 넘는지(가로 clip/유출) 측정한다.
## check_inventory_clip.gd(세로 clip)과 짝이 되는 가로 검사 - 이 화면은
## 지금까지 스크린샷/폭 검증이 한 번도 없었다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	# EQUIPMENT 중 가장 긴 이름을 직접 찾는다(하드코딩 금지 - 설계가 바뀌어도 그대로 잡아낸다).
	var longest := ""
	for item_name in GameState.EQUIPMENT:
		if item_name.length() > longest.length():
			longest = item_name

	GameState.inventory.clear()
	GameState.level = 99
	GameState.add_item(longest)
	GameState.equip(longest)
	GameState.enhance_levels[GameState.item_uid[0]] = 10

	main._toggle_storage()
	main.storage_index = 0
	main._refresh_storage()
	await get_tree().process_frame

	var info: Label = main.get_node("HUD/Storage/Info")
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
	print("가장 긴 항목: ", longest)
	print("패널 폭(px): ", panel_width)
	print("가장 넓은 줄: '", widest_line, "' 너비(px): ", max_width)
	var ok := max_width <= panel_width
	print("가로 유출 없음(=", ok, ")")
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
