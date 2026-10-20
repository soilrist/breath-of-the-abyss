extends Node
## TOWER_DESIGN.md 2절(1~100층 구조)·3절(층별 능력치 스케일링)·5절(난이도
## 5단계) 표 값과 game_state.gd의
## TOWER_BASE_STATS/TOWER_TIERS/TOWER_FLOOR_COUNT/tower_floor_stats()가
## 어긋나지 않는지 대조한다.

func _ready() -> void:
	var ok := true

	ok = _check("TOWER_BASE_STATS hp 470", GameState.TOWER_BASE_STATS["hp"] == 470) and ok
	ok = _check("TOWER_BASE_STATS damage 58", GameState.TOWER_BASE_STATS["damage"] == 58) and ok
	ok = _check("TOWER_BASE_STATS defense 20", GameState.TOWER_BASE_STATS["defense"] == 20) and ok

	ok = _check_tier("easy", 1.0, 1.0) and ok
	ok = _check_tier("normal", 1.5, 1.3) and ok
	ok = _check_tier("hard", 2.2, 1.7) and ok
	ok = _check_tier("hell", 3.2, 2.2) and ok
	ok = _check_tier("abyss", 4.5, 3.0) and ok

	# 성장 공식(3절): hp*(1+f*0.045), damage*(1+f*0.035), defense*(1+f*0.03),
	# 10층마다 x1.6, 25/50/75/100층은 x2.5. tier=easy(mult 1.0)로 배율만 검증.
	var f1 := GameState.tower_floor_stats(1, "easy")
	ok = _check("1층 hp = base*(1+0.045)", f1["hp"] == int(470 * 1.045)) and ok
	ok = _check("1층 damage = base*(1+0.035)", f1["damage"] == int(58 * 1.035)) and ok
	ok = _check("1층 defense = base*(1+0.03)", f1["defense"] == int(20 * 1.03)) and ok

	var f10 := GameState.tower_floor_stats(10, "easy")
	ok = _check("10층 미니보스 x1.6", f10["hp"] == int(470 * (1.0 + 10 * 0.045) * 1.6)) and ok

	var f25 := GameState.tower_floor_stats(25, "easy")
	ok = _check("25층 고정보스 x2.5", f25["hp"] == int(470 * (1.0 + 25 * 0.045) * 2.5)) and ok

	var f50 := GameState.tower_floor_stats(50, "easy")
	ok = _check("50층 고정보스 x2.5", f50["hp"] == int(470 * (1.0 + 50 * 0.045) * 2.5)) and ok

	var f75 := GameState.tower_floor_stats(75, "easy")
	ok = _check("75층 고정보스 x2.5", f75["hp"] == int(470 * (1.0 + 75 * 0.045) * 2.5)) and ok

	var f100 := GameState.tower_floor_stats(100, "easy")
	ok = _check("100층 고정보스 x2.5", f100["hp"] == int(470 * (1.0 + 100 * 0.045) * 2.5)) and ok

	var f20 := GameState.tower_floor_stats(20, "easy")
	ok = _check("20층은 미니보스(x1.6)일 뿐 고정보스(x2.5) 아님", f20["hp"] == int(470 * (1.0 + 20 * 0.045) * 1.6)) and ok

	# 2절: "탑 구조 — 1~100층".
	ok = _check("TOWER_FLOOR_COUNT 100", GameState.TOWER_FLOOR_COUNT == 100) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check_tier(key: String, mob_mult: float, reward_mult: float) -> bool:
	var tier: Dictionary = GameState.TOWER_TIERS[key]
	var ok := true
	ok = _check(key + " mob_mult x" + str(mob_mult), is_equal_approx(float(tier["mob_mult"]), mob_mult)) and ok
	ok = _check(key + " reward_mult x" + str(reward_mult), is_equal_approx(float(tier["reward_mult"]), reward_mult)) and ok
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
