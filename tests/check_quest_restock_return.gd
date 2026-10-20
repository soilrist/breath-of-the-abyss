extends Node
## AUTOHUNT_DESIGN.md §10.7(INBOX 답, 2026-09-07 00:45) 검증.
## 물약 조기 귀환(`_quest_mode_tick()` 사냥터 분기, potions<=0·gold>=가격)이
## 마을로 돌려보내기 직전 있던 지역을 `_quest_resume_zone`(한 티어 아래·
## 그라인드)이 아니라 새 변수 `_quest_restock_zone`에 기억해 두고, 마을에서
## 물약을 채운 직후(그라인드 없이) 그 자리로 바로 돌아가는지 확인한다.
## (1) 사냥터(dungeon)·potions 0·gold>=가격 -> 귀환 호출, map=village,
##     _quest_restock_zone=="dungeon".
## (2) 마을 틱 1회 -> 물약 MAX 구매, map=="dungeon"(그 자리로 복귀),
##     _quest_restock_zone==""·_quest_grind_zone=="" (그라인드 아님).
## (3) 마을·potions 0·gold<가격·restock_zone="dungeon" -> 텔레포트 없이
##     기존 동쪽 걷기 유지(자금 없으면 못 사고 나간다).

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
	GameState.quest_stage = 1
	GameState.unlock_map("village")
	GameState.unlock_map("hill")
	GameState.unlock_map("hill_ridge")
	GameState.unlock_map("forest_w")
	GameState.unlock_map("glade")
	GameState.unlock_map("dungeon")
	main.quest_mode = true
	player.max_health = 100
	player.health = 100

	# (1) 사냥터(dungeon)에서 potions=0, gold>=가격 -> 귀환.
	var price: int = main._quest_potion_price()
	GameState.current_map = "dungeon"
	GameState.potions = 0
	GameState.gold = price * (GameState.MAX_POTIONS + 5)
	main._quest_restock_zone = ""
	main._quest_resume_zone = ""
	main._quest_mode_tick()
	await get_tree().process_frame
	ok = _check("(1) dungeon potions=0·gold>=가격 -> village로 귀환", GameState.current_map == "village") and ok
	ok = _check("(1) _quest_restock_zone==\"dungeon\"", main._quest_restock_zone == "dungeon") and ok

	# (2) 마을 틱 1회 -> 물약 MAX 구매 + 그 자리(dungeon)로 그라인드 없이 복귀.
	main._quest_grind_zone = ""
	main._quest_mode_tick()
	await get_tree().process_frame
	ok = _check("(2) 물약 MAX 구매", GameState.potions == GameState.MAX_POTIONS) and ok
	ok = _check("(2) dungeon으로 복귀", GameState.current_map == "dungeon") and ok
	ok = _check("(2) _quest_restock_zone 소비됨", main._quest_restock_zone == "") and ok
	ok = _check("(2) _quest_grind_zone 그대로 빈 값(그라인드 아님)", main._quest_grind_zone == "") and ok

	# (3) 마을·potions 0·gold<가격·restock_zone 있음 -> 텔레포트 없이 동쪽 걷기.
	GameState.current_map = "village"
	GameState.potions = 0
	GameState.gold = price - 1
	main._quest_restock_zone = "dungeon"
	main._quest_mode_tick()
	await get_tree().process_frame
	ok = _check("(3) gold<가격 -> village에 그대로(텔레포트 없음)", GameState.current_map == "village") and ok
	ok = _check("(3) restock_zone 그대로 남음(소비 안 됨)", main._quest_restock_zone == "dungeon") and ok
	ok = _check("(3) 동쪽 걷기 유지", player.auto_walk_active == true) and ok

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
