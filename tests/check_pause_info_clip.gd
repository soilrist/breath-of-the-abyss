extends Node
## 일시정지 화면 Info 라벨(폭 202px, 폰트 10, 가운데 정렬, autowrap 켜짐)에
## 두 variant(모바일 짧은 요약 / PC 전체 단축키 안내) 모두 실제 렌더링된
## 줄 수가 라벨 높이(패널 안)에 다 들어가는지 측정한다.
## check_inventory_clip.gd와 같은 패턴(get_line_count() vs 패널높이/줄높이).

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var info: Label = main.get_node("HUD/Pause/Info")

	# 최악 폭: 음악/효과음 둘 다 "꺼짐"(글자 수 "켜짐"과 동일해 폭 차 없음),
	# 체력바/스킬바 크기 실제 최댓값(main.gd:95 HUD_SCALE_MAX=1.1 -> "110%",
	# 세 자리라 두 자리보다 폭이 넓음, 줄바꿈이 가장 많이 일어나는 조건) 가정.
	Audio.music_muted = true
	Audio.sfx_muted = true
	main.hud_stat_scale = main.HUD_SCALE_MAX
	main.hud_skill_scale = main.HUD_SCALE_MAX

	var line_height: float = info.get_theme_default_font().get_height(info.get_theme_font_size("font_size"))
	var panel_height: float = info.size.y
	var visible_lines := int(panel_height / line_height) if line_height > 0 else -1
	var all_ok := true

	for mobile in [false, true]:
		main.get_node("HUD/MobileControls").visible = mobile
		main._refresh_pause_info()
		await get_tree().process_frame
		var variant := "모바일" if mobile else "PC"
		var line_count := info.get_line_count()
		var ok := line_count <= visible_lines
		print(variant, " - 실제 렌더 줄 수: ", line_count, " / 패널에 다 들어가는 줄 수(추정): ", visible_lines, " -> ", "OK" if ok else "FAIL")
		if not ok:
			all_ok = false

	print("줄 높이(px): ", line_height, "  패널 높이(px): ", panel_height)
	print("클리핑 없음(=", all_ok, ")")
	print("RESULT ", "PASS" if all_ok else "FAIL")
	get_tree().quit()
