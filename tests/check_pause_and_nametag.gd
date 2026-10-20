extends Node

## 일시정지 화면 겹침 수정과 적 이름표 거리 기반 숨김을 검증한다.
func _ready() -> void:
	var ok := true
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(game)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# 1) 터치 모드를 강제로 켜서 일시정지 텍스트가 짧아지는지 확인.
	var mobile: Control = game.get_node("HUD/MobileControls")
	mobile.force_visible = true
	mobile.visible = true
	game.set_pause_open(true)
	await get_tree().process_frame
	var touch_text: String = game.get_node("HUD/Pause/Info").text
	if touch_text.length() > 60:
		print("FAIL touch pause text too long: ", touch_text.length())
		ok = false
	if touch_text.find("WASD") != -1:
		print("FAIL touch pause text still has keyboard hints")
		ok = false
	print("touch pause text: ", touch_text)

	# 2) 터치 모드를 끄면 원래의 상세 키보드 안내가 나오는지 확인.
	mobile.force_visible = false
	mobile.visible = false
	game._refresh_pause_info()
	var kb_text: String = game.get_node("HUD/Pause/Info").text
	if kb_text.find("WASD") == -1:
		print("FAIL keyboard pause text missing WASD hint")
		ok = false
	print("keyboard pause text len: ", kb_text.length())
	game.set_pause_open(false)
	await get_tree().process_frame

	# 3) 적 이름표: 멀리 있으면 숨겨지고 가까이 오면 보이는지 확인.
	var enemy := (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(enemy)
	await get_tree().process_frame
	await get_tree().process_frame
	var player := game.get_node("Player")
	enemy.global_position = player.global_position + Vector2(500, 0)
	enemy._physics_process(0.016)
	if enemy.get_node("Name").visible:
		print("FAIL name label visible when far away")
		ok = false
	enemy.global_position = player.global_position + Vector2(10, 0)
	enemy._physics_process(0.016)
	if not enemy.get_node("Name").visible:
		print("FAIL name label hidden when close")
		ok = false
	print("name label near visible: ", enemy.get_node("Name").visible)

	if ok:
		print("RESULT PASS")
	else:
		print("RESULT FAIL")
	get_tree().quit()
