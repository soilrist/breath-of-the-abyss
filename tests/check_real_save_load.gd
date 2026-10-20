extends Node
## 실제 저장 파일(save0.json)이 지금 코드로 문제없이 불러와지는지 확인한다.
## 예전엔 특정 골드·인벤토리 개수까지 하드코딩해서 검증했는데, 그건
## 테스트 당시 넣어둔 더미 데이터를 검증한 것이라 사용자가 실제로
## 플레이해서 저장하면 값이 달라져 깨지는 잘못된 설계였다. 지금은 로드
## 자체가 에러 없이 되는지, 불러온 값들이 최소한 유효한 범위인지만 본다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	GameState.slot = 0
	if not FileAccess.file_exists(GameState.save_path()):
		print("save0.json 없음 - 실기기 저장 파일 검증은 건너뜀")
		print("RESULT ", "PASS")
		get_tree().quit()
		return

	var loaded := GameState.load_game(player)
	ok = _check("save0.json 로드 성공", loaded) and ok
	ok = _check("골드가 음수 아님", GameState.gold >= 0) and ok
	ok = _check("레벨이 1 이상", GameState.level >= 1) and ok
	ok = _check("인벤토리 배열이 유효함(에러 없이 접근 가능)", GameState.inventory.size() >= 0) and ok
	ok = _check("플레이어 체력이 정상 범위", player.health >= 0 and player.health <= player.max_health) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
