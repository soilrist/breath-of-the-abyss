extends Node
## INBOX O 조각 2(몸통 실루엣)를 실제 화면으로 확인한다 - 갑옷마다 몸통
## 그림이 실제로 바뀌는지 매핑된 14종 + 폴백(여행자 옷) 전부를 입혀
## 스크린샷으로 본다.
## shot_equip_part_colors.gd 와 동일한 줌인 패턴을 따른다.

const ARMORS: Array[String] = ["여행자 옷", "가죽 갑옷", "사슬 갑옷", "파수병 흉갑", "흑기사 갑주", "설원의 망토", "서리군주의 갑주", "용의 비늘", "용린 갑주", "심연의 갑주", "파수꾼의 갑주", "심판자의 갑주", "종언의 갑주", "겁화의 갑주", "천공의 갑주"]

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

	for armor in ARMORS:
		GameState.inventory = [armor]
		GameState.equip(armor)
		main._apply_equipment_to_player()
		cam.global_position = player.global_position
		player._update_sprite(Vector2.ZERO)
		print(armor, " skin=", GameState.body_skin_for(armor))
		# 필드를 돌아다니는 몹이 우연히 화면에 겹쳐 판별을 방해하지 않도록 치운다.
		for enemy in get_tree().get_nodes_in_group("enemies"):
			enemy.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var safe_name := armor.replace(" ", "_")
		get_viewport().get_texture().get_image().save_png("user://shot_body_skin_%s.png" % safe_name)

	print("SHOT body_skins done")
	get_tree().quit()
