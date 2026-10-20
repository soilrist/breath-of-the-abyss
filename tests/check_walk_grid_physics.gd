extends Node
## (감독 2026-09-09) auto_walk A* 격자가 실제 물리와 같은지. 바닥 타일엔
## 충돌체가 없으니 solid는 가장자리 0번 칸과 소품 몸체 칸뿐이어야 한다.
## 테두리 글자를 얼룩·길로도 쓰는 지역(twisted_sanctum, temple)에서 얼룩
## 칸이 벽으로 찍혀 5칸 옆 적을 지도 한 바퀴 돌아 쫓던 STALL의 회귀 검사.
const AREAS_TO_CHECK := ["twisted_sanctum", "temple", "hall_of_afterimages", "cave", "hill"]


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	GameState.reset()
	while main.dialogue_open: main._advance_dialogue()
	var world: Node = main.get_node("World")
	var ok := true
	for area in AREAS_TO_CHECK:
		GameState.unlock_map(area)
		main._change_map(area, false, Vector2(42, 135))
		await get_tree().physics_frame
		var size: Vector2i = World.size_of(area)
		var prop_cells := {}
		for child in world._props.get_children():
			if not (child is StaticBody2D):
				continue
			var half: Vector2 = child.get_node("CollisionShape2D").shape.size * 0.5
			var c0 := Vector2i((child.position - half) / World.TILE)
			var c1 := Vector2i(((child.position + half) / World.TILE).ceil()) - Vector2i.ONE
			for gy in range(c0.y, c1.y + 1):
				for gx in range(c0.x, c1.x + 1):
					prop_cells[Vector2i(gx, gy)] = true
		var wrong := 0
		for y in size.y:
			for x in size.x:
				var c := Vector2i(x, y)
				var ring := x < 1 or y < 1 or x >= size.x - 1 or y >= size.y - 1
				var solid: bool = world.walk_grid_solid_near(area, c, 0)[c]
				if solid != (ring or prop_cells.has(c)):
					wrong += 1
		var area_ok := wrong == 0
		print(area, " 걷기 격자 solid = 가장자리+소품 몸체 칸 ", "PASS" if area_ok else "FAIL", " wrong=", wrong)
		ok = ok and area_ok
	# twisted_sanctum 무덤(120,180) 아래: (93,196)->(167,216)은 바닥 줄로 곧장 간다.
	main._change_map("twisted_sanctum", false, Vector2(42, 135))
	await get_tree().physics_frame
	var wp: Array = world.walk_waypoints("twisted_sanctum", Vector2(93, 196), Vector2(167, 216))
	var short_ok := wp.size() <= 8
	print("twisted_sanctum 무덤 아래 5칸 옆 목표까지 짧은 경로 ", "PASS" if short_ok else "FAIL", " wp=", wp.size())
	ok = ok and short_ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
