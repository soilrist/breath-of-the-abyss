extends Node
## HUD 크기 조절이 실제로 StatBar/SkillBar scale 에 반영되고 파일에 저장되는지 확인한다.

func _ready() -> void:
	# 이전 실행이 남긴 설정 파일이 있으면 결과가 오염되니 지운다.
	if FileAccess.file_exists("user://ui_settings.json"):
		DirAccess.remove_absolute("user://ui_settings.json")

	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var ok := true
	ok = ok and _check("기본값 1.0", main.get_node("HUD/StatBar").scale.x, 1.0)
	ok = ok and _check("기본값 스킬바 1.0", main.get_node("HUD/SkillBar").scale.x, 1.0)

	main._adjust_hud_scale("stat", -0.3)
	ok = ok and _check("체력바 축소 0.7", main.get_node("HUD/StatBar").scale.x, 0.7)
	main._adjust_hud_scale("skill", 0.1)
	ok = ok and _check("스킬바 확대 1.1", main.get_node("HUD/SkillBar").scale.x, 1.1)
	# 범위를 넘는 값은 한계에서 멈춰야 한다.
	main._adjust_hud_scale("skill", 1.0)
	ok = ok and _check("스킬바 상한 1.1", main.get_node("HUD/SkillBar").scale.x, 1.1)

	# 음악/효과음 음소거도 같은 파일에 같이 저장된다 - 껐다 켜도 유지되는지 확인.
	main._toggle_audio_mute("music")
	ok = ok and _check_bool("음악 음소거 켬", Audio.music_muted, true)

	# 파일로 저장됐는지, main.gd 를 다시 만들어도 불러와지는지 확인한다.
	# Audio 는 전역 싱글톤이라 값을 먼저 되돌려야 파일에서 실제로
	# 읽어오는지(그냥 이전 실행 상태가 남아있는 게 아닌지) 검증된다.
	Audio.set_music_muted(false)
	var main2: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main2)
	await get_tree().process_frame
	while main2.dialogue_open: main2._advance_dialogue()
	ok = ok and _check("재시작 후 체력바 유지", main2.get_node("HUD/StatBar").scale.x, 0.7)
	ok = ok and _check("재시작 후 스킬바 유지", main2.get_node("HUD/SkillBar").scale.x, 1.1)
	ok = ok and _check_bool("재시작 후 음악 음소거 유지", Audio.music_muted, true)

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, got: float, want: float) -> bool:
	var pass_ := absf(got - want) < 0.001
	print(label, " got=", got, " want=", want, " ", "OK" if pass_ else "FAIL")
	return pass_


func _check_bool(label: String, got: bool, want: bool) -> bool:
	var pass_ := got == want
	print(label, " got=", got, " want=", want, " ", "OK" if pass_ else "FAIL")
	return pass_
