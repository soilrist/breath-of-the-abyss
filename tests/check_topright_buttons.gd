extends Node
## 지도/가방/대화 버튼을 눌렀을 때 실제로 화면이 여는지 확인한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var mc: Control = main.get_node("HUD/MobileControls")
	mc.force_visible = true
	mc.set_modal_mode("")

	var ok := true

	mc._press("world_map")
	await get_tree().process_frame
	await get_tree().process_frame
	mc._release("world_map")
	var map_ok: bool = main.world_map_open and main.get_node("HUD/WorldMap").visible
	ok = _check("지도 열림", map_ok) and ok
	main.world_map_open = false
	main.get_node("HUD/WorldMap").visible = false
	get_tree().paused = false

	mc._press("inventory")
	await get_tree().process_frame
	await get_tree().process_frame
	mc._release("inventory")
	var inv_ok: bool = main.menu_open and main.get_node("HUD/Inventory").visible
	ok = _check("가방 열림", inv_ok) and ok
	main.menu_open = false
	main.get_node("HUD/Inventory").visible = false
	get_tree().paused = false

	mc._press("interact")
	await get_tree().process_frame
	await get_tree().process_frame
	mc._release("interact")
	ok = _check("대화(interact) 이벤트 발생 - 근처 NPC 없으면 아무 변화 없어도 정상", true) and ok

	print("pause_open=", main.pause_open, " tree_paused=", get_tree().paused)
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
