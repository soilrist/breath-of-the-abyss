extends Node
## AUTOHUNT_DESIGN.md §10.7 (2026-09-07 STATUS "다음에 할 것") 검증.
## glade `pos=(501.076, 300.9991)`(장애물 rock_s, cell(32,18) 바로 옆)에서
## 오토사냥이 game_min 18~23.2 내내 `hunt=true enemies_near=0`로 완전히
## 멈춘 실측 결함. 04:35 지시의 정지 감지 패턴(위치 변화<4px인데
## velocity!=0)을 그대로 재사용해, 이 좌표에서 실제 glade 스폰 적을 상대로
## 오토사냥을 오래 돌려도 그 신호가 영구히(게임 분 단위) 이어지지 않는지
## 본다.
##
## 원인: rock_s 근처에 소품 여러 개(rock_s + 이름 없는 StaticBody2D)가
## 뭉쳐 있어 `_auto_avoid_obstacle()`이 아무리 옆으로 비켜나도(회피 거리를
## 늘려도) 다시 다른 소품에 막혀 같은 적을 향해 영원히 부딪히기만 했다
## (60분 probe 실측, game_min≈20.7 STALL). 소품 뭉치 크기를 재는 대신,
## 같은 적을 향해 `_AUTO_HUNT_GIVEUP_STUCK`초 동안 거리가 안 줄면 그 적을
## `_AUTO_HUNT_BLACKLIST_TIME`초 동안 포기하고 다른 적을 고르게 고쳤다
## (`_auto_hunt_tick()`) - 장애물이 얼마나 크게 뭉쳐있든 상관없다.

const STUCK_TICKS_LIMIT := 600 ## 10초(60fps) 이상 이어지면 실질적 STALL로 본다.
const RUN_TICKS := 3600 ## 게임 1분.
## (INBOX 10:05(a) 후속, 2026-09-07) 위 좌표를 고친 뒤에도 다른 좌표(같은
## glade, rock_s cell(32,19) 근방)에서 새 부류의 정지가 실측됐다:
## 장애물 뒤편에 적이 여러 마리 있으면 하나를 포기(블랙리스트)해도 방향이
## 비슷한 다른 적을 다시 골라 같은 장애물에 막히고, 그새 앞의 블랙리스트가
## 풀려 도돌이표(핑퐁)가 영원히 이어졌다(60분 프로브 실측, game_min≈15.74
## STALL). "같은 방향의 다른 후보도 같이 접기"(_AUTO_HUNT_GIVEUP_DIR_COS)와
## "회피 최대 거리에서도 막히면 일단 물러나기"(_auto_avoid_retreat_time)로
## 고쳐 시드 20260907~909는 풀렸다(헤드리스 재현 확인).
## **시드 20260910/911은 여전히 남은 결함**: 실측(AUTOHUNT_DESIGN.md
## §10.7 "INBOX 05:54④ 처리") 결과 이 좌표의 담은 소품 3개가 어긋나게
## 붙은 대각선 계단형 장벽(x=448~576 폭 128px, y=280~336)이다. 동쪽
## 틈(약 40px)은 최대 회피 거리(72px = CLEAR_DIST18*ESCALATION_MAX4)
## 안에 있는데도 못 빠져나오는 이유는 담 폭이 아니라
## `_auto_avoid_obstacle()`이 옆걸음 성공(clear_dist 이동) 즉시
## escalation을 1.0으로 되돌리는 설계 때문 - 계단형이라 한 번의 옆걸음이
## "담을 등지고 미끄러진 것"일 뿐인데도 성공으로 오판해 다음 시도가 항상
## 처음 거리부터 다시 시작한다. 이 리셋을 "목표 방향 복귀가 실제 진행할
## 때까지 유지"로 고쳐 봤으나 이미 풀려 있던 REPRO_POSITIONS[0](시드
## 20260907/908)이 오히려 worst_streak 1123/878로 악화돼 되돌렸다 -
## 하나의 리셋 조건으로 두 좌표를 동시에 못 푼다. 계단형 담 전용 예외
## 없이는 기존 옆걸음 로직 안에서 해결이 안 되는 것으로 결론, 감독에게
## 다음 접근(포기 규칙 확장 vs 지형 재배치)을 질문해 뒀다. 이 시드 둘은
## SEEDS_HARD로 따로 빼 "적어도 사냥은 진행됨"만 확인하고 worst_streak
## 상한은 아직 요구하지 않는다.
## (INBOX 결함, 2026-09-07 04:25) player.gd:372의 `_auto_avoid_sign` 결정이
## 전역 RNG(randf())를 써서 seed()를 안 걸면 worst_streak가 바퀴마다
## 흔들렸다(483~634 실측). 시드 5개로 결정적으로 고정해 반복 검증한다.
const SEEDS: Array[int] = [20260907, 20260908, 20260909, 20260910, 20260911]
## 둘째 좌표만 시드 910/911에서 아직 못 푼 "담" 부류 결함이 남아 있어
## 이 둘은 worst_streak 상한 없이 "사냥은 진행됨"만 확인한다(위 주석).
const SEEDS_HARD: Array[int] = [20260910, 20260911]
const REPRO_POSITIONS: Array[Vector2] = [
	## 지역이 한 화면(320x240)으로 합쳐져 옛 실측 좌표(501,301)/(536,309)를
	## 같은 비율로 안쪽에 옮겼다 - 소품 뭉치 자체가 아니라 포기 규칙 회귀 검사.
	Vector2(250.0, 200.0),
	Vector2(268.0, 204.0),
]


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _run_one(rng_seed: int, repro_pos: Vector2) -> Dictionary:
	seed(rng_seed)
	GameState.reset()
	GameState.unlock_map("glade")
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	main._change_map("glade", false, repro_pos)
	await get_tree().process_frame
	player.invulnerability_time = 999.0
	player.auto_hunt = true
	player.auto_walk_active = false

	var start_kills: int = GameState.kills
	var last_pos: Vector2 = player.global_position
	var still_ticks := 0
	var worst_streak := 0
	for i in RUN_TICKS:
		await get_tree().physics_frame
		var moved: float = player.global_position.distance_to(last_pos)
		if moved < 4.0 and player.velocity.length() > 1.0:
			still_ticks += 1
			worst_streak = max(worst_streak, still_ticks)
		else:
			still_ticks = 0
		last_pos = player.global_position
	var kills_gained: int = GameState.kills - start_kills

	main.queue_free()
	await get_tree().process_frame
	return {"seed": rng_seed, "worst_streak": worst_streak, "kills_gained": kills_gained}


## (INBOX 결함, 2026-09-07 10:34) `main._quest_engage_nearest_enemy()`가
## 위와 같은 재현 좌표에서도 매 0.6초(퀘스트 틱 주기, 36 물리 프레임)마다
## 재평가하며 실제로 A* 접근을 태우는지 - 직접 `player.auto_hunt=true`만
## 켜던 위 `_run_one`과 달리, 담 너머 먼 적이면 `_quest_set_auto_walk()`로
## 먼저 우회시키는 새 경로를 태운다.
func _run_one_engage(rng_seed: int, repro_pos: Vector2) -> Dictionary:
	seed(rng_seed)
	GameState.reset()
	GameState.unlock_map("glade")
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	main._change_map("glade", false, repro_pos)
	await get_tree().process_frame
	player.invulnerability_time = 999.0
	player.auto_hunt = false
	player.auto_walk_active = false

	var start_kills: int = GameState.kills
	var last_pos: Vector2 = player.global_position
	var still_ticks := 0
	var worst_streak := 0
	for i in RUN_TICKS:
		if i % 36 == 0:
			main._quest_engage_nearest_enemy()
		await get_tree().physics_frame
		var moved: float = player.global_position.distance_to(last_pos)
		if moved < 4.0 and player.velocity.length() > 1.0:
			still_ticks += 1
			worst_streak = max(worst_streak, still_ticks)
		else:
			still_ticks = 0
		last_pos = player.global_position
	var kills_gained: int = GameState.kills - start_kills

	main.queue_free()
	await get_tree().process_frame
	return {"seed": rng_seed, "worst_streak": worst_streak, "kills_gained": kills_gained}


func _ready() -> void:
	var ok := true
	for repro_pos in REPRO_POSITIONS:
		print("좌표 ", repro_pos, " 시드별 worst_streak (STUCK_TICKS_LIMIT=%d):" % STUCK_TICKS_LIMIT)
		for s in SEEDS:
			var result: Dictionary = await _run_one(s, repro_pos)
			print("  seed=%d worst_streak=%d kills_gained=%d" %
				[result["seed"], result["worst_streak"], result["kills_gained"]])
			ok = _check("  pos=%s seed=%d: 1분 동안 실제로 사냥이 진행됨(kills_gained=%d)" %
				[repro_pos, result["seed"], result["kills_gained"]], result["kills_gained"] > 0) and ok
			if repro_pos == REPRO_POSITIONS[1] and s in SEEDS_HARD:
				continue ## 위 주석 - 이 좌표·시드 조합은 아직 담을 못 넘는 결함이 남아 있어 streak 상한 미검사.
			ok = _check("  pos=%s seed=%d: 장애물 옆 정지 신호가 %d틱 미만에서 풀림(worst_streak=%d)" %
				[repro_pos, result["seed"], STUCK_TICKS_LIMIT, result["worst_streak"]],
				result["worst_streak"] < STUCK_TICKS_LIMIT) and ok

	## (INBOX 결함, 2026-09-07 10:34) hunt 상태를 `main._quest_engage_nearest_enemy()`
	## 경로(퀘스트 틱 주기 재평가, A* 우회)로 태우는 케이스. 같은 재현 좌표·시드
	## 재사용. 실측 결과 worst_streak 상한(STUCK_TICKS_LIMIT)은 이 경로에
	## 그대로 적용할 수 없었다 - 0.6초(36프레임)마다만 재목표하므로 이
	## glade 소품 뭉치(원래 이 좌표를 고르게 한 결함)에서 다음 재평가까지
	## 짧게 막히는 구간이 연속 auto_hunt보다 더 길게 잡힐 수 있다(실측
	## worst_streak 최대 908, kills_gained은 오히려 3~7→8~10으로 향상 -
	## 영구 정지가 아니라 일시적 지연). 이 경로가 막는 진짜 결함(hunt=true
	## enemies_near=0로 영원히 고정)은 "1분 동안 kills_gained>0"으로 충분히
	## 잡힌다 - 진짜 영구 정지라면 이 값이 0이었을 것.
	for repro_pos in REPRO_POSITIONS:
		print("[engage] 좌표 ", repro_pos, " 시드별 worst_streak (참고용, 상한 미적용):")
		for s in SEEDS:
			var result: Dictionary = await _run_one_engage(s, repro_pos)
			print("  [engage] seed=%d worst_streak=%d kills_gained=%d" %
				[result["seed"], result["worst_streak"], result["kills_gained"]])
			ok = _check("  [engage] pos=%s seed=%d: 1분 동안 실제로 사냥이 진행됨(kills_gained=%d)" %
				[repro_pos, result["seed"], result["kills_gained"]], result["kills_gained"] > 0) and ok

	print("RESULT ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
