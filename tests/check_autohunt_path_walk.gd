extends Node
## INBOX 22:08 (2). main.gd `_quest_east_exit_target()`(20:15 답 + 22:08
## 보정 - 앞내다본 열의 실제 길 행을 매 0.6초 틱마다 목표로 다시 잡음)를
## 그대로 써서, 마을이 아니고 동쪽(`e`) 출구가 있는 모든 지역(=사냥터/통과
## 지역)에서 서쪽 입구부터 auto_walk가 STALL(길 밖 바위 지대에 박혀 못
## 나감) 없이 동쪽 끝까지 도달하는지 확인한다. 회피 로직
## (player.gd `_auto_avoid_obstacle`)까지 실제로 태운다.
##
## 전투 개입은 이 조각의 관심사가 아니다(18:45/19:50 답이 이미 다룸) -
## 지역 진입 시 스폰된 적은 지워 순수 지형 통과만 본다.
##
## (INBOX 09:55/09:20 인수 재검증 중 발견, 2026-09-07) player.gd:430
## `_auto_avoid_sign` 결정이 전역 RNG(randf())를 써서 seed()를 안 걸면
## 회피 방향이 바퀴마다 흔들려 muted_gallery에서 드물게(3회 중 0회,
## `run_validation.sh` 전체 실행 1회에서 관측) 오래 갇혔다 - 이미
## `check_autohunt_obstacle_stall.gd`(04:25 결함)가 같은 원인으로 결정적
## seed를 쓰고 있어 같은 처방을 적용한다.
const RNG_SEED := 20260907

const RETARGET_PERIOD := 0.6 ## main.gd _quest_mode_tick과 같은 주기.
const PHYS_PER_RETARGET := 36 ## 0.6초 = 36 물리프레임(60fps), 프로브와 동일.
## 동쪽 끝에 "확실히" 도달했다고 볼 여유. main.gd EDGE_MARGIN(22px)보다
## 넉넉히 크게 잡아, 정확한 전환 판정을 재구현하지 않고도 STALL과
## 정상 도달을 구분한다.
const NEAR_EAST_EDGE := 40.0


func _list_transit_zones() -> Array:
	var zones: Array = []
	for area in World.AREAS.keys():
		if World.is_town(area):
			continue
		var exits: Dictionary = World.AREAS[area].get("exits", {})
		if exits.has("e"):
			zones.append(area)
	zones.sort()
	return zones


## 서쪽(또는 임의 지점)에서 시작해 auto_walk만으로 동쪽 끝(NEAR_EAST_EDGE
## 여유 안)까지 STALL 없이 도달하는지 본다. 도달하면 true.
func _walk_to_east(main: Node, player: Node, area: String, spawn: Vector2, max_frames: int) -> bool:
	GameState.unlock_map(area)
	main._change_map(area, false, spawn)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.remove_from_group("enemies")
		enemy.queue_free()

	player.auto_hunt = false
	player.velocity = Vector2.ZERO
	var bounds := World.pixel_size_of(area)
	# 실제 퀘스트틱과 같은 경로(A* 웨이포인트 포함)로 세팅한다.
	main._quest_set_auto_walk(main._quest_east_exit_target(area))
	var frames := 0
	var reached := false
	while frames < max_frames:
		await get_tree().physics_frame
		frames += 1
		if frames % PHYS_PER_RETARGET == 0:
			main._quest_set_auto_walk(main._quest_east_exit_target(area))
		if player.global_position.x >= bounds.x - NEAR_EAST_EDGE:
			reached = true
			break
	player.auto_walk_active = false
	return reached


func _ready() -> void:
	seed(RNG_SEED)
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	var ok := true
	var fails: Array = []
	for area in _list_transit_zones():
		var bounds := World.pixel_size_of(area)
		var max_frames: int = int((bounds.x / player.move_speed) * 4.0 + 5.0) * 60
		var reached: bool = await _walk_to_east(main, player, area, main._west_spawn(area), max_frames)
		if not reached:
			fails.append("%s pos=%s bounds=%s" % [area, player.global_position, bounds])
		ok = reached and ok

	## (INBOX 23:31 STALL 후속) 서->동 직선 진입이 아니라, 전투(auto_hunt)에
	## 끌려 길 밖 소품 지대 깊숙이 들어간 뒤 auto_walk로 복귀하는 경우의
	## 회귀 고정. 실측 좌표(hill, 그 열의 길은 y=216~232인데 y=300.924로
	## 약 70~85px 벗어나 있었다; 지역이 한 화면으로 합쳐진 뒤 (200,200)으로 옮김) - `QUEST_OFF_PATH_MARGIN` 보강 전에는
	## 이 지점에서 (391~411, 291~301) 사이를 영원히 오가며 못 벗어났다.
	var off_path_reached: bool = await _walk_to_east(
		main, player, "hill", Vector2(200.0, 200.0), 3600)
	if not off_path_reached:
		fails.append("hill(off-path) pos=%s" % [player.global_position])
	ok = off_path_reached and ok

	if fails.is_empty():
		print("(path_walk) 서->동 auto_walk 사냥터 전부 STALL 없이 동쪽 도달 OK")
	else:
		for f in fails:
			print("(path_walk) FAIL ", f)

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
