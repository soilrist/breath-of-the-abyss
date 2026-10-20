extends Node
## 같은 이름의 중복 장비가 있을 때, 하나만 착용해도 나머지 사본은
## 착용 표시 없이 정상적으로 팔거나 창고에 넣을 수 있어야 한다.

func _ready() -> void:
	GameState.reset()
	var ok := true

	GameState.level = 20
	GameState.inventory = ["철검", "철검", "가죽 갑옷"]
	GameState.equip("철검")

	ok = _check("첫 번째 칸(장착된 사본)은 착용중", GameState.is_equipped_at(0)) and ok
	ok = _check("두 번째 칸(여분 사본)은 착용중 아님", not GameState.is_equipped_at(1)) and ok

	var gold_before := GameState.gold
	ok = _check("장착된 칸(0)은 판매 실패", GameState.sell_at(0) == 0) and ok
	ok = _check("판매 실패 후 인벤토리 그대로", GameState.inventory.size() == 3) and ok

	var sold := GameState.sell_at(1)
	ok = _check("여분 사본(1)은 판매 성공", sold > 0) and ok
	ok = _check("판매 후 인벤토리 2개로 줄어듦", GameState.inventory.size() == 2) and ok
	ok = _check("장착한 철검은 여전히 남아있음", GameState.inventory.has("철검")) and ok
	ok = _check("골드가 늘어남", GameState.gold == gold_before + sold) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
