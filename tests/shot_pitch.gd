extends Node
## 한 장 소개서에 쓸 스크린샷. 4장 분위기를 대표하는 넓은 샷 4장 +
## 실제 HUD가 보이는 액션 샷 1장.

const WIDE_AREAS := ["forest_w", "citadel", "glacier", "throne"]

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var player_cam: Camera2D = main.get_node("Player/Camera2D")
	player_cam.enabled = false
	var view := Camera2D.new()
	main.add_child(view)
	view.enabled = true
	main.get_node("HUD").visible = false
	for area in WIDE_AREAS:
		main._change_map(area, false)
		var size: Vector2 = World.pixel_size_of(area)
		view.zoom = Vector2(320.0 / size.x, 240.0 / size.y)
		view.zoom = Vector2.ONE * minf(view.zoom.x, view.zoom.y)
		view.global_position = size * 0.5
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://pitch_%s.png" % area)
		print("SHOT ", area)

	# 실제 조작 화면: HUD가 보이는 액션 샷.
	view.enabled = false
	player_cam.enabled = true
	main.get_node("HUD").visible = true
	GameState.level = 12
	main._apply_equipment_to_player()
	main._change_map("forest_w", false)
	var player: Node = main.get_node("Player")
	player.health = int(player.max_health * 0.62)
	player.health_changed.emit(player.health, player.max_health)
	GameState.exp = 120
	GameState.next_exp = 300
	GameState.gold = 640
	main._update_stats()
	player.facing = Vector2.DOWN
	player.cooldown_time = 0.0
	player.attack()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://pitch_action.png")
	print("SHOT action")

	get_tree().quit()
