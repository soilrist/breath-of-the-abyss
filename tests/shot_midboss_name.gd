extends Node
## 중간보스 이름표("<몬스터 이름> (중간보스)")가 실제 화면에서 잘리거나
## 옆 몬스터와 겹치지 않는지 확인한다. 지금까지는 `has_midboss()`로 존재
## 여부만 함수 호출로 확인했지 렌더링을 본 적이 없었다(⑥ 규칙 위반 소지).
## `echo_of_captain`(9장)은 MIDBOSS_AREAS 중 중간보스 라벨이 가장 긴 곳
## (twisted_knight="뒤틀린 흑기사", 접미사 붙이면 "뒤틀린 흑기사 (중간보스)")
## 이라 이름표 폭(44px, 폰트 7) 초과 위험이 가장 크다.

func _ready() -> void:
	GameState.chapter = 9
	GameState.chapter_kills = 0
	GameState.quest_stage = 51
	GameState.unlock_map("echo_of_captain")
	GameState.current_map = "echo_of_captain"
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		main._advance_dialogue()
	main._change_map("echo_of_captain", false)
	await get_tree().create_timer(0.4).timeout

	var midboss: Node = null
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_midboss:
			midboss = enemy
			break
	print("MIDBOSS_FOUND=%s label=%s" % [midboss != null, midboss.get_node("Name").text if midboss else ""])
	if midboss:
		var player := main.get_node("Player")
		player.max_health = 999999
		player.health = 999999
		# 화면 좌하단에 고정된 가상 조이스틱과 겹치지 않도록 화면 중앙 쪽으로 옮긴다.
		var center := Vector2(World.size_of("echo_of_captain")) * World.TILE / 2.0
		midboss.global_position = center
		player.global_position = center + Vector2(0, 40)

	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://midboss_name.png")
	print("SHOT midboss_name")
	get_tree().quit()
