extends Area2D
## 잠긴 문. 같은 이름의 열쇠를 들고 닿으면 열린다.
##
## 던전이 그냥 지나가는 통로라 탐색할 거리가 없었다. 문을 두고 열쇠를
## 지역 어딘가에 숨겨 두면, 한 번은 돌아다녀야 한다.

signal opened(door_id: String)
signal refused(door_id: String)

## 어느 열쇠로 열리는지. 열쇠 아이템과 같은 값을 쓴다.
var door_id := ""
## 문이 막고 있는 칸 수. 가로로 이만큼 늘어선다.
var span := 3

var _body: StaticBody2D


func _ready() -> void:
	add_to_group("doors")
	_build()
	body_entered.connect(_on_body_entered)


func _build() -> void:
	# 자물쇠 그림을 칸 수만큼 늘어놓는다.
	var sheet: Texture2D = load("res://assets/tiles/TilesetLogic.png")
	for i in span:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		# 4행 4열이 자물쇠 그림이다.
		atlas.region = Rect2(4 * 16, 2 * 16, 16, 16)
		var sprite := Sprite2D.new()
		sprite.texture = atlas
		sprite.centered = false
		sprite.position = Vector2(i * 16, 0)
		add_child(sprite)

	# 닿는 범위는 문 앞 한 칸까지 넓게 잡는다.
	var shape := RectangleShape2D.new()
	shape.size = Vector2(span * 16, 24)
	var area_shape := CollisionShape2D.new()
	area_shape.shape = shape
	area_shape.position = Vector2(span * 8, 8)
	add_child(area_shape)

	# 실제로 막는 몸. 열리면 없앤다.
	_body = StaticBody2D.new()
	var solid := RectangleShape2D.new()
	solid.size = Vector2(span * 16, 16)
	var solid_shape := CollisionShape2D.new()
	solid_shape.shape = solid
	solid_shape.position = Vector2(span * 8, 8)
	_body.add_child(solid_shape)
	add_child(_body)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if GameState.open_door(door_id):
		opened.emit(door_id)
		_vanish()
	else:
		refused.emit(door_id)


## 열리면 사라진다. 다시 들어와도 열린 채로 둔다.
func _vanish() -> void:
	remove_from_group("doors")
	queue_free()
