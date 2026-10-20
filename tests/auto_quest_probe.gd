extends Node

## INBOX 답(2026-09-06 18:05): 실제 게임은 `_quest_timer`(main.gd:165, wait_time=0.6)
## 주기로 `_quest_mode_tick()`을 부르는데, 이 프로브는 원래 매 물리 프레임(1/60초)마다
## 불러 8000틱이 게임 시간 2분 13초에 불과했다(측정 오류). 60fps 고정 실행에서
## 36 물리 프레임(=0.6초)마다 한 번만 불러 실제 게임과 같은 결정 주기로 맞춘다.
## `--fixed-fps 60`으로 띄워야 시계가 맞는다(실시간 동기 없이 프레임을 최대 속도로 돌림).
const PHYS_PER_QUEST_TICK := 36
const FRAMES_PER_GAME_MIN := 3600
## (INBOX 답, 2026-09-07 05:18) 10:05(a)를 "장별 독립 세팅"이 아니라
## "1장부터 이어 달리는 연속 시뮬레이션"으로 승인 - 격리 세팅에 필요한
## "챕터별 권장 레벨/장비" 값이 기획서에 없어(규칙③) 지을 수 없었던
## 문제를 우회한다. 예산을 10장 전체가 들어갈 만큼 크게 잡고(벽시계
## 실측상 게임 60분이 약 20~52초 걸렸으므로 게임 600분도 수 분 안쪽일
## 것으로 추정), 실제 상한은 호출 쪽(perl alarm 등)의 벽시계 제한이 맡는다.
const BUDGET_FRAMES := 2160000 ## 게임 시간 600분(10시간) - 사실상 벽시계가 상한
## (INBOX 답, 2026-09-07 05:18) "장 전환 뒤 600틱 무진행이면 FAIL" 지시의
## "틱"은 `_quest_mode_tick()` 호출 주기(PHYS_PER_QUEST_TICK=36프레임)를
## 가리킨다 - 600 * 36 = 21600프레임(게임 6분). 새 숫자가 아니라 지시
## 문구를 그대로 프레임 단위로 환산한 값.
const STALL_FRAMES := 21600 ## 퀘스트틱 600개(게임 6분)

## (INBOX 보정, 2026-09-07 05:54) 전역 RNG(회피 방향 등)가 시드 미고정이라
## 같은 STALL이 재실행에서 재현되지 않았다 - `check_autohunt_obstacle_stall.gd`의
## SEEDS 관례(20260907 시작)를 그대로 따른다. 새 숫자 아님.
const PROBE_SEED_DEFAULT := 20260907

## (INBOX 2026-10-20 00:11 감독 06:30 재검수) origin_throne 재현이 "장비·능력치
## 배분 없는 가짜 사람"이 아니라 실제 이 플레이의 10장 진입 상태를 쓰도록
## `check_origin_death_cause.gd`가 읽을 스냅샷을 전용 슬롯(99)에 남긴다.
func _save_chapter10_snapshot(player: Node) -> void:
	var snap := GameState.to_dict()
	snap["player_x"] = player.global_position.x
	snap["player_y"] = player.global_position.y
	snap["health"] = player.health
	snap["mana"] = player.mana
	snap["max_health"] = player.max_health
	snap["max_mana"] = player.max_mana
	snap["attack_damage"] = player.attack_damage
	var path := GameState.save_path(GameState.CHAPTER10_SNAPSHOT_SLOT)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(snap))
		print("CHAPTER10_SNAPSHOT_SAVED path=", path, " level=", GameState.level,
			" job=", GameState.job, " second_job=", GameState.second_job)


func _ready() -> void:
	var probe_seed := PROBE_SEED_DEFAULT
	var env_seed := OS.get_environment("PROBE_SEED")
	if env_seed != "":
		probe_seed = env_seed.to_int()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			probe_seed = arg.trim_prefix("--seed=").to_int()
	seed(probe_seed)
	print("PROBE_SEED=", probe_seed)

	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	GameState.reset()
	var guard := 0
	while main.dialogue_open and guard < 40:
		main._advance_dialogue()
		guard += 1
	main.quest_mode = true
	var player: Node = main.get_node("Player")
	var npc_key: String = main.TOWN_QUEST_NPC.get(GameState.current_map, "elder")
	var target: Vector2 = World.town_npc_position(GameState.current_map, npc_key)
	player.global_position = target + Vector2(1, 0)

	## (INBOX 답, 2026-09-06 18:45 ③) 자체 `died` 신호 구독 대신 `_quest_handle_death()`가
	## 실제로 실행되는 경로에서 직접 세는 `main.quest_death_count`를 읽는다.
	var start_msec := Time.get_ticks_msec()
	var last_stage: int = GameState.quest_stage
	var last_map: String = GameState.current_map
	var stage_seen := {last_stage: true}
	var zone_frames := {}
	var zone_start_frame := 0
	var last_boss_defeated: bool = GameState.boss_defeated
	var boss_log: Array = []
	## (INBOX 답, 2026-09-06 23:16 ③) 1분 샘플 근사로는 사망 지역을 못 믿는다
	## - `main.quest_death_count`가 늘어나는 순간(아직 죽은 지역을 벗어나기
	## 전, `_change_map`은 call_deferred라 한 프레임 늦게 반영됨) 바로 찍는다.
	var last_death_count: int = main.quest_death_count

	var last_progress_kills: int = GameState.kills
	var last_progress_map: String = GameState.current_map
	var last_progress_stage: int = GameState.quest_stage
	var last_progress_level: int = GameState.level
	var last_progress_frame := 0
	var stalled := false
	## (INBOX 답, 2026-09-07 00:12 ③) `_change_map`은 call_deferred라
	## `quest_death_count`가 늘어난 그 프레임엔 이미 map이 바뀌어 있다
	## (DEATH 줄이 사망 지역을 늘 village로 잘못 찍던 원인) - 직전 표본의
	## 비마을 map을 따로 기억해 뒀다가 그것을 찍는다.
	var last_nontown_map: String = ("" if World.is_town(GameState.current_map) else GameState.current_map)

	## (INBOX 답, 2026-09-07 05:18) 연속 시뮬레이션이 10장까지 이어가므로
	## 장 전환마다 (틱, 레벨, 장비 요약)을 찍어 §10에 실측표로 남긴다.
	var last_chapter: int = GameState.chapter
	print("CHAPTER_ENTER seed=", probe_seed, " chapter=", last_chapter, " tick=0 game_min=0.00",
		" level=", GameState.level, " weapon=", GameState.weapon, " armor=", GameState.armor,
		" job=", GameState.job, " second_job=", GameState.second_job, " stats=", GameState.stats)

	var final_frame := 0
	## (INBOX 결함, 2026-09-07 12:35) STALL 판정 순간 딱 그 프레임에만
	## get_slide_collision()을 물으면 충돌이 간헐적일 때 빈 배열만 잡힌다
	## (marsh cell(34,22): 6분 정체 내내 매 프레임 충돌하는 게 아니라
	## 벽 경계에서 밀림↔풀림을 반복). 정체 구간 전체에서 마지막으로 실제
	## 충돌이 있었던 프레임을 기억해 뒀다가 STALL 줄에 그걸 찍는다.
	var last_slide_hits: Array = []
	var last_slide_hit_frame := -1
	for i in BUDGET_FRAMES:
		final_frame = i
		if i % PHYS_PER_QUEST_TICK == 0:
			main._quest_mode_tick()
		await get_tree().physics_frame

		if player.get_slide_collision_count() > 0:
			last_slide_hit_frame = i
			last_slide_hits = []
			for si in player.get_slide_collision_count():
				var slide_col: KinematicCollision2D = player.get_slide_collision(si)
				var slide_collider: Object = slide_col.get_collider()
				last_slide_hits.append({"name": str(slide_collider.name) if slide_collider else "?",
					"class": slide_collider.get_class() if slide_collider else "?",
					"pos": (slide_collider as Node2D).global_position if slide_collider is Node2D else null,
					"parent": (slide_collider as Node).get_parent().get_path() if slide_collider is Node and (slide_collider as Node).get_parent() else null,
					"normal": slide_col.get_normal()})

		if GameState.boss_defeated != last_boss_defeated:
			boss_log.append({"game_min": i / float(FRAMES_PER_GAME_MIN), "result": ("승리" if GameState.boss_defeated else "재도전 가능")})
			last_boss_defeated = GameState.boss_defeated

		if GameState.quest_stage != last_stage or GameState.current_map != last_map:
			zone_frames[last_map] = int(zone_frames.get(last_map, 0)) + (i - zone_start_frame)
			zone_start_frame = i
			## (INBOX 답, 2026-09-07 00:12 ③) 귀환 원인 분기(물약조기귀환 vs
			## 후퇴포기 vs 통과 근접추격)가 로그만으로 갈리도록 지도 전이
			## 줄에 물약·골드·후퇴/재개/그라인드 상태를 같이 찍는다.
			print("tick=", i, " game_min=", "%.2f" % (i / float(FRAMES_PER_GAME_MIN)),
				" stage=", GameState.quest_stage, " map=", GameState.current_map,
				" chapter=", GameState.chapter, " pos=", player.global_position,
				" kills=", GameState.kills, " chapter_kills=", GameState.chapter_kills,
				" exp=", GameState.exp, " next_exp=", GameState.next_exp, " level=", GameState.level,
				" boss_defeated=", GameState.boss_defeated, " unlocked=", GameState.unlocked_maps,
				" potions=", GameState.potions, " gold=", GameState.gold,
				" retreat_streak=", main._quest_retreat_streak,
				" resume=", main._quest_resume_zone, " grind=", main._quest_grind_zone)
			last_stage = GameState.quest_stage
			last_map = GameState.current_map

		if GameState.chapter != last_chapter:
			print("CHAPTER_ENTER seed=", probe_seed, " chapter=", GameState.chapter, " tick=", i,
				" game_min=", "%.2f" % (i / float(FRAMES_PER_GAME_MIN)),
				" level=", GameState.level, " weapon=", GameState.weapon, " armor=", GameState.armor,
				" job=", GameState.job, " second_job=", GameState.second_job, " stats=", GameState.stats)
			last_chapter = GameState.chapter
			if GameState.chapter == 10:
				_save_chapter10_snapshot(player)

		if not World.is_town(GameState.current_map):
			last_nontown_map = GameState.current_map

		if i % FRAMES_PER_GAME_MIN == 0:
			## (INBOX 답, 2026-09-06 20:15) 맵 전체 적 수가 아니라 후퇴 판정과
			## 같은 반경(attack_range*2.5) 안에 실제로 있는 적만 센다.
			var near_dist: float = player.attack_range * 2.5
			var enemies_near := 0
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy.health > 0 and player.global_position.distance_to(enemy.global_position) <= near_dist:
					enemies_near += 1
			print("  hp game_min=", i / FRAMES_PER_GAME_MIN, " tick=", i, " health=", player.health, "/", player.max_health,
				" potions=", GameState.potions, " gold=", GameState.gold,
				" level=", GameState.level, " exp=", GameState.exp, "/", GameState.next_exp,
				" enemies_near=", enemies_near,
				" pos=", player.global_position, " walk=", player.auto_walk_active,
				" hunt=", player.auto_hunt, " map=", GameState.current_map,
				" deaths=", main.quest_death_count, " quest_mode=", main.quest_mode)

		if main.quest_death_count != last_death_count:
			var death_near_dist: float = player.attack_range * 2.5
			var death_enemies_near := 0
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy.health > 0 and player.global_position.distance_to(enemy.global_position) <= death_near_dist:
					death_enemies_near += 1
			print("DEATH game_min=", "%.2f" % (i / float(FRAMES_PER_GAME_MIN)),
				" map=", last_nontown_map, " level=", GameState.level,
				" hp_max=", player.max_health, " potions=", GameState.potions,
				" gold=", GameState.gold, " enemies_near=", death_enemies_near,
				" last_hit=", player.last_hit_source)
			last_death_count = main.quest_death_count

		stage_seen[GameState.quest_stage] = true

		## (INBOX 답, 2026-09-06 18:45 ③) quest_mode가 꺼지는 순간은 정체가
		## 아니라 실패다(사망 3연속 등, `_quest_handle_death()`가 규칙대로
		## 끈 것) - STALL(5분 무변화)까지 기다리지 않고 그 자리에서 바로 끊는다.
		if not main.quest_mode:
			print("QUEST_MODE_OFF tick=", i, " game_min=", "%.2f" % (i / float(FRAMES_PER_GAME_MIN)),
				" stage=", GameState.quest_stage, " map=", GameState.current_map,
				" deaths=", main.quest_death_count, " last_message=", main.get_node("HUD/Message").text)
			stalled = true
			break

		if GameState.kills != last_progress_kills or GameState.current_map != last_progress_map \
				or GameState.quest_stage != last_progress_stage or GameState.level != last_progress_level:
			last_progress_kills = GameState.kills
			last_progress_map = GameState.current_map
			last_progress_stage = GameState.quest_stage
			last_progress_level = GameState.level
			last_progress_frame = i
		elif i - last_progress_frame >= STALL_FRAMES:
			stalled = true
			var cell := Vector2i(player.global_position / World.TILE)
			var near_props: Array = main.get_node("World").props_near(cell, 2)
			## (INBOX 결함, 2026-09-07 11:50) marsh cell(34,22) auto_walk 무한
			## 밀기의 원인이 ①(경로 없음 → 직선 폴백)인지 ②(격자는 walkable인데
			## 실제 충돌체가 있음)인지 확정하려면 walk_target/waypoints/3x3
			## solid 판정이 필요하다.
			var solid3x3: Dictionary = main.get_node("World").walk_grid_solid_near(GameState.current_map, cell, 1)
			print("STALL seed=", probe_seed, " tick=", i, " reason=kills/map/stage/level 게임 6분(퀘스트틱 600개) 무변화",
				" health=", player.health, "/", player.max_health,
				" map=", GameState.current_map, " pos=", player.global_position, " cell=", cell,
				" gold=", GameState.gold, " potions=", GameState.potions,
				" near_props=", near_props,
				" auto_hunt=", player.auto_hunt, " auto_walk=", player.auto_walk_active,
				" velocity=", player.velocity, " stage=", GameState.quest_stage,
				" walk_target=", player.auto_walk_target,
				" waypoints=(", player.auto_walk_waypoints.size(), ",",
				(player.auto_walk_waypoints[0] if player.auto_walk_waypoints.size() > 0 else null), ")",
				" solid3x3=", solid3x3,
				" last_slide_hit_frame=", last_slide_hit_frame, " last_slide_hits=", last_slide_hits)
			break

		## (INBOX 답, 2026-09-07 05:18) quest_stage=70은 10장(최종장) 보스
		## 처치 후 대사까지 끝난 상태(main.gd:1085) - 여기서 멈춘다.
		if GameState.quest_stage >= 70:
			break

	zone_frames[last_map] = int(zone_frames.get(last_map, 0)) + (final_frame - zone_start_frame)

	var passed: bool = GameState.quest_stage >= 70 and stage_seen.has(1) and not stalled
	var wall_ms := Time.get_ticks_msec() - start_msec
	print("FINAL seed=", probe_seed, " stage=", GameState.quest_stage, " map=", GameState.current_map,
		" chapter=", GameState.chapter, " passed=", passed, " stalled=", stalled,
		" deaths=", main.quest_death_count, " level=", GameState.level, " exp=", GameState.exp, "/", GameState.next_exp,
		" game_min=", "%.2f" % (final_frame / float(FRAMES_PER_GAME_MIN)), " wall_ms=", wall_ms,
		" stage2_reached=", stage_seen.has(2))

	if not passed:
		print("ZONE_TIME(게임분):")
		for zone in zone_frames:
			print("  ", zone, "=", "%.2f" % (int(zone_frames[zone]) / float(FRAMES_PER_GAME_MIN)))
		print("BOSS_LOG:")
		for entry in boss_log:
			print("  game_min=", "%.2f" % entry.game_min, " result=", entry.result)
		var minutes: float = max(0.001, final_frame / float(FRAMES_PER_GAME_MIN))
		print("KILLS_PER_MIN=", "%.2f" % (GameState.kills / minutes))
		push_error("퀘스트모드가 예산 안에 10장(최종장) 완료 단계까지 진행되지 않았다(또는 정체)")
		get_tree().quit(1)
		return
	get_tree().quit()
