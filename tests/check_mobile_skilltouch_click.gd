extends Node
## HUD/MobileControls의 SkillTouch0~5 버튼은 지금까지 실제 클릭 경로 검사가
## 없었다(check_mobile_button_click.gd가 Attack~Sell까지는 다뤘지만
## SkillTouch는 미검증으로 남겨뒀다, docs/STATUS.md 참고). SkillTouch4/5는
## 2차 전직 스킬이라 GameState.second_job이 있어야 보이고 눌리는데,
## mobile_controls.gd:38~39의 pressed 연결은 _ready() 시점의
## GameState.active_skills().size()로 한 번만 이뤄진다 — main.tscn을
## add_child()하기 *전에* job/second_job을 미리 정해둬야 SkillTouch4/5가
## 실제로 연결된 상태로 뜬다(연결 안 된 채면 클릭해도 아무 일도 안 일어나
## "버튼은 보이는데 안 눌린다"는 진짜 버그가 될 수 있는 지점).

func _click(button: Button) -> void:
	# check_mobile_button_click.gd와 동일한 이유로 get_viewport().push_input()을
	# 쓴다: project.godot의 window/stretch/mode="canvas_items"가 320x240 논리
	# 뷰포트를 확대하므로 Input.parse_input_event()로는 stretch 변환을 안 탄다.
	var center: Vector2 = button.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	button.get_viewport().push_input(down, true)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	up.global_position = center
	button.get_viewport().push_input(up, true)
	await get_tree().process_frame


func _ready() -> void:
	var ok := true

	# job/second_job을 main.tscn이 트리에 들어가기 전에 정해서 SkillTouch4/5
	# pressed 연결이 실제로 이뤄지게 한다(위 주석 참고).
	GameState.reset()
	GameState.job = "mage"
	GameState.second_job = "elementalist"
	GameState.level = 40

	var game: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	while game.dialogue_open: game._advance_dialogue()
	await get_tree().process_frame

	var player: Node = game.get_node("Player")
	var mobile := game.get_node("HUD/MobileControls")
	mobile.force_visible = true
	mobile.show()
	mobile.set_modal_mode("")
	await get_tree().process_frame

	# mage 1차 스킬 4개: flame/ice_spear/mana_burst는 마력을 쓰고,
	# heal("마나 순환")은 마력 대신 HP를 쓴다(hp_cost_pct).
	var skills: Array = GameState.active_skills()
	ok = _check("mage+elementalist 조합에서 스킬 6개가 준비됨", skills.size() == 6) and ok

	for i in range(4):
		var data: Dictionary = skills[i]
		player.mana = 999
		player.max_mana = 999
		player.health = player.max_health
		player.skill_cooldowns[i] = 0.0
		var btn: Button = mobile.get_node("SkillTouch%d" % i)
		ok = _check("SkillTouch%d 버튼이 실제로 화면에 보임" % i, btn.visible) and ok
		var mana_before: int = player.mana
		var hp_before: int = player.health
		await _click(btn)
		if data.has("hp_cost_pct"):
			ok = _check("진짜 마우스 클릭으로 SkillTouch%d(%s)가 HP를 소모(cast_skill)" %
				[i, str(data["name"])], player.health < hp_before) and ok
		else:
			ok = _check("진짜 마우스 클릭으로 SkillTouch%d(%s)가 마력을 소모(cast_skill)" %
				[i, str(data["name"])], player.mana == mana_before - int(data["cost"])) and ok

	# 2차 전직 스킬 2개(SkillTouch4/5): 둘 다 마력을 쓴다.
	for i in range(4, 6):
		var data: Dictionary = skills[i]
		player.mana = 999
		player.max_mana = 999
		player.skill_cooldowns[i] = 0.0
		var btn: Button = mobile.get_node("SkillTouch%d" % i)
		ok = _check("SkillTouch%d(2차 전직) 버튼이 실제로 화면에 보임" % i, btn.visible) and ok
		var mana_before: int = player.mana
		await _click(btn)
		ok = _check("진짜 마우스 클릭으로 SkillTouch%d(%s)가 마력을 소모(cast_skill)" %
			[i, str(data["name"])], player.mana == mana_before - int(data["cost"])) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
