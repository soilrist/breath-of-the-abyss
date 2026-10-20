extends Node
## INBOX O 조각 2(투구 모양)를 실제 화면으로 확인한다 - 투구마다 머리
## 오버레이 그림이 실제로 바뀌는지 12종 전부를 입혀 스크린샷으로 본다.
## shot_body_skins.gd 와 동일한 줌인 패턴을 따른다.

const HELMETS: Array[String] = ["가죽 모자", "철 투구", "파수병 투구", "서리왕관", "수호자의 투구", "흑기사단장의 투구", "용각 투구", "파수꾼의 투구", "심판자의 투구", "종언의 투구", "겁화의 투구", "천공의 투구"]

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	GameState.level = 60
	main._change_map("forest_w", false)
	main.get_node("HUD").visible = false

	player.set_physics_process(false)
	var cam: Camera2D = player.get_node("Camera2D")
	cam.zoom = Vector2(6, 6)
	player.facing = Vector2.DOWN

	for helmet in HELMETS:
		GameState.inventory = [helmet]
		GameState.equip(helmet)
		main._apply_equipment_to_player()
		cam.global_position = player.global_position
		player._update_sprite(Vector2.ZERO)
		print(helmet, " skin=", GameState.helmet_skin_for(helmet))
		# 필드를 돌아다니는 몹이 우연히 화면에 겹쳐 판별을 방해하지 않도록 치운다.
		for enemy in get_tree().get_nodes_in_group("enemies"):
			enemy.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var safe_name := helmet.replace(" ", "_")
		get_viewport().get_texture().get_image().save_png("user://shot_helmet_shape_%s.png" % safe_name)

	print("SHOT helmet_shapes done")
	get_tree().quit()
