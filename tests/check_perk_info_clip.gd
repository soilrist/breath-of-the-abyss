extends Node
## 특성 선택 화면(HUD/Perk/Info, 폭 220px, 폰트 9, autowrap 없음)에
## 가장 긴 특성 이름+보유 스택 표기가 들어간 목록 줄이 패널 폭을 넘는지
## (가로 유출) 측정한다. 다른 Info 라벨들(check_forge_info_clip.gd 등)과
## 짝이지만 이 화면은 아직 폭 검증이 없었다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.perks.clear()
	var offer: Array[String] = []
	for key in GameState.PERKS:
		GameState.perks[key] = 99
		offer.append(str(key))
	GameState.perk_offer = offer
	GameState.perk_picks = 1
	main.perk_index = 0
	main._refresh_perk()
	await get_tree().process_frame

	var info: Label = main.get_node("HUD/Perk/Info")
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
	print("패널 폭(px): ", panel_width)
	print("가장 넓은 줄: '", widest_line, "' 너비(px): ", max_width)
	var ok := max_width <= panel_width
	print("가로 유출 없음(=", ok, ")")
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
