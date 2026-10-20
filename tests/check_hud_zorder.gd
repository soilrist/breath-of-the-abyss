extends Node
## INBOX C 발견: 인벤토리/상점/창고/월드맵 등 패널이 열리면 그 아래 그려지는
## HUD/StatBar(Lv·골드·HP·MP·EXP)가 패널 뒤로 가려졌었다(같은 offset_bottom=206
## 대역에서 형제 노드 순서상 StatBar가 패널보다 먼저 그려졌기 때문).
## StatBar가 항상 다른 패널들보다 나중에(위에) 그려지는지 형제 순서로 검사한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var hud: Node = main.get_node("HUD")
	var stat_idx: int = hud.get_node("StatBar").get_index()
	var ok := true

	# StatBar와 겹치는 y대역(offset_bottom<=238)을 쓰는 패널들.
	var panels := ["Inventory", "Shop", "Storage", "Character", "WorldMap", "Skills", "Quest", "Guide"]
	for p in panels:
		var idx: int = hud.get_node(p).get_index()
		if idx > stat_idx:
			print("FAIL: ", p, " (index ", idx, ") 이 StatBar(index ", stat_idx,
				") 보다 나중에 그려져 StatBar를 가릴 수 있음")
			ok = false

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
