extends Node
## 새 8방향 칼질 스윙(뽑기-자세-베기-마무리)이 실제로 어떻게 보이는지 찍어 본다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	GameState.level = 20
	main._change_map("village", false)
	main.get_node("HUD").visible = false

	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = -100000
	cam.limit_top = -100000
	cam.limit_right = 100000
	cam.limit_bottom = 100000
	player.global_position = Vector2(300, 300)
	player.bounds = Vector2(10000, 10000)

	var weapons := ["철검", "수호자의 검"]
	var dirs := {"down": Vector2.DOWN, "right": Vector2.RIGHT, "upright": Vector2(0.7, -0.7)}
	for weapon in weapons:
		GameState.equipped["weapon"] = weapon
		GameState._recalc_bonuses()
		for dir_name in dirs:
			player.facing = dirs[dir_name]
			player.cooldown_time = 0.0
			player.attack()
			var shots := 0
			while player.motion_time > 0.0 and shots < 5:
				await get_tree().physics_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("user://swing_%s_%s_%d.png" % [weapon, dir_name, shots])
				shots += 1
			print("SHOT ", weapon, " ", dir_name)
	get_tree().quit()
