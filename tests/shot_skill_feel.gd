extends Node
## (루프, 2026-10-20) 스킬·처치 손맛 눈으로 보기 — 재촬영(결함 2026-10-20 14:40).
## 이전 캡처는 적 40마리가 겹친 forest_w 시험 장면 + 디버그 피해 99999 숫자라
## 스킬 팝인·사망 트윈이 구분이 안 됐다. 이번엔 적 1~2마리만 둔 깨끗한 장면에서
## 발동·처치 각각 0/0.05/0.1초 3장 + 플레이어 주변 2배 확대 1장을 찍는다.
func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	GameState.reset()
	var guard := 0
	while main.dialogue_open and guard < 50:
		main._advance_dialogue()
		guard += 1
	main._change_map("forest_w", false)
	guard = 0
	while main.dialogue_open and guard < 50:
		main._advance_dialogue()
		guard += 1
	# forest_w 는 _change_map 이 지역 고정 스폰점을 전부 깐다 — 깨끗한 장면을
	# 위해 전부 치우고 이번 촬영용 1~2마리만 손으로 둔다.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()
	await get_tree().process_frame

	var player: CharacterBody2D = main.get_node("Player")
	GameState.level = 20
	player.mana = 999
	player.max_mana = 999
	player.facing = Vector2.DOWN

	# 1. 스킬 발동 — 0 / 0.05 / 0.1초 (3 / 6틱, 60fps 기준).
	var slot := 0
	player.skill_cooldowns[slot] = 0.0
	player.cast_skill(slot)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_skill_feel_cast_0.png")
	for i in 3:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_skill_feel_cast_1.png")
	for i in 3:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_skill_feel_cast_2.png")
	print("SHOT cast 3")

	# 2. 적 1마리만 둔 처치 — 실제 체력값으로 일격사(디버그 99999 금지), 0 / 0.05 / 0.1초.
	var enemy: CharacterBody2D = preload("res://scenes/enemy.tscn").instantiate()
	enemy.archetype = "beast"
	enemy.area_id = GameState.current_map
	enemy.max_health = 40
	enemy.health = 40
	enemy.position = player.global_position + Vector2(20, 0)
	main.add_child(enemy)
	await get_tree().physics_frame
	enemy.take_damage(enemy.health, Vector2.RIGHT, false)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_skill_feel_death_0.png")
	for i in 3:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_skill_feel_death_1.png")
	for i in 3:
		await get_tree().physics_frame
	print("DEATH alive=", is_instance_valid(enemy), " alpha=", (enemy.modulate.a if is_instance_valid(enemy) else -1.0))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_skill_feel_death_2.png")
	print("SHOT death 3")

	# 3. 플레이어 주변 2배 확대(zoom 2.0) — 사망 파편·흰 번쩍이 축소 화면에서도
	# 보이는지 확인용 한 장. 카메라 limit(0~320,0~240)에 안 걸리게 맵 가운데로
	# 옮긴 뒤 적 1마리를 다시 둬 처치 순간을 잡는다.
	var camera: Camera2D = player.get_node("Camera2D")
	var zoom_before := camera.zoom
	camera.zoom = Vector2(2.0, 2.0)
	player.global_position = Vector2(160, 120)
	var enemy2: CharacterBody2D = preload("res://scenes/enemy.tscn").instantiate()
	enemy2.archetype = "beast"
	enemy2.area_id = GameState.current_map
	enemy2.max_health = 40
	enemy2.health = 40
	enemy2.position = player.global_position + Vector2(16, 0)
	main.add_child(enemy2)
	await get_tree().physics_frame
	enemy2.take_damage(enemy2.health, Vector2.RIGHT, false)
	await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_skill_feel_closeup.png")
	print("SHOT closeup")
	camera.zoom = zoom_before
	get_tree().quit()
