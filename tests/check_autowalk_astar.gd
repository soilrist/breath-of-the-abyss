extends Node
## (INBOX 답, 2026-09-07 08:10) auto_walk가 AStarGrid2D로 실제 경로를
## 구하는지 확인한다. hill_ridge의 계단형 소품 담(cell 3,7/4,7 부근,
## §10.7에서 직진+옆걸음으로 못 넘던 곳)을 낀 서쪽 입구 -> 그 담 너머
## 목표까지 경로 길이가 0보다 큰지(=길을 찾아냄)만 본다. 실제로 그
## 경로를 밟아 도착하는지는 auto_quest_probe 5시드로 따로 검증한다.

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var area := "hill_ridge"
	GameState.unlock_map(area)
	main._change_map(area, false, main._west_spawn(area))

	var world: Node = main.get_node("World")
	var from_pos: Vector2 = main._west_spawn(area)
	var beyond_wall := Vector2(6 * World.TILE + 8.0, 7 * World.TILE + 8.0)
	var t0 := Time.get_ticks_usec()
	var waypoints: Array = world.walk_waypoints(area, from_pos, beyond_wall)
	var elapsed_ms := (Time.get_ticks_usec() - t0) / 1000.0
	## (INBOX 결함, 2026-09-07 09:20 ①②) 실측용 — PASS 조건에는 안 넣는다.
	## `_quest_mode_tick`이 0.6초마다 이 호출을 반복하므로 이 숫자가 크면
	## 그만큼 매 tick 멈춘다는 뜻. 숫자는 §10.7에 옮겨 적는다. 격자 캐시(②)
	## 적용 후 같은 지역 2번째 호출(다른 좌표)이 훨씬 빨라야 캐시가 실제로
	## 재사용되는지 확인된다.
	print("(측정) walk_waypoints() 1회(격자 새로 생성) 소요 ", elapsed_ms, "ms (area=", area, ")")
	var t1 := Time.get_ticks_usec()
	world.walk_waypoints(area, beyond_wall, from_pos)
	var elapsed2_ms := (Time.get_ticks_usec() - t1) / 1000.0
	print("(측정) walk_waypoints() 2회째(캐시 재사용) 소요 ", elapsed2_ms, "ms (area=", area, ")")

	var ok := true
	ok = _check("(1) hill_ridge 서쪽 입구->담 너머 목표 경로 길이>0", waypoints.size() > 0) and ok

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
