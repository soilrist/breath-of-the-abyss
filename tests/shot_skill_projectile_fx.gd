extends Node
## (루프, 2026-10-20) INBOX 17:45 3층 — 표창 던지기(도적, projectile: true)가
## 몸에서만 번쩍이고 끝나지 않고, 실제로 날아가 적 위에서 터지는지 찍는다.
## ① 시전 직후(작은 몸 번쩍임) ② 비행 중(화살이 적 쪽으로 이동) ③ 착탄(적
## 위치에서 터지는 FX) 세 장을 같은 장면에서 이어 찍는다.

func _ready() -> void:
	GameState.reset()
	GameState.level = 15
	GameState.change_job("rogue")
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var guard := 0
	while main.dialogue_open and guard < 50:
		main._advance_dialogue()
		guard += 1
	main._change_map("forest_w", false)
	guard = 0
	while main.dialogue_open and guard < 50:
		main._advance_dialogue()
		guard += 1
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()
	await get_tree().process_frame

	var player: CharacterBody2D = main.get_node("Player")
	player.mana = 999
	player.max_mana = 999
	player.facing = Vector2.RIGHT
	player.skill_cooldowns = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0] as Array[float]

	var enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
	enemy.max_health = 9999
	enemy.health = 9999
	enemy.defense = 0
	main.get_node("World").add_child(enemy)
	enemy.global_position = player.global_position + Vector2(60, 0)
	await get_tree().process_frame

	var skills: Array = GameState.active_skills()
	var shuriken_idx := -1
	for i in skills.size():
		if str(skills[i].get("id", "")) == "shuriken":
			shuriken_idx = i
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_skill_projectile_before.png")
	print("SHOT skill_projectile before")

	player.cast_skill(shuriken_idx)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_skill_projectile_cast.png")
	print("SHOT skill_projectile cast")

	# 시전 은색 별이 지워지지 않고 빠르게(약 0.05초) 사라지는지(INBOX
	# 2026-10-20 22:15) — 0.1초 뒤엔 주인공 몸 위에 별이 없어야 한다.
	await get_tree().create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_skill_projectile_cast_0_1.png")
	print("SHOT skill_projectile cast_0_1")

	for i in 3:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_skill_projectile_flight.png")
	print("SHOT skill_projectile flight")

	var hp_before: int = enemy.health
	for _tick in 60:
		await get_tree().physics_frame
		if enemy.health < hp_before:
			break
	for i in 3:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_skill_projectile_impact.png")
	print("SHOT skill_projectile impact")

	# 착탄 뒤 0.05초·0.2초 — 표창이 적에 박혀 돌아야 한다(INBOX 2026-10-20
	# 21:55). 0.4초(embed 0.3초 지남) 뒤엔 사라져 있어야 한다.
	await get_tree().create_timer(0.05).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_skill_projectile_impact_0_05.png")
	print("SHOT skill_projectile impact_0_05")

	await get_tree().create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_skill_projectile_impact_0_2.png")
	print("SHOT skill_projectile impact_0_2")

	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_skill_projectile_impact_0_4.png")
	print("SHOT skill_projectile impact_0_4")

	# 독침(poison_dart, Lv12 슬롯)도 같은 방식으로 날려 회전 칸이 아니라
	# 화살 그림으로 날아가지 않는지 따로 찍는다(INBOX 2026-10-20 불합격분).
	enemy.health = 9999
	enemy.global_position = player.global_position + Vector2(60, 0)
	player.skill_cooldowns = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0] as Array[float]
	var dart_idx := -1
	for i in skills.size():
		if str(skills[i].get("id", "")) == "poison_dart":
			dart_idx = i
	player.cast_skill(dart_idx)
	for i in 3:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_skill_projectile_dart_flight.png")
	print("SHOT skill_projectile dart_flight")

	get_tree().quit()
