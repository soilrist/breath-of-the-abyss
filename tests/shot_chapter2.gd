extends Node
## 2장(청람 지방) 사냥터를 실제 화면으로 확인하기 위한 스크린샷.
## 1~10장 중 2장만 shot_chapter* 검사가 없었다(shot_chapter2_boss.gd는 성채 보스방 전용).


func _ready() -> void:
	GameState.chapter = 2
	GameState.chapter_kills = 0
	GameState.quest_stage = 4
	GameState.unlock_map("harbor")
	GameState.unlock_map("marsh")
	GameState.current_map = "marsh"
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		main._advance_dialogue()
	main._change_map("marsh", false)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter2_marsh.png")
	print("SHOT chapter2_marsh")
	get_tree().quit()
