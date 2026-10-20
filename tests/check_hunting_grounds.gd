extends Node
## 새로 넣은 사냥터 4곳(바람 능선/깊은 늪/얼어붙은 능선/잿불 협곡)이 실제로
## 갈 수 있고, 몬스터가 깔리고, 지도 좌표가 안 겹치는지 확인한다.

const NEW_AREAS := ["hill_ridge", "marsh_deep", "frost_ridge", "ash_hollow"]
const PARENTS := {"hill_ridge": "hill", "marsh_deep": "marsh", "frost_ridge": "snowfield", "ash_hollow": "abyss"}

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	# 지도 좌표가 다른 지역과 안 겹치는지.
	var seen := {}
	for area in World.AREAS:
		var grid: Vector2i = World.AREAS[area].get("grid", Vector2i.ZERO)
		if seen.has(grid) and (NEW_AREAS.has(area) or NEW_AREAS.has(seen[grid])):
			ok = _check("%s 와 %s 지도 좌표 겹침" % [area, seen[grid]], false) and ok
		seen[grid] = area

	for area in NEW_AREAS:
		var parent: String = PARENTS[area]
		ok = _check("%s -> %s 연결 있음" % [parent, area], World.exit_of(parent, _dir_to(parent, area)) == area) and ok
		var back_dir := _dir_to(area, parent)
		ok = _check("%s -> %s 되돌아오는 연결 있음" % [area, parent], World.exit_of(area, back_dir) == parent) and ok
		ok = _check("%s 몬스터 배치 있음" % area, not (main.AREA_SPAWNS.get(area, []) as Array).is_empty()) and ok

		main._change_map(area, false)
		await get_tree().process_frame
		var mobs := get_tree().get_nodes_in_group("enemies")
		ok = _check("%s 입장 시 몬스터 스폰" % area, not mobs.is_empty()) and ok
		var size := World.pixel_size_of(area)
		ok = _check("%s 크기가 정상" % area, size.x > 0 and size.y > 0) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


## 두 지역이 어느 방향으로 이어지는지 찾는다. exits 표에서 직접 뒤진다.
func _dir_to(from_area: String, to_area: String) -> String:
	var exits: Dictionary = World.AREAS.get(from_area, {}).get("exits", {})
	for dir in exits:
		if str(exits[dir]) == to_area:
			return str(dir)
	return ""


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
