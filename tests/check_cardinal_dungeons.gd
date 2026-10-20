extends Node
## 예전 동서남북 던전 4곳(황혼의 폐사원/가라앉은 유적/빙하 균열/심연 너머)이
## 이제 별도 지역(area+exits)이 아니라 부모 지역 하나의 큰 맵 안에
## 화면 전환 없이 흡수돼 있는지 확인한다 - 사용자 요청("전에는 맵을
## 쪼개지 않고 이 4개를 전부 붙여서 그 큰 맵 안에서 돌아다니게끔 했었어").

const ABSORBED := {
	# 부모 지역 -> [예전 별도 지역이었던 이름(문서용), 그 구역 전용 몬스터, 전용 드랍]
	"glade": {"was": "twilight_temple", "kind": "eye", "item": "황혼의 부적"},
	"marsh_deep": {"was": "sunken_ruins", "kind": "mollusc", "item": "가라앉은 목걸이"},
	"frost_gorge": {"was": "glacier_rift", "kind": "frostbear", "item": "빙하의 파편"},
	"ash_ridge": {"was": "beyond_abyss", "kind": "dragon", "item": "용의 비늘"},
}

func _ready() -> void:
	var ok := true
	var enemy_kinds: Dictionary = preload("res://scripts/enemy.gd").KINDS
	for area_id in ABSORBED:
		var d: Dictionary = ABSORBED[area_id]
		var here: Dictionary = World.AREAS[area_id]
		# 예전 별도 지역 이름은 더 이상 AREAS에 없어야 한다(화면 전환 구조 폐기).
		ok = _check("%s: 예전 별도 지역(%s)이 더는 AREAS에 없음" % [area_id, d["was"]],
			not World.AREAS.has(d["was"])) and ok
		# exits에 남북(n/s) 분기가 남아 있지 않아야 한다(순수 좌우 외길 유지).
		var exits: Dictionary = here.get("exits", {})
		ok = _check("%s: exits에 남북(n/s) 분기 없음" % area_id,
			not exits.has("n") and not exits.has("s")) and ok
		# (감독 2026-09-09) 모든 지역은 320x240 한 화면(screens 1x1)으로 합쳤다 -
		# 사용자 요청("4개로 쪼갠거 1개로만들고 거기 몹들 밀어넣고"). 흡수된
		# 던전은 화면을 키우는 대신 그 몬스터를 부모 지역 스폰 목록에 넣는다.
		var screens: Vector2i = here.get("screens", Vector2i.ONE)
		ok = _check("%s: 한 화면 지역(screens=%s)" % [area_id, screens],
			screens == Vector2i.ONE) and ok
		var roster: Array = preload("res://scripts/main.gd").AREA_SPAWNS.get(area_id, [])
		var has_kind := false
		for e in roster:
			if e.get("kind", "") == d["kind"]: has_kind = true
		ok = _check("%s: 흡수된 던전 몬스터(%s)가 이 지역 스폰 목록에 있음" % [area_id, d["kind"]],
			has_kind) and ok
		ok = _check("%s: 흡수된 던전 전용 몬스터(%s)가 KINDS에 있음" % [area_id, d["kind"]],
			enemy_kinds.has(d["kind"])) and ok
		ok = _check("%s: 흡수된 던전 전용 드랍(%s)이 GameState.area_item과 일치" % [area_id, d["item"]],
			GameState.area_item(area_id) == d["item"]) and ok
		ok = _check("%s: 전용 드랍템이 EQUIPMENT에 있음" % area_id,
			GameState.EQUIPMENT.has(d["item"])) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
