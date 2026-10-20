extends Node
## 4장(잿불 지방, abyss) 마을·사냥터를 실제 화면으로 확인하기 위한 스크린샷.
## shot_chapter3과 같은 패턴 - 1·2·4·9·10장은 지금까지 스크린샷 검사가 없었다.


func _ready() -> void:
	GameState.chapter = 4
	GameState.chapter_kills = 0
	GameState.quest_stage = 8
	GameState.unlock_map("abyss")
	GameState.current_map = "abyss"
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		main._advance_dialogue()
	main._change_map("abyss", false)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter4_abyss.png")
	print("SHOT chapter4_abyss")
	get_tree().quit()
