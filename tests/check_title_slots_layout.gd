extends Node
## 타이틀 화면 저장 슬롯 목록이 화면(240px) 밖으로 잘리지 않는지 확인한다.
## 예전엔 화면 아래쪽에 있어서 슬롯 3개+안내문구를 다 못 담고 잘렸다
## ("빨간 부분 보이지, 글이 짤리잖아" 피드백) - 오른쪽 빈 공간으로 옮겼다.

func _ready() -> void:
	var title: Node = preload("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	var ok := true

	var slots: Label = title.get_node("Slots")
	ok = _check("슬롯 목록이 화면 높이(240) 안에 다 들어감", slots.offset_bottom <= 240.0) and ok
	ok = _check("슬롯 목록이 메뉴 오른쪽(빈 공간)에 있음", slots.offset_left > title.get_node("Menu").offset_right) and ok
	ok = _check("슬롯 텍스트에 안내문구+슬롯 3개가 다 있음",
		slots.text.contains("슬롯 선택") and slots.text.contains("[1]")
		and slots.text.contains("2 ") and slots.text.contains("3 ")) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
