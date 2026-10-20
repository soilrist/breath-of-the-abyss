extends Node
## save0/아이콘 검증에 이어, 근접 무기를 실제로 착용→공격시켜 화면에
## 그려지는 손그림이 무기마다 다르게 보이는지 확인한다(shot_bow.gd와
## 같은 패턴). tests/check_hand_sheets.gd가 파일 존재·규격은 이미
## 검사하므로 여기서는 "실제로 화면에 그려지는가"만 스크린샷으로 본다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	GameState.level = 60
	main._change_map("forest_w", false)

	for w in ["철검", "종언의 검", "천공의 검"]:
		GameState.inventory = [w]
		GameState.equip(w)
		main._apply_equipment_to_player()
		player.facing = Vector2.DOWN
		player.cooldown_time = 0.0
		player._update_sprite(Vector2.ZERO)
		player.attack()
		for i in 6:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			"user://shot_hand_%s.png" % w.replace(" ", "_"))
		print("SHOT hand_", w, " weapon_hand()=", GameState.weapon_hand())

	print("RESULT PASS - 3종 손그림 스크린샷 저장 완료")
	get_tree().quit()
