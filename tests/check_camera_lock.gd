extends Node
## 카메라가 320x240 화면 단위로 고정되는지 숫자로 확인한다.
## 모든 지역이 한 화면(1x1)이라 어디에 서든 카메라 중심은 (160,120)이어야 한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	main._change_map("forest_w", false)

	var cases := [
		# [플레이어 위치, 기대하는 카메라 중심]
		[Vector2(50, 50), Vector2(160, 120)],     # 0번 화면
		[Vector2(300, 50), Vector2(160, 120)],    # 0번 화면 안, 오른쪽 끝 쪽
		[Vector2(160, 200), Vector2(160, 120)],   # 아래쪽도 같은 화면
	]
	var ok := true
	for pair in cases:
		player.global_position = pair[0]
		await get_tree().physics_frame
		await get_tree().physics_frame
		var cam: Vector2 = player.get_node("Camera2D").global_position
		var expect: Vector2 = pair[1]
		var pass_ := cam.distance_to(expect) < 0.5
		ok = ok and pass_
		print("pos=", pair[0], " cam=", cam, " expect=", expect, " ", "OK" if pass_ else "FAIL")
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
