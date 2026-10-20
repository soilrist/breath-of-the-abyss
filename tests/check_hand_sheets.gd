extends Node
## 근접 무기가 손에 들었을 때도 전부 다르게 보이는지 확인한다.
## 예전엔 무기 14종이 손그림 6장을 나눠 써서 "빙하의 파편"부터 최상위
## "천공의 검"까지 인게임에서 똑같이 생겼다. 지금은 무기마다 전용 그림과
## 스윙 시트가 있다(tools/build_hand_sheets.py 가 생성).

## scripts/player.gd 의 시트 규격. 프레임 56x56(가운데 = 플레이어 원점), 5단계 x 8방향.
const SHEET_SIZE := Vector2i(280, 448)

func _ready() -> void:
	var ok := true

	var melee: Array[String] = []
	var bows: Array[String] = []
	for item in GameState.EQUIPMENT:
		var data: Dictionary = GameState.EQUIPMENT[item]
		if str(data.get("slot", "")) != "weapon":
			continue
		if str(data.get("kind", "")) == "bow":
			bows.append(str(item))
		else:
			melee.append(str(item))

	# 1. 근접 무기는 전부 hand 이름이 있어야 한다. 없으면 손에 아무것도 안 그린다.
	var nameless: Array[String] = []
	for item in melee:
		if str(GameState.EQUIPMENT[item].get("hand", "")) == "":
			nameless.append(item)
	ok = _check("근접 무기 %d종 전부 hand 지정됨%s" % [
		melee.size(),
		"" if nameless.is_empty() else " (빠짐: %s)" % ", ".join(nameless),
	], nameless.is_empty()) and ok

	# 2. 두 무기가 같은 손그림을 쓰면 안 된다.
	var seen := {}
	var clashes: Array[String] = []
	for item in melee:
		var hand := str(GameState.EQUIPMENT[item].get("hand", ""))
		if seen.has(hand):
			clashes.append("%s = %s" % [seen[hand], item])
		else:
			seen[hand] = item
	ok = _check("손그림이 서로 겹치지 않음%s" % (
		"" if clashes.is_empty() else " (겹침: %s)" % ", ".join(clashes)
	), clashes.is_empty()) and ok

	# 3. 손그림과 스윙 시트 파일이 실제로 있어야 하고, 시트는 규격에 맞아야 한다.
	var absent: Array[String] = []
	var wrong_size: Array[String] = []
	for hand in seen:
		var still := "res://assets/items/hand/%s.png" % hand
		var swing := "res://assets/items/hand_fx/%s_swing.png" % hand
		if not ResourceLoader.exists(still):
			absent.append(still)
		if not ResourceLoader.exists(swing):
			absent.append(swing)
			continue
		var tex: Texture2D = load(swing)
		if tex.get_size() != Vector2(SHEET_SIZE):
			wrong_size.append("%s %s" % [swing, str(tex.get_size())])
	ok = _check("그림 파일이 전부 존재함%s" % (
		"" if absent.is_empty() else " (없음: %s)" % ", ".join(absent)
	), absent.is_empty()) and ok
	ok = _check("스윙 시트가 280x448 규격%s" % (
		"" if wrong_size.is_empty() else " (어긋남: %s)" % ", ".join(wrong_size)
	), wrong_size.is_empty()) and ok

	# 4. 활은 손그림을 쓰지 않는다(화살을 쏘므로 hand 가 비어 있어야 한다).
	var bow_with_hand: Array[String] = []
	for item in bows:
		if str(GameState.EQUIPMENT[item].get("hand", "")) != "":
			bow_with_hand.append(item)
	ok = _check("활 %d종은 손그림을 쓰지 않음%s" % [
		bows.size(),
		"" if bow_with_hand.is_empty() else " (지정됨: %s)" % ", ".join(bow_with_hand),
	], bow_with_hand.is_empty()) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
