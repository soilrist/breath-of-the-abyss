extends Node
## (결함 조사, INBOX 2026-10-20 00:11) 10장 최종보스 origin_throne 반복 사망
## 원인을 가른다: ①자동전투가 보스 원거리(volley, homing) 공격을 못 보는지
## ②순수 난이도인지. 전체 1~9장을 다시 돌리면(auto_quest_probe) 벽시계로
## 수십 분~시간이 걸려 보스방만 직행하되, 사람이 아니라 실제 `auto_quest_probe
## --seed=1`이 10장에 들어설 때 가진 장비·능력치·스킬(전용 슬롯 99 스냅샷,
## `GameState.CHAPTER10_SNAPSHOT_SLOT`)을 그대로 읽어 재현한다 - 스냅샷이
## 없으면(그 바퀴를 아직 안 돌렸으면) archive 실측값(level=23, hp_max=844,
## potions=21)으로 폴백한다. player.last_hit_source로 사인을 직접 찍는다.

const SIM_FRAMES := 21600 ## 게임 6분(퀘스트틱 600개) - auto_quest_probe STALL_FRAMES와 같은 예산


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
	GameState.reset()
	# (감독 06:30 재검수) archive 하드코딩 값은 GameState.level만 넣고 장비·능력치
	# 배분이 없어(방어 0) 실제 seed=1 플레이(장비 있음)와 다른 사람이었다.
	# `auto_quest_probe --seed=1`이 10장 진입 때 전용 슬롯(99)에 떠 둔 실제
	# GameState(장비·능력치·스킬)가 있으면 그걸 읽는다 - 없으면(아직 그 바퀴를
	# 안 돌렸으면) 예전 archive 하드코딩 값으로 폴백한다.
	var snapshot_path := GameState.save_path(GameState.CHAPTER10_SNAPSHOT_SLOT)
	var has_snapshot := FileAccess.file_exists(snapshot_path)
	if not has_snapshot:
		GameState.chapter = 10
		GameState.level = 23
		GameState.potions = 21
		GameState.gold = 80104
	GameState.unlock_map("origin_throne")
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var player: Node = main.get_node("Player")
	if has_snapshot:
		GameState.slot = GameState.CHAPTER10_SNAPSHOT_SLOT
		GameState.load_game(player)
		GameState.chapter = 10
		GameState.unlock_map("origin_throne")
		# `load_game()`는 player.health/mana/max_health 등만 되돌리고 potions는
		# main.gd `_ready()`가 이미 (로드 전 기본값으로) 한 번 동기화해 둔 뒤라
		# `player.potions`가 그대로 남는다 - 직접 다시 맞춘다.
		player.potions = GameState.potions
		print("USING_CHAPTER10_SNAPSHOT path=", snapshot_path, " level=", GameState.level,
			" job=", GameState.job, " second_job=", GameState.second_job, " stats=", GameState.stats,
			" weapon=", GameState.weapon, " armor=", GameState.armor,
			" max_health=", player.max_health, " potions=", GameState.potions)
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
		print("RESULT FAIL - 보스가 스폰되지 않음")
		get_tree().quit(1)
		return

	if not has_snapshot:
		# archive 실측 조건(level=23, hp_max=844)을 그대로 - 레벨→HP 환산식은
		# 이번 조사와 무관해(기존 공식 그대로 23렙에 도달했을 값) 직접 덮어쓴다.
		player.max_health = 844
		player.health = 844
	boss.global_position = Vector2(216, 110)
	player.global_position = Vector2(216, 130)
	main.quest_mode = true
	player.auto_hunt = true

	var deaths := 0
	var last_death_count: int = main.quest_death_count
	var hits := {}
	# (감독 05:30 재검수) 소모한 물약 수는 restock(자동 구매)로 늘어날 수도 있는
	# gold=80104 조건이라, 21에서 끝값을 빼면 음수가 나올 수 있다 - 줄어들 때만
	# 더해서 실제로 "마신" 횟수를 센다.
	var potions_quaffed := 0
	var start_potions: int = player.potions
	var last_potions: int = player.potions
	# (INBOX 2026-10-20 00:11 #13 "합성 스냅샷 5회 중 3회 이상 이기면") 보스가
	# 죽으면(5번 사망을 다 쓰기 전에) 이김으로 바로 끝낸다 - 예전엔 "죽음 5번"만
	# 종료 조건이라 이겨도 계속 돌았다.
	var boss_won := false
	for i in SIM_FRAMES:
		if not is_instance_valid(main) or not main.quest_mode:
			print("QUEST_MODE_OFF frame=", i, " deaths=", deaths)
			break
		await get_tree().physics_frame
		if is_instance_valid(player) and player.last_hit_source != "":
			hits[player.last_hit_source] = hits.get(player.last_hit_source, 0) + 1
		if is_instance_valid(player) and player.potions < last_potions:
			potions_quaffed += last_potions - player.potions
		if is_instance_valid(player):
			last_potions = player.potions
		if not is_instance_valid(boss) or boss.health <= 0:
			boss_won = true
			print("BOSS_DEFEATED frame=", i, " deaths=", deaths)
			break
		if main.quest_death_count != last_death_count:
			deaths += 1
			last_death_count = main.quest_death_count
			print("DEATH frame=", i, " deaths=", deaths, " last_hit=", player.last_hit_source,
				" enemies_near=", _enemies_near(player))
			if deaths >= 5:
				break
	print("HIT_TALLY ", hits)
	# (INBOX 2026-10-20 00:11 감독 05:30 재검수) 전조 수정 전/후를 나란히
	# 인용하려면 사망 수뿐 아니라 보스 남은 HP·물약 소모량도 같이 찍어야 한다.
	var boss_hp: int = boss.health if is_instance_valid(boss) else 0
	var boss_hp_max: int = boss.max_health if is_instance_valid(boss) else 0
	print("FINAL deaths=", deaths, " boss_hp=", boss_hp, "/", boss_hp_max,
		" potions_quaffed=", potions_quaffed, "/", start_potions)
	# (#13) 5회 중 3회 이상 "WIN"이면 숫자 그대로, 아니면 보스 공격력·체력을
	# 내리는 근거로 삼는다. 스냅샷 없이(폴백) 돌면 측정 목적이 다르니 그대로
	# 사망 재현 여부로 판정한다(예전 의미 유지).
	if has_snapshot:
		print("RESULT ", "WIN" if boss_won else "LOSE")
		get_tree().quit(0)
	else:
		print("RESULT ", "PASS" if deaths > 0 else "FAIL - 사망이 재현되지 않음")
		get_tree().quit(0 if deaths > 0 else 1)


func _enemies_near(player: Node) -> int:
	var near_dist: float = player.attack_range * 2.5
	var n := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.health > 0 and player.global_position.distance_to(enemy.global_position) <= near_dist:
			n += 1
	return n
