extends Node
## to_dict()의 equipped(이름 딕셔너리)는 check_save_load_enhance_uid.gd가
## equipped_uid(칸 번호)만 확인하고 있어 이름 자체의 왕복은 검사가 없었다
## (STATUS.md "다음 후보"). weapon/armor/helmet/trinket 4칸을 착용 후
## 저장/불러오기해도 이름이 그대로 복원되는지 확인한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	GameState.reset()
	GameState.slot = 3
	GameState.level = 20
	GameState.inventory = ["철검", "가죽 갑옷", "가죽 모자", "구리 반지"]
	ok = _check("무기 착용", GameState.equip("철검")) and ok
	ok = _check("방어구 착용", GameState.equip("가죽 갑옷")) and ok
	ok = _check("투구 착용", GameState.equip("가죽 모자")) and ok
	ok = _check("장신구 착용", GameState.equip("구리 반지")) and ok

	ok = _check("저장 성공", GameState.save_game(player)) and ok

	GameState.reset()
	ok = _check("불러오기 성공", GameState.load_game(player)) and ok
	ok = _check("무기 이름 복원", str(GameState.equipped.get("weapon", "")) == "철검") and ok
	ok = _check("방어구 이름 복원", str(GameState.equipped.get("armor", "")) == "가죽 갑옷") and ok
	ok = _check("투구 이름 복원", str(GameState.equipped.get("helmet", "")) == "가죽 모자") and ok
	ok = _check("장신구 이름 복원", str(GameState.equipped.get("trinket", "")) == "구리 반지") and ok

	var save_file := GameState.save_path()
	if FileAccess.file_exists(save_file):
		DirAccess.remove_absolute(save_file)

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
