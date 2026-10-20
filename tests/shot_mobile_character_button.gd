extends Node
## INBOX 결함(감독, 2026-09-06 09:50) (c) — 스킬 6칸 전부 채운 최악 데이터로
## 모바일 플레이 화면을 찍어 Auto/Quest/캐릭 버튼이 SkillBar와 안 겹치고
## 잘 보이는지 눈으로 확인한다(shot_mobile_auto_button.gd과 같은 패턴).

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		main._advance_dialogue()
		await get_tree().process_frame

	GameState.reset()
	GameState.job = "mage"
	GameState.second_job = "elementalist"
	GameState.level = 40

	var mobile := main.get_node("HUD/MobileControls")
	mobile.force_visible = true
	mobile.show()
	mobile.set_modal_mode("")
	await get_tree().process_frame

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://mobile_character_button_play.png")

	print("SHOT mobile_character_button_play skill_slot_count=", GameState.skill_slot_count(),
		" character_button_hidden=", not mobile.get_node("Character").visible,
		" auto_visible=", mobile.get_node("Auto").visible,
		" quest_visible=", mobile.get_node("Quest").visible)
	get_tree().quit()
