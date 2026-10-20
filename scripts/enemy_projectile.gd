extends Area2D
## 원거리/마법형 몬스터가 실제로 쏘는 투사체. 화살(ranged)과 마법구(magic)를
## 텍스처만 바꿔 하나로 처리한다.
##
## 예전에는 _act_ranged()/_act_magic()가 사거리 안이면 즉시 플레이어에게
## 피해를 넣었다 - 맞는 이유가 화면에 안 보여 "무조건 내가 맞는 구조"로
## 느껴진다는 지적을 받았다. player.gd의 arrow.gd(플레이어 화살) 패턴을
## 그대로 가져와 몬스터도 실제로 날아가는 걸 보여주고, 맞았을 때만
## 피해가 들어가게 바꾼다.

const SPEED_ARROW := 160.0
const SPEED_MAGIC := 110.0
const LIFE := 1.4
## 보스 투사체 추적: 느리지만 오래 날며 플레이어 쪽으로 서서히 꺾인다.
const SPEED_HOMING := 90.0
const HOMING_LIFE := 2.2
const HOMING_TURN := 3.0

var damage := 0
var direction := Vector2.RIGHT
## "arrow" 또는 "magic". 텍스처·속도·회전 방식이 다르다.
var kind := "arrow"
var homing := false

var _life := LIFE
var _speed := SPEED_ARROW


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemy_projectiles")
	var sprite := Sprite2D.new()
	if kind == "magic":
		_speed = SPEED_MAGIC
		sprite.texture = load("res://assets/fx/flame.png")
		sprite.hframes = 9
		sprite.frame = 0
		sprite.scale = Vector2.ONE * 0.4
	else:
		_speed = SPEED_ARROW
		sprite.texture = load("res://assets/items/arrow.png")
		# 그림이 오른쪽 위를 향해 그려져 있다(player.gd의 arrow.gd와 동일 텍스처).
		sprite.rotation = direction.angle() + PI * 0.25
	sprite.name = "Sprite"
	add_child(sprite)
	if homing:
		_speed = SPEED_HOMING
		_life = HOMING_LIFE
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if homing:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null:
			var turn := direction.angle_to(player.global_position - global_position)
			direction = direction.rotated(clampf(turn, -HOMING_TURN * delta, HOMING_TURN * delta))
	global_position += direction * _speed * delta
	_life -= delta
	if kind == "magic":
		var sprite := get_node("Sprite") as Sprite2D
		sprite.frame = int(absf(LIFE - _life) / LIFE * 9.0) % 9
	if _life <= 0.0:
		_vanish()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	# 추적형(homing)은 전부 보스 volley - 진단 로그가 근접/원거리를 가르는 태그.
	body.take_damage(damage, direction, "volley" if homing else kind)
	_vanish()


func _vanish() -> void:
	remove_from_group("enemy_projectiles")
	queue_free()
