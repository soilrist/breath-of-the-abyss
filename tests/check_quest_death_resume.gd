extends Node
## AUTOHUNT_DESIGN.md §10.7(INBOX 답, 2026-09-06 23:16) 검증.
## 통과 중(goal_reached) 사망 -> 마을 부활 -> 같은 길 재진입 -> 사망의 무한
## 순환을 끊는 고침: `_quest_handle_death()`가 `_apply_death_penalty()`를
## 부르기 **전**(`GameState.current_map`이 아직 죽은 지역인 시점)에 그 지역의
## 이전 지역("w" 방향, `World.exit_of`)을 `_quest_resume_zone`으로 잡는다 -
## 후퇴 포기(`_quest_do_retreat` giveup 가지)와 같은 메커니즘 재사용, 새
## 상수·새 상태·새 함수 없음.
## (1) forest_w에서 사망 -> resume_zone=hill_ridge(그 지역의 이전 지역),
##     quest_mode 유지, 마을(village) 부활.
## (2) prev가 unlocked_maps에 없으면 resume_zone을 잡지 않는다.
## (3) hill에서 사망 -> prev=village는 마을이므로 resume_zone을 잡지 않는다
##     (재개할 사냥터가 아니다).

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	GameState.reset()
	GameState.chapter = 1
	GameState.unlock_map("hill")
	GameState.unlock_map("hill_ridge")
	GameState.unlock_map("forest_w")
	main.quest_mode = true
	player.max_health = 100
	player.health = 100

	# (1) forest_w에서 사망 -> resume_zone=hill_ridge, quest_mode 유지, village 부활.
	GameState.current_map = "forest_w"
	GameState.kills = 6
	main._quest_resume_zone = ""
	main._quest_death_streak = 0
	main._quest_kills_at_last_death = -1
	main._quest_handle_death()
	await get_tree().process_frame
	ok = _check("(1) forest_w 사망 -> resume_zone=hill_ridge(이전 지역)",
		main._quest_resume_zone == "hill_ridge") and ok
	ok = _check("(1) forest_w 사망 -> quest_mode 유지", main.quest_mode == true) and ok
	ok = _check("(1) forest_w 사망 -> village에서 부활", GameState.current_map == "village") and ok

	# (2) prev(hill_ridge)가 unlocked_maps에 없으면 resume_zone을 잡지 않는다.
	GameState.unlocked_maps.erase("hill_ridge")
	GameState.current_map = "forest_w"
	main._quest_resume_zone = ""
	main._quest_death_streak = 0
	main._quest_kills_at_last_death = -1
	main._quest_handle_death()
	await get_tree().process_frame
	ok = _check("(2) prev 미해금 -> resume_zone 안 잡음", main._quest_resume_zone == "") and ok
	GameState.unlock_map("hill_ridge")

	# (3) hill에서 사망 -> prev=village는 마을이므로 resume_zone을 잡지 않는다.
	GameState.current_map = "hill"
	main._quest_resume_zone = ""
	main._quest_death_streak = 0
	main._quest_kills_at_last_death = -1
	main._quest_handle_death()
	await get_tree().process_frame
	ok = _check("(3) hill 사망 -> prev(village)는 마을 -> resume_zone 안 잡음",
		main._quest_resume_zone == "") and ok
	ok = _check("(3) hill 사망 -> quest_mode 유지", main.quest_mode == true) and ok

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
