extends Node
## 10장_근원_DESIGN.md "보스" 다단계 연출(가배치, 2026-09-05)이 실제 화면에서
## 보이는지 확인. shot_chapter1_boss.gd와 같은 원칙 — 대화는 실제 E 키
## 입력으로 넘기고, 진짜 전투 화면을 찍는다. 플레이어는 무적으로 세워
## 10장 보스(공격력 350, 2026-10-20 INBOX 00:11로 하향)에게 죽어 마을로
## 되돌아가는 것만 막는다.

func _press_e() -> void:
	var down := InputEventKey.new()
	down.physical_keycode = KEY_E
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.physical_keycode = KEY_E
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _ready() -> void:
	GameState.chapter = 10
	GameState.unlock_map("origin_throne")
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var guard0 := 0
	while main.dialogue_open and guard0 < 20:
		await _press_e()
		guard0 += 1
	main._change_map("origin_throne", false)
	await get_tree().create_timer(0.4).timeout
	var guard := 0
	while main.dialogue_open and guard < 20:
		await _press_e()
		guard += 1

	var boss: Node = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_boss:
			boss = e
			break
	if boss == null:
		print("SHOT origin_boss_phase FAIL: 보스가 스폰되지 않음")
		get_tree().quit(1)
		return
	var player: Node = main.get_node("Player")
	player.invulnerability_time = 999.0
	boss.global_position = Vector2(216, 110)
	player.global_position = Vector2(216, 130)

	await get_tree().physics_frame
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://origin_boss_phase0.png")
	print("SHOT origin_boss_phase0 tint=%s phase=%d" % [boss.get_node("Sprite").modulate, boss.boss_phase])

	boss.health = int(boss.max_health * 0.65)
	await get_tree().physics_frame
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://origin_boss_phase1.png")
	print("SHOT origin_boss_phase1 tint=%s phase=%d" % [boss.get_node("Sprite").modulate, boss.boss_phase])

	boss.health = int(boss.max_health * 0.25)
	await get_tree().physics_frame
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://origin_boss_phase2.png")
	print("SHOT origin_boss_phase2 tint=%s phase=%d" % [boss.get_node("Sprite").modulate, boss.boss_phase])
	get_tree().quit()
