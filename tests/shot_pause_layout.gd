extends Node
## INBOX 지시(2026-09-06, HUD 창 13개 강화 창 기준 전수 점검) — Pause 최악 데이터
## 데스크톱/모바일 각 1장. check_pause_layout.gd과 같은 최악 데이터(데스크톱
## 단축키 안내 9줄, 모바일 상태 요약 3줄 + Save/Title/ToggleControls/
## MusicMute/SfxMute/Quit 버튼)를 씀.

func _shot(main: Node, tag: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://pause_layout_%s.png" % tag)
	print("SHOT pause_layout_%s" % tag)


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()

	main.get_node("HUD/MobileControls").visible = false
	main.set_pause_open(true)
	await get_tree().process_frame
	await _shot(main, "desktop")
	main.set_pause_open(false)

	main.get_node("HUD/MobileControls").visible = true
	main.set_pause_open(true)
	await get_tree().process_frame
	await _shot(main, "mobile")
	main.set_pause_open(false)

	get_tree().quit()
