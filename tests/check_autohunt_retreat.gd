extends Node
## AUTOHUNT_DESIGN.md §10.7 후퇴(INBOX 답, 2026-09-06 09:30) 검증.
## (1) 적 GameState.AUTOHUNT_RETREAT_ENEMIES 마리 근접 -> 이전 지역으로 후퇴.
## (2) HP 비율 AUTOHUNT_RETREAT_HP_RATIO 이하 -> 같은 결과.
## (3) 같은 지역 AUTOHUNT_RETREAT_GIVEUP_STREAK회 연속 후퇴 -> 홈 귀환 +
##     한 티어 아래(그 지역의 "w" 이전 지역) 재개 예약.
## (4) INBOX 답(2026-09-06 11:20): 0.6초 타이머를 기다리지 않고, 피격
##     (`Player.take_damage()` -> `health_changed`)만으로 HP가 임계값
##     아래로 떨어지면 같은 프레임에 후퇴가 걸린다.
## (5) INBOX 답(2026-09-06 13:45): 후퇴 진입 시 try_use_potion() 자동
##     사용 - HP<40%·potions>0이면 potions 1 감소, HP 상승.
## (6) INBOX 답(2026-09-06 14:20): potions=0이어도 gold<물약값이면 귀환하지
##     않고 계속 사냥, gold>=물약값이면 그대로 귀환.
## (7)~(10) INBOX 답(2026-09-06 19:20, 18:45 ① 재정정, 2026-09-07 01:20 ①로
##     HP 조건 추가): 근접 규칙(근접≥AUTOHUNT_RETREAT_ENEMIES)은 HP<=
##     AUTOHUNT_RETREAT_HP_RATIO일 때만 보되, 그 안에서는 통과 중이든
##     아니든·회복 수단 여부와도 무관하게 항상 후퇴다(HP>임계면 근접 수와
##     무관하게 후퇴 없음 - 근접이 단독 사유였던 옛 규칙은 cave_deep→
##     forest_w 한 프레임 연쇄 후퇴의 원인이라 폐기). 근접<임계일 때의 HP
##     규칙은 `_quest_can_recover()`(물약>0 또는 골드>=물약값) 게이트가
##     있어야 후퇴한다 - 회복 수단이 아예 없으면 후퇴는 회복하러 갈 곳이
##     없는 문(정지)일 뿐이라, 근접 0마리에서도 HP 규칙만으로 영원히
##     마을⇄사냥터를 반복하는 정체가 났다(18:45 통합판 실측, INBOX 19:15
##     질문). HP 규칙이 걸렸는데 potions>0이면 `_quest_should_retreat()`가
##     `try_use_potion()`을 먼저 시도해 성공하면 후퇴하지 않는다(14:55 방식
##     복원). 18:45 ④ 둘째 케이스(물약 0·골드 부족·근접 1마리·HP 30% ->
##     후퇴 true)는 사람이 오판으로 철회 - false가 맞다.
## (i)~(iii) INBOX 답(2026-09-07 01:20 ①): `_quest_should_retreat()`의 세
##     경계(HP 100%, HP 임계+근접≥N, HP 임계+근접<N)를 직접 확인.
## (iv) INBOX 답(2026-09-07 01:20 ②): `_quest_do_retreat()` 직후(둘 다
##     auto_hunt/auto_walk_active=false) 재차 `health_changed`가 울려도
##     `_on_health_changed()`가 재평가를 건너뛰어 한 프레임 연쇄 후퇴가
##     없다.
## (12)~(13) INBOX 답(2026-09-06 16:09 나): 퀘스트모드 중 사망은 quest_mode를
##     끄지 않고 마을 부활로 잇는다(부활의 깃털 자동 소모 안 함) - 단 킬 진전
##     없이 GIVEUP_STREAK회 연속 사망하면 quest_mode를 끈다.
## (14)~(15) INBOX 답(2026-09-06 16:50): 통과 중(goal_reached) 응전 - 추격
##     없이(auto_walk_active 유지) 사거리 안 적만 attack()으로 때린다.
## (16)~(17) INBOX 답(2026-09-06 17:26): 포기 후 재개 지역(_quest_grind_zone)
##     에서는 goal_reached를 무시하고 적이 남아 있으면 추격(auto_hunt)한다.
##     적이 전멸하면 grind_zone을 비우고 동쪽 출구로 걸어 나간다.
## 숫자는 game_state.gd 상수를 그대로 읽어 쓴다 - 여기서 베끼지 않는다.

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _spawn_enemies(main: Node, count: int) -> Array:
	var enemies := []
	for i in count:
		var enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
		enemy.max_health = 100
		enemy.health = 100
		main.get_node("World").add_child(enemy)
		enemy.global_position = main.get_node("Player").global_position + Vector2(20 + i * 4, 0)
		enemies.append(enemy)
	return enemies


## (결함 조사, 2026-10-20 #15) `queue_free()`는 프레임 끝에 처리돼 그
## 사이에 "enemies" 그룹에 한 프레임 더 남는다(CLAUDE.md 함정) - 뒤에 오는
## (15)(17) 같은 그룹 전체 순회 판정이 이미 지운 것으로 믿은 적을 여전히
## 세어 간헐적으로 실패했다(실측: enemies_count가 기대 1 대신 10으로 남음).
## 지우기 전에 먼저 그룹에서 빼 그 프레임부터 바로 안 보이게 한다.
func _clear_enemies(enemies: Array) -> void:
	for e in enemies:
		e.remove_from_group("enemies")
		e.queue_free()


## (INBOX 결함, 2026-09-07 09:20 대조 확인) `GameState.current_map`만 바꾸고
## world를 그대로 두면 `_build_walk_grid()`가 "이미 paint()된 지역 전용"
## 전제를 어겨 `walkable()`이 실제 `_grid` 밖 칸을 읽어 SCRIPT ERROR(out
## of bounds)가 난다(위 check_quest_transit_chase.gd와 같은 결함 부류) -
## 지역을 바꿀 때마다 함께 paint() 해 전제를 지킨다.
func _goto(main: Node, area: String) -> void:
	GameState.current_map = area
	main.get_node("World").paint(area)


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	## (결함 조사, 2026-10-20 #15) 이 조각들은 전부 `_quest_mode_tick()`을
	## 직접 호출해 판정만 보는데, `_quest_timer`(0.6초)가 로딩으로 느려진
	## 프레임 delta 때문에 예측 못 한 순간 자동으로도 같은 함수를 불러
	## 수동 호출과 경합했다(실측: enemies_count가 간헐적으로 10 — 그 자동
	## 호출이 먼저 상태를 바꿔 놓음) - `check_quest_pickup_wall.gd`와 같은
	## 방식으로 꺼서 수동 호출만 남긴다.
	main._quest_timer.stop()
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true
	var spawn_pos: Vector2 = player.global_position

	GameState.reset()
	GameState.chapter = 1
	GameState.unlock_map("hill")
	GameState.unlock_map("hill_ridge")
	main.quest_mode = true
	_goto(main, "hill_ridge")
	GameState.potions = 99
	GameState.boss_defeated = false
	player.max_health = 100
	player.health = 100
	# (1)~(3)은 순수 판정/상태 전환 로직만 보는 조각이라, 근접 스폰한 적이
	# 같은 프레임에 실제로 때려 `take_damage` -> `health_changed`가 터지면
	# (4)에서 새로 붙인 "피격 즉시 재평가"가 여기서도 끼어들어 상태 전환
	# 순서가 뒤섞인다(적이 이미 다음 지역으로 넘어가며 `queue_free`됨).
	# 무적으로 막아 이 조각들이 전투 타이밍과 무관하게 동작하게 한다.
	player.invulnerability_time = 999.0

	# (1) 적 임계값 이상 근접 -> 후퇴, 목표는 이전 지역("hill").
	# (INBOX 답, 2026-09-07 01:20 ①) 근접 규칙은 이제 HP<=임계일 때만 보므로
	# HP도 임계값 이하로 맞춘다(HP>임계면 근접 수와 무관하게 후퇴 없음).
	# (감독 2026-09-09) 물약이 있으면 근접 수와 무관하게 먼저 마시므로, 순수
	# 근접 규칙을 보려면 물약을 비운다(골드는 무관).
	player.potions = 0
	GameState.potions = 0
	player.health = int(player.max_health * GameState.AUTOHUNT_RETREAT_HP_RATIO)
	var crowd := _spawn_enemies(main, GameState.AUTOHUNT_RETREAT_ENEMIES)
	await get_tree().process_frame
	ok = _check("(1) HP 임계값 이하·물약 0·적 %d마리 근접 -> 후퇴 판단" % GameState.AUTOHUNT_RETREAT_ENEMIES,
		main._quest_should_retreat()) and ok
	main._quest_do_retreat()
	ok = _check("(1) 후퇴 후 이전 지역 예약(hill) - 1회차라 이동 없음, streak만 증가",
		main._quest_retreat_zone == "hill_ridge" and main._quest_retreat_streak == 1) and ok
	# (INBOX 답, 2026-09-06 18:45 ②) 포기(giveup)까지 안 간 후퇴도 도착한
	# 지역(hill)을 grind_zone으로 잡아 한 바퀴 소탕하게 한다 - 안 그러면
	# 스토리 목표를 채운 지역으로 되돌아가자마자 재진입->재후퇴를 무한
	# 반복한다(18:35 질문이 실측한 hill<->village 216틱 왕복과 같은 부류).
	ok = _check("(1) 포기 전 후퇴도 도착 지역(hill)을 grind_zone으로 잡음",
		main._quest_grind_zone == "hill" and GameState.current_map == "hill") and ok
	main._quest_grind_zone = ""
	_clear_enemies(crowd)
	await get_tree().process_frame

	# (2) HP 비율 임계값 이하 -> 같은 결과(적 수는 무관). 물약이 있으면
	# (19:20 답, 9c) 후퇴 대신 물약 회복을 먼저 시도하므로, 순수 후퇴 판정을
	# 보려면 potions=0·gold>=가격(can_recover=true, 회복 시도는 안 걸림)으로
	# 맞춘다.
	main._quest_retreat_zone = ""
	main._quest_retreat_streak = 0
	player.potions = 0
	GameState.potions = 0
	GameState.gold = main._quest_potion_price()
	player.health = int(player.max_health * GameState.AUTOHUNT_RETREAT_HP_RATIO)
	ok = _check("(2) 물약 0·골드>=가격·HP %.0f%% -> 후퇴 판단" % (GameState.AUTOHUNT_RETREAT_HP_RATIO * 100),
		main._quest_should_retreat()) and ok
	player.health = player.max_health
	player.potions = 99
	GameState.potions = 99

	# (3) 같은 지역 GIVEUP_STREAK회 연속 후퇴 -> 홈 귀환 + 한 티어 아래(hill) 재개.
	main._quest_retreat_zone = ""
	main._quest_retreat_streak = 0
	for i in GameState.AUTOHUNT_RETREAT_GIVEUP_STREAK:
		# 매번 hill_ridge 로 돌아와 후퇴하는 상황(실제로는 봇이 이전 지역에서
		# 다시 동쪽으로 걸어 들어감)을 흉내낸다 - 후퇴 판단 자체가 아니라
		# streak 누적/티어 하향 로직만 확인하는 것이 이 케이스의 목적이다.
		_goto(main, "hill_ridge")
		main._quest_do_retreat()
	ok = _check("(3) %d회 연속 후퇴 -> streak/zone 초기화" % GameState.AUTOHUNT_RETREAT_GIVEUP_STREAK,
		main._quest_retreat_streak == 0 and main._quest_retreat_zone == "") and ok
	ok = _check("(3) 한 티어 아래(hill) 재개 예약",
		main._quest_resume_zone == "hill") and ok
	ok = _check("(3) 홈 마을(village)로 귀환", GameState.current_map == "village") and ok
	ok = _check("(3) 귀환 뒤에도 quest_mode 유지(INBOX 13:25 보정)",
		main.quest_mode == true) and ok

	# (4) 타이머 없이 take_damage 한 번으로 즉시 후퇴(11:20 답). 물약을
	# 비워(potions=0·gold>=가격) 회복 시도(9c)가 아니라 실제 후퇴가 걸리는지
	# 본다. (INBOX 답, 2026-09-07 01:20 ②) 재평가 게이트가
	# auto_hunt/auto_walk_active 중 하나를 요구하므로, 실전에서 사냥 중
	# 피격되는 상황대로 auto_hunt를 켜 둔다(연쇄 차단은 (iv)가 따로 본다).
	main._quest_retreat_zone = ""
	main._quest_retreat_streak = 0
	_goto(main, "hill_ridge")
	GameState.unlock_map("hill")
	player.health = player.max_health
	player.invulnerability_time = 0.0
	player.potions = 0
	GameState.potions = 0
	GameState.gold = main._quest_potion_price()
	player.auto_hunt = true
	var hp_before_hit: int = player.max_health
	var hp_after_threshold := int(player.max_health * GameState.AUTOHUNT_RETREAT_HP_RATIO)
	player.take_damage(hp_before_hit - hp_after_threshold + 1, Vector2.ZERO)
	## (감독 결함 수정, 2026-09-08) `_on_health_changed`는 피격 콜백(물리
	## 플러시 중)에서 오므로 실제 후퇴(`_change_map`)는 `call_deferred`로
	## 프레임 끝에 실행된다 - 한 프레임 넘겨서 본다.
	await get_tree().process_frame
	ok = _check("(4) take_damage 한 번으로 HP %.0f%% 아래 -> 프레임 끝 후퇴(streak 증가)"
			% (GameState.AUTOHUNT_RETREAT_HP_RATIO * 100),
		main._quest_retreat_zone == "hill_ridge" and main._quest_retreat_streak == 1) and ok
	ok = _check("(4) 후퇴로 이전 지역(hill)에 도착", GameState.current_map == "hill") and ok
	player.invulnerability_time = 0.0
	player.health = player.max_health

	# (5) 후퇴 진입 시 물약 자동 사용(INBOX 13:45 답) - HP<40%·potions>0이면
	# _quest_do_retreat()가 try_use_potion()을 한 번 불러 HP가 오르고
	# potions가 하나 줄어드는지 확인. 이게 없으면 auto_hunt=false인 후퇴
	# 중에는 HP가 영원히 회복 안 돼 hill<->village를 무한 반복한다(13:25
	# 보정 실측).
	main._quest_retreat_zone = ""
	main._quest_retreat_streak = 0
	_goto(main, "hill_ridge")
	player.potions = 5
	GameState.potions = 5
	player.health = int(player.max_health * GameState.AUTOHUNT_RETREAT_HP_RATIO)
	var hp_before_retreat: int = player.health
	var potions_before_retreat: int = player.potions
	main._quest_do_retreat()
	ok = _check("(5) 후퇴 진입 시 물약 자동 사용 -> potions 1 감소",
		player.potions == potions_before_retreat - 1
		and GameState.potions == potions_before_retreat - 1) and ok
	ok = _check("(5) 후퇴 진입 시 물약 자동 사용 -> HP 상승",
		player.health > hp_before_retreat) and ok
	player.invulnerability_time = 0.0
	player.health = player.max_health

	# (6) INBOX 답(2026-09-06 14:20) 골드 고갈 블로커: potions=0이어도
	# 물약값을 못 살 돈이면 귀환하지 않고 계속 사냥한다 - 안 그러면 tier1
	# 골드 보상(6) < 물약값(20)이라 3킬 이내에 사냥터<->마을을 영원히
	# 왕복하며 전투를 한 번도 못 해 골드가 늘지 않는다(15:10 질문 실측).
	var price: int = main._quest_potion_price()
	main._quest_retreat_zone = ""
	main._quest_retreat_streak = 0
	_goto(main, "hill_ridge")
	GameState.boss_defeated = false
	GameState.potions = 0
	GameState.gold = price - 1
	main._quest_mode_tick()
	ok = _check("(6) potions=0·gold<가격 -> 귀환하지 않고 hill_ridge에 남음",
		GameState.current_map == "hill_ridge") and ok

	_goto(main, "hill_ridge")
	GameState.potions = 0
	GameState.gold = price
	main._quest_mode_tick()
	ok = _check("(6) potions=0·gold>=가격 -> 홈 마을로 귀환",
		GameState.current_map == "village") and ok

	# (7) INBOX 답(2026-09-06 18:45 ①): 통과 중(goal_reached, quest_stage 1의
	# "가자" 문구)이어도 근접 적이 임계값 이상이면 후퇴한다 - 14:55~16:09의
	# "통과 중엔 근접 규칙을 안 본다" 예외는 18:35 질문이 실측한 3연속 사망의
	# 원인이라 폐기됐다.
	# (1)~(3)처럼 실제 전투(피격)가 섞이면 `_on_health_changed`의 즉시 재평가가
	# 우리보다 먼저 후퇴·`_change_map`을 실행해 여기서 스폰한 적을
	# `_spawn_area_enemies`가 지워 버린다(area_id 불일치) - 무적으로 막는다.
	player.invulnerability_time = 999.0
	_goto(main, "hill_ridge")
	GameState.quest_stage = 1
	GameState.kills = 6
	# (INBOX 답, 2026-09-07 01:20 ①) HP도 임계값 이하로 맞춘다 - HP가
	# 안전하면 근접 수와 무관하게 후퇴 없음이 새 규칙이다.
	player.health = int(player.max_health * GameState.AUTOHUNT_RETREAT_HP_RATIO)
	player.potions = 5
	GameState.potions = 5
	var crowd2 := _spawn_enemies(main, GameState.AUTOHUNT_RETREAT_ENEMIES)
	await get_tree().process_frame
	# (감독 2026-09-09) 1x1 통합 뒤 근접≥N은 평소 상태라, 물약이 있으면
	# 마릿수와 무관하게 먼저 마시고 후퇴하지 않는다(qm.log 195/196회
	# 근접 후퇴 정체의 수정). 물약이 없을 때만 근접 규칙이 남는다.
	ok = _check("(7) 통과 중·HP 임계값 이하·근접 적 %d마리·물약 5 -> 물약 먼저(후퇴 없음, potions 4)"
			% GameState.AUTOHUNT_RETREAT_ENEMIES,
		not main._quest_should_retreat() and player.potions == 4) and ok
	player.potions = 0
	GameState.potions = 0
	player.health = int(player.max_health * GameState.AUTOHUNT_RETREAT_HP_RATIO)
	ok = _check("(7b) 같은 조건·물약 0 -> 근접 규칙으로 후퇴",
		main._quest_should_retreat()) and ok
	_clear_enemies(crowd2)
	await get_tree().process_frame

	# (8) 통과 중·근접 적 없음·HP 안전 -> 후퇴하지 않는다.
	player.health = player.max_health
	ok = _check("(8) 통과 중·근접 적 없음·HP 안전 -> 후퇴하지 않음",
		not main._quest_should_retreat()) and ok

	# (9) INBOX 답(2026-09-06 19:20): 통과 중·근접 적 없음·물약 0·골드 부족
	# (can_recover=false) -> 회복 수단이 없으니 후퇴하지 않는다(19:15 질문이
	# 실측한 hill<->village 영구 정지의 원인 - 근접 0마리인데도 HP 규칙만으로
	# 후퇴가 걸려 회복도 전투도 사망도 없이 영원히 반복했다).
	player.potions = 0
	GameState.potions = 0
	GameState.gold = main._quest_potion_price() - 1
	player.health = int(player.max_health * GameState.AUTOHUNT_RETREAT_HP_RATIO)
	ok = _check("(9) 통과 중·근접 0·물약 0·골드 부족·HP %.0f%% -> 후퇴하지 않음(19:15 정체 재현)"
			% (GameState.AUTOHUNT_RETREAT_HP_RATIO * 100),
		not main._quest_should_retreat()) and ok

	# (9b) 같은 조건, 골드만 물약값 이상(can_recover=true) -> 후퇴한다(귀환해
	# 물약을 사서 회복할 수 있으므로).
	GameState.gold = main._quest_potion_price()
	ok = _check("(9b) 통과 중·근접 0·물약 0·골드>=가격·HP %.0f%% -> 후퇴"
			% (GameState.AUTOHUNT_RETREAT_HP_RATIO * 100),
		main._quest_should_retreat()) and ok

	# (9c) 물약이 있으면(can_recover=true) `_quest_should_retreat()`가
	# try_use_potion()을 먼저 시도해 성공하면 후퇴하지 않는다(14:55 방식 복원).
	player.potions = 5
	GameState.potions = 5
	player.health = int(player.max_health * GameState.AUTOHUNT_RETREAT_HP_RATIO)
	var hp_before_9c: int = player.health
	ok = _check("(9c) 통과 중·근접 0·물약 있음·HP 낮음 -> 물약 사용 후 후퇴하지 않음",
		not main._quest_should_retreat()) and ok
	ok = _check("(9c) 물약 사용으로 potions 1 감소·HP 상승",
		player.potions == 4 and player.health > hp_before_9c) and ok
	player.health = player.max_health
	player.potions = 5
	GameState.potions = 5

	# (10) INBOX 답(2026-09-06 18:45 ④, 2026-09-07 01:20 ①로 HP 조건 추가):
	# 목표 달성·HP 임계값 이하·물약 0·골드<물약값 상태에서 근접
	# AUTOHUNT_RETREAT_ENEMIES마리 -> 후퇴(근접 규칙, can_recover 무관).
	player.health = int(player.max_health * GameState.AUTOHUNT_RETREAT_HP_RATIO)
	player.potions = 0
	GameState.potions = 0
	GameState.gold = main._quest_potion_price() - 1
	var crowd3 := _spawn_enemies(main, GameState.AUTOHUNT_RETREAT_ENEMIES)
	await get_tree().process_frame
	ok = _check("(10) 목표 달성·HP 임계값 이하·물약 0·골드 부족·근접 %d마리 -> 후퇴"
			% GameState.AUTOHUNT_RETREAT_ENEMIES,
		main._quest_should_retreat()) and ok
	_clear_enemies(crowd3)
	await get_tree().process_frame

	# (10b) INBOX 답(2026-09-06 19:20, 18:45 ④ 둘째 케이스 철회): 같은 조건
	# (물약 0·골드 부족)·근접 1마리(임계값 미만)·HP 30% -> can_recover=false라
	# 후퇴하지 않는다(18:45 ④가 "후퇴 true"라 했던 것은 사람의 오판이었다).
	var lone := _spawn_enemies(main, 1)
	await get_tree().process_frame
	player.health = int(player.max_health * 0.3)
	ok = _check("(10b) 물약 0·골드 부족·근접 1마리·HP 30% -> 후퇴하지 않음",
		not main._quest_should_retreat()) and ok
	_clear_enemies(lone)
	await get_tree().process_frame
	player.health = player.max_health
	player.potions = 5
	GameState.potions = 5
	player.invulnerability_time = 0.0

	# (11) INBOX 답(2026-09-06 15:15) 90ed569 누락분: auto_walk_active로
	# 걷다가 회피 중(commit_time>0)에 재차 막히면(_auto_stuck_time이
	# _AUTO_STUCK_TRIGGER 이상) 같은 쪽으로 계속 미는 대신 _auto_avoid_sign이
	# 반대로 뒤집힌다(모서리 걸림 대응).
	player.auto_hunt = false
	player.auto_walk_active = true
	player._auto_avoid_commit_time = 0.3
	player._auto_avoid_origin = player.global_position
	player._auto_avoid_sign = 1.0
	player._auto_stuck_time = player._AUTO_STUCK_TRIGGER
	player._auto_avoid_obstacle(Vector2.RIGHT, 0.05)
	ok = _check("(11) auto_walk_active 회피 중 재차 막히면 _auto_avoid_sign 반전",
		player._auto_avoid_sign == -1.0) and ok
	player.auto_walk_active = false
	player._auto_avoid_commit_time = 0.0
	player._auto_stuck_time = 0.0

	# (12) INBOX 답(2026-09-06 16:09 나): 퀘스트모드 중 사망은 quest_mode를
	# 끄지 않고 마을 부활로 잇는다 - 부활의 깃털(사람 자원)은 자동 소모하지
	# 않는다(대사창도 안 뜬다).
	main.quest_mode = true
	main._quest_death_streak = 0
	main._quest_kills_at_last_death = -1
	GameState.kills = 3
	GameState.revive_potions = 2
	player.health = 1
	main._on_player_died()
	for i in 5: await get_tree().process_frame
	ok = _check("(12) 퀘스트모드 중 사망 -> quest_mode 유지", main.quest_mode == true) and ok
	ok = _check("(12) 퀘스트모드 중 사망 -> 부활의 깃털 자동 소모 안 함(대사창 없음)",
		GameState.revive_potions == 2 and not main.dialogue_open) and ok
	ok = _check("(12) 퀘스트모드 중 사망 -> 마을에서 부활(체력 회복)",
		GameState.current_map == "village" and player.health == player.max_health) and ok

	# (13) (감독 2026-09-09) 킬이 하나도 안 늘며 AUTOHUNT_RETREAT_GIVEUP_STREAK회
	# 연속 사망해도 quest_mode는 끄지 않는다(사용자가 켠 오토가 저절로 꺼지면
	# "고장") - 재개 사냥터를 한 단계 내리고 연속 카운트를 리셋한다.
	main.quest_mode = true
	main._quest_death_streak = 0
	main._quest_kills_at_last_death = GameState.kills
	for i in GameState.AUTOHUNT_RETREAT_GIVEUP_STREAK:
		player.health = 1
		main._on_player_died()
		for j in 5: await get_tree().process_frame
	ok = _check("(13) 킬 진전 없이 %d회 연속 사망 -> quest_mode 유지 + 연속 카운트 리셋"
			% GameState.AUTOHUNT_RETREAT_GIVEUP_STREAK,
		main.quest_mode == true and main._quest_death_streak == 0) and ok

	# (14)~(15) INBOX 답(2026-09-07 00:12 ①, 16:50 대체): 통과 중(goal_reached)
	# near_dist(attack_range*2.5) 안에 적이 있으면 추격(auto_hunt)한다 - 예전
	# "사거리 안 적만 attack(), 추격 없음" 판정은 forest_w 같은 밀집 지역에서
	# 몹이 계속 따라붙어 맞다가 물약이 바닥나는 순환의 원인이라 넓혔다(§10.7).
	# (13) 뒤에도 켜져 있지만 아래 검사의 전제를 명시한다.
	main.quest_mode = true
	_goto(main, "hill_ridge")
	GameState.quest_stage = 1
	GameState.kills = 6
	player.health = player.max_health
	player.potions = 5
	GameState.potions = 5
	player.cooldown_time = 0.0
	var near_enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
	near_enemy.max_health = 100
	near_enemy.health = 100
	main.get_node("World").add_child(near_enemy)
	near_enemy.global_position = player.global_position + Vector2(5, 0)
	await get_tree().process_frame
	main._quest_mode_tick()
	ok = _check("(14) 통과 중 near_dist 안 적 1마리 -> 추격(auto_hunt)",
		player.auto_hunt == true and player.auto_walk_active == false) and ok
	near_enemy.remove_from_group("enemies")
	near_enemy.queue_free()
	await get_tree().process_frame

	player.cooldown_time = 0.0
	var far_enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
	far_enemy.max_health = 100
	far_enemy.health = 100
	main.get_node("World").add_child(far_enemy)
	far_enemy.global_position = player.global_position + Vector2(300, 0)
	await get_tree().process_frame
	main._quest_mode_tick()
	ok = _check("(15) 통과 중 near_dist 밖 적만 -> 추격 안 하고 경로(auto_walk) 유지",
		player.auto_walk_active == true and player.auto_hunt == false) and ok
	far_enemy.remove_from_group("enemies")
	far_enemy.queue_free()
	await get_tree().process_frame

	# (16)~(17) INBOX 답(2026-09-06 17:26): 포기 후 재개(_quest_grind_zone)
	# 지역에서는 스토리 목표(kills=6)를 이미 채웠어도 그 지역에 적이 남아
	# 있으면 사냥(추격)을 계속한다 - _change_map()으로 재진입할 때마다 몹이
	# 처음 수로 리스폰되므로 "한 바퀴 소탕"이 실제로 일어나는지가 핵심.
	main.quest_mode = true
	_goto(main, "hill")
	GameState.quest_stage = 1
	GameState.kills = 6
	main._quest_grind_zone = "hill"
	player.health = player.max_health
	player.potions = 5
	GameState.potions = 5
	var grind_enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
	grind_enemy.max_health = 100
	grind_enemy.health = 100
	main.get_node("World").add_child(grind_enemy)
	grind_enemy.global_position = player.global_position + Vector2(20, 0)
	await get_tree().process_frame
	main._quest_mode_tick()
	ok = _check("(16) 재개 지역에 적 있음 -> goal_reached 무시하고 추격(auto_hunt)",
		player.auto_hunt == true and player.auto_walk_active == false) and ok
	ok = _check("(16) 재개 지역에 적 있는 동안은 grind_zone 유지",
		main._quest_grind_zone == "hill") and ok

	grind_enemy.remove_from_group("enemies")
	grind_enemy.queue_free()
	await get_tree().process_frame
	main._quest_mode_tick()
	ok = _check("(17) 재개 지역 적 전멸 -> grind_zone 비우고 동쪽 출구로 이동",
		main._quest_grind_zone == "" and player.auto_hunt == false
		and player.auto_walk_active == true) and ok

	# (18) INBOX 답(2026-09-06 19:40): hill (410,291)~(410,298) 실측 -
	# 장애물 모서리에서 위아래로 미세하게 떨면(매 프레임 이동량은 기준치를
	# 넘지만 누적 실제 진행은 0에 가까움) 예전 프레임 단위 판정은
	# _auto_stuck_time이 매 프레임 0으로 리셋돼 영원히 트리거되지 않았다.
	# 0.5초 창(_AUTO_STUCK_WINDOW) 동안 8프레임을 y좌표만 3px씩 왕복시켜
	# (프레임당 이동량은 충분하지만 누적 순 이동은 0) 회피가 걸리는지 확인.
	player.auto_walk_active = true
	player._auto_stuck_time = 0.0
	player._auto_stuck_window_time = 0.0
	player.global_position = Vector2(200, 150)
	var jitter_frame_delta := 0.07  # 8프레임 * 0.07 = 0.56초, 윈도우(0.5초) 넘김
	for i in 8:
		var before: Vector2 = player.global_position
		player.global_position = Vector2(200, 150 if i % 2 == 0 else 157)
		player._auto_track_stuck(Vector2.RIGHT, before, jitter_frame_delta)
	ok = _check("(18) 모서리에서 미세 진동해도 0.5초 창 순 이동으로 stuck 누적됨",
		player._auto_stuck_time > 0.0) and ok
	player.auto_walk_active = false
	player._auto_stuck_time = 0.0
	player._auto_stuck_window_time = 0.0
	# (18)이 모서리 옆(410,291)에 남겨뒀다 - 그대로 두면 다음 조각의 근접
	# 스폰이 그 모서리 벽 너머로 밀려나 근접 판정이 어긋난다(2026-09-07
	# 검증 중 발견, "물약 8" 케이스가 벽에 밀려 거리 계산이 틀렸었다).
	player.global_position = spawn_pos

	# (i)~(iii) INBOX 답(2026-09-07 01:20 ①) `_quest_should_retreat()` 가중
	# 조건 직접 검증 - (1)(7)(10)은 부수 상태(이동/추격 전환) 확인이 목적이라
	# 여기서 판정식 자체의 세 경계를 못 박는다.
	main.quest_mode = true
	_goto(main, "hill_ridge")
	player.invulnerability_time = 999.0
	player.health = player.max_health
	player.potions = 9
	GameState.potions = 9
	var crowd_i := _spawn_enemies(main, GameState.AUTOHUNT_RETREAT_ENEMIES)
	await get_tree().process_frame
	ok = _check("(i) HP 100%%·근접 %d마리·물약 9 -> 후퇴 없음, 물약 그대로"
			% GameState.AUTOHUNT_RETREAT_ENEMIES,
		not main._quest_should_retreat() and player.potions == 9) and ok
	player.health = int(player.max_health * GameState.AUTOHUNT_RETREAT_HP_RATIO)
	# (감독 2026-09-09) 물약 우선: 근접 N마리여도 물약이 있으면 마시고 후퇴 없음.
	ok = _check("(ii) HP %.0f%%·근접 %d마리·물약 9 -> 물약 먼저(후퇴 없음), 물약 8"
			% [GameState.AUTOHUNT_RETREAT_HP_RATIO * 100, GameState.AUTOHUNT_RETREAT_ENEMIES],
		not main._quest_should_retreat() and player.potions == 8) and ok
	player.potions = 9
	GameState.potions = 9
	_clear_enemies(crowd_i)
	await get_tree().process_frame
	player.health = player.max_health

	var lone_iii := _spawn_enemies(main, 1)
	await get_tree().process_frame
	player.health = int(player.max_health * GameState.AUTOHUNT_RETREAT_HP_RATIO)
	ok = _check("(iii) HP %.0f%%·근접 1마리·물약 9 -> 후퇴 없음(물약 소모로 회복), 물약 8"
			% (GameState.AUTOHUNT_RETREAT_HP_RATIO * 100),
		not main._quest_should_retreat() and player.potions == 8) and ok
	_clear_enemies(lone_iii)
	await get_tree().process_frame
	player.health = player.max_health
	player.invulnerability_time = 0.0
	player.potions = 5
	GameState.potions = 5

	# (iv) INBOX 답(2026-09-07 01:20 ②) 연쇄 후퇴 차단: `_quest_do_retreat()`
	# 직후(auto_hunt=false, auto_walk_active=false) `health_changed`가
	# 근접 4마리·HP 30% 상태로 다시 울려도 `_on_health_changed()`가 재평가를
	# 건너뛰어 cave_deep 같은 연쇄 지도 전이가 없다 - current_map이 그대로다.
	main._quest_retreat_zone = ""
	main._quest_retreat_streak = 0
	main._quest_grind_zone = ""
	_goto(main, "hill_ridge")
	GameState.unlock_map("hill")
	player.potions = 9
	GameState.potions = 9
	player.health = player.max_health
	main._quest_do_retreat()
	var map_after_retreat: String = GameState.current_map
	ok = _check("(iv) 후퇴 직후 auto_hunt/auto_walk_active 둘 다 false(재평가 게이트 닫힘)",
		player.auto_hunt == false and player.auto_walk_active == false) and ok
	var crowd_iv := _spawn_enemies(main, GameState.AUTOHUNT_RETREAT_ENEMIES)
	await get_tree().process_frame
	player.health = int(player.max_health * 0.3)
	main._on_health_changed(player.health, player.max_health)
	ok = _check("(iv) 연쇄 재평가 차단 - map이 후퇴 직후 그대로(%s)" % map_after_retreat,
		GameState.current_map == map_after_retreat) and ok
	_clear_enemies(crowd_iv)
	await get_tree().process_frame
	player.health = player.max_health
	player.auto_hunt = false
	player.auto_walk_active = false

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
