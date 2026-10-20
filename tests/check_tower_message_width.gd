extends Node
## check_tower_milestone_reward.gd는 마일스톤 획득 메시지가 다음 층 안내에
## 묻히지 않고 합쳐지는지만(문자열 내용) 확인했지 그 합쳐진 문장이
## HUD/Message 라벨 폭(223px)을 넘어 autowrap으로 여러 줄이 되면서 바로
## 아래 HUD/Area 라벨(y:42~58, Message는 y:7~40, 틈 2px)을 침범하는지는
## 아무도 재본 적이 없었다(실제 입력 경로/화면 검증 공백). 5개 난이도
## 전부의 최악 문구(재료명 5자 + 3자리 층수)로 렌더 폭을 잰다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var msg: Label = main.get_node("HUD/Message")
	var font := msg.get_theme_default_font()
	var font_size := msg.get_theme_font_size("font_size")
	var box_width: float = msg.size.x
	var ok := true

	for tier in GameState.TOWER_TIERS:
		var tier_name := str(GameState.TOWER_TIERS.get(tier, {}).get("name", tier))
		var material_name := GameState.tower_material_name(tier)
		# _spawn_tower_floor()의 마일스톤 합산 문구 형식 그대로(main.gd:2465).
		var text := "%s %d개 획득! 탑 %d층 (%s)" % [material_name, 3, 100, tier_name]
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var cond := w <= box_width
		print(tier, ": '", text, "' 너비(px)=", w, " 박스 폭(px)=", box_width, " OK=", cond)
		ok = cond and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
