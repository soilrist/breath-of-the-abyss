extends Node
## 예전 동서남북 던전(황혼의 폐사원/가라앉은 유적/빙하 균열/심연 너머)이
## 부모 지역에 흡수된 뒤에도 그 전용 몬스터가 부모 지역 스폰 목록에
## 실제로 남아 있는지 확인한다(텍스처 로드 실패 등은 여기서 걸린다).

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	var cases := {
		"glade": "eye", "marsh_deep": "mollusc",
		"frost_gorge": "frostbear", "ash_ridge": "dragon",
	}
	for area_id in cases:
		main._change_map(area_id, false)
		await get_tree().process_frame
		var enemies := get_tree().get_nodes_in_group("enemies")
		var kinds := []
		for e in enemies:
			kinds.append(str(e.kind.get("id", "")))
		ok = _check("%s: 지역 진입 후 몬스터 스폰됨" % area_id, enemies.size() > 0) and ok
		ok = _check("%s: 스폰된 몬스터에 흡수된 던전 전용 종류(%s) 포함" % [area_id, cases[area_id]],
			kinds.has(cases[area_id])) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
