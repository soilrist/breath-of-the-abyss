extends Node
## 5장(유민의 땅) 마을과 사냥터를 실제 화면으로 확인하기 위한 스크린샷.

func _ready() -> void:
	GameState.chapter = 5
	GameState.chapter_kills = 0
	GameState.quest_stage = 11
	GameState.unlock_map("remnant_village")
	GameState.unlock_map("collapsed_spires")
	GameState.current_map = "collapsed_spires"
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	main._change_map("collapsed_spires", false)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter5_spires.png")
	print("SHOT chapter5_spires")
	get_tree().quit()
