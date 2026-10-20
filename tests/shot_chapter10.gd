extends Node
## 10장(근원, 최종장) 화면을 실제 화면으로 확인하기 위한 스크린샷.
## shot_chapter9.gd와 같은 패턴 - origin_gate(근원 입구)는 챕터 진입 직후 첫 지역.


func _ready() -> void:
	GameState.chapter = 10
	GameState.chapter_kills = 0
	GameState.quest_stage = 61
	GameState.unlock_map("origin_gate")
	GameState.current_map = "origin_gate"
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		main._advance_dialogue()
	main._change_map("origin_gate", false)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter10_origin_gate.png")
	print("SHOT chapter10_origin_gate")
	get_tree().quit()
