extends Node
## (감독 2026-09-09) "몬스터가 겹쳐서 빠르게 움직이는 것처럼 보인다" -
## `_area_spawn_points()`가 같은 칸에 두 마리를 깔면 CharacterBody2D 둘이 매
## 프레임 서로 밀어내며 떨린다. AREA_SPAWNS의 모든 지역에서 스폰 칸이 겹치지
## 않는지 확인한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var dup := 0
	var total := 0
	for map_name in main.AREA_SPAWNS:
		var seen := {}
		for p in main._area_spawn_points(map_name):
			total += 1
			var at: Vector2 = p["at"]
			if seen.has(at):
				dup += 1
				print("DUP map=", map_name, " at=", at, " kind=", p["kind"])
			seen[at] = true
	print("spawn points total=", total, " dup=", dup)
	main.queue_free()
	print("RESULT ", "PASS" if dup == 0 else "FAIL")
	get_tree().quit()
