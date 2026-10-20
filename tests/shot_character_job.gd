extends Node
## 캐릭터 화면 전직 탭(HUD/Character, character_mode=="job")을 실제로 열어
## 스크린샷으로 확인한다. Info 라벨(scenes/main.tscn)은 autowrap_mode가
## 없고, 세로로는 바로 아래 Help 라벨(offset_top=136)이 Info 박스
## (offset_top=8~offset_bottom=156) 범위 안에 들어와 있어 여유가 빠듯하다.
## 2차 전직까지 열린 최악 조합(기본 직업 3줄 + 구분선 1줄 + 2차 전직
## 갈래 2줄 = 헤더 3줄 포함 총 9줄)을 만들어 겹침 여부를 확인한다.
## --headless로는 frame_post_draw가 안 돌아 무한 대기하니 반드시 일반
## 실행(창 모드)으로 띄워야 한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	GameState.level = GameState.SECOND_JOB_UNLOCK_LEVEL
	GameState.chapter = GameState.SECOND_JOB_UNLOCK_CHAPTER
	GameState.job = "warrior"
	main.character_mode = "job"
	main.character_open = true
	main.job_index = GameState.JOB_NAMES.size() + GameState.SECOND_JOB_BRANCHES["warrior"].size() - 1
	main._refresh_character()
	main.get_node("HUD/Character").visible = true

	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://character_job_max.png")
	print("SHOT character_job_max")

	get_tree().quit()
