extends Node

func _ready() -> void:
	for scene in ["title", "ending"]:
		var node: Node = load("res://scenes/%s.tscn" % scene).instantiate()
		add_child(node)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://menu_%s.png" % scene)
		print("SHOT ", scene)
		remove_child(node)
		node.free()
		await RenderingServer.frame_post_draw
	get_tree().quit()
