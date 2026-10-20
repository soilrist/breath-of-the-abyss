extends Node
## 타격감. 데미지 숫자, 잠깐 멈춤, 화면 흔들림을 한곳에서 낸다.
##
## 때렸을 때 아무 반응이 없으면 숫자만 조용히 깎여 손맛이 없다.
## 이 세 가지가 붙으면 같은 수치라도 훨씬 세게 느껴진다.

## 히트스톱: 맞은 순간 시간을 아주 잠깐 늦춘다. 타격이 "박히는" 느낌을 준다.
const STOP_SCALE := 0.05
const STOP_TIME := 0.06

var _shake := 0.0
var _shake_power := 0.0
var _camera: Camera2D
var _stop_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	# 히트스톱은 실제 시간으로 재야 한다. 느려진 시간으로 재면 안 풀린다.
	var real := delta / maxf(Engine.time_scale, 0.001)
	if _stop_left > 0.0:
		_stop_left -= real
		if _stop_left <= 0.0:
			Engine.time_scale = 1.0
	if _shake <= 0.0:
		return
	_shake -= real
	if not is_instance_valid(_camera):
		return
	if _shake <= 0.0:
		_camera.offset = Vector2.ZERO
		return
	var power := _shake_power * (_shake / 0.18)
	_camera.offset = Vector2(randf_range(-power, power), randf_range(-power, power))


## 맞은 자리에 숫자를 띄운다. 치명타는 크고 노랗게.
## 숫자는 1.4배로 튀어나온 뒤 1.0배로 가라앉아("팝") 맞은 순간이 눈에 바로 들어오게 한다.
func popup(world: Node2D, at: Vector2, amount: int, critical := false) -> void:
	if not is_instance_valid(world):
		return
	var label := Label.new()
	label.text = str(amount)
	label.z_index = 50
	label.add_theme_font_size_override("font_size", 12 if critical else 9)
	label.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.3) if critical else Color(1.0, 0.95, 0.9))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.05))
	label.add_theme_constant_override("outline_size", 3)
	label.position = at + Vector2(randf_range(-5.0, 5.0), -18.0)
	label.pivot_offset = Vector2(10.0, 7.0)
	label.scale = Vector2(1.4, 1.4)
	world.add_child(label)

	var rise := label.position + Vector2(randf_range(-6.0, 6.0), -14.0)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", rise, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.15)
	tween.chain().tween_callback(label.queue_free)


## 화면을 흔든다. 세기는 픽셀 단위다.
func shake(power: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		var found := get_tree().get_first_node_in_group("player")
		if found != null and found.has_node("Camera2D"):
			_camera = found.get_node("Camera2D")
	_shake = 0.18
	_shake_power = maxf(_shake_power, power)


## 잠깐 멈춘다. 이미 멈춰 있어도 더 긴 멈춤이 오면 그만큼 늘인다
## (처치처럼 뒤에 온 더 긴 값이 앞선 멈춤에 가려지지 않게).
func hitstop(duration := STOP_TIME) -> void:
	_stop_left = maxf(_stop_left, duration)
	Engine.time_scale = STOP_SCALE


## 한 번에: 숫자 + 흔들림 + 멈춤. 세기는 피해량으로 정한다.
func strike(world: Node2D, at: Vector2, amount: int, critical := false) -> void:
	popup(world, at, amount, critical)
	shake(3.5 if critical else 1.6)
	if critical:
		hitstop(0.09)
	else:
		hitstop()
