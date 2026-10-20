extends Node
## 9장(역전의 탑, rift_camp 이후 사냥터) 화면을 실제 화면으로 확인하기 위한 스크린샷.
## shot_chapter3/4와 같은 패턴 - rift_camp(캠프)는 shot_town_npcs.gd가 이미 검사하므로
## 여기서는 그 다음 사냥터 inverted_stair(거꾸로 된 계단)를 본다.


func _ready() -> void:
	GameState.chapter = 9
	GameState.chapter_kills = 0
	GameState.quest_stage = 51
	GameState.unlock_map("inverted_stair")
	GameState.current_map = "inverted_stair"
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		main._advance_dialogue()
	main._change_map("inverted_stair", false)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter9_inverted_stair.png")
	print("SHOT chapter9_inverted_stair")
	get_tree().quit()
