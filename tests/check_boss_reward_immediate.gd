## INBOX 지시(2026-10-20 23:42): 보스 격파 즉시 보상 + 장 전환 보상.
## main._on_boss_fallen()이 그 자리에서 골드·강화석·장비를 주고
## (GameState.boss_instant_reward) 다음 장 지역을 unlocked_maps 에
## 넣는지(CHAPTER_NEXT_MAP) 1~10장 전부 확인한다. 10장은 마지막 장이라
## 다음 지역이 없다.
extends Node

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


## main.gd _spawn_boss()가 실제로 그 장 보스를 꽂아 넣는 지역(world.gd
## AREAS[x]["boss"]==장번호). GameState.current_map 이 보스가 있는 지역과
## 맞아야 chapter_essence 지급 분기도 같은 경로로 탄다.
const CHAPTER_BOSS_MAP := {
	1: "cave_deep", 2: "citadel", 3: "temple", 4: "throne",
	5: "rift_of_origin", 6: "the_watcher_reef", 7: "sanctum_of_light",
	8: "chamber_of_wardens", 9: "throne_of_reversal", 10: "origin_throne",
}


func _ready() -> void:
	seed(1)
	var ok := true
	for ch in range(1, 11):
		GameState.reset()
		GameState.chapter = ch
		GameState.current_map = str(CHAPTER_BOSS_MAP[ch])
		var main: Node = preload("res://scenes/main.tscn").instantiate()
		add_child(main)
		await get_tree().process_frame
		while main.dialogue_open: main._advance_dialogue()
		var gold_before: int = GameState.gold
		var inv_before: int = GameState.inventory.size()
		var unlocked_before: int = GameState.unlocked_maps.size()
		main._on_boss_fallen()
		await get_tree().process_frame
		while main.dialogue_open: main._advance_dialogue()
		await get_tree().process_frame
		ok = _check("%d장 골드 즉시 증가" % ch, GameState.gold > gold_before) and ok
		ok = _check("%d장 인벤토리 즉시 증가" % ch, GameState.inventory.size() > inv_before) and ok

		## 결함(2026-10-20 19:50): 보스방은 재입장마다 다시 스폰한다 - 같은
		## 장 보스를 두 번째 처치하면(claimed_boss_rewards) 골드·quest_stage
		## 가 더는 바뀌면 안 된다(파편만).
		var gold_after_first: int = GameState.gold
		var quest_stage_after_first: int = GameState.quest_stage
		main._on_boss_fallen()
		await get_tree().process_frame
		while main.dialogue_open: main._advance_dialogue()
		await get_tree().process_frame
		ok = _check("%d장 같은 보스 2번째 처치 골드 불변" % ch,
			GameState.gold == gold_after_first) and ok
		ok = _check("%d장 같은 보스 2번째 처치 quest_stage 불변" % ch,
			GameState.quest_stage == quest_stage_after_first) and ok

		## 옛 장(ch-1) 보스방이 아직 남아 있어도(재입장 가능) 현재 장(ch)
		## 보스로 뒤바뀌어 처리되면 안 된다 - chapter·quest_stage 불변.
		if CHAPTER_BOSS_MAP.has(ch - 1):
			var chapter_before_old: int = GameState.chapter
			var quest_stage_before_old: int = GameState.quest_stage
			var gold_before_old: int = GameState.gold
			GameState.current_map = str(CHAPTER_BOSS_MAP[ch - 1])
			main._on_boss_fallen()
			await get_tree().process_frame
			while main.dialogue_open: main._advance_dialogue()
			await get_tree().process_frame
			ok = _check("%d장 옛(%d장) 보스방 처치 chapter 불변" % [ch, ch - 1],
				GameState.chapter == chapter_before_old) and ok
			ok = _check("%d장 옛(%d장) 보스방 처치 quest_stage 불변" % [ch, ch - 1],
				GameState.quest_stage == quest_stage_before_old) and ok
			ok = _check("%d장 옛(%d장) 보스방 처치 골드 불변" % [ch, ch - 1],
				GameState.gold == gold_before_old) and ok

		if main.CHAPTER_NEXT_MAP.has(ch):
			var next_map: String = str(main.CHAPTER_NEXT_MAP[ch])
			ok = _check("%d장 다음 지역(%s) 즉시 개방" % [ch, next_map],
				GameState.unlocked_maps.has(next_map)) and ok
		else:
			ok = _check("%d장(마지막) 새 지역 개방 없음" % ch,
				GameState.unlocked_maps.size() == unlocked_before) and ok
		main.queue_free()
		await get_tree().process_frame

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
