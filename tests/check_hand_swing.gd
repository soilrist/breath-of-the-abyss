extends Node
## 공격할 때 손무기가 draw/ready/slash/follow 프레임으로 실제로 넘어가는지 확인한다.
## 가만히 들고만 있으면 안 되고(항상 idle 프레임), 공격 시작~끝 사이에 프레임이 바뀌어야 한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	GameState.equipped["weapon"] = "철검"
	GameState._recalc_bonuses()
	player.facing = Vector2.DOWN
	player.cooldown_time = 0.0

	var idle_frame: int = player.get_node("Hand").frame
	player.attack()
	await get_tree().physics_frame
	var start_frame: int = player.get_node("Hand").frame
	for i in 6:
		await get_tree().physics_frame
	var mid_frame: int = player.get_node("Hand").frame
	while player.motion_time > 0.0:
		await get_tree().physics_frame
	var end_idle_frame: int = player.get_node("Hand").frame

	print("idle=", idle_frame, " swing_start=", start_frame, " swing_mid=", mid_frame, " after=", end_idle_frame)
	var moved := mid_frame != start_frame or mid_frame != idle_frame
	var settled := end_idle_frame == idle_frame
	print("RESULT ", "PASS" if moved and settled else "FAIL")
	get_tree().quit()
