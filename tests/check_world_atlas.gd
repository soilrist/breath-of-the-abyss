extends Node

func _ready() -> void:
	var atlas := preload("res://scripts/world_atlas.gd").new()
	add_child(atlas)
	var ok := true
	ok = _check("챕터 대륙 10개 표시", atlas.CONTINENTS.size() == 10) and ok
	ok = _check("6장 실제 이름", atlas.CONTINENTS[5][0] == "파편의 바다") and ok
	ok = _check("7장 실제 이름", atlas.CONTINENTS[6][0] == "잊힌 성소") and ok
	ok = _check("8장 실제 이름", atlas.CONTINENTS[7][0] == "침묵의 회랑") and ok
	ok = _check("9장 실제 이름", atlas.CONTINENTS[8][0] == "역전의 탑") and ok
	ok = _check("10장 미지 잠금", atlas.CONTINENTS[9][0] == "미지의 대륙") and ok
	var shape: PackedVector2Array = atlas._blob_shape(5, Vector2(40, 40), 8.0)
	ok = _check("대륙 윤곽이 10점 다각형", shape.size() == 10) and ok
	ok = _check("대륙 윤곽이 원이 아닌 불규칙 도형", shape[0].distance_to(Vector2(48, 40)) != shape[1].distance_to(Vector2(40, 40))) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)

func _check(label: String, condition: bool) -> bool:
	print(label, " ", "OK" if condition else "FAIL")
	return condition
