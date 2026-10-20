extends Node
## quest_stage=69(진짜 최종 클리어, 10장 보스 처치 후) HUD 문구를 실제 화면으로
## 확인하기 위한 스크린샷. shot_chapter10.gd와 같은 패턴, 지역만 근원의 옥좌
## (origin_throne, 보스방)로 바꾸고 quest_stage를 69로 맞춘다.


func _ready() -> void:
	GameState.chapter = 10
	GameState.chapter_kills = 12
	GameState.quest_stage = 69
	GameState.boss_defeated = true
	GameState.unlock_map("origin_throne")
	GameState.current_map = "origin_throne"
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		main._advance_dialogue()
	main._change_map("origin_throne", false)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter10_clear.png")
	print("SHOT chapter10_clear")
	get_tree().quit()
