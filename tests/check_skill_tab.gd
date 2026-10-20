extends Node
## 캐릭터 창 탭 → 스킬 창 연결("스킬탭도 없네", 2026-09-08). 창 없이 돌리면 PNG는 빈 그림이고 판정만 본다.
func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	GameState.reset()
	while main.dialogue_open:
		main._advance_dialogue()
	GameState.job = "mage"
	GameState.perk_picks = 2
	main._toggle_character()
	main.character_mode = "job"
	main._refresh_character()
	await get_tree().process_frame
	var mob: Node = main.get_node("HUD/MobileControls")
	mob.force_visible = true
	mob.visible = true
	mob.set_modal_mode("character")
	_shot("user://shot_skill_tab_char.png")
	main._cycle_character_mode(1)
	var ok: bool = main.skills_open and not main.character_open
	print("after cycle: skills=%s char=%s sell_visible=%s" % [main.skills_open, main.character_open, mob.get_node("Sell").visible])
	await get_tree().process_frame
	await get_tree().process_frame
	_shot("user://shot_skill_tab_skills.png")
	mob._toggle_shop_tab()
	ok = ok and main.character_open and not main.skills_open and main.character_mode == "stats"
	print("after tab: skills=%s char=%s mode=%s" % [main.skills_open, main.character_open, main.character_mode])
	main._cycle_character_mode(-1)
	ok = ok and main.skills_open
	main._skills_to_character(-1)
	ok = ok and main.character_open and main.character_mode == "job"
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


## --headless 에선 뷰포트 그림이 null 이라 save_png 가 터져 quit 을 못 부르고
## 스위트가 멈췄다(2026-09-08). 그림이 없으면 건너뛴다.
func _shot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(path)
