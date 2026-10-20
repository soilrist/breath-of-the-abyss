extends Control


func _ready() -> void:
	$World.paint("village")
	Audio.play_music("ending")
	$Summary.text = "최종 기록\n\n레벨 %d    처치 %d    골드 %d\n무기 %s\n방어구 %s" % [GameState.level, GameState.kills, GameState.gold, GameState.weapon, GameState.armor]
	$TouchReturn.visible = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	$TouchReturn.pressed.connect(_return_to_title)


func _return_to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("attack"):
		_return_to_title()
