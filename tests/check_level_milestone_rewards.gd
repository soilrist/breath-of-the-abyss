extends Node
## 레벨 단계별 보상(INBOX 2026-10-20 00:10). 5레벨마다 상자(장비+골드+강화석),
## 10레벨마다 칭호+물약 상한 증가. 같은 단계 재지급 0, 옛 세이브는 지난
## 단계를 한 번만 소급 지급하는지 단언한다.

func _ready() -> void:
	GameState.reset()
	var ok := true

	# 순수 함수: 4까지는 5단위 마일스톤이 없다.
	ok = _check("Lv4 까지는 보상 없음", GameState.claim_level_milestones(4).is_empty()) and ok

	var r5: Array = GameState.claim_level_milestones(5)
	ok = _check("Lv5 에서 보상 1개", r5.size() == 1) and ok
	if r5.size() == 1:
		ok = _check("Lv5 보상엔 칭호 없음", str(r5[0].get("title", "")) == "") and ok
		ok = _check("Lv5 보상 골드 > 0", int(r5[0].get("gold", 0)) > 0) and ok
		ok = _check("Lv5 보상 강화석 > 0", int(r5[0].get("stones", 0)) > 0) and ok
		var item := str(r5[0].get("item", ""))
		ok = _check("Lv5 보상 장비가 레어 이상(실제: %s)" % item,
			item != "" and GameState.rarity_rank(item) >= GameState.RARITY_ORDER.find("레어")) and ok

	# 같은 단계 재지급 0.
	ok = _check("Lv5 재호출은 중복 지급 0", GameState.claim_level_milestones(5).is_empty()) and ok

	var r10: Array = GameState.claim_level_milestones(10)
	ok = _check("Lv10 에서 보상 1개(5는 이미 받음)", r10.size() == 1) and ok
	if r10.size() == 1:
		ok = _check("Lv10 보상엔 칭호 있음(실제: %s)" % str(r10[0].get("title", "")),
			str(r10[0].get("title", "")) != "") and ok
		ok = _check("Lv10 보상에 큰 보상 문구 있음", str(r10[0].get("big_reward", "")) != "") and ok
	ok = _check("Lv10 칭호가 level_titles에 기록됨(실제: %s)" % str(GameState.level_titles),
		not GameState.level_titles.is_empty()) and ok
	ok = _check("물약 상한이 10 늘어남(실제: %d)" % GameState.potion_cap(), GameState.potion_cap() == GameState.MAX_POTIONS + 10) and ok

	# 옛 세이브 소급: claimed_level_milestones가 비어 있는데 level만 12인 상태.
	GameState.reset()
	GameState.level = 12
	var backfill: Array = GameState.claim_level_milestones(GameState.level)
	ok = _check("소급 지급은 Lv5·Lv10 두 번(실제: %d개)" % backfill.size(), backfill.size() == 2) and ok
	ok = _check("소급 지급 뒤 재호출은 중복 0", GameState.claim_level_milestones(GameState.level).is_empty()) and ok

	# 실제 씬에서 레벨업 시 인벤토리·골드가 실제로 늘어나는지(main._on_enemy_defeated 경로).
	GameState.reset()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var inv_before: int = GameState.inventory.size()
	var gold_before: int = GameState.gold
	var stones_before: int = GameState.materials[GameState.MATERIAL]
	while GameState.level < 5:
		main._on_enemy_defeated(GameState.next_exp, 0)
	ok = _check("Lv5 도달 시 인벤토리가 늘어남(실제: %d→%d)" % [inv_before, GameState.inventory.size()],
		GameState.inventory.size() > inv_before) and ok
	ok = _check("Lv5 도달 시 골드가 늘어남(실제: %d→%d)" % [gold_before, GameState.gold],
		GameState.gold > gold_before) and ok
	ok = _check("Lv5 도달 시 강화석이 늘어남(실제: %d→%d)" % [stones_before, GameState.materials[GameState.MATERIAL]],
		GameState.materials[GameState.MATERIAL] > stones_before) and ok
	ok = _check("상자 큐에 레벨업 보상이 쌓임", not main._level_reward_queue.is_empty()) and ok

	# 옛 세이브 소급이 실제 불러오기 경로(main._load_current_game)에서도
	# 일어나는지 - 세이브 데이터를 손으로 만들어 claimed_level_milestones를
	# 지우고 올린다(이 기능 전에 저장된 파일 흉내).
	GameState.reset()
	GameState.level = 12
	GameState.save_game(main.get_node("Player"))
	var save_file := GameState.save_path()
	var read_file := FileAccess.open(save_file, FileAccess.READ)
	var raw: Dictionary = JSON.parse_string(read_file.get_as_text())
	read_file.close()
	raw.erase("claimed_level_milestones")
	var write_file := FileAccess.open(save_file, FileAccess.WRITE)
	write_file.store_string(JSON.stringify(raw))
	write_file.close()
	GameState.reset()
	main._load_current_game()
	ok = _check("옛 세이브 불러오면 Lv5·Lv10 소급 지급됨(실제: %s)" % str(GameState.claimed_level_milestones),
		GameState.claimed_level_milestones.has(5) and GameState.claimed_level_milestones.has(10)) and ok
	ok = _check("소급 보상도 상자 큐에 쌓임", not main._level_reward_queue.is_empty()) and ok
	if FileAccess.file_exists(save_file):
		DirAccess.remove_absolute(save_file)

	# 결함(감독, 2026-10-20 03:28): 보상 줄이 스킬 줄(y170~)과 고리 빛(glow)
	# 둘 다와 안 겹치는지 - Rect 는 늘 스킬 줄 위, 글자는 glow 가 사라진
	# 뒤에만 보이는지 단언한다.
	var box: LevelRewardBox = LevelRewardBox.new()
	add_child(box)
	await get_tree().process_frame
	box.show_reward({"quest_label": "독버섯 토벌", "item": "가죽 모자", "gold": 60, "stones": 0})
	box._open()
	var reward_lines: VBoxContainer = box._reward_lines
	ok = _check("보상 줄 Rect 가 스킬 줄(y170) 위에서 끝남(실제: %.1f)" % (reward_lines.position.y + reward_lines.size.y),
		reward_lines.position.y + reward_lines.size.y <= 170.0) and ok
	# 흔들림(0.3초) 뒤 터지는 순간: glow 가 아직 안 꺼졌으니 글자는 숨겨져 있어야 함.
	await get_tree().create_timer(0.35).timeout
	ok = _check("터지는 순간엔 고리 빛이 아직 있어 글자가 숨겨짐", not reward_lines.visible) and ok
	# glow(4프레임×0.07초=0.28초) 가 다 꺼진 뒤엔 글자가 보여야 함.
	await get_tree().create_timer(0.35).timeout
	ok = _check("고리 빛이 꺼진 뒤엔 글자가 보임", reward_lines.visible) and ok
	box.queue_free()

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
