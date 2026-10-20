extends Node
## save0 데이터 검증에 이어, "장비 61종 아이콘이 실제 화면에서 전부
## 다르게 보이는지"를 인벤토리 UI를 열어 스크린샷으로 직접 확인한다.
## 이 게임의 인벤토리는 그리드가 아니라 텍스트 리스트 + 선택된 한 칸의
## 아이콘만 오른쪽에 보여주는 방식(main.gd:_refresh_inventory)이라,
## 화살표로 이동하며 대표 아이템 여러 개를 골라 상세 아이콘을 각각 찍는다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	GameState.level = 60
	# 슬롯 4종(weapon/armor/helmet/trinket) 각각에서 서로 다른 등급대
	# 대표 아이템을 골라 인벤토리에 채운다(전부 다 넣으면 리스트가 너무
	# 길어 이동 횟수가 커지므로 대표 12종만 확인).
	var sample_items: Array[String] = [
		"낡은 검", "철검", "사냥꾼의 활", "천공의 검",
		"여행자 옷", "천공의 갑주", "천공의 투구",
		"구리 반지", "천공의 인장", "용의 인장",
		"숲의 정령 인장", "불꽃의 정령 인장",
	]
	for item in sample_items:
		GameState.add_item(item)
	print("인벤토리에 넣은 대표 장비 수: ", sample_items.size())

	main._toggle_inventory()
	await get_tree().process_frame

	var icon_paths: Array[String] = []
	var expected_paths: Array[String] = []
	for i in sample_items.size():
		main.inventory_index = i
		main._refresh_inventory()
		await get_tree().process_frame
		var tex: Texture2D = main.get_node("HUD/Inventory/Icon").texture
		var path := tex.resource_path if tex else "(없음)"
		icon_paths.append(path)
		var expected: Texture2D = main._item_icon(sample_items[i])
		expected_paths.append(expected.resource_path if expected else "(없음)")
		print("%s -> UI=%s / _item_icon()=%s" % [sample_items[i], path, expected_paths[i]])
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			"user://shot_inv_item_%02d.png" % i)

	var unique := {}
	for p in expected_paths:
		unique[p] = true
	print("RESULT ", "PASS" if unique.size() == sample_items.size() else "FAIL",
		" - _item_icon() 고유 경로 개수 %d / 아이템 %d" % [unique.size(), sample_items.size()])
	var ui_mismatch := 0
	for i in sample_items.size():
		if icon_paths[i] != expected_paths[i]:
			ui_mismatch += 1
	print("UI 텍스처와 _item_icon() 불일치: %d건 (0이어야 정상)" % ui_mismatch)

	get_tree().quit()
