extends Node
## 장비를 갈아 끼우는 것 말고 그냥 "벗기"가 안 됐던 문제를 확인한다.
## 아이폰에서 착용/해제 버튼이 "대화"라고 떠서 헷갈리던 것도 같이 고쳤다.

func _ready() -> void:
	GameState.reset()
	var ok := true

	GameState.level = 20
	GameState.inventory = ["철검", "가죽 갑옷", "가죽 모자"]
	GameState.equip("철검")
	GameState.equip("가죽 갑옷")
	GameState.equip("가죽 모자")

	ok = _check("착용한 무기의 슬롯을 찾음", GameState.equipped_slot_of("철검") == "weapon") and ok
	ok = _check("안 낀 물건은 빈 슬롯", GameState.equipped_slot_of("낡은 검") == "") and ok

	ok = _check("투구는 벗으면 빈 자리로", GameState.unequip("helmet")) and ok
	ok = _check("벗은 투구 슬롯이 비어있음", str(GameState.equipped.get("helmet", "")) == "") and ok
	ok = _check("이미 빈 슬롯은 다시 벗겨지지 않음", not GameState.unequip("helmet")) and ok

	ok = _check("무기는 벗으면 기본 무기로 돌아감", GameState.unequip("weapon")) and ok
	ok = _check("무기 슬롯이 낡은 검(기본)으로 돌아감", GameState.equipped["weapon"] == GameState.weapon) and ok
	ok = _check("철검은 여전히 인벤토리에 있음(사라지지 않음)", GameState.inventory.has("철검")) and ok

	# 실제 씬에서 인벤토리 착용/해제 토글 + 모바일 버튼 라벨 확인.
	GameState.reset()
	GameState.level = 20
	GameState.inventory = ["철검", "가죽 갑옷"]
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	main._toggle_inventory()
	main.inventory_index = main._inventory_order().find(GameState.inventory.find("철검"))
	var interact_label: Button = main.get_node("HUD/MobileControls/Interact")
	ok = _check("안 낀 물건 선택하면 버튼이 착용", interact_label.text == "착용") and ok

	press_action(main, "interact")
	ok = _check("착용 버튼 누르면 실제로 착용됨", GameState.equipped["weapon"] == "철검") and ok
	ok = _check("착용하면 버튼이 해제로 바뀜", interact_label.text == "해제") and ok

	press_action(main, "interact")
	ok = _check("해제 버튼 누르면 실제로 벗겨짐", GameState.equipped["weapon"] != "철검") and ok
	ok = _check("벗으면 버튼이 다시 착용으로", interact_label.text == "착용") and ok

	main._toggle_inventory()
	ok = _check("인벤토리를 닫으면 버튼 라벨이 대화로 돌아감", interact_label.text == "대화") and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func press_action(game: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game._unhandled_input(event)


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
