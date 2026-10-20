extends Node
## AUTOHUNT_DESIGN.md §8 "실제 게임 실행(GUI) 스크린샷" 확인용 - 토글 자체는
## shot_auto_hunt_toggle.gd가 이미 확인했다. 이번엔 오토사냥이 실제로 필드에서
## 이동+공격하는 전투 장면 자체를 화면으로 확인한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var player: Node = main.get_node("Player")
	main._change_map("forest_w", false)
	for stray in get_tree().get_nodes_in_group("enemies"):
		stray.queue_free()
	await get_tree().process_frame
	player.bounds = World.pixel_size_of("forest_w")
	player.global_position = Vector2(20.0, World.path_row("forest_w") * World.TILE + 8.0)
	player.motion_time = 0.0
	player.cooldown_time = 0.0

	var mob = preload("res://scenes/enemy.tscn").instantiate()
	main.add_child(mob)
	mob.max_health = 200
	mob.health = 200
	mob.global_position = player.global_position + Vector2(120.0, 0.0)

	var t_key := InputEventKey.new()
	t_key.physical_keycode = KEY_T
	t_key.pressed = true
	main._unhandled_input(t_key)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://auto_hunt_combat_start.png")

	var mob_hp_before: int = mob.health
	for tick in 300:
		if not is_instance_valid(mob) or mob.health <= 0:
			break
		await get_tree().physics_frame

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://auto_hunt_combat_after.png")

	print("SHOT auto_hunt_combat auto_hunt=", player.auto_hunt,
		" player_pos=", player.global_position,
		" mob_hp_before=", mob_hp_before,
		" mob_alive=", is_instance_valid(mob),
		" mob_hp_after=", (mob.health if is_instance_valid(mob) else -1))
	get_tree().quit()
