extends Control
## 대륙 이동도 오른쪽에 표시하는 대륙 개관도.
## 실제 지역 데이터는 World.AREAS에서 읽고, 아직 도달하지 못한 챕터는
## 대륙 형체는 보이되 흐리게 잠금 표시한다.
##
## 예전에는 1~5장만 실제 좌표로 그려지고 6~10장은 전부 "미지의 대륙"
## 원(circle) 하나로 뭉뚱그려졌다 - 사용자 지적: "지금 5장까지만 나와있고
## 나머지 우측에 지도에 표시가 안돼", "저기에 맵처럼 그림을 그려줬으면
## 좋겠어". 9장까지 실제 이름을 채우고, 표시도 점이 아니라 대륙처럼
## 보이는 불규칙한 윤곽선 도형(blob)으로 바꿨다.

## [이름, 기준색]. 각 장 분위기를 따서 지었다(1~9장은 구현 완료, 10장은
## CHAPTER6_10_MASTERPLAN.md 설계만 있어 미지로 남김).
const CONTINENTS := [
	["바람골", Color("#83b7a3")], ["청람", Color("#5ca6c9")], ["서리벌", Color("#9bc9e0")],
	["잿불", Color("#d27654")], ["유민의 땅", Color("#a982c4")], ["파편의 바다", Color("#4a8fa8")],
	["잊힌 성소", Color("#c9a35a")], ["침묵의 회랑", Color("#7a7d87")],
	["역전의 탑", Color("#8a4fa0")], ["미지의 대륙", Color("#596275")],
]
## 대륙마다 다른 윤곽(blob) 모양 - 반지름 배율을 8방향으로 흔들어
## 완전한 원이 아니라 삐뚤빼뚤한 땅덩이처럼 보이게 한다. 씨앗만
## 다르면 되므로 대륙 순서를 그대로 씨앗으로 쓴다.
const BLOB_POINTS := 10

const MAP_RECT := Rect2(4, 20, 106, 98)
## 현재 위치를 찍는 점의 반지름. 탭 판정 반지름(AREA_TAP_RADIUS)도 여기서
## 파생시킨다 - 새 숫자를 만들지 않고 그리는 점 크기의 2배로 맞춘다
## (INBOX 2026-09-07 12:40 "그리는 점 반지름의 2배").
const SELECTED_DOT_RADIUS := 1.6
const AREA_TAP_RADIUS := SELECTED_DOT_RADIUS * 2.0
## 심연의 탑 표식(감독 2026-09-10 "10장 뒤 탭에 넣지 말고 지도에서 바로
## 눌러 가게"). 장 목록·탭에는 없고 개관도 아래 빈자리에 탑 아이콘 하나로
## 서 있으며, 이 사각형 안을 누르면 바로 탑 입장(난이도 선택)이다.
const TOWER_POS := Vector2(30, 110)
const TOWER_RECT := Rect2(22, 100, 46, 18)
var pulse := 0.0
var selected_chapter := 1
var selected_area := ""
var game_state: Node
var world_data: Node


func _ready() -> void:
	game_state = get_node_or_null("/root/GameState")
	world_data = load("res://scripts/world.gd").new()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func set_location(chapter: int, area: String) -> void:
	selected_chapter = chapter
	selected_area = area
	queue_redraw()


func _process(delta: float) -> void:
	pulse = fmod(pulse + delta * 3.5, TAU)
	queue_redraw()


func _draw() -> void:
	var panel := Rect2(Vector2.ZERO, size)
	draw_style_box(_box(Color("#101923"), Color("#4b6170"), 1), panel)
	draw_string(ThemeDB.fallback_font, Vector2(7, 14), "세계 지도 · %d대륙" % CONTINENTS.size(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#c8d4dc"))
	draw_style_box(_box(Color("#172735"), Color("#314956"), 1), MAP_RECT)
	for i in range(CONTINENTS.size()):
		var p := _continent_position(i)
		var unlocked: bool = i + 1 <= game_state.chapter
		var active := i + 1 == selected_chapter
		var col: Color = CONTINENTS[i][1]
		var base_radius := _continent_radius(i)
		if not unlocked:
			col = col.darkened(0.55)
		var shape := _blob_shape(i, p, base_radius)
		if active:
			var glow := PackedVector2Array()
			for v in shape:
				glow.append(p + (v - p) * 1.35)
			draw_colored_polygon(glow, Color(col, 0.16))
		draw_colored_polygon(shape, Color(col, 0.95 if unlocked else 0.4))
		draw_polyline(shape + PackedVector2Array([shape[0]]), Color(col.darkened(0.3), 0.9), 1.0)
		if active:
			draw_polyline(shape + PackedVector2Array([shape[0]]), Color("#ff5b51", 0.8), 1.2)
		var label := str(i + 1)
		draw_string(ThemeDB.fallback_font, p + Vector2(-2, 2.5), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color("#101923"))
	_draw_tower()
	# 현재 지역 위치는 선택 대륙 내부에서 빨간 점으로 표시한다.
	# 탑 안에 있을 때는 장 목록에 탑이 없으니 탑 표식 위에 찍는다.
	var here := "tower" if game_state.current_map == "tower" else selected_area
	if here != "":
		var pos := _area_position(here)
		var wave := (sin(pulse) + 1.0) * 0.5  # 0~1로 커졌다 작아졌다
		draw_circle(pos, 2.0 + wave * 3.0, Color("#ff4b43", 0.55 - wave * 0.4))
		draw_circle(pos, SELECTED_DOT_RADIUS, Color("#ff4b43"))
	draw_string(ThemeDB.fallback_font, Vector2(4, 128), "● 현재 위치(반짝임)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color("#ff6259"))


## 심연의 탑 표식: 작은 탑 아이콘 + 이름. 잠겨 있으면 흐리게.
func _draw_tower() -> void:
	var unlocked: bool = game_state.unlocked_maps.has("tower")
	var col := Color("#b08de0") if unlocked else Color("#b08de0").darkened(0.55)
	var alpha := 0.95 if unlocked else 0.4
	var x := TOWER_POS.x
	var y := TOWER_POS.y
	# 몸통(6×10) + 꼭대기 톱니 3개
	draw_rect(Rect2(x - 3, y - 5, 6, 10), Color(col, alpha))
	for dx in [-3.0, -1.0, 1.0]:
		draw_rect(Rect2(x + dx, y - 7, 1.5, 2), Color(col, alpha))
	draw_rect(Rect2(x - 3, y - 5, 6, 10), Color(col.darkened(0.3), 0.9), false, 1.0)
	if game_state.current_map == "tower":
		draw_rect(Rect2(x - 4, y - 8, 8, 14), Color("#ff5b51", 0.8), false, 1.2)
	draw_string(ThemeDB.fallback_font, Vector2(x + 7, y + 3), "심연의 탑",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(col.lightened(0.2), alpha))


## 탭 좌표가 탑 표식(아이콘+이름) 안인가. 잠김 여부는 보지 않는다 -
## 잠긴 표식을 눌렀을 때 "아직 열리지 않았다"고 알려 주기 위해서다.
func tower_hit(local_pos: Vector2) -> bool:
	return TOWER_RECT.has_point(local_pos)


## 원이 아니라 대륙처럼 삐뚤빼뚤한 윤곽선 다각형을 만든다. 대륙 인덱스를
## 씨앗 삼아 반지름을 방향마다 다르게 흔든다(같은 대륙은 항상 같은 모양).
func _blob_shape(seed_index: int, center: Vector2, base_radius: float) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_index * 7919 + 13
	var points := PackedVector2Array()
	for i in BLOB_POINTS:
		var angle := TAU * float(i) / float(BLOB_POINTS)
		var wobble := 0.7 + rng.randf() * 0.6  # 0.7~1.3배로 들쭉날쭉하게
		var r := base_radius * wobble
		points.append(center + Vector2(cos(angle), sin(angle) * 0.82) * r)
	return points


func _continent_radius(index: int) -> float:
	return 8.0 if index + 1 == selected_chapter else 6.5


## 미니맵 탭 좌표에 해당하는 지역을 찾는다(main.gd의 터치 처리에서 호출).
## AREA_TAP_RADIUS 안에서 가장 가까운 지역점(잠김 포함)을 먼저 찾는다 -
## 그 점이 미해금이면 사용자가 특정 지역을 겨눈 것이므로 대륙 전환으로
## 대신하지 않고 그냥 무시한다("변화 없음"). 근처에 점이 아예 없을 때만
## 탭이 대륙 윤곽(blob) 안에 들어가는지 봐서 그 대륙의 해금된 지역
## 하나를 대신 돌려준다(챕터만 바꾸라는 뜻).
func area_at(local_pos: Vector2) -> String:
	var nearest := ""
	var nearest_dist := AREA_TAP_RADIUS
	for area in world_data.AREAS:
		if area == "tower":
			continue  # 탑은 tower_hit()으로 따로 판정
		var dist: float = _area_position(area).distance_to(local_pos)
		if dist <= nearest_dist:
			nearest = area
			nearest_dist = dist
	if nearest != "":
		return nearest if game_state.unlocked_maps.has(nearest) else ""
	for i in range(CONTINENTS.size()):
		if i + 1 > game_state.chapter:
			continue
		var shape := _blob_shape(i, _continent_position(i), _continent_radius(i))
		if not Geometry2D.is_point_in_polygon(local_pos, shape):
			continue
		for area in world_data.AREAS:
			if world_data.chapter_of(area) == i + 1 and game_state.unlocked_maps.has(area):
				return area
	return ""


func _continent_position(index: int) -> Vector2:
	# 비율(0~1)로 저장해 MAP_RECT 크기가 바뀌어도 항상 안쪽에 들어오게 한다.
	var frac := [
		Vector2(0.15, 0.16), Vector2(0.40, 0.12), Vector2(0.66, 0.18),
		Vector2(0.86, 0.32), Vector2(0.72, 0.50), Vector2(0.46, 0.44),
		Vector2(0.20, 0.42), Vector2(0.14, 0.68), Vector2(0.42, 0.72),
		Vector2(0.70, 0.78),
	]
	return MAP_RECT.position + frac[index] * MAP_RECT.size


func _area_position(area: String) -> Vector2:
	if area == "tower":
		return TOWER_POS
	var continent := clampi(world_data.chapter_of(area) - 1, 0, CONTINENTS.size() - 1)
	var base := _continent_position(continent)
	var data: Dictionary = world_data.AREAS.get(area, {})
	var grid: Vector2i = data.get("grid", Vector2i.ZERO)
	var offset := Vector2(float(grid.x % 9 - 4) * 1.1, float(grid.y % 5 - 2) * 1.2)
	return base + offset


func _box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	return box
