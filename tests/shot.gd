extends Node

const AREAS := ["village", "hill", "forest_w", "glade", "dungeon", "cave_deep", "marsh", "ruins_w", "glacier", "abyss", "throne"]

func _ready() -> void:
	var main := preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	for area in AREAS:
		main._change_map(area, false)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png("user://shot_%s.png" % area)
		print("SHOT ", area)
	get_tree().quit()
