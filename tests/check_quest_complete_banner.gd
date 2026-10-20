extends Node
## 퀘스트 완료도 같은 상자 배너로(INBOX 2026-10-20 00:10 나머지 절반). 의뢰
## (bounty) 완료 시 `LevelRewardBox`를 "퀘스트 완료!" 제목으로 큐에 쌓는지,
## 레벨 보상과 제목이 서로 안 섞이는지 단언한다.

func _ready() -> void:
	GameState.reset()
	# quest_stage==1 은 main.gd _interact_npc()의 어느 메인 스토리 분기에도
	# 안 걸려(0,2,3,4,5,7,9,10,19... 목록에 1이 없다) bounty_done() 분기로
	# 바로 떨어진다.
	GameState.quest_stage = 1
	GameState.take_bounty()
	var bounty: Dictionary = GameState.current_bounty()
	GameState.bounty_progress = int(bounty["count"])
	var ok := true
	ok = _check("의뢰 완료 상태", GameState.bounty_done()) and ok

	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var gold_before: int = GameState.gold
	main.get_node("Player").global_position = World.town_npc_position(GameState.current_map, "elder")
	main._interact_npc()
	ok = _check("대화가 열림(보상 안내)", main.dialogue_open) and ok
	ok = _check("의뢰 보상은 대화가 끝난 뒤에만 쌓임(아직 비어 있어야 함)",
		main._level_reward_queue.is_empty()) and ok
	while main.dialogue_open: main._advance_dialogue()

	ok = _check("의뢰 골드가 실제로 들어옴(실제: %d→%d)" % [gold_before, GameState.gold],
		GameState.gold > gold_before) and ok
	ok = _check("대화가 끝나면 큐에 보상이 쌓임", not main._level_reward_queue.is_empty()) and ok
	if not main._level_reward_queue.is_empty():
		var entry: Dictionary = main._level_reward_queue[0]
		ok = _check("제목이 '퀘스트 완료!'(실제: %s)" % str(entry.get("title", "")),
			str(entry.get("title", "")) == "퀘스트 완료!") and ok
		var reward: Dictionary = entry.get("reward", {})
		ok = _check("보상에 의뢰 이름이 들어 있음(실제: %s)" % str(reward.get("quest_label", "")),
			str(reward.get("quest_label", "")) == str(bounty["label"])) and ok
		ok = _check("보상에 아이템이 들어 있음(실제: %s)" % str(reward.get("item", "")),
			str(reward.get("item", "")) == str(bounty["item"])) and ok

	# 레벨업 보상(제목 기본값)과 퀘스트 완료 보상(제목 "퀘스트 완료!")이
	# 큐에서 서로 다른 제목을 유지하는지 - 같은 상자를 공유해도 안 섞임.
	main._level_reward_queue.clear()
	main._queue_level_reward_box({"item": "", "gold": 10, "stones": 1})
	main._queue_level_reward_box({"item": "", "gold": 5, "quest_label": "다른 의뢰"}, "퀘스트 완료!")
	ok = _check("두 보상이 각자 제목을 유지(실제: %s)" % str([main._level_reward_queue[0]["title"], main._level_reward_queue[1]["title"]]),
		main._level_reward_queue[0]["title"] == "레벨 보상 상자!" and main._level_reward_queue[1]["title"] == "퀘스트 완료!") and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
