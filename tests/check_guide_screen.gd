extends Node
## G 키로 가이드 화면이 열리고, 전체 쪽(GUIDE_PAGE_COUNT)을 순서대로 도는지 확인한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	main._toggle_guide()
	ok = _check("G로 가이드 열림", main.guide_open and main.get_node("HUD/Guide").visible) and ok
	ok = _check("첫 쪽은 강화 설명", main.get_node("HUD/Guide/Info").text.begins_with("[강화]")) and ok

	main.guide_page += 1
	main._refresh_guide()
	ok = _check("두번째 쪽은 소켓 설명", main.get_node("HUD/Guide/Info").text.begins_with("[소켓")) and ok

	main.guide_page += 1
	main._refresh_guide()
	ok = _check("세번째 쪽은 세트(드랍) 설명", main.get_node("HUD/Guide/Info").text.begins_with("[세트 효과 1/5")) and ok

	main.guide_page += 1
	main._refresh_guide()
	ok = _check("네번째 쪽은 세트(제작 1) 설명", main.get_node("HUD/Guide/Info").text.begins_with("[세트 효과 2/5")) and ok

	main.guide_page += 1
	main._refresh_guide()
	ok = _check("다섯번째 쪽은 세트(제작 2) 설명", main.get_node("HUD/Guide/Info").text.begins_with("[세트 효과 3/5")) and ok

	main.guide_page += 1
	main._refresh_guide()
	ok = _check("세트(5~7장) 설명", main.get_node("HUD/Guide/Info").text.begins_with("[세트 효과 4/5")) and ok

	main.guide_page += 1
	main._refresh_guide()
	ok = _check("세트(8~10장) 설명", main.get_node("HUD/Guide/Info").text.begins_with("[세트 효과 5/5")) and ok

	main.guide_page += 1
	main._refresh_guide()
	ok = _check("여섯번째 쪽은 정령 인장 설명", main.get_node("HUD/Guide/Info").text.begins_with("[정령 인장]")) and ok

	main.guide_page += 1
	main._refresh_guide()
	ok = _check("일곱번째 쪽은 제작(1) 설명", main.get_node("HUD/Guide/Info").text.begins_with("[제작 1/3")) and ok

	main.guide_page += 1
	main._refresh_guide()
	ok = _check("여덟번째 쪽은 제작(2) 설명", main.get_node("HUD/Guide/Info").text.begins_with("[제작 2/3")) and ok

	main.guide_page += 1
	main._refresh_guide()
	ok = _check("제작(3, 5~10장) 설명", main.get_node("HUD/Guide/Info").text.begins_with("[제작 3/3")) and ok
	ok = _check("제작 3쪽에 정수 6종 이름", main.get_node("HUD/Guide/Info").text.contains("근원의 정수")) and ok

	main.guide_page += 1
	main._refresh_guide()
	ok = _check("보스 설명", main.get_node("HUD/Guide/Info").text.begins_with("[보스]")) and ok

	main.guide_page += 1
	main._refresh_guide()
	ok = _check("아홉번째 쪽은 낚시 설명", main.get_node("HUD/Guide/Info").text.begins_with("[낚시]")) and ok

	main.guide_page += 1
	main._refresh_guide()
	ok = _check("열번째 쪽은 탑(1) 설명", main.get_node("HUD/Guide/Info").text.begins_with("[탑 1/2")) and ok

	main.guide_page += 1
	main._refresh_guide()
	ok = _check("열한번째 쪽은 탑(2) 설명", main.get_node("HUD/Guide/Info").text.begins_with("[탑 2/2")) and ok

	main.guide_page += 1
	main._refresh_guide()
	ok = _check("열두번째 쪽은 직업·전직(1) 설명", main.get_node("HUD/Guide/Info").text.begins_with("[직업·전직 1/2")) and ok

	main.guide_page += 1
	main._refresh_guide()
	ok = _check("열세번째 쪽은 직업·전직(2) 설명", main.get_node("HUD/Guide/Info").text.begins_with("[직업·전직 2/2")) and ok

	main.guide_page += 1
	main._refresh_guide()
	ok = _check("열네번째 쪽은 조작·상태효과 설명", main.get_node("HUD/Guide/Info").text.begins_with("[조작·상태효과]")) and ok

	main.guide_page += 1
	main._refresh_guide()
	ok = _check("열다섯번째는 다시 강화(순환)", main.get_node("HUD/Guide/Info").text.begins_with("[강화]")) and ok

	main._toggle_guide()
	ok = _check("닫으면 가이드 안 보임", not main.guide_open and not main.get_node("HUD/Guide").visible) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
