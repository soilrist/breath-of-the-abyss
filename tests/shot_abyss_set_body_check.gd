extends Node
## "천공 세트를 입으면 캐릭터가 실제로 무지개색으로 보이는가"를 확실히
## 확인하기 위해, 화면 전체가 아니라 플레이어 Sprite 텍스처 영역만 크게
## 잘라 저장한다(필드 화면 축소로 판별이 어려웠던 문제 회피).

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	GameState.level = 60
	main._change_map("forest_w", false)
	main.get_node("HUD").visible = false

	GameState.inventory = ["천공의 검", "천공의 갑주", "천공의 투구"]
	GameState.equip("천공의 검")
	GameState.equip("천공의 갑주")
	GameState.equip("천공의 투구")
	main._apply_equipment_to_player()
	player._update_armor_tint()
	print("modulate=", player.get_node("Sprite").modulate)

	# 카메라를 플레이어 위치에 맞추고 줌을 크게 키워 캐릭터가 화면을
	# 꽉 채우게 한다. player._physics_process()가 매 틱 카메라를
	# 화면(320x240) 격자 칸 중앙으로 되돌리므로(_lock_camera_to_screen),
	# 그대로 두면 줌을 키워도 카메라가 플레이어가 아니라 방 중앙을 비춰
	# 캐릭터가 화면 밖으로 빠진다 - 물리 처리를 꺼서 덮어쓰지 못하게 한다.
	player.set_physics_process(false)
	var cam: Camera2D = player.get_node("Camera2D")
	cam.zoom = Vector2(12, 12)
	cam.global_position = player.global_position
	player.facing = Vector2.DOWN
	player._update_sprite(Vector2.ZERO)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_abyss_body_zoom.png")
	print("SHOT abyss_body_zoom done")
	get_tree().quit()
