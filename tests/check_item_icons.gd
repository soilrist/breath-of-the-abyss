extends Node
## 장비 61종이 전부 서로 다른 아이콘을 쓰는지 확인한다.
## 예전엔 무기 아니면 방어구, 딱 두 장을 돌려썼고 그 뒤로도 슬롯·손그림
## 종류별로 몇 장을 나눠 썼다. 그래서 등급이 하늘과 땅 차이인 장비가
## 인벤토리에서 똑같이 보였다. 지금은 아이템마다 전용 그림이 있다
## (GameState.ITEM_ICONS, tools/build_item_icons.py 가 생성).

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	# 1. 장비마다 아이콘 표에 등록되어 있어야 한다. 빠지면 슬롯 공통 아이콘으로
	#    떨어지면서 다른 장비와 똑같이 보인다.
	var missing: Array[String] = []
	for item in GameState.EQUIPMENT:
		if not GameState.ITEM_ICONS.has(item):
			missing.append(str(item))
	ok = _check("장비 %d종 전부 전용 아이콘이 지정됨%s" % [
		GameState.EQUIPMENT.size(),
		"" if missing.is_empty() else " (빠짐: %s)" % ", ".join(missing),
	], missing.is_empty()) and ok

	# 2. 두 장비가 같은 그림을 쓰면 안 된다.
	var seen := {}
	var clashes: Array[String] = []
	for item in GameState.EQUIPMENT:
		var path: String = main._item_icon(str(item)).resource_path
		if seen.has(path):
			clashes.append("%s = %s" % [seen[path], item])
		else:
			seen[path] = item
	ok = _check("장비 아이콘이 서로 겹치지 않음%s" % (
		"" if clashes.is_empty() else " (겹침: %s)" % ", ".join(clashes)
	), clashes.is_empty()) and ok

	# 3. 지정한 파일이 실제로 있어야 한다.
	var absent: Array[String] = []
	for item in GameState.ITEM_ICONS:
		var path := "res://assets/items/%s.png" % GameState.ITEM_ICONS[item]
		if not ResourceLoader.exists(path):
			absent.append(path)
	ok = _check("아이콘 파일이 전부 존재함%s" % (
		"" if absent.is_empty() else " (없음: %s)" % ", ".join(absent)
	), absent.is_empty()) and ok

	# 4. 장비가 아닌 물건은 예전 규칙 그대로다.
	var fish_icon: Texture2D = main._item_icon("피라미")
	ok = _check("물고기 아이콘은 전용 그림",
		fish_icon.resource_path == "res://assets/items/icon_fish.png") and ok
	var misc_icon: Texture2D = main._item_icon("보스의 파편")
	ok = _check("장비도 물고기도 아닌 물건은 기타 아이콘",
		misc_icon.resource_path == "res://assets/items/icon_misc.png") and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
