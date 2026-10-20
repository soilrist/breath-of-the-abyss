extends Node
## 레벨업해도 전투 중에 특성 창이 강제로 안 뜨고, 능력치 화면(C)의
## 특성 탭에서 안전하게 고를 수 있는지 확인한다.

var main: Node


func _ready() -> void:
	main = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	GameState.perk_picks = 0
	main._on_enemy_defeated(999999, 0, "beast")
	ok = _check("레벨업해도 특성 창이 자동으로 안 뜸", not main.perk_open) and ok
	ok = _check("선택권은 그래도 쌓임", GameState.perk_picks > 0) and ok

	main._toggle_character()
	ok = _check("C키로 능력치 화면 열림(일시정지도 됨)", main.character_open and get_tree().paused) and ok
	main.character_mode = "stats"
	_press("move_right")
	ok = _check("→ 누르면 특성 탭으로 전환", main.character_mode == "perks") and ok

	var picks_before: int = GameState.perk_picks
	main.perk_index = 0
	_press("interact")
	ok = _check("특성 탭에서 E로 고르면 선택권이 줄어듦", GameState.perk_picks == picks_before - 1) and ok
	ok = _check("특성 탭에서 골라도 예전 강제 창은 안 뜸", not main.perk_open) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	main._unhandled_input(ev)
