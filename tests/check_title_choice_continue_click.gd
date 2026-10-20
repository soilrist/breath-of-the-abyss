extends Node
## title.gd TouchMenu/Choice1("이어하기") 실제 클릭 경로 검사, 저장이 있는
## 경우(has_save() == true). _activate()의 case 1은 GameState.pending_load
## = true 를 찍은 뒤 change_scene_to_file()로 검사 트리를 갈아치운다 —
## check_title_choice_newgame_click.gd와 같은 이유로 클릭 뒤 self.get_tree()는
## 못 쓰고, GameState(오토로드)로만 확인한다. 실제 저장 파일(save0.json)을
## 건드리므로 시작 전 백업하고 끝나면 복원한다.

func _click(button: Button) -> void:
	var center: Vector2 = button.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	button.get_viewport().push_input(down, true)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	up.global_position = center
	button.get_viewport().push_input(up, true)


func _ready() -> void:
	GameState.slot = 0
	var path := GameState.save_path()
	var backup: PackedByteArray = []
	var had_backup := FileAccess.file_exists(path)
	if had_backup:
		backup = FileAccess.get_file_as_bytes(path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"level": 3, "current_map": "village", "game_cleared": false}))
	f.close()

	GameState.pending_load = false

	var title: Node = preload("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame

	var touch_menu: Control = title.get_node("TouchMenu")
	touch_menu.visible = true
	var choice1: Button = touch_menu.get_node("Choice1")

	_click(choice1)

	var ok := GameState.pending_load
	print("Choice1(저장 있음) 클릭 -> GameState.pending_load = true 로 설정됨",
		" ", "OK" if ok else "FAIL")
	print("RESULT ", "PASS" if ok else "FAIL")

	if had_backup:
		var restore := FileAccess.open(path, FileAccess.WRITE)
		restore.store_buffer(backup)
		restore.close()
	else:
		DirAccess.remove_absolute(path)

	(Engine.get_main_loop() as SceneTree).quit()
