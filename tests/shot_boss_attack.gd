extends Node
## (감독, 2026-09-10) 보스 근접 공격 모션 눈으로 확인용: 예비동작(뒤로 젖힘+색)
## 한 장, 타격 직후(전진 + 플레이어 위치 붉은 베기 궤적) 한 장.
func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	GameState.reset()
	while main.dialogue_open:
		main._advance_dialogue()
	GameState.chapter = 2
	main._change_map("village", false)
	while main.dialogue_open:
		main._advance_dialogue()
	var player: CharacterBody2D = main.get_node("Player")
	player.max_health = 9999
	player.health = 9999
	var boss: CharacterBody2D = preload("res://scenes/enemy.tscn").instantiate()
	boss.is_boss = true
	boss.archetype = "beast"
	boss.area_id = GameState.current_map
	boss.position = player.global_position + Vector2(44, 0)
	main.add_child(boss)
	boss.attack_time = 99.0
	boss.special_time = 0.0
	for i in 3:
		await get_tree().physics_frame
	print("SWING=", boss.swing, " special=", boss.swing_special, " offset=", boss.get_node("Sprite").offset)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_boss_windup.png")
	for i in 90:
		await get_tree().physics_frame
		if player.health < player.max_health:
			break
	print("HIT hp=", player.health, " boss_pos=", boss.global_position)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_boss_hit.png")
	print("SHOT ", ProjectSettings.globalize_path("user://shot_boss_hit.png"))
	get_tree().quit()
