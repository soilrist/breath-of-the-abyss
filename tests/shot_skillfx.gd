extends Node
## 스킬 넷이 서로 다른 이펙트를 내는지 눈으로 본다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	GameState.level = 20
	GameState.equipped = {"weapon": "철검", "armor": "", "helmet": "", "trinket": ""}
	GameState._recalc_bonuses()
	main._apply_equipment_to_player()
	main._change_map("forest_w", false)
	player.mana = 999
	player.max_mana = 999

	for slot in range(GameState.SKILLS.size()):
		var data: Dictionary = GameState.SKILLS[slot]
		player.facing = Vector2.DOWN
		player.skill_cooldowns[slot] = 0.0
		player.mana = 999
		player.cast_skill(slot)
		# 이펙트가 커지는 중간 프레임에서 찍는다.
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://fx_%s.png" % str(data["id"]))
		print("SHOT ", data["id"])
		await get_tree().create_timer(0.5).timeout
	get_tree().quit()
