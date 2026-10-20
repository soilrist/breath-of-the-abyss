extends Node
## 대륙 이동도 화면에 새로 넣은 세계 지도(Atlas) 시각효과를 눈으로 확인하기 위한 스크린샷.
## 3장 탭까지 열어야 눈에 잘 보이므로, 기본 시작(1장) 그대로 두고 지도에서 탭만 넘긴다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	main._toggle_world_map()
	var graph: Control = main.get_node("HUD/WorldMap/Graph")
	graph.change_chapter(1)  # 1장 -> 2장으로 한 칸 이동, 탭 갱신 확인용
	graph.change_chapter(1)  # 2장 -> 3장(서리벌)까지 이동
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://world_map_atlas.png")
	print("SHOT world_map_atlas")
	get_tree().quit()
