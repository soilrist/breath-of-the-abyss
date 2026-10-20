extends Control
## 네모난 방향키 4개 대신 쓰는 동그란 반투명 가상 조이스틱.
## 요즘 모바일 게임은 다 이런 식이라 방향키 버튼을 이걸로 바꾼다.
## 드래그한 각도로 기존 move_* 액션을 그대로 누르고 떼서, 이동 코드는 손대지 않는다.

## 조이스틱 칸이 72×72 정사각형(INBOX 20:16)이라 그려지는 원(RADIUS+10)이
## 칸 절반(36)을 넘으면 화면 끝에서 잘린다. 26+10=36으로 딱 맞춘다.
const RADIUS := 26.0
## 손끝이 살짝만 떨려도 이동이 튀는 느낌이 나서(사용자 피드백: "스틱이 너무 민감하다")
## 죽은 영역을 14 -> 20 으로 넓혔던 비율(RADIUS의 2/3)을 유지해 축소했다.
const DEAD_ZONE := 17.0

var _dragging := false
var _knob := Vector2.ZERO
var _active: Array[String] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _exit_tree() -> void:
	_release_all()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if get_global_rect().has_point(event.position):
				_dragging = true
				_update_knob(event.position)
				get_viewport().set_input_as_handled()
		elif _dragging:
			_end_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_update_knob(event.position)


func _update_knob(global_pos: Vector2) -> void:
	var center: Vector2 = get_global_rect().get_center()
	var offset: Vector2 = global_pos - center
	_knob = offset.limit_length(RADIUS)
	_apply_direction(offset)
	queue_redraw()


func _end_drag() -> void:
	_dragging = false
	_knob = Vector2.ZERO
	_release_all()
	queue_redraw()


## 드래그 각도를 8방향으로 나눠 기존 move_* 액션을 누른다. 대각선은 두 축이 같이 눌린다.
func _apply_direction(offset: Vector2) -> void:
	var wanted: Array[String] = []
	if offset.length() > DEAD_ZONE:
		if offset.x < -DEAD_ZONE * 0.5: wanted.append("move_left")
		if offset.x > DEAD_ZONE * 0.5: wanted.append("move_right")
		if offset.y < -DEAD_ZONE * 0.5: wanted.append("move_up")
		if offset.y > DEAD_ZONE * 0.5: wanted.append("move_down")
	for action in _active:
		if not wanted.has(action):
			Input.action_release(action)
	for action in wanted:
		if not _active.has(action):
			Input.action_press(action)
	_active = wanted


func _release_all() -> void:
	for action in _active:
		Input.action_release(action)
	_active = []


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, RADIUS + 10.0, Color(1, 1, 1, 0.12))
	draw_arc(center, RADIUS + 10.0, 0.0, TAU, 24, Color(1, 1, 1, 0.35), 1.5)
	draw_circle(center + _knob, 10.0, Color(1, 1, 1, 0.45 if _dragging else 0.3))
