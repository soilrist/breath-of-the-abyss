extends Node
## INBOX 지시(2026-09-06 10:05 (a), 승인(감독 2026-09-07 05:18 (ii))
## "1~10장을 한 번의 연속 시뮬레이션으로 이어 달리며 각 장 진입 시각을
## 기록하고, 장 전환 시점부터 600틱(퀘스트틱, =21600 물리 프레임=게임
## 6분) 무진행이면 FAIL"의 헤드리스 check 버전. `tests/auto_quest_probe.gd`의
## 연속 시뮬레이션 로직을 그대로 가져와 `check_*.gd` 관례(RESULT PASS/FAIL,
## exit code)로 감싼다.
##
## ④ 요구("120틱 동안 위치 변화 <4px인데 velocity!=0이면 그 자리에서 FAIL")도
## 추가한다 - 6분 매크로 정체(kills/map/stage/level 무변화)보다 먼저 잡아
## 정확한 좌표를 남기려는 것. 판정은 120프레임(2초) **구간 전체**의 순이동
## 거리로 잰다 - 매 프레임 직전 프레임 대비 이동량으로 재면 걷기 기본속도
## (72px/s = 프레임당 1.2px)조차 항상 4px 미만이라 정상 보행에서까지
## 상시 오탐한다(이 check 작성 중 실측: SEED=20260907, tick=191에서 오탐).
##
## run_validation.sh에는 아직 안 붙인다 - `auto_quest_probe.gd`와 같은 이유로
## 10장 완주까지 벽시계 수십 분이 들 수 있어 매 커밋 검증에 넣기엔 너무
## 길다(그 파일도 같은 이유로 안 붙어 있음, STATUS.md 참고). 수동으로
## `godot --headless --fixed-fps 60 res://tests/check_quest_mode_all_chapters.tscn`
## 로 돌린다.

const PHYS_PER_QUEST_TICK := 36 ## main.gd _quest_timer wait_time=0.6초 = 36 물리 프레임.
const FRAMES_PER_GAME_MIN := 3600
const BUDGET_FRAMES := 7200000 ## 게임 2000분 상한(4~5장 보스 재도전으로 600분으론 5장까지만 닿았다, 감독 2026-09-08) - 실제 상한은 호출 쪽 벽시계.
const STALL_FRAMES := 21600 ## 퀘스트틱 600개(게임 6분) 무진행 매크로 정체.
## ④는 "120틱(2초)"을 제시했으나 그대로 쓰면 오탐이 난다: `player.gd`의
## 자체 포기 임계값 `_AUTO_HUNT_GIVEUP_STUCK`가 2.5초라, 정상적인
## "막힌 적 포기하고 새 적 고르기" 전환 도중에도 2초 창이 먼저 걸린다
## (실측: seed=20260907, tick=1560, hill map, auto_hunt=true에서 FREEZE
## 오발동). 게임 자체 포기 주기보다 넉넉히 긴 180프레임(3초)으로 늘린다.
## (감독 결함 조사, 2026-09-08) ruins_w cell(110,11) 담 모서리 실측: 담 너머
## 적을 향한 회피(옆걸음↔복귀) 춤이 3초 창의 순이동 0으로 잡혔지만
## `check_autohunt_block_corner`로 재현하니 14초 안에 돌아 들어가 처치한다.
## 진짜 결함(속도≠0인데 위치가 영원히 고정, hill_ridge 사례)은 창을 늘려도
## 그대로 잡히므로 `check_autohunt_obstacle_stall`의 STALL 기준(10초)과 맞춘다.
const FREEZE_FRAMES := 600
const PROBE_SEED_DEFAULT := 20260907

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond

func _ready() -> void:
	var probe_seed := PROBE_SEED_DEFAULT
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			probe_seed = arg.trim_prefix("--seed=").to_int()
	seed(probe_seed)
	print("SEED=", probe_seed)

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
	## (감독 2026-09-09) 사망 위치·틱 진단 - 3연속 무진행 사망의 실제 장면 파악용.
	player.died.connect(func() -> void:
		print("DEATH map=", GameState.current_map, " pos=", player.global_position, " lvl=", GameState.level,
			" hp=", player.health, "/", player.max_health, " pot=", GameState.potions, " kills=", GameState.kills,
			" streak=", main._quest_death_streak, " resume=", main._quest_resume_zone, " grind=", main._quest_grind_zone))
	var npc_key: String = main.TOWN_QUEST_NPC.get(GameState.current_map, "elder")
	var target: Vector2 = World.town_npc_position(GameState.current_map, npc_key)
	player.global_position = target + Vector2(1, 0)

	var chapters_entered := {1: true}
	var last_chapter: int = GameState.chapter
	var last_progress_kills: int = GameState.kills
	var last_progress_map: String = GameState.current_map
	var last_progress_stage: int = GameState.quest_stage
	var last_progress_level: int = GameState.level
	var last_progress_frame := 0
	var freeze_window_pos: Vector2 = player.global_position
	var freeze_window_frame := 0
	var freeze_trail: Array = []
	var freeze_window_target: Vector2 = player.auto_walk_target
	var freeze_window_walk: bool = player.auto_walk_active
	var freeze_window_map: String = GameState.current_map
	var freeze_window_kills: int = GameState.kills
	var freeze_window_enemy_hp: int = _enemy_hp_sum()
	var fail_reason := ""
	var final_frame := 0

	for i in BUDGET_FRAMES:
		final_frame = i
		if i % PHYS_PER_QUEST_TICK == 0:
			main._quest_mode_tick()
		await get_tree().physics_frame
		## (감독 결함 조사, 2026-09-08) marsh game_min 269 STALL이 원인 추적
		## 불가였다 - 게임 1분마다 상태 한 줄.
		if i % FRAMES_PER_GAME_MIN == 0:
			print("MIN %d map=%s pos=%s stage=%d kills=%d ckills=%d lvl=%d hp=%d/%d pot=%d gold=%d hunt=%s walk=%s tgt=%s wp=%d retreat=%s/%d deaths=%d exp=%d/%d sp=%d" % [
				i / FRAMES_PER_GAME_MIN, GameState.current_map, player.global_position, GameState.quest_stage,
				GameState.kills, GameState.chapter_kills, GameState.level, player.health, player.max_health,
				GameState.potions, GameState.gold, player.auto_hunt, player.auto_walk_active,
				player.auto_walk_target, player.auto_walk_waypoints.size(), main._quest_retreat_zone, main._quest_retreat_streak,
				main.quest_death_count, GameState.exp, GameState.next_exp, GameState.stat_points])

		## (INBOX 결함 보정, 2026-09-07 12:20) hill (140.452, 242.7111)
		## tick=7380 실측: 실제로는 안 막혀 있었다(point_hits=[], solid3x3
		## 전부 false) - 근접 전투로 제자리에 서 있다가(auto_walk=false)
		## 그 적이 죽자 `_quest_engage_nearest_enemy()`가 즉시 먼 다음 적으로
		## `auto_walk_target`을 새로 잡은 순간이 FREEZE 창(3초) 끝자락과
		## 겹쳐, "3초 내내 안 막혔다"를 "방금 막 새 목표로 전속력을 낸
		## 첫 프레임"과 같은 창으로 묶어 오탐했다. 목표(walk_target) 또는
		## 이동 모드(auto_walk_active)가 바뀐 순간은 그 자체가 진행이므로
		## 창을 다시 연다 - 새 숫자 없이 기존 STALL의 progress-reset과
		## 같은 패턴 재사용.
		## (감독 결함 조사, 2026-09-08) dungeon↔village 물약 왕복 실측: 두 지역
		## 스폰이 같은 (42,135)라 `_change_map`을 사이에 둔 3초 창이 "순이동 0"
		## 으로 묶여 FREEZE 오탐(kills 208→210, 골드 +20으로 실제론 진행 중).
		## 지역 전환도 진행이므로 창을 다시 연다.
		## (감독 2026-09-09, 6장 abyssal_trench 358분 실측) 벽 모서리(24,24)에
		## 몰린 채 뒤로 빠지려는 조수술사 중간보스(4040hp)를 제자리에서
		## 근접으로 계속 때리는 정상 전투(20초에 2640 피해, 남은 1400)를
		## "10초 순이동 1px"로 FREEZE 오탐. 처치 수가 늘거나 적 체력 합이
		## 줄었으면(피해를 주고 있음) 진행 중이므로 창을 다시 연다.
		var enemy_hp_sum := _enemy_hp_sum()
		if player.auto_walk_target != freeze_window_target or player.auto_walk_active != freeze_window_walk \
				or GameState.current_map != freeze_window_map \
				or GameState.kills != freeze_window_kills or enemy_hp_sum < freeze_window_enemy_hp:
			freeze_window_target = player.auto_walk_target
			freeze_window_walk = player.auto_walk_active
			freeze_window_map = GameState.current_map
			freeze_window_kills = GameState.kills
			freeze_window_enemy_hp = enemy_hp_sum
			freeze_window_pos = player.global_position
			freeze_window_frame = i

		if GameState.chapter != last_chapter:
			print("CHAPTER_ENTER chapter=", GameState.chapter, " tick=", i,
				" game_min=", "%.2f" % (i / float(FRAMES_PER_GAME_MIN)), " level=", GameState.level)
			last_chapter = GameState.chapter
			chapters_entered[GameState.chapter] = true

		if i % 30 == 0:
			freeze_trail.append([i, player.global_position, player.velocity])
			if freeze_trail.size() > 24:
				freeze_trail.pop_front()
		## ④ 위치 고정 즉시 감지: FREEZE_FRAMES(10초) 구간 전체의 순이동 거리로 판정.
		if i - freeze_window_frame >= FREEZE_FRAMES:
			var window_moved: float = player.global_position.distance_to(freeze_window_pos)
			if window_moved < 4.0 and player.velocity.length() > 1.0:
				fail_reason = "FREEZE"
				var world: Node = main.get_node("World")
				var cell := Vector2i(player.global_position / World.TILE)
				var solid3x3: Dictionary = world.walk_grid_solid_near(GameState.current_map, cell, 1)
				var nearest: Node2D = null
				var nearest_dist := INF
				for enemy in get_tree().get_nodes_in_group("enemies"):
					if enemy.health <= 0:
						continue
					var d: float = player.global_position.distance_to(enemy.global_position)
					if d < nearest_dist:
						nearest_dist = d
						nearest = enemy
				var hit_info: Array = []
				for si in player.get_slide_collision_count():
					var col: KinematicCollision2D = player.get_slide_collision(si)
					var collider: Object = col.get_collider()
					hit_info.append({"name": str(collider.name) if collider else "?",
						"class": collider.get_class() if collider else "?",
						"pos": (collider as Node2D).global_position if collider is Node2D else null,
						"parent": (collider as Node).get_parent().get_path() if collider is Node and (collider as Node).get_parent() else null,
						"normal": col.get_normal()})
				print("FREEZE tick=", i, " game_min=", "%.2f" % (i / float(FRAMES_PER_GAME_MIN)),
					" pos=", player.global_position, " map=", GameState.current_map,
					" stage=", GameState.quest_stage, " auto_hunt=", player.auto_hunt,
					" auto_walk=", player.auto_walk_active, " velocity=", player.velocity,
					" window_moved=", window_moved,
					" walk_target=", player.auto_walk_target,
					" waypoints=(", player.auto_walk_waypoints.size(), ",",
					(player.auto_walk_waypoints[0] if player.auto_walk_waypoints.size() > 0 else null), ")",
					" solid3x3=", solid3x3,
					" hunt_target_pos=", (nearest.global_position if nearest != null else null),
					" hunt_target_dist=", nearest_dist,
					" slide_hits=", hit_info)
				## (감독 2026-09-09) 9장 echo_of_forest FREEZE 원인 추적용 - 적 전체와
				## 오토사냥 상태, 최근 10초 발자취를 같이 찍는다.
				var roster: Array = []
				for enemy in get_tree().get_nodes_in_group("enemies"):
					roster.append({"kind": enemy.archetype, "pos": enemy.global_position, "hp": enemy.health,
						"dist": "%.1f" % player.global_position.distance_to(enemy.global_position),
						"bl": player._auto_hunt_blacklist.has(enemy.get_instance_id()),
						"speed": enemy.speed, "vel": enemy.velocity})
				print("FREEZE_ENEMIES ", roster)
				print("FREEZE_HUNT target_id=", player._auto_hunt_target_id, " noprog=", player._auto_hunt_no_progress_time,
					" rc=", player._auto_hunt_retreat_count, " bl=", player._auto_hunt_blacklist,
					" commit=", player._auto_avoid_commit_time, " esc=", player._auto_avoid_escalation,
					" sign=", player._auto_avoid_sign, " retreat=", player._auto_avoid_retreat_time,
					" stuck=", player._auto_stuck_time, " attack_range=", player.attack_range,
					" pickups=", get_tree().get_nodes_in_group("pickups").size(), " speed=", player._current_move_speed())
				print("FREEZE_TRAIL ", freeze_trail)
				var vis: Array = []
				for c in main.get_node("HUD").get_children():
					if c is CanvasItem and c.visible: vis.append(c.name)
				print("FREEZE_CTX paused=", get_tree().paused, " dialogue=", main.dialogue_open, " quest=", main.quest_mode, " lock=", main.transition_lock, " potions=", GameState.potions, " gold=", GameState.gold, " kills=", GameState.kills, " level=", GameState.level, " deaths=", main.quest_death_count, " restock=", main._quest_restock_zone, " resume=", main._quest_resume_zone, " hud=", vis)
				break
			freeze_window_pos = player.global_position
			freeze_window_frame = i
			freeze_window_kills = GameState.kills
			freeze_window_enemy_hp = enemy_hp_sum

		if not main.quest_mode:
			fail_reason = "QUEST_MODE_OFF"
			print("QUEST_MODE_OFF tick=", i, " game_min=", "%.2f" % (i / float(FRAMES_PER_GAME_MIN)),
				" stage=", GameState.quest_stage, " map=", GameState.current_map,
				" deaths=", main.quest_death_count)
			break

		if GameState.kills != last_progress_kills or GameState.current_map != last_progress_map \
				or GameState.quest_stage != last_progress_stage or GameState.level != last_progress_level:
			last_progress_kills = GameState.kills
			last_progress_map = GameState.current_map
			last_progress_stage = GameState.quest_stage
			last_progress_level = GameState.level
			last_progress_frame = i
		elif i - last_progress_frame >= STALL_FRAMES:
			fail_reason = "STALL"
			var cell := Vector2i(player.global_position / World.TILE)
			print("STALL tick=", i, " game_min=", "%.2f" % (i / float(FRAMES_PER_GAME_MIN)),
				" map=", GameState.current_map, " pos=", player.global_position, " cell=", cell,
				" auto_hunt=", player.auto_hunt, " auto_walk=", player.auto_walk_active,
				" velocity=", player.velocity, " stage=", GameState.quest_stage,
				" walk_target=", player.auto_walk_target, " wp=", player.auto_walk_waypoints.size(),
				" hunt_target=", player._auto_hunt_target_id, " blacklist=", player._auto_hunt_blacklist.size(),
				" grind=", main._quest_grind_zone, " resume=", main._quest_resume_zone)
			for e in get_tree().get_nodes_in_group("enemies"):
				print("STALL_ENEMY ", e.name, " pos=", e.global_position, " cell=", Vector2i(e.global_position / World.TILE),
					" hp=", e.health, "/", e.max_health, " area=", e.area_id, " visible=", e.visible,
					" solid=", main.get_node("World").walk_grid_solid_near(GameState.current_map, Vector2i(e.global_position / World.TILE), 0))
			break

		if GameState.quest_stage >= 70:
			break

	var ok := true
	ok = _check("10장(최종장) 완료 단계(quest_stage>=70) 도달", GameState.quest_stage >= 70) and ok
	ok = _check("정체/정지 없이 진행(fail_reason=%s)" % fail_reason, fail_reason == "") and ok
	for c in range(1, 11):
		ok = _check("%d장 진입 확인" % c, chapters_entered.has(c)) and ok

	print("FINAL stage=", GameState.quest_stage, " chapter=", GameState.chapter,
		" game_min=", "%.2f" % (final_frame / float(FRAMES_PER_GAME_MIN)), " fail_reason=", fail_reason)
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _enemy_hp_sum() -> int:
	var total := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		total += maxi(int(enemy.health), 0)
	return total
