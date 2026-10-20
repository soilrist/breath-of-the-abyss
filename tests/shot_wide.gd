extends Node
## 넓어진 지역 전체를 한 장에 담는다. 카메라를 떼고 축소해서 찍는다.

const AREAS := ["hill", "forest_w", "glade", "marsh", "ruins_w", "glacier", "abyss", "throne"]

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var cam: Camera2D = main.get_node("Player/Camera2D")
	cam.enabled = false
	var view: Camera2D = Camera2D.new()
	main.add_child(view)
	view.enabled = true
	main.get_node("HUD").visible = false
	for area in AREAS:
		main._change_map(area, false)
		var size: Vector2 = World.pixel_size_of(area)
		view.zoom = Vector2(320.0 / size.x, 240.0 / size.y)
		view.zoom = Vector2.ONE * minf(view.zoom.x, view.zoom.y)
		view.global_position = size * 0.5
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://wide_%s.png" % area)
		print("SHOT ", area)
	get_tree().quit()
