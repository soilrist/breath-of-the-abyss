extends Node
## to_dict()엔 있지만 실제 저장/불러오기 왕복 검사가 없던 기본 스탯 필드
## (exp/next_exp/kills/potions/revive_potions)를 확인한다. attack_bonus 등
## 4종 보너스는 from_dict()가 아니라 장비 재계산으로 채워지는 파생값이라
## (game_state.gd:1242~1245) 대상이 아니다. tower_titles는 check_tower_titles.gd가
## 이미 왕복 검사한다(중복 불필요).

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	GameState.reset()
	GameState.slot = 5
	GameState.exp = 42
	GameState.next_exp = 130
	GameState.kills = 17
	GameState.potions = 6
	GameState.revive_potions = 2

	ok = _check("저장 성공", GameState.save_game(player)) and ok

	GameState.reset()
	ok = _check("불러오기 성공", GameState.load_game(player)) and ok
	ok = _check("경험치 복원", GameState.exp == 42 and GameState.next_exp == 130) and ok
	ok = _check("처치 수 복원", GameState.kills == 17) and ok
	ok = _check("포션 보유량 복원", GameState.potions == 6 and GameState.revive_potions == 2) and ok

	var save_file := GameState.save_path()
	if FileAccess.file_exists(save_file):
		DirAccess.remove_absolute(save_file)

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
