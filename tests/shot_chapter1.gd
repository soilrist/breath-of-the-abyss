extends Node
## 1장(안개숲) 사냥터를 실제 화면으로 확인하기 위한 스크린샷.
## 1~10장 중 1장만 shot_chapter* 검사가 없었다(shot_chapter1_boss.gd는 던전
## 보스방 전용). forest_w는 INBOX D 시범 조각(ca0a38d)에서 3지역을 합친
## 곳으로, 그때 확인은 임시 스크립트(커밋 안 함)였다 - 이번이 첫 영구 검사.


func _ready() -> void:
	GameState.chapter = 1
	GameState.quest_stage = 1
	GameState.unlock_map("forest_w")
	GameState.current_map = "forest_w"
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		main._advance_dialogue()
	main._change_map("forest_w", false)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter1_forest_w.png")
	print("SHOT chapter1_forest_w")
	get_tree().quit()
