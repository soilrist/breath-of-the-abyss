extends Sprite2D
class_name SlashFx
## 칼을 휘두를 때 나오는 베기 궤적.
##
## 예전에는 흰 선 하나(Line2D)가 방향 표시로 튀어나왔다. 프로토타입 때
## 방향을 알아보려고 둔 것인데 칼질처럼 보이지 않았다.
## 에셋팩의 베기 궤적을 프레임으로 돌린다.

const FRAMES := 6
const FRAME_TIME := 0.045

var _tick := 0.0


func _ready() -> void:
	texture = load("res://assets/fx/slash.png")
	hframes = FRAMES
	frame = 0
	z_index = 10


func _process(delta: float) -> void:
	_tick += delta
	var step := int(_tick / FRAME_TIME)
	if step >= FRAMES:
		queue_free()
		return
	frame = step



