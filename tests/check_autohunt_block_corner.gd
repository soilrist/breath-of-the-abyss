extends Node

## (감독 결함 조사, 2026-09-08) `check_quest_mode_all_chapters` ruins_w
## game_min 187.39 FREEZE 실측 좌표 재현: 담(ruin 3x3, cell(110,10)의 아래
## 절반 충돌체) 바로 위에서 담 아래 적(35px)을 쫓으면 직진이 막혀 옆걸음↔
## 복귀 춤이 몇 초 이어진다. 회피(`player._auto_avoid_obstacle`)가 결국 담을
## 돌아 들어가 처치하는지 본다 - 영원히 못 가면 진짜 FREEZE 결함.

## 지역이 한 화면으로 합쳐져 옛 ruins_w 실측 좌표(1768,181)/(1779,214)를 안쪽으로 옮겼다.
const PLAYER_POS := Vector2(200.0, 100.0)
const ENEMY_POS := Vector2(210.8, 133.1)
const RUN_TICKS := 1800 ## 게임 30초 상한(실측: 기사 8.4초, 망령 13.8초).


func _run(use_quest_tick: bool, want: String, static_enemy: bool) -> bool:
	seed(20260907)
	GameState.reset()
	GameState.unlock_map("ruins_w")
	GameState.chapter = 2
	GameState.quest_stage = 4
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	main.quest_mode = use_quest_tick
	main._change_map("ruins_w", false, PLAYER_POS)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var keep: Node = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if keep == null and e.archetype == want:
			keep = e
			continue
		e.remove_from_group("enemies")
		e.queue_free()
	await get_tree().process_frame
	keep.global_position = ENEMY_POS
	if static_enemy: keep.speed = 0.0
	player.global_position = PLAYER_POS
	player.invulnerability_time = 999.0
	player.potions = 99
	player.health = player.max_health
	player.auto_hunt = true
	player.auto_walk_active = false
	print("== run quest_tick=", use_quest_tick, " static=", static_enemy, " enemy=", keep.archetype, " r=", keep.body_radius(), " speed=", keep.speed, " hp=", keep.health)
	var world: Node = main.get_node("World")
	print("props=", world.props_near(Vector2i(13, 7), 1))
	print("solid=", world.walk_grid_solid_near("ruins_w", Vector2i(12, 6), 2))
	for i in RUN_TICKS:
		if use_quest_tick and i % 36 == 0:
			main._quest_mode_tick()
		await get_tree().physics_frame
		if i % 120 == 0:
			var ep: Vector2 = keep.global_position if is_instance_valid(keep) else Vector2.INF
			var eh: int = keep.health if is_instance_valid(keep) else -1
			print("t=%.2f p=%s v=%s e=%s ehp=%d walk=%s commit=%.2f esc=%.0f sign=%.0f retreat=%.2f stuck=%.2f noprog=%.2f bl=%d rc=%d" % [
				i / 60.0, player.global_position, player.velocity, ep, eh, player.auto_walk_active,
				player._auto_avoid_commit_time, player._auto_avoid_escalation, player._auto_avoid_sign,
				player._auto_avoid_retreat_time, player._auto_stuck_time, player._auto_hunt_no_progress_time,
				player._auto_hunt_blacklist.size(), player._auto_hunt_retreat_count])
		if not is_instance_valid(keep) or keep.health <= 0:
			print("ENEMY DEAD at t=%.2f kills=%d" % [i / 60.0, GameState.kills])
			break
	var ok: bool = GameState.kills >= 1
	main.queue_free()
	await get_tree().process_frame
	print("담 모서리(ruins_w) %s 처치 %d초 안에 " % [want, RUN_TICKS / 60], "OK" if ok else "FAIL")
	return ok


func _ready() -> void:
	var ok := true
	ok = await _run(true, "knight", false) and ok
	ok = await _run(true, "spirit", false) and ok
	print("RESULT ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
