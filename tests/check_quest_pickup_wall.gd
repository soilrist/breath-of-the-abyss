extends Node
## (감독 2026-09-09) hill FREEZE 회귀 검사. 상자 hill_a가 나무 담(96,88)
## 충돌체 안 (104,88)에 스폰되고, 퀘스트모드가 가까운 아이템을 직선 접근
## `_auto_hunt_tick`에 맡겨 영원히 나무를 밀던 결함. 세 가지를 본다:
## 1) 지역 스폰 픽업이 걷기 격자 solid 칸에 놓이지 않는다.
## 2) 소품 안에 억지로 놓은 픽업을 퀘스트모드가 건너뛰고 앞으로 나간다.
## 3) 순수 오토사냥도 그 픽업을 무진행 포기(blacklist)한다.
## (감독 2026-09-09) 소품 1/3 감소로 원래 나무 담(96,88)이 사라져 담 자리를
## 실행 시점에 고른다: hill 걷기 격자의 solid 칸(소품 몸체) 중 남쪽 두 칸이
## 비어 있고 x<=136인 첫 칸 - 픽업은 그 칸 중심, 플레이어는 11px 아래.
var WALL_PICKUP := Vector2.ZERO
var START := Vector2.ZERO


func _pick_wall(world: Node) -> void:
	var size: Vector2i = World.size_of("hill")
	for y in range(1, size.y - 3):
		for x in range(2, 9):
			var c := Vector2i(x, y)
			if not world.walk_grid_solid_near("hill", c, 0)[c]:
				continue
			var s1 := Vector2i(x, y + 1)
			var s2 := Vector2i(x, y + 2)
			if world.walk_grid_solid_near("hill", s1, 0)[s1] or world.walk_grid_solid_near("hill", s2, 0)[s2]:
				continue
			if not world.walkable("hill", s1) or not world.walkable("hill", s2):
				continue
			WALL_PICKUP = Vector2(c) * World.TILE + Vector2(8, 8)
			START = WALL_PICKUP + Vector2(-2.6, 11.07)
			print("WALL cell=", c, " pickup=", WALL_PICKUP, " start=", START)
			return


func _ready() -> void:
	seed(20260909)
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	GameState.reset()
	while main.dialogue_open: main._advance_dialogue()
	GameState.unlock_map("hill")
	main.quest_mode = true
	main._quest_timer.stop()
	var player: Node = main.get_node("Player")
	var world: Node = main.get_node("World")
	main._change_map("hill", false, Vector2(42, 135))
	await get_tree().physics_frame
	_pick_wall(world)
	var ok := WALL_PICKUP != Vector2.ZERO
	print("hill에 담 자리(소품 solid 칸)가 있다 ", "PASS" if ok else "FAIL")
	for pk in get_tree().get_nodes_in_group("pickups"):
		var cell := Vector2i((pk.global_position / World.TILE).floor())
		if world.walk_grid_solid_near("hill", cell, 0)[cell]:
			print("FAIL 스폰 픽업이 소품 칸 안: ", pk.global_position)
			ok = false
	print("스폰 픽업이 소품 칸을 피한다 ", "PASS" if ok else "FAIL")
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()
	for pk in get_tree().get_nodes_in_group("pickups"):
		pk.queue_free()
	await get_tree().process_frame
	var wall := preload("res://scenes/pickup.tscn").instantiate()
	wall.kind = "gold"
	wall.amount = 1
	wall.global_position = WALL_PICKUP
	main.add_child(wall)
	# 2) 퀘스트모드: 프리즈 자리에서 시작, 상자를 건너뛰고 동쪽 출구로 간다.
	GameState.kills = 40
	GameState.chapter_kills = 40
	player.global_position = START
	player.velocity = Vector2.ZERO
	var passed := false
	for t in 200:
		if t % 36 == 0:
			main._quest_mode_tick()
			while main.dialogue_open: main._advance_dialogue()
		await get_tree().physics_frame
		if player.global_position.x > START.x + 64.0 or GameState.current_map != "hill":
			passed = true
			break
	var skipped: bool = is_instance_valid(wall) and main._quest_pickup_skip.has(wall.get_instance_id())
	print("퀘스트모드가 소품 안 아이템을 건너뛴다 ", "PASS" if skipped else "FAIL", " skip=", main._quest_pickup_skip.size())
	print("퀘스트모드가 벽 앞에서 멈추지 않고 나아간다 ", "PASS" if passed else "FAIL", " pos=", player.global_position, " map=", GameState.current_map)
	ok = ok and skipped and passed
	# 3) 순수 오토사냥: 같은 픽업을 2.5초 무진행 뒤 포기한다.
	main.quest_mode = false
	player.auto_walk_active = false
	if GameState.current_map != "hill":
		main._change_map("hill", false, Vector2(42, 135))
		await get_tree().physics_frame
		for e in get_tree().get_nodes_in_group("enemies"):
			e.remove_from_group("enemies")
			e.queue_free()
		for pk in get_tree().get_nodes_in_group("pickups"):
			pk.queue_free()
		await get_tree().process_frame
		wall = preload("res://scenes/pickup.tscn").instantiate()
		wall.kind = "gold"
		wall.amount = 1
		wall.global_position = WALL_PICKUP
		main.add_child(wall)
	player.global_position = START
	player.velocity = Vector2.ZERO
	player.auto_hunt = true
	var gave_up := false
	for t in 360:
		await get_tree().physics_frame
		if is_instance_valid(wall) and player._auto_hunt_blacklist.has(wall.get_instance_id()):
			gave_up = true
			break
	print("오토사냥이 못 닿는 아이템을 포기한다 ", "PASS" if gave_up else "FAIL")
	ok = ok and gave_up
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
