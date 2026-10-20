extends Node
## 3장(서리벌 지방) 마을·사냥터를 실제 화면으로 확인하기 위한 스크린샷.
## chapter5~8과 달리 3장은 지금까지 한 번도 스크린샷 검사가 없었다.


func _ready() -> void:
	GameState.chapter = 3
	GameState.chapter_kills = 0
	GameState.quest_stage = 6
	GameState.unlock_map("frost_camp")
	GameState.unlock_map("snowfield")
	GameState.current_map = "snowfield"
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		main._advance_dialogue()
	main._change_map("snowfield", false)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter3_snowfield.png")
	print("SHOT chapter3_snowfield")
	get_tree().quit()
