extends Node
## 낚싯대가 있고 연못이 있는 지역에서만 F로 낚시가 되는지, 값이 다른
## 물고기가 제값에 팔리는지 확인한다.
## 기존엔 main._try_fish()를 코드로 직접 호출해서만 확인했다 - 실제로
## 사람이 누르는 유일한 경로인 F 키(project.godot "fish" 액션,
## main.gd:_unhandled_input -> _try_fish())를 태운 적이 없었다(⑥ 규칙이
## 경고하는 "함수는 돌지만 사람이 누르면 반응 안 함" 패턴). check_potion_
## key_input.gd와 동일하게 main._unhandled_input()에 진짜 InputEventKey를
## 넣어 F 키 입력 -> _try_fish() 전체 경로를 확인한다.

func _send_key(main: Node, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.pressed = true
	main._unhandled_input(ev)


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	GameState.chapter = 1
	main._change_map("village", false)  # village 는 연못이 있다.

	ok = _check("낚싯대 없으면 낚시 실패", not GameState.can_fish()) and ok
	var before_count := GameState.inventory.size()
	_send_key(main, KEY_F)
	ok = _check("낚싯대 없이 F 눌러도 인벤토리 그대로", GameState.inventory.size() == before_count) and ok

	GameState.inventory.append(GameState.FISHING_ROD)
	ok = _check("낚싯대를 가지면 낚시 가능", GameState.can_fish()) and ok
	_send_key(main, KEY_F)
	ok = _check("F 키 입력만으로 낚시해서 인벤토리가 늘어남", GameState.inventory.size() == before_count + 2) and ok

	main.fish_cooldown = 0.0
	main._change_map("hill", false)  # hill 은 연못이 없다.
	var before_count2 := GameState.inventory.size()
	_send_key(main, KEY_F)
	ok = _check("연못 없는 지역에서는 낚시 안 됨", GameState.inventory.size() == before_count2) and ok

	# 가격표: 1장 물고기 중 가장 비싼 '빛나는 진주'가 제값에 팔림
	ok = _check("물고기별로 다른 값에 팔림", GameState.sell_price("빛나는 진주") == 90
		and GameState.sell_price("피라미") == 8) and ok

	# 낚싯대는 장비가 아니라 가방에 있기만 하면 되는 도구다. 인벤토리에서
	# E로 "착용"을 시도하면 "레벨 1 이상 필요" 같은 헷갈리는 문구 대신
	# 애초에 장비가 아니라는 걸 알려줘야 한다.
	main._toggle_inventory()
	main.inventory_index = GameState.inventory.find(GameState.FISHING_ROD)
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	main._unhandled_input(ev)
	ok = _check("낚싯대는 착용 시도해도 여전히 미착용", not GameState.is_equipped(GameState.FISHING_ROD)) and ok
	ok = _check("착용 불가 안내 문구가 명확함",
		main.get_node("HUD/Inventory/Notice").text == "착용할 수 없는 물건이다") and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
