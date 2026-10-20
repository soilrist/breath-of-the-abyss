extends Node
## TOWER_DESIGN.md 6절(초월 등급)·8절(칭호/별) 표 값과 game_state.gd 상수가
## 어긋나지 않는지 대조한다. 3·5절은 check_tower_design_values.gd가 이미
## 담당하므로 여기서는 나머지 절만 본다.

const TOWER_SETS := ["tower_easy_set", "tower_normal_set", "tower_hard_set",
	"tower_hell_set", "tower_abyss_set"]

func _ready() -> void:
	var ok := true

	# 6절: "초월" 등급 색/순서/소켓 수.
	ok = _check("RARITY_ORDER 마지막이 초월", GameState.RARITY_ORDER[-1] == "초월") and ok
	ok = _check("초월 색 Color(0.75,0.95,1.0)",
		GameState.RARITY_COLORS["초월"].is_equal_approx(Color(0.75, 0.95, 1.0))) and ok
	ok = _check("초월 소켓 수 = 신화와 동일(3)",
		int(GameState.SOCKETS_BY_RARITY["초월"]) == 3) and ok

	# 6절: 계열마다 검/갑주/투구/인장 4종, 5계열 = 20종, 전부 초월 등급.
	var prev_atk := -1
	for set_key in TOWER_SETS:
		var set_def: Dictionary = GameState.SETS[set_key]
		var pieces: Array = set_def["pieces"]
		ok = _check(set_key + " 4종", pieces.size() == 4) and ok
		var weapon_atk := 0
		for piece_name in pieces:
			var item: Dictionary = GameState.EQUIPMENT[piece_name]
			ok = _check(str(piece_name) + " 등급 초월", str(item.get("rarity")) == "초월") and ok
			if str(item.get("slot")) == "weapon":
				weapon_atk = int(item.get("atk", 0))
		# 능력치는 쉬움 < 보통 < 어려움 < 헬 < 심연 순으로 계속 올라간다.
		ok = _check(set_key + " 무기 공격력이 이전 난이도보다 높음", weapon_atk > prev_atk) and ok
		prev_atk = weapon_atk

	# 6절: 심연 탑템(4조각)은 지금 최강인 용기사 세트(4조각)보다 확실히 세야 한다.
	var abyss_4pc: Dictionary = GameState.SETS["tower_abyss_set"]["bonuses"][4]
	var dragon_4pc: Dictionary = GameState.SETS["boss_set"]["bonuses"][4]
	ok = _check("천공 세트 4조각 atk가 용기사 세트보다 큼",
		int(abyss_4pc["atk"]) > int(dragon_4pc["atk"])) and ok
	ok = _check("천공 세트 4조각 def가 용기사 세트보다 큼",
		int(abyss_4pc["def"]) > int(dragon_4pc["def"])) and ok

	# 8절: 별(칭호)은 난이도 클리어마다 1개, 난이도가 5단계이니 최대 5개.
	ok = _check("탑 난이도 5단계 = 별 최대 5개", GameState.TOWER_TIERS.size() == 5) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
