extends Node
## 사용자 보고 "돌이나 다른 오브젝트가 앞에있으면 그걸 지나치지않고
## 거기에 걸려서 진행이 안돼" 확인용 GUI 스크린샷.
## forest_w에 정적 장애물(돌 크기 StaticBody2D)을 플레이어와 목표 아이템
## 사이에 놓고, 오토사냥이 제자리걸음하지 않고 옆으로 비켜 결국 아이템에
## 도달하는 장면을 화면으로 확인한다.

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

	var obstacle_shape := RectangleShape2D.new()
	obstacle_shape.size = Vector2(16.0, 16.0)
	var obstacle_collision := CollisionShape2D.new()
	obstacle_collision.shape = obstacle_shape
	var obstacle := StaticBody2D.new()
	obstacle.add_child(obstacle_collision)
	obstacle.global_position = player.global_position + Vector2(60.0, 0.0)
	main.add_child(obstacle)

	var gold_pickup := preload("res://scenes/pickup.tscn").instantiate()
	gold_pickup.kind = "gold"
	gold_pickup.amount = 7
	gold_pickup.global_position = player.global_position + Vector2(150.0, 0.0)
	main.add_child(gold_pickup)
	gold_pickup.collected.connect(main._on_pickup_collected)

	var gold_before: int = GameState.gold
	var start_x: float = player.global_position.x

	var t_key := InputEventKey.new()
	t_key.physical_keycode = KEY_T
	t_key.pressed = true
	main._unhandled_input(t_key)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://auto_hunt_obstacle_start.png")

	for tick in 360:
		if not is_instance_valid(gold_pickup):
			break
		await get_tree().physics_frame

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://auto_hunt_obstacle_after.png")

	print("SHOT auto_hunt_obstacle auto_hunt=", player.auto_hunt,
		" pickup_alive=", is_instance_valid(gold_pickup),
		" gold_before=", gold_before,
		" gold_after=", GameState.gold,
		" start_x=", start_x,
		" final_x=", player.global_position.x)
	get_tree().quit()
