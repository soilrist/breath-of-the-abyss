extends Node
## INBOX 지시(2026-09-06 04:35, HUD 창 13개 강화 창 기준 전수 점검) — Skills
## 최악 데이터 데스크톱/모바일 각 1장. check_skills_layout.gd과 같은 최악
## 조합(2차 전직 elementalist, 스킬 6칸 전부 노출, 레벨 99 전부 해금)을 찍는다.
## 주의: --headless로 돌리면 frame_post_draw에서 무한 대기한다. 창을 띄운 채
## (헤드리스 없이) 실행할 것.

func _shot(mc: Node, tag: String) -> void:
	mc._toggle_controls()
	mc.set_modal_mode("skills")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://skills_layout_%s_desktop.png" % tag)
	print("SHOT skills_layout_%s_desktop controls_hidden=" % tag, mc.controls_hidden)

	mc._toggle_controls()
	mc.set_modal_mode("skills")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://skills_layout_%s_mobile.png" % tag)
	print("SHOT skills_layout_%s_mobile controls_hidden=" % tag, mc.controls_hidden)


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	var mc := main.get_node("HUD/MobileControls")

	GameState.job = "mage"
	GameState.second_job = "elementalist"
	GameState.level = 99
	main._toggle_skills()
	await get_tree().process_frame
	await _shot(mc, "elementalist99")

	get_tree().quit()
