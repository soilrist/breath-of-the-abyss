extends Area2D
class_name Pickup
## 몬스터가 떨어뜨린 바닥 아이템. 플레이어가 밟으면 줍는다.

const KINDS := {
	"potion": {"texture": "res://assets/items/potion.png", "label": "회복약"},
	"gold": {"texture": "res://assets/items/gold.png", "label": "골드"},
	# 상자 그림은 닫힘·열림 두 칸이 붙어 있다. 왼쪽 칸만 쓴다.
	"chest": {"texture": "res://assets/items/chest.png", "label": "상자", "frame": Rect2(0, 0, 16, 16)},
	"stone": {"texture": "res://assets/items/stone.png", "label": "강화석"},
	"key": {"texture": "res://assets/items/key.png", "label": "열쇠"},
	"magic_stone": {"texture": "res://assets/items/stone.png", "label": "마법돌"},
	# 탑 전용 결정. 그 난이도 탑 몬스터만 낮은 확률로 떨어뜨리고,
	# "초월" 등급 장비 제작 재료로 쓴다. GameState.tower_material_counts에
	# 난이도별로 쌓인다(인벤토리 아이템이 아니라 강화석 같은 카운터).
	"tower_material": {"texture": "res://assets/items/stone.png", "label": "탑 결정"},
	# 사냥터 중간보스 전용 드랍. 실제 타입(전사/마법사/도적)은 stone_id에
	# 담아 GameState.JOB_STONES 중 하나를 가리킨다.
	"job_stone": {"texture": "res://assets/items/stone.png", "label": "전직의 돌"},
	# 5~10장 잡몹·보스 드랍 제작 재료. 어느 장 정수인지는 essence 에 담는다
	# (GameState.CHAPTER_ESSENCES 값). 그 장 세트 장비를 대장간에서 만든다.
	"essence": {"texture": "res://assets/items/stone.png", "label": "정수"},
}

## 어느 종류인지와 값. 골드는 액수, 장비는 아이템 이름이 들어간다.
var kind := "potion"
var amount := 0
var item_name := ""
## "mob"/"boss"면 몬스터 드랍 - 이 장비에만 랜덤 옵션이 붙는다(맵 상자는 "").
var drop_source := ""
## 마법돌일 때 어느 돌인지. GameState.STONES 의 키.
var stone_id := ""
## 탑 결정일 때 어느 난이도 결정인지. GameState.TOWER_TIERS 의 키.
var tower_tier := ""
## 정수일 때 어느 장 정수인지. GameState.CHAPTER_ESSENCES 의 값(이름).
var essence := ""
## 지역에 놓인 상자만 쓴다. 한 번 열면 다시 안 나오게 기록한다.
var chest_id := ""
## 열쇠일 때 어느 문을 여는지.
var key_id := ""

var _bob := 0.0


func _ready() -> void:
	add_to_group("pickups")
	var art: Texture2D = load(KINDS[kind]["texture"])
	if KINDS[kind].has("frame"):
		var atlas := AtlasTexture.new()
		atlas.atlas = art
		atlas.region = KINDS[kind]["frame"]
		art = atlas
	$Sprite.texture = art
	if kind == "magic_stone":
		# 돌 등급을 색으로 구분한다. 바닥에서부터 뭐가 좋은 돌인지 보이게.
		var rarity := str(GameState.STONES.get(stone_id, {}).get("rarity", "일반"))
		modulate = GameState.RARITY_COLORS.get(rarity, Color.WHITE)
	if kind == "tower_material":
		modulate = GameState.RARITY_COLORS.get("초월", Color.WHITE)
	if kind == "essence":
		modulate = GameState.RARITY_COLORS.get("전설", Color.WHITE)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	# 바닥에 가만히 있으면 배경에 묻힌다. 살짝 떠 있게 한다.
	_bob += delta * 4.0
	$Sprite.position.y = -6.0 + sin(_bob) * 1.5


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	match kind:
		"potion":
			body.add_potion()
			Audio.play_sfx("potion")
		"gold":
			GameState.gold += amount
			Audio.play_sfx("coin")
		"key":
			GameState.take_key(key_id)
			Audio.play_sfx("pickup")
		"stone":
			GameState.add_material(amount if amount > 0 else 1)
			GameState.record_material()
			Audio.play_sfx("pickup")
		"magic_stone":
			GameState.add_stone(stone_id)
			Audio.play_sfx("pickup")
		"tower_material":
			GameState.add_tower_material(tower_tier)
			Audio.play_sfx("pickup")
		"job_stone":
			GameState.add_job_stone(stone_id)
			Audio.play_sfx("pickup")
		"essence":
			GameState.add_essence(essence)
			Audio.play_sfx("pickup")
		"chest":
			if drop_source != "":
				GameState.add_dropped_item(item_name, drop_source == "boss")
			else:
				GameState.add_item(item_name)
			if chest_id != "" and not GameState.opened_chests.has(chest_id):
				GameState.opened_chests.append(chest_id)
			Audio.play_sfx("pickup")
	collected.emit(self)
	_despawn()


## queue_free 는 프레임 끝에 처리된다. 그때까지 그룹에 남아 있으면
## 이미 주운 물건이 다시 세어진다. 그룹에서 먼저 뺀다.
func _despawn() -> void:
	remove_from_group("pickups")
	queue_free()


signal collected(pickup: Area2D)


## 떨어뜨릴 내용을 확률로 정한다. 아무것도 안 나오면 빈 사전을 준다.
static func roll_drop(is_boss: bool) -> Dictionary:
	if is_boss:
		return {"kind": "chest", "item_name": "강철 대검"}
	# 한국 MMORPG식으로 갈아엎으면서 드랍률도 확 낮췄다. 예전엔 잡몹 한 마리당
	# 절반이 물약/골드였고 장비도 4%나 나와서 강화·소켓 재료가 너무 쉽게
	# 모였다. 지금은 대부분(43%) 아무것도 안 나온다 - 파밍하는 맛을 위해서.
	# 장비는 2%→5%(감독 2026-09-08, "아이템이 너무 적다"). 랜덤 옵션이 붙어
	# 같은 이름이라도 다르게 나오니 여러 개 주워 비교하는 재미가 있어야 한다.
	var roll := randi() % 100
	if roll < 12:
		return {"kind": "potion"}
	if roll < 30:
		return {"kind": "gold", "amount": 5 + randi() % 12}
	if roll < 48:
		return {"kind": "stone", "amount": 1}
	# 지역(장)별 확률 드랍 - 마법돌과 장비. 잡몹도 가끔 쓸 만한 걸 준다.
	if roll < 52:
		var stone_id := GameState.roll_chapter_stone()
		if stone_id != "":
			return {"kind": "magic_stone", "stone_id": stone_id}
	if roll < 57:
		var item := GameState.roll_chapter_item()
		if item != "":
			return {"kind": "chest", "item_name": item}
	return {}
