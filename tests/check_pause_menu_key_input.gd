extends Node
## docs/STATUS.md "다음 후보"(81번)가 남긴 것: main.gd:2919~2940의 일시정지
## 화면 숫자키(1 저장/2 타이틀로/3~6 HUD 크기/7~8 음소거/9 종료)는 지금까지
## HUD/MobileControls의 대응 버튼(Save/Title/MusicMute/SfxMute/Quit)만 마우스
## 클릭으로 검증됐고, main.gd 자체의 키보드 숫자키 분기(_is_key)는 실제
## InputEventKey 입력으로 검증된 적이 없었다. 여기서는 트리를 죽이지 않는
## KEY_1/3/4/5/6/7/8을 한 트리에서 순서대로 검증한다(2 타이틀로/9 종료는
## 트리 자체를 죽이므로 check_pause_title_key_input.gd/
## check_pause_quit_key_input.gd에서 따로 다룬다).

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _ready() -> void:
	if FileAccess.file_exists("user://ui_settings.json"):
		DirAccess.remove_absolute("user://ui_settings.json")

	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	main.set_pause_open(true)
	await get_tree().process_frame
	var ok := _check("일시정지 화면 열림(사전조건)", main.pause_open and get_tree().paused)

	# KEY_1: 저장. save0.json이 남으면 다른 검사 프로세스를 오염시키니
	# check_mobile_button_click.gd와 동일하게 백업/복원한다.
	var save_path: String = GameState.save_path()
	var had_save_backup := FileAccess.file_exists(save_path)
	var save_backup: PackedByteArray = []
	if had_save_backup:
		save_backup = FileAccess.get_file_as_bytes(save_path)

	main.get_node("HUD/Pause/Info").text = ""
	_send_key(main, KEY_1)
	ok = _check("KEY_1 실제 입력으로 저장 완료 문구 표시", main.get_node("HUD/Pause/Info").text.contains("저장 완료")) and ok
	ok = _check("KEY_1 입력으로 save0.json 생성 확인", FileAccess.file_exists(save_path)) and ok

	if had_save_backup:
		var restore_f := FileAccess.open(save_path, FileAccess.WRITE)
		restore_f.store_buffer(save_backup)
		restore_f.close()
	else:
		DirAccess.remove_absolute(save_path)

	# KEY_3/4: 체력바 크기 -/+
	var stat_before: float = main.hud_stat_scale
	_send_key(main, KEY_3)
	ok = _check("KEY_3 입력으로 체력바 축소", main.hud_stat_scale < stat_before) and ok
	ok = _check("KEY_3 입력이 실제 StatBar scale에 반영됨",
		absf(main.get_node("HUD/StatBar").scale.x - main.hud_stat_scale) < 0.001) and ok
	var stat_after_shrink: float = main.hud_stat_scale
	_send_key(main, KEY_4)
	ok = _check("KEY_4 입력으로 체력바 확대", main.hud_stat_scale > stat_after_shrink) and ok

	# KEY_5/6: 스킬바 크기 -/+
	var skill_before: float = main.hud_skill_scale
	_send_key(main, KEY_5)
	ok = _check("KEY_5 입력으로 스킬바 축소", main.hud_skill_scale < skill_before) and ok
	ok = _check("KEY_5 입력이 실제 SkillBar scale에 반영됨",
		absf(main.get_node("HUD/SkillBar").scale.x - main.hud_skill_scale) < 0.001) and ok
	var skill_after_shrink: float = main.hud_skill_scale
	_send_key(main, KEY_6)
	ok = _check("KEY_6 입력으로 스킬바 확대", main.hud_skill_scale > skill_after_shrink) and ok

	# KEY_7/8: 음악/효과음 음소거 토글
	var music_before: bool = Audio.music_muted
	_send_key(main, KEY_7)
	ok = _check("KEY_7 실제 입력으로 음악 음소거 토글", Audio.music_muted != music_before) and ok
	var sfx_before: bool = Audio.sfx_muted
	_send_key(main, KEY_8)
	ok = _check("KEY_8 실제 입력으로 효과음 음소거 토글", Audio.sfx_muted != sfx_before) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().paused = false
	main.queue_free()
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
