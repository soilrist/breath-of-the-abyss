## INBOX 지시(2026-10-20 23:42) 3층 캡처: 보스를 실제로 쳐서 죽인 뒤
## "보스 격파 보상!" 상자 배너가 실제로 뜨는지 눈으로 본다
## (check_boss_persist_on_reentry.gd와 같은 방식으로 직접 공격해 처치).
extends Node

func _ready() -> void:
	GameState.chapter = 1
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	main._change_map("cave_deep", false)
	await get_tree().process_frame
	var boss: Node = null
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_boss:
			boss = enemy
	print("SHOT boss_found=%s" % (boss != null))
	if boss != null:
		var player: CharacterBody2D = main.get_node("Player")
		player.global_position = boss.global_position + Vector2(boss.body_radius() + 5.0, 0.0)
		player.attack_damage = 400
		player.facing = Vector2.LEFT
		for i in 40:
			if not is_instance_valid(boss):
				break
			player.cooldown_time = 0.0
			player.attack()
			await get_tree().physics_frame
		var guard := 0
		while main.dialogue_open and guard < 20:
			main._advance_dialogue()
			await get_tree().process_frame
			guard += 1
	# LEVEL_REWARD_BOX_DELAY(2.0초) 뒤 상자가 뜬다(열기 전 모습을 찍는다 -
	# 열리는 연출·보상 줄 가독성은 #9 에서 이미 검증한 같은 LevelRewardBox
	# 코드라 다시 찍지 않는다). 헤드리스는 frame_post_draw 가 안 와(렌더링
	# 백엔드 제한, docs/checks/godot.md 28행) - 반드시 창 띄워 실행한다.
	await get_tree().create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://boss_reward_banner.png")
	print("SHOT boss_reward_banner")
	get_tree().quit()
