extends Node
## INBOX 보스 표시 재현용. main._spawn_boss()를 직접 호출해 보스 스폰과 렌더링을 검증

func _ready() -> void:
	# Godot 4.7에서 테스트 씬은 PROCESS_MODE_ALWAYS로 동작하므로
	# 즉시 quit 하지 않고, 프레임 대기 후 보스 스폰을 호출
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.chapter = 2
	GameState.quest_stage = 11
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(main):
		push_error("main scene failed to instantiate")
		get_tree().quit()
		return
	GameState.current_map = "citadel"
	print("SHOT_BEFORE_SPAWN map=%s" % GameState.current_map)
	# 자동 맵 루틴은 대화/일시정지에 영향을 받으므로, 테스트에서는
	# 플레이어와 카메라를 보스 좌표에 맞춘 뒤 스폰 함수만 검증한다.
	main.get_node("Player").global_position = Vector2(216, 110)
	main._spawn_boss()
	print("SHOT_AFTER_SPAWN boss_spawned=%s" % main.boss_spawned)
	# 보스가 스폰되고 렌더링될 때까지 대기
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shot_chapter2_boss_spawned.png")
	var bosses := get_tree().get_nodes_in_group("enemies")
	print("SHOT_BOSS_SPAWNED boss_spawned=%s enemies=%d" % [main.boss_spawned, bosses.size()])
	for enemy in bosses:
		print("SHOT_ENEMY pos=%s visible=%s sprite_visible=%s" % [enemy.global_position, enemy.visible, enemy.get_node("Sprite").visible])
