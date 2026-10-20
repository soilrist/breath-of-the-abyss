extends Node
## 전직하면 캐릭터 머리 위에 직업 아이콘이 "즉시" 표시되는지 검증한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var player: Node = main.get_node("Player")
	var icon: Sprite2D = player.get_node("JobIcon")

	var ok := true
	ok = _check("전직 전에는 아이콘이 숨겨져 있다", not icon.visible) and ok

	GameState.level = 20
	GameState.gold = 10000
	GameState.job = ""
	var result := GameState.change_job("warrior")
	ok = _check("change_job(warrior) 성공(빈 문자열 반환)", result == "") and ok
	print("GameState.job 값=", GameState.job)

	# 다음 physics 프레임에 _update_sprite -> _update_job_icon 이 반영된다.
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("icon.visible=", icon.visible, " icon.texture=", icon.texture)
	ok = _check("전사로 전직 직후 아이콘이 보인다", icon.visible) and ok
	ok = _check("전사 아이콘 텍스처 로드됨", icon.texture != null) and ok
	var warrior_tex := icon.texture

	result = GameState.change_job("mage")
	ok = _check("재전직(mage) 성공", result == "") and ok
	await get_tree().physics_frame
	ok = _check("마법사로 재전직 직후 아이콘이 보인다", icon.visible) and ok
	ok = _check("마법사 아이콘 텍스처가 전사와 다르다", icon.texture != warrior_tex) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
