extends Node
## 사용자 보고 "아이템이 떨어져 있어도 안 먹고 지나간다" 확인용 GUI 스크린샷.
## forest_w에 적은 다 지우고 골드 아이템 하나만 놓은 뒤 오토사냥을 켜서
## 실제로 걸어가서 줍는 장면을 화면으로 확인한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var player: Node = main.get_node("Player")
	main._change_map("forest_w", false)
	for stray in get_tree().get_nodes_in_group("enemies"):
		stray.queue_free()
	for stray in get_tree().get_nodes_in_group("pickups"):
		stray.queue_free()
	await get_tree().process_frame
	player.bounds = World.pixel_size_of("forest_w")
	player.global_position = Vector2(20.0, World.path_row("forest_w") * World.TILE + 8.0)
	player.motion_time = 0.0
	player.cooldown_time = 0.0

	var gold_pickup := preload("res://scenes/pickup.tscn").instantiate()
	gold_pickup.kind = "gold"
	gold_pickup.amount = 7
	gold_pickup.global_position = player.global_position + Vector2(150.0, 0.0)
	main.add_child(gold_pickup)
	gold_pickup.collected.connect(main._on_pickup_collected)

	var gold_before: int = GameState.gold

	var t_key := InputEventKey.new()
	t_key.physical_keycode = KEY_T
	t_key.pressed = true
	main._unhandled_input(t_key)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://auto_hunt_pickup_start.png")

	for tick in 300:
		if not is_instance_valid(gold_pickup):
			break
		await get_tree().physics_frame

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://auto_hunt_pickup_after.png")

	print("SHOT auto_hunt_pickup auto_hunt=", player.auto_hunt,
		" pickup_alive=", is_instance_valid(gold_pickup),
		" gold_before=", gold_before,
		" gold_after=", GameState.gold)
	get_tree().quit()
