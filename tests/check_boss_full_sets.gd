extends Node
## 보스 세트(수호자 세트 등)는 원래대로 3조각(보스 확정 드랍 둘 + 상점템
## 하나)이고, 제작템은 여기 안 붙는다 - 제작템 4개는 별도의 "용기사 세트"로
## 묶인다.

func _ready() -> void:
	GameState.reset()
	var ok := true

	ok = _check("수호자 세트는 3조각", GameState.SETS["guardian_set"]["pieces"].size() == 3) and ok
	ok = _check("새 보스 전용 투구가 guardian_set", GameState.item_data("수호자의 투구").get("set") == "guardian_set") and ok
	ok = _check("boss_drop_extra(guardian)이 새 투구", GameState.boss_drop_extra("guardian") == "수호자의 투구") and ok
	ok = _check("제작템(용린 갑주)은 guardian_set이 아니라 boss_set",
		GameState.item_data("용린 갑주").get("set") == "boss_set") and ok

	GameState.level = 20
	GameState.inventory = ["수호자의 검", "숲의 심장", "수호자의 투구"]
	GameState.equip("수호자의 검")
	GameState.equip("숲의 심장")
	var atk_2pc := GameState.attack_bonus
	GameState.equip("수호자의 투구")
	var atk_3pc := GameState.attack_bonus
	ok = _check("3조각 다 맞추면 2조각보다 공격력이 더 오름", atk_3pc > atk_2pc) and ok
	ok = _check("세트 요약이 3/3으로 표시", GameState.active_set_summary()[0].ends_with("(3/3)")) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
