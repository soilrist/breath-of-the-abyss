extends Node
## 무기를 손에 들려 보는 실험. 붙였을 때와 안 붙였을 때를 비교한다.
## 16px 캐릭터에 6~16px 무기라 지저분해질 수 있어 눈으로 판단해야 한다.

## 방향별 무기 위치와 회전. 0 아래, 1 위, 2 왼쪽, 3 오른쪽.
const HAND := [
	{"pos": Vector2(5, -2), "rot": 0.35, "back": false},
	{"pos": Vector2(-5, -6), "rot": -0.35, "back": true},
	{"pos": Vector2(-6, -3), "rot": -1.2, "back": false},
	{"pos": Vector2(6, -3), "rot": 1.2, "back": false},
]

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	GameState.level = 20
	main._change_map("village", false)
	main.get_node("HUD").visible = false

	# 줌 없이 원본 픽셀로 찍고 나중에 잘라 키운다. 줌을 걸면 배경만 커진다.
	# 카메라 한계 때문에 주인공이 화면 가운데가 아닐 수 있으니 한계를 푼다.
	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = -100000
	cam.limit_top = -100000
	cam.limit_right = 100000
	cam.limit_bottom = 100000
	player.global_position = Vector2(300, 300)
	player.bounds = Vector2(10000, 10000)

	for weapon in ["sword_iron", "bigsword_steel", "lance_frost", "rapier_glacier"]:
		var hand := Sprite2D.new()
		hand.texture = load("res://assets/items/hand/%s.png" % weapon)
		player.add_child(hand)
		for dir_index in 4:
			var facing: Vector2 = [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT][dir_index]
			player.facing = facing
			player._update_sprite(Vector2.ZERO)
			var setup: Dictionary = HAND[dir_index]
			hand.position = setup["pos"]
			hand.rotation = setup["rot"]
			hand.z_index = -1 if setup["back"] else 1
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("user://hand_%s_%d.png" % [weapon, dir_index])
		hand.queue_free()
		await get_tree().process_frame
		print("SHOT ", weapon)

	# 무기 없이 (지금 상태)
	for dir_index in 4:
		player.facing = [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT][dir_index]
		player._update_sprite(Vector2.ZERO)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://hand_none_%d.png" % dir_index)
	print("SHOT none")
	get_tree().quit()
