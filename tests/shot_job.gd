extends Node
## 전직/직업 UI를 실제로 렌더링해 스크린샷으로 남긴다(HANDOFF.md 관례:
## 텍스트 잘림은 존재 여부 검사만으로 못 잡으니 반드시 그림으로 확인).

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	GameState.level = 15
	GameState.gold = 999999
	main._apply_equipment_to_player()

	await snap(main, "job_tab_before", func() -> void:
		main.character_mode = "job"
		main.job_index = 0
		main._toggle_character())
	_close_character(main)

	GameState.change_job("warrior")
	main._apply_equipment_to_player()
	await snap(main, "job_tab_warrior", func() -> void:
		main.character_mode = "job"
		main.job_index = 1
		main._toggle_character())
	_close_character(main)

	await snap(main, "skillbar_warrior", func() -> void:
		main._update_skill_bar())

	await snap(main, "skills_screen_warrior", func() -> void:
		main._toggle_skills())
	_close_skills(main)

	GameState.change_job("mage")
	main._apply_equipment_to_player()
	await snap(main, "skillbar_mage", func() -> void:
		main._update_skill_bar())

	GameState.gold = 999999
	GameState.change_job("rogue")
	main._apply_equipment_to_player()
	await snap(main, "skillbar_rogue", func() -> void:
		main._update_skill_bar())

	await snap(main, "job_tab_rogue", func() -> void:
		main.character_mode = "job"
		main.job_index = 2
		main._toggle_character())
	_close_character(main)

	get_tree().quit()


func _close_character(main: Node) -> void:
	if main.character_open:
		main._toggle_character()


func _close_skills(main: Node) -> void:
	if main.skills_open:
		main._toggle_skills()


func snap(main: Node, label: String, open: Callable) -> void:
	open.call()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://job_%s.png" % label)
	print("SHOT ", label)
