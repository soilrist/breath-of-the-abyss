extends Area2D
## 활이 쏘는 화살. 날아가다 처음 닿은 적에게 꽂힌다.
##
## 활을 들어도 근접 공격과 똑같이 동작해서 활처럼 느껴지지 않았다.
## 실제로 날아가는 화살이 있어야 활로 읽힌다.

const SPEED := 220.0
const LIFE := 0.9

var damage := 0
var critical := false
var direction := Vector2.RIGHT

## 투사체 그림(INBOX 2026-10-20 17:45 불합격분, 21:20 정리 — 표창·독침이
## 평타 화살 그림으로 날아가면 안 된다). 기본은 화살(평타).
## - sprite_hframes: 가로로 늘어선 회전 칸 수(표창 4칸). 1이면 칸 없음.
## - spin: true면 rotation 은 0 으로 고정하고 칸을 넘겨 도는 것처럼 보인다
##   (표창). false면 rotation 을 진행 방향에 맞춘다(화살·독침).
## - rotation_offset: spin 이 false 일 때만 쓴다. 화살 그림은 오른쪽 위를
##   보고 그려져 있어 PI*0.25 보정이 필요하지만, 독침은 오른쪽을 보고
##   그려져 있어 보정이 필요 없다(0.0).
var sprite_path := "res://assets/items/arrow.png"
var sprite_hframes := 1
var spin := false
var rotation_offset := PI * 0.25

## 맞으면 바로 안 사라지고 적에게 박혀 0.3초 머물다 사라진다(INBOX
## 2026-10-20 21:55 — 큰 별 FX 대신 "뱅글뱅글 돌면서 타격감"). 표창·독침만
## true, 평타 화살은 기존처럼 즉시 사라진다.
var embed := false
const EMBED_TIME := 0.3

var _life := LIFE
var _sprite: Sprite2D
var _spin_timer := 0.0
const SPIN_FRAME_TIME := 0.04

var _embedded := false
var _embed_timer := 0.0
var _embed_target: Node2D = null
var _embed_offset := Vector2.ZERO


func _ready() -> void:
	# Player/Enemy와 같은 이유(Main = ALWAYS 상속)로 명시한다.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("arrows")
	_sprite = Sprite2D.new()
	_sprite.texture = load(sprite_path)
	_sprite.hframes = sprite_hframes
	if spin:
		_sprite.rotation = 0.0
	else:
		# 그림이 오른쪽 위를 향해 그려져 있다. 진행 방향에 맞춰 돌린다.
		_sprite.rotation = direction.angle() + rotation_offset
	add_child(_sprite)
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _embedded:
		_embed_timer -= delta
		if is_instance_valid(_embed_target):
			global_position = _embed_target.global_position + _embed_offset
		if spin:
			_spin_timer += delta
			if _spin_timer >= SPIN_FRAME_TIME:
				_spin_timer -= SPIN_FRAME_TIME
				_sprite.frame = (_sprite.frame + 1) % sprite_hframes
		if _embed_timer <= 0.0:
			_vanish()
		return
	global_position += direction * SPEED * delta
	_life -= delta
	if spin:
		_spin_timer += delta
		if _spin_timer >= SPIN_FRAME_TIME:
			_spin_timer -= SPIN_FRAME_TIME
			_sprite.frame = (_sprite.frame + 1) % sprite_hframes
	if _life <= 0.0:
		_vanish()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("enemies"):
		return
	body.take_damage(damage, direction, critical)
	if not embed:
		_vanish()
		return
	# 적 중심에서 날아온 방향 반대로 3px — 깊이 박히지 않고 표면에 닿은
	# 것처럼 보이게(INBOX 2026-10-20 21:55).
	_embedded = true
	_embed_timer = EMBED_TIME
	_embed_target = body
	_embed_offset = -direction.normalized() * 3.0
	global_position = body.global_position + _embed_offset
	# body_entered 신호 처리 중이라 monitoring 을 바로 못 바꾼다(Godot 제약).
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if not spin:
		# 회전 칸이 없는 독침은 대신 초록 번쩍으로 "박힌" 순간을 보여준다.
		_sprite.modulate = Color(1.5, 3.0, 1.2)
		var flash := create_tween()
		flash.tween_property(_sprite, "modulate", Color.WHITE, 0.08)


func _vanish() -> void:
	remove_from_group("arrows")
	queue_free()
