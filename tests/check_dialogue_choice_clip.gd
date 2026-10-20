extends Node
## NPC 대화 선택지(전직 3택)가 Choices 라벨(고정 높이 40px) 안에서
## 실제로 3줄 다 보이는지, 커서를 마지막 선택지로 내렸을 때도 그 줄이
## clip 되지 않는지 측정한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.level = 20
	GameState.gold = 10000
	GameState.job = ""
	print("A: about to call _play_dialogue")
	main.dialogue_choice_after = main._on_job_choice
	main._play_dialogue([
		["elder", "자네의 실력이 충분히 무르익었군.\n어떤 길을 걷겠나?", [
			["전사 - 강인한 근접 전투", "job_warrior"],
			["마법사 - 강력한 원소 마법", "job_mage"],
			["도적 - 빠른 연속 공격", "job_rogue"],
		]],
	])
	print("B: _play_dialogue returned")
	await get_tree().process_frame
	print("C: after process_frame")

	var choices_label: Label = main.get_node("HUD/Dialogue/Choices")
	print("Choices 텍스트:\n", choices_label.text)
	print("Choices 노드 offset_top=", choices_label.offset_top, " offset_bottom=", choices_label.offset_bottom)
	var panel_height: float = choices_label.offset_bottom - choices_label.offset_top
	var line_height := choices_label.get_theme_default_font().get_height(choices_label.get_theme_font_size("font_size"))
	var visible_lines := int(panel_height / line_height) if line_height > 0 else -1
	print("패널 높이=", panel_height, " 줄 높이=", line_height, " 들어가는 줄 수 추정=", visible_lines)
	print("선택지 개수=", main.dialogue_choices.size())

	# 세 번째(마지막) 선택지로 커서를 옮겨서 그 줄이 clip_text 등으로
	# 가려지지 않는지 - clip_text 속성 자체가 있는지도 확인한다.
	main._move_dialogue_choice(1)
	main._move_dialogue_choice(1)
	await get_tree().process_frame
	print("마지막 선택지로 이동 후 텍스트:\n", choices_label.text)
	print("clip_text=", choices_label.clip_text)
	print("autowrap_mode=", choices_label.autowrap_mode)

	var ok: bool = main.dialogue_choices.size() <= visible_lines and not choices_label.clip_text
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
