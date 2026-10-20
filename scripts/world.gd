extends Node2D
class_name World
## 지역 배경. 한 지역은 여러 화면 크기다. 카메라가 따라가며 스크롤한다.
##
## 예전에는 지역마다 20x15 타일 한 화면을 손으로 적었다. 화면 하나면
## 다 둘러보는 데 몇 초라 게임이 금방 끝났다. 지금은 지역마다 크기를 주고
## 바닥을 규칙대로 깔고 오브젝트를 흩는다. 같은 씨앗이면 항상 같은 지형이
## 나오므로 다시 들어가도 지형이 바뀌지 않는다.

const TILE := 16
## 한 화면 크기. 지역 크기는 이것의 배수로 잡는다.
const SCREEN_COLS := 20
const SCREEN_ROWS := 15
const TOWNS := [
	"village", "harbor", "frost_camp", "abyss", "remnant_village", "driftwood_pier",
	"lantern_village", "waystation_camp", "rift_camp", "origin_camp"
]

static func is_town(map_name: String) -> bool:
	return TOWNS.has(map_name)

static func town_npc_position(map_name: String, role: String) -> Vector2:
	match role:
		"elder": return Vector2(56, 108)
		"merchant": return Vector2(212, 108)
		"smith": return Vector2(136, 108)
		"inn": return Vector2(96, 108)
		"keeper": return Vector2(172, 108)
	return Vector2(56, 108)

const SHEETS := {
	"floor": "res://assets/tiles/TilesetFloor.png",
	"nat": "res://assets/tiles/TilesetNature.png",
	"water": "res://assets/tiles/TilesetWater.png",
	"house": "res://assets/tiles/TilesetHouse.png",
	"ruin": "res://assets/tiles/TilesetVillageAbandoned.png",
	"ifloor": "res://assets/tiles/TilesetInteriorFloor.png",
	"tower": "res://assets/tiles/TilesetTowers.png",
}

# 바닥 문자 -> [시트, 아틀라스 좌표]
const GROUND := {
	"g": ["floor", Vector2i(1, 12)],   # 밝은 풀
	"G": ["floor", Vector2i(12, 12)],  # 짙은 풀
	"d": ["floor", Vector2i(1, 8)],    # 흙길
	"D": ["floor", Vector2i(12, 8)],   # 어두운 흙
	"s": ["floor", Vector2i(1, 1)],    # 모래
	"S": ["floor", Vector2i(12, 19)],  # 폐허 돌바닥
	"n": ["floor", Vector2i(1, 15)],   # 눈
	"i": ["floor", Vector2i(1, 22)],   # 언 바닥
	"w": ["water", Vector2i(1, 1)],    # 물
	"k": ["ifloor", Vector2i(13, 14)], # 던전 바닥
	"K": ["ifloor", Vector2i(12, 13)], # 던전 벽
	"c": ["ifloor", Vector2i(14, 9)],  # 성채 바닥
}

# 바닥 문자 -> 같은 칸에 섞어 쓸 무늬 변형 아틀라스 좌표들(같은 시트, 같은
# 색 계열의 결 디테일만 다름). `paint()`가 칸마다 낮은 확률로 골라 섞어
# 단색 네모가 반복되는 느낌을 줄인다. `_grid`(바닥 문자)는 그대로 두고
# 그릴 좌표만 바꾸므로 길·충돌·경로탐색에는 영향이 없다.
const GROUND_VARIANTS := {
	"g": [Vector2i(2, 12), Vector2i(3, 12), Vector2i(4, 12)],  # 풀 결 변형
	"n": [Vector2i(2, 19), Vector2i(3, 19), Vector2i(4, 19)],  # 눈 결 변형
	"s": [Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5)],     # 모래 결 변형
}
const GROUND_VARIANT_CHANCE := 0.15

# 오브젝트 -> [시트, 좌상단 아틀라스 좌표, 타일 크기, 충돌 여부]
const PROPS := {
	"tree": ["nat", Vector2i(0, 0), Vector2i(2, 2), true],
	"tree2": ["nat", Vector2i(2, 0), Vector2i(2, 2), true],
	"dead": ["nat", Vector2i(4, 0), Vector2i(2, 2), true],
	"bigtree": ["nat", Vector2i(4, 2), Vector2i(3, 3), true],
	"bigdead": ["nat", Vector2i(0, 5), Vector2i(3, 3), true],
	"rock": ["nat", Vector2i(13, 5), Vector2i(3, 3), true],
	"rock_g": ["nat", Vector2i(17, 5), Vector2i(3, 3), true],
	"rock_s": ["nat", Vector2i(13, 8), Vector2i(2, 2), true],
	"rock_gs": ["nat", Vector2i(17, 8), Vector2i(2, 2), true],
	"stump": ["nat", Vector2i(0, 8), Vector2i(2, 2), true],
	"bush": ["nat", Vector2i(0, 10), Vector2i(1, 1), false],
	"grass": ["nat", Vector2i(4, 10), Vector2i(1, 1), false],
	"flower": ["nat", Vector2i(0, 11), Vector2i(1, 1), false],
	"house_a": ["house", Vector2i(0, 0), Vector2i(4, 3), true],
	"house_b": ["house", Vector2i(4, 0), Vector2i(4, 3), true],
	"house_c": ["house", Vector2i(12, 0), Vector2i(4, 3), true],
	"cave": ["house", Vector2i(4, 7), Vector2i(4, 3), true],
	"ruin_a": ["ruin", Vector2i(0, 0), Vector2i(4, 3), true],
	"ruin_b": ["ruin", Vector2i(4, 0), Vector2i(3, 3), true],
	"grave": ["ruin", Vector2i(8, 0), Vector2i(3, 3), true],
	"ruin_c": ["ruin", Vector2i(11, 0), Vector2i(3, 3), true],
	"rubble": ["ruin", Vector2i(6, 3), Vector2i(1, 1), false],
	"tower_a": ["tower", Vector2i(0, 2), Vector2i(2, 2), true],
	"tower_b": ["tower", Vector2i(6, 2), Vector2i(2, 2), true],
	"tower_c": ["tower", Vector2i(18, 0), Vector2i(2, 2), true],
}

## 지역 정의.
## screens: 가로·세로 화면 수. base/accent: 바닥과 얼룩. path: 길.
## border: 가장자리를 두르는 벽 문자. pond: 물웅덩이 문자.
## exits: 동서 연결만 쓴다(위아래 이동 없음). 모든 지역은 320x240 한 화면(screens 1x1).
## grid: 지도 화면에 그릴 자리. exits 와 어긋나면 지도가 이상해진다.
## chapter: 이 지역이 열리는 장.
const AREAS := {
	# --- 1장 바람골 지방 ---
	"village": {
		"title": "바람골 마을", "chapter": 1, "grid": Vector2i(0, 0),
		"exits": {"e": "hill"},
		# 4구획(2x2)이던 마을을 1구획으로 통합했다. NPC 다섯 명이 전부 한
		# 화면(y108 근처)에 서 있는데 마을만 4배 넓어서 나머지 세 구획이
		# 빈 잔디였다("몬스터도 NPC도 없는 빈 화면" 피드백).
		"screens": Vector2i(1, 1), "base": "g", "accent": "G", "path": "d",
		"pond": "w", "ponds": 1, "town": true,
		"landmarks": [["house_a", 1, 1], ["house_b", 8, 1], ["house_c", 15, 1]],
		"scatter": {"tree": 4, "tree2": 3, "bush": 5, "flower": 4, "grass": 5, "rock_s": 2},
	},
	"hill": {
		"title": "바람 언덕", "chapter": 1, "grid": Vector2i(1, 0),
		"exits": {"w": "village", "e": "hill_ridge"},
		"screens": Vector2i(1, 1), "base": "g", "accent": "s", "path": "d",
		"landmarks": [["rock_g", 3, 1], ["rock_g", 12, 1], ["rock_g", 15, 11]],
		"scatter": {"rock_g": 2, "rock_gs": 4, "rock_s": 4, "grass": 2, "bush": 2, "tree": 1},
	},
	# 사냥터. 이야기 진행에는 필요 없고 잡으러만 가는 곳이다.
	"hill_ridge": {
		"title": "바람 능선", "chapter": 1, "grid": Vector2i(2, 0),
		"exits": {"w": "hill", "e": "forest_w"},
		"screens": Vector2i(1, 1), "base": "g", "accent": "s", "path": "d",
		"landmarks": [["rock_g", 2, 1], ["rock_g", 13, 1], ["rock_gs", 8, 11]],
		"scatter": {"rock_g": 3, "rock_gs": 4, "rock_s": 4, "grass": 2, "bush": 2},
	},
	"forest_w": {
		# 서편/깊은 곳/동편 3개 지역(각 3x2/2x2/3x2)을 화면 전환 없이 한
		# 맵으로 합쳤다(INBOX D, 잘게 쪼개진 사냥터 통합). 가로로 나란히
		# 이어붙여 8x2 화면. 좌표는 옛 forest_n/forest_e 랜드마크를 각각
		# +60/+100 타일 옮긴 것.
		"title": "안개숲", "chapter": 1, "grid": Vector2i(3, 0),
		"exits": {"w": "hill_ridge", "e": "glade"},
		"screens": Vector2i(1, 1), "base": "G", "accent": "g", "path": "d",
		# 1x1 한 방에는 연못이 가운데 띠를 막아 몹까지 못 간다 - 연못 없음.
		"landmarks": [["bigtree", 1, 1], ["bigdead", 4, 1], ["bigtree", 6, 11], ["stump", 2, 11], ["bigdead", 8, 1]],
		"scatter": {"tree": 2, "tree2": 2, "dead": 2, "bush": 3, "flower": 1, "grass": 1, "rock_s": 1, "stump": 1},
	},
	"glade": {
		"title": "이끼 빈터", "chapter": 1, "grid": Vector2i(4, 0),
		"exits": {"w": "forest_w", "e": "dungeon"},
		# 원래 남쪽 별도 지역(황혼의 폐사원)이었던 곳을 화면 전환 없이
		# 한 맵 안에서 돌아다니도록 흡수했다 - 사용자 요청("전에는 맵을
		# 쪼개지 않고 이 4개를 전부 붙여서 그 큰 맵 안에서 돌아다니게끔
		# 했었어"). 위쪽(북)에 폐사원 구역을 붙여 화면을 세로로 키운다.
		"screens": Vector2i(1, 1), "base": "g", "accent": "G", "path": "d",
		"pond": "w", "ponds": 1,
		"landmarks": [["bigtree", 2, 1], ["stump", 12, 11], ["bigtree", 14, 12], ["ruin_b", 13, 1], ["ruin_a", 8, 11]],
		"scatter": {"flower": 6, "bush": 4, "grass": 4, "stump": 1, "tree": 1, "rubble": 3, "rock_gs": 3, "rock_s": 2, "grave": 1},
	},
	"dungeon": {
		"title": "수호자의 동굴", "chapter": 1, "grid": Vector2i(5, 0),
		"exits": {"w": "glade", "e": "cave_deep"},
		"screens": Vector2i(1, 1), "base": "k", "accent": "K", "path": "k",
		"border": "K",
		"landmarks": [["rock_g", 2, 2], ["rock_g", 10, 2]],
		"scatter": {"rock_g": 2, "rock_gs": 4, "rock_s": 4, "rubble": 4},
	},
	"cave_deep": {
		"title": "수호자의 제단", "chapter": 1, "grid": Vector2i(6, 0),
		"exits": {"w": "dungeon"}, "boss": 1,
		"screens": Vector2i(1, 1), "base": "k", "accent": "K", "path": "k",
		"border": "K",
		"landmarks": [["rock_g", 2, 2], ["rock_g", 15, 2]],
		"scatter": {"rock_gs": 4, "rock_s": 4, "rubble": 4},
	},

	# --- 2장 청람 지방 ---
	"harbor": {
		"title": "청람 항구마을", "chapter": 2, "grid": Vector2i(0, 1),
		"exits": {"e": "shore"},
		# village와 같은 이유로 1구획으로 통합.
		"screens": Vector2i(1, 1), "base": "s", "accent": "g", "path": "d",
		"pond": "w", "ponds": 1, "town": true,
		"landmarks": [["house_b", 1, 1], ["house_a", 8, 1], ["house_c", 15, 1]],
		"scatter": {"tree": 3, "tree2": 2, "rock_s": 3, "bush": 5, "grass": 5, "rock_gs": 2},
	},
	"shore": {
		"title": "모래 해안", "chapter": 2, "grid": Vector2i(1, 1),
		"exits": {"w": "harbor", "e": "marsh"},
		"screens": Vector2i(1, 1), "base": "s", "accent": "g", "path": "d",
		"pond": "w", "ponds": 1,
		"landmarks": [["rock_s", 2, 2], ["rock_g", 10, 1], ["rock_s", 15, 11]],
		"scatter": {"rock_s": 2, "rock_gs": 2, "bush": 2, "grass": 2, "tree": 1},
	},
	"marsh": {
		"title": "안개 늪지", "chapter": 2, "grid": Vector2i(2, 1),
		"exits": {"w": "shore", "e": "marsh_deep"},
		"screens": Vector2i(1, 1), "base": "G", "accent": "D", "path": "D",
		"pond": "w", "ponds": 1,
		"landmarks": [["bigdead", 2, 1], ["ruin_b", 12, 1], ["bigdead", 14, 11]],
		"scatter": {"dead": 4, "bigdead": 2, "bush": 3, "rubble": 2, "rock_s": 2},
	},
	# 사냥터.
	"marsh_deep": {
		"title": "깊은 늪", "chapter": 2, "grid": Vector2i(3, 1),
		"exits": {"w": "marsh", "e": "ruins_w"},
		# 원래 남쪽 별도 지역(가라앉은 유적)이었던 곳을 화면 전환 없이
		# 한 맵 안에서 돌아다니도록 흡수했다.
		"screens": Vector2i(1, 1), "base": "G", "accent": "D", "path": "D",
		"pond": "w", "ponds": 1,
		"landmarks": [["bigdead", 2, 1], ["ruin_b", 12, 1], ["bigdead", 8, 11], ["bigdead", 12, 11]],
		"scatter": {"dead": 3, "bigdead": 2, "bush": 2, "rubble": 2, "rock_s": 1, "ruin_b": 1},
	},
	"ruins_w": {
		# 폐허 서편/망루/동편 3개 지역(각 3x2/2x2/3x2)을 화면 전환 없이 한
		# 맵으로 합쳤다(INBOX D, 잘게 쪼개진 사냥터 통합, 안개숲과 같은 패턴).
		# 가로로 나란히 이어붙여 8x2 화면. 좌표는 옛 watchtower/ruins_e
		# 랜드마크를 각각 +60/+100 타일 옮긴 것.
		"title": "잿빛 폐허", "chapter": 2, "grid": Vector2i(4, 1),
		"exits": {"w": "marsh_deep", "e": "citadel_gate"},
		"screens": Vector2i(1, 1), "base": "S", "accent": "D", "path": "D",
		"landmarks": [["ruin_a", 1, 1], ["ruin_b", 6, 1], ["ruin_a", 2, 11], ["ruin_c", 6, 11], ["tower_a", 10, 2]],
		"scatter": {"rubble": 5, "rock_s": 2, "grave": 1, "ruin_b": 1, "rock_gs": 1, "tower_a": 1, "tower_b": 1},
	},
	"citadel_gate": {
		"title": "검은 성채 관문", "chapter": 2, "grid": Vector2i(5, 1),
		"exits": {"w": "ruins_w", "e": "citadel"},
		"screens": Vector2i(1, 1), "base": "c", "accent": "K", "path": "K",
		"border": "K",
		"landmarks": [["tower_c", 2, 2], ["tower_c", 14, 2], ["tower_a", 8, 11]],
		"scatter": {"tower_a": 2, "tower_b": 2, "rubble": 4, "rock_gs": 2},
	},
	"citadel": {
		"title": "검은 성채", "chapter": 2, "grid": Vector2i(6, 1),
		"exits": {"w": "citadel_gate"}, "boss": 2,
		"screens": Vector2i(1, 1), "base": "c", "accent": "K", "path": "K",
		"border": "K",
		"landmarks": [["tower_c", 2, 2], ["tower_c", 9, 2], ["tower_c", 17, 2], ["tower_a", 5, 11], ["tower_b", 13, 11]],
		"scatter": {"tower_a": 2, "tower_b": 2, "rubble": 4, "rock_gs": 2},
	},

	# --- 3장 서리벌 지방 ---
	"frost_camp": {
		"title": "얼어붙은 야영지", "chapter": 3, "grid": Vector2i(0, 2),
		"exits": {"e": "snowfield"},
		"screens": Vector2i(1, 1), "base": "n", "accent": "i", "path": "d",
		"pond": "i", "ponds": 1, "town": true,
		"landmarks": [["house_b", 2, 1], ["house_a", 10, 1], ["house_c", 6, 11]],
		"scatter": {"tree2": 2, "dead": 2, "rock_gs": 2, "bush": 2, "rock_s": 2},
	},
	"snowfield": {
		"title": "서리벌 설원", "chapter": 3, "grid": Vector2i(1, 2),
		"exits": {"w": "frost_camp", "e": "frost_ridge"},
		"screens": Vector2i(1, 1), "base": "n", "accent": "i", "path": "d",
		"pond": "i", "ponds": 1,
		"landmarks": [["bigtree", 1, 1], ["bigdead", 9, 1], ["rock_g", 15, 1], ["bigdead", 5, 11], ["rock_g", 13, 11]],
		"scatter": {"tree2": 2, "bigtree": 1, "dead": 1, "rock_gs": 2, "rock_s": 1, "bush": 2, "grass": 2, "stump": 1},
	},
	# 사냥터.
	"frost_ridge": {
		"title": "얼어붙은 능선", "chapter": 3, "grid": Vector2i(2, 2),
		"exits": {"w": "snowfield", "e": "frost_gorge"},
		"screens": Vector2i(1, 1), "base": "n", "accent": "i", "path": "d",
		"pond": "i", "ponds": 1,
		"landmarks": [["bigdead", 2, 1], ["rock_g", 12, 1], ["bigtree", 8, 11]],
		"scatter": {"tree2": 2, "dead": 2, "rock_gs": 3, "rock_s": 2, "bush": 2},
	},
	"frost_gorge": {
		"title": "서리 협곡", "chapter": 3, "grid": Vector2i(3, 2),
		"exits": {"w": "frost_ridge", "e": "frozen_falls"},
		# 원래 북쪽 별도 지역(빙하 균열)이었던 곳을 화면 전환 없이 한 맵
		# 안에서 돌아다니도록 흡수했다.
		"screens": Vector2i(1, 1), "base": "n", "accent": "i", "path": "d",
		"pond": "i", "ponds": 1,
		"landmarks": [["rock_g", 2, 1], ["bigdead", 12, 11], ["rock_gs", 8, 12], ["bigdead", 12, 1]],
		"scatter": {"rock_gs": 2, "rock_g": 2, "tree2": 1, "dead": 1, "bush": 1},
	},
	"frozen_falls": {
		"title": "얼어붙은 폭포", "chapter": 3, "grid": Vector2i(4, 2),
		"exits": {"w": "frost_gorge", "e": "blizzard_plain"},
		"screens": Vector2i(1, 1), "base": "i", "accent": "n", "path": "i",
		"pond": "w", "ponds": 1,
		"landmarks": [["rock_g", 3, 1], ["rock_gs", 13, 2], ["rock_g", 8, 11]],
		"scatter": {"rock_gs": 4, "rock_g": 2, "rock_s": 2, "dead": 2},
	},
	"blizzard_plain": {
		"title": "눈보라 평원", "chapter": 3, "grid": Vector2i(5, 2),
		"exits": {"w": "frozen_falls", "e": "glacier"},
		"screens": Vector2i(1, 1), "base": "n", "accent": "i", "path": "d",
		"pond": "i", "ponds": 1,
		"landmarks": [["bigtree", 2, 1], ["bigdead", 9, 1], ["rock_g", 15, 11]],
		"scatter": {"tree2": 2, "bigtree": 1, "dead": 2, "rock_gs": 2, "bush": 1},
	},
	"glacier": {
		"title": "얼음 계곡", "chapter": 3, "grid": Vector2i(6, 2),
		"exits": {"w": "blizzard_plain", "e": "temple"},
		"screens": Vector2i(1, 1), "base": "n", "accent": "i", "path": "i",
		"landmarks": [["rock_g", 2, 1], ["rock_g", 9, 1], ["rock_g", 16, 11]],
		"scatter": {"rock_g": 2, "rock_gs": 4, "rock_s": 3, "dead": 2, "rubble": 2},
	},
	"temple": {
		"title": "얼어붙은 신전", "chapter": 3, "grid": Vector2i(7, 2),
		"exits": {"w": "glacier"}, "boss": 3,
		"screens": Vector2i(1, 1), "base": "i", "accent": "n", "path": "c",
		"border": "c",
		"landmarks": [["tower_c", 2, 2], ["tower_c", 9, 2], ["tower_c", 17, 2], ["tower_c", 5, 11], ["tower_c", 13, 11]],
		"scatter": {"rock_gs": 4, "rock_s": 3, "rubble": 3, "tower_c": 2},
	},

	# --- 4장 잿불 지방 ---
	"abyss": {
		"title": "잿불 야영지", "chapter": 4, "grid": Vector2i(0, 3),
		"exits": {"e": "ash_hollow"},
		"screens": Vector2i(1, 1), "base": "D", "accent": "k", "path": "S", "town": true,
		"landmarks": [["bigdead", 2, 1], ["ruin_a", 9, 1], ["bigdead", 15, 11]],
		"scatter": {"dead": 4, "bigdead": 3, "rubble": 5, "rock_s": 3, "grave": 2, "stump": 2, "ruin_b": 1},
	},
	# 사냥터.
	"ash_hollow": {
		"title": "잿불 협곡", "chapter": 4, "grid": Vector2i(1, 3),
		"exits": {"w": "abyss", "e": "ash_ridge"},
		"screens": Vector2i(1, 1), "base": "D", "accent": "k", "path": "S",
		"landmarks": [["bigdead", 2, 1], ["ruin_a", 12, 1], ["grave", 8, 11]],
		"scatter": {"dead": 4, "bigdead": 2, "rubble": 4, "rock_s": 2, "grave": 2},
	},
	"ash_ridge": {
		"title": "잿불 능선", "chapter": 4, "grid": Vector2i(2, 3),
		"exits": {"w": "ash_hollow", "e": "ember_valley"},
		# 원래 북쪽 별도 지역(심연 너머)이었던 곳을 화면 전환 없이 한 맵
		# 안에서 돌아다니도록 흡수했다.
		"screens": Vector2i(1, 1), "base": "D", "accent": "k", "path": "S",
		"landmarks": [["rock_s", 2, 2], ["bigdead", 12, 11], ["rock_gs", 8, 12], ["ruin_a", 12, 1]],
		"scatter": {"rock_s": 3, "bigdead": 2, "rubble": 4, "dead": 2, "grave": 2, "tower_b": 1, "rock_gs": 2},
	},
	"ember_valley": {
		"title": "잉걸불 골짜기", "chapter": 4, "grid": Vector2i(3, 3),
		"exits": {"w": "ash_ridge", "e": "charred_corridor"},
		"screens": Vector2i(1, 1), "base": "D", "accent": "S", "path": "S",
		"landmarks": [["ruin_a", 2, 1], ["ruin_b", 9, 1], ["grave", 15, 11]],
		"scatter": {"rubble": 4, "grave": 1, "dead": 2, "ruin_b": 1},
	},
	"charred_corridor": {
		"title": "타버린 회랑", "chapter": 4, "grid": Vector2i(4, 3),
		"exits": {"w": "ember_valley", "e": "ash_marsh"},
		"screens": Vector2i(1, 1), "base": "k", "accent": "K", "path": "k",
		"border": "K",
		"landmarks": [["rock_gs", 2, 2], ["rubble", 12, 2], ["rock_s", 8, 11]],
		"scatter": {"rock_gs": 4, "rubble": 5, "rock_s": 4},
	},
	"ash_marsh": {
		"title": "재의 늪", "chapter": 4, "grid": Vector2i(5, 3),
		"exits": {"w": "charred_corridor", "e": "throne"},
		"screens": Vector2i(1, 1), "base": "D", "accent": "k", "path": "S",
		"pond": "k", "ponds": 1,
		"landmarks": [["dead", 2, 2], ["bigdead", 12, 1], ["grave", 8, 11]],
		"scatter": {"dead": 5, "bigdead": 3, "rubble": 3, "grave": 2},
	},
	"throne": {
		"title": "심연의 왕좌", "chapter": 4, "grid": Vector2i(6, 3),
		"exits": {"w": "ash_marsh"}, "boss": 4,
		"screens": Vector2i(1, 1), "base": "K", "accent": "c", "path": "c",
		"border": "K",
		"landmarks": [["tower_a", 2, 2], ["tower_b", 9, 2], ["tower_a", 17, 2], ["tower_b", 5, 11], ["tower_a", 13, 11]],
		"scatter": {"tower_a": 2, "tower_b": 2, "rubble": 4, "rock_gs": 2},
	},
	# 곁가지 보너스 던전. 예전에는 남북(n/s) exits로 별도 지역이었으나,
	# 화면 전환 없이 한 맵 안에서 발견하는 방식으로 되돌렸다 - 사용자
	# 요청("전에는 맵을 쪼개지 않고 이 4개를 전부 붙여서 그 큰 맵 안에서
	# 돌아다니게끔 했었어"). 실제 내용(황혼의 폐사원/가라앉은 유적/빙하
	# 균열/심연 너머)은 각 부모 지역(glade/marsh_deep/frost_gorge/
	# ash_ridge)의 landmarks/scatter로 흡수됐다.

	# --- 엔드게임: 탑 ---
	# 스토리 클리어 후 여는 다층 던전. 맵은 이 하나뿐이고 층 번호로
	# main.gd _spawn_tower_floor() 가 몬스터만 절차적으로 바꿔 채운다.
	# 상세 설계: TOWER_DESIGN.md.
	# 원래 2x2 화면(4구획)이었는데 스크롤하며 넘어다녀야 해서 "맵 하나가
	# 4개로 쪼개진 것 같다"는 피드백이 있었다 - 한 화면(1x1)짜리 방
	# 하나로 줄였다. 층은 여전히 몬스터·능력치만 바뀌는 식으로 진행된다.
	"tower": {
		"title": "심연의 탑", "chapter": 4, "grid": Vector2i(8, -4),
		"screens": Vector2i(1, 1), "base": "k", "accent": "K", "path": "k",
		"border": "K",
		"landmarks": [["tower_a", 3, 3], ["tower_b", 14, 3], ["tower_c", 8, 10]],
		"scatter": {"rubble": 5, "rock_gs": 4},
	},

	# --- 5장 유민의 땅 (CHAPTER5_EXPANSION_DESIGN.md 3절) ---
	# 4장을 깬 뒤 이어지는 확장팩. 폐허가 된 옛 문명 + 침식된 현실 톤.
	# 팔레트는 기존 지역과 겹치지 않게 폐허 돌바닥(S)+던전 벽(K)+짙은
	# 풀(G) 조합으로 보라/암녹 느낌을 낸다(새 타일 코드 추가 없이 재사용).
	"remnant_village": {
		"title": "잔영의 마을 (은둔지)", "chapter": 5, "grid": Vector2i(0, 4),
		"exits": {"e": "collapsed_spires"},
		"screens": Vector2i(1, 1), "base": "S", "accent": "G", "path": "D",
		"landmarks": [["ruin_c", 2, 1], ["house_c", 12, 1], ["ruin_a", 8, 11]],
		"scatter": {"rubble": 4, "grave": 2, "bush": 2},
	},
	"collapsed_spires": {
		"title": "무너진 첨탑 거리", "chapter": 5, "grid": Vector2i(1, 4),
		"exits": {"w": "remnant_village", "e": "eroded_plaza"},
		"screens": Vector2i(1, 1), "base": "S", "accent": "K", "path": "D",
		"border": "K",
		"landmarks": [["ruin_a", 2, 2], ["ruin_b", 12, 2]],
		"scatter": {"rubble": 6, "ruin_b": 2, "grave": 2},
	},
	"eroded_plaza": {
		"title": "침식된 광장", "chapter": 5, "grid": Vector2i(2, 4),
		"exits": {"w": "collapsed_spires", "e": "cracked_statue"},
		"screens": Vector2i(1, 1), "base": "K", "accent": "S", "path": "k",
		"border": "K",
		"landmarks": [["tower_c", 2, 2], ["rubble", 12, 2]],
		"scatter": {"rubble": 5, "rock_gs": 2, "tower_c": 2},
	},
	"cracked_statue": {
		"title": "갈라진 석상", "chapter": 5, "grid": Vector2i(3, 4),
		"exits": {"w": "eroded_plaza", "e": "hall_of_afterimages"},
		"screens": Vector2i(1, 1), "base": "S", "accent": "G", "path": "D",
		"landmarks": [["ruin_c", 2, 1], ["tower_a", 12, 2], ["grave", 8, 11]],
		"scatter": {"rubble": 4, "grave": 2, "ruin_c": 2},
	},
	"hall_of_afterimages": {
		"title": "잔영의 회랑", "chapter": 5, "grid": Vector2i(4, 4),
		"exits": {"w": "cracked_statue", "e": "twisted_sanctum"},
		"screens": Vector2i(1, 1), "base": "k", "accent": "K", "path": "k",
		"border": "K",
		"landmarks": [["ruin_a", 2, 2], ["grave", 12, 2]],
		"scatter": {"grave": 4, "rubble": 4, "ruin_a": 2},
	},
	"twisted_sanctum": {
		"title": "뒤틀린 사원", "chapter": 5, "grid": Vector2i(5, 4),
		"exits": {"w": "hall_of_afterimages", "e": "rift_of_origin"},
		"screens": Vector2i(1, 1), "base": "S", "accent": "K", "path": "D",
		"border": "K",
		"landmarks": [["ruin_c", 2, 2], ["ruin_a", 9, 2], ["tower_b", 15, 11]],
		"scatter": {"rubble": 4, "ruin_c": 2, "grave": 1},
	},
	"rift_of_origin": {
		"title": "근원의 균열", "chapter": 5, "grid": Vector2i(6, 4),
		"exits": {"w": "twisted_sanctum"}, "boss": 5,
		"screens": Vector2i(1, 1), "base": "K", "accent": "G", "path": "k",
		"border": "K",
		"landmarks": [["tower_a", 2, 2], ["tower_c", 9, 2], ["tower_b", 17, 2], ["tower_a", 5, 11], ["tower_c", 13, 11]],
		"scatter": {"tower_a": 2, "tower_c": 2, "rubble": 4, "rock_gs": 2},
	},

	# --- 6장 파편의 바다 (CHAPTER6_10_MASTERPLAN.md 2절) ---
	# 태초의 심연이 재봉인되며 흩어진 힘의 파편이 가라앉은 침수 지대.
	# 청록/남색 톤 - 기존 물(w)/모래(s)/눈(n,i) 코드를 재조합해 새 타일
	# 코드 추가 없이 "가라앉은 항로" 느낌을 낸다.
	"driftwood_pier": {
		"title": "표류자의 부두", "chapter": 6, "grid": Vector2i(0, 5),
		"exits": {"e": "sunken_causeway"},
		"screens": Vector2i(1, 1), "base": "s", "accent": "S", "path": "d",
		"pond": "w", "ponds": 1,
		"landmarks": [["ruin_b", 2, 1], ["house_b", 12, 1], ["ruin_a", 8, 11]],
		"scatter": {"rubble": 3, "bush": 2, "rock_s": 2},
	},
	"sunken_causeway": {
		"title": "가라앉은 방죽길", "chapter": 6, "grid": Vector2i(1, 5),
		"exits": {"w": "driftwood_pier", "e": "tideglass_shallows"},
		"screens": Vector2i(1, 1), "base": "s", "accent": "n", "path": "i",
		"pond": "w", "ponds": 1,
		"landmarks": [["ruin_a", 2, 1], ["ruin_c", 12, 1], ["rock_s", 8, 11]],
		"scatter": {"rubble": 4, "rock_s": 3, "ruin_b": 2},
	},
	"tideglass_shallows": {
		"title": "조수유리 여울", "chapter": 6, "grid": Vector2i(2, 5),
		"exits": {"w": "sunken_causeway", "e": "current_maw"},
		"screens": Vector2i(1, 1), "base": "i", "accent": "n", "path": "i",
		"pond": "w", "ponds": 1,
		"landmarks": [["rock_gs", 2, 2], ["rock_g", 12, 1], ["rock_s", 8, 11]],
		"scatter": {"rock_gs": 4, "rock_g": 2, "rubble": 2},
	},
	"current_maw": {
		"title": "소용돌이 아가리", "chapter": 6, "grid": Vector2i(3, 5),
		"exits": {"w": "tideglass_shallows", "e": "coral_wreckage"},
		"screens": Vector2i(1, 1), "base": "n", "accent": "s", "path": "i",
		"border": "K",
		"pond": "w", "ponds": 1,
		"landmarks": [["rock_g", 2, 2], ["ruin_b", 12, 2], ["rock_gs", 8, 11]],
		"scatter": {"rock_g": 4, "rubble": 4, "ruin_b": 2},
	},
	"coral_wreckage": {
		"title": "산호 난파지", "chapter": 6, "grid": Vector2i(4, 5),
		"exits": {"w": "current_maw", "e": "abyssal_trench"},
		"screens": Vector2i(1, 1), "base": "s", "accent": "S", "path": "d",
		"pond": "w", "ponds": 1,
		"landmarks": [["ruin_a", 2, 1], ["ruin_c", 12, 1], ["ruin_b", 8, 11]],
		"scatter": {"ruin_a": 2, "rubble": 5, "rock_s": 2},
	},
	"abyssal_trench": {
		"title": "심연의 해구", "chapter": 6, "grid": Vector2i(5, 5),
		"exits": {"w": "coral_wreckage", "e": "the_watcher_reef"},
		"screens": Vector2i(1, 1), "base": "K", "accent": "n", "path": "k",
		"border": "K",
		"pond": "w", "ponds": 1,
		"landmarks": [["ruin_c", 2, 2], ["rock_g", 9, 2]],
		"scatter": {"rubble": 3, "rock_g": 2, "ruin_c": 1},
	},
	"the_watcher_reef": {
		"title": "파수꾼의 암초", "chapter": 6, "grid": Vector2i(6, 5),
		"exits": {"w": "abyssal_trench"}, "boss": 6,
		"screens": Vector2i(1, 1), "base": "K", "accent": "i", "path": "k",
		"border": "K",
		"pond": "w", "ponds": 1,
		"landmarks": [["tower_a", 2, 2], ["tower_c", 9, 2], ["tower_b", 17, 2], ["tower_a", 13, 11]],
		"scatter": {"tower_a": 1, "rock_g": 2, "rubble": 4},
	},
	# --- 7장 잊힌 성소 (CHAPTER6_10_MASTERPLAN.md 2절) ---
	# 파편이 모여 오래전 무너진 신전이 다시 빛을 낸다. "신성한 것이
	# 침식됐다"는 톤 -- 빛바랜 금색/흰색. 모래(s)/성채바닥(c)/폐허(S)
	# 조합으로 새 타일 코드 없이 표현한다.
	"lantern_village": {
		"title": "등불지기 마을", "chapter": 7, "grid": Vector2i(0, 6),
		"exits": {"e": "sunbleached_stair"},
		"screens": Vector2i(1, 1), "base": "s", "accent": "c", "path": "d",
		"landmarks": [["house_a", 2, 1], ["house_c", 12, 1], ["house_b", 8, 11]],
		"scatter": {"flower": 4, "bush": 2, "grass": 4},
	},
	"sunbleached_stair": {
		"title": "빛바랜 계단길", "chapter": 7, "grid": Vector2i(1, 6),
		"exits": {"w": "lantern_village", "e": "vow_terrace"},
		"screens": Vector2i(1, 1), "base": "s", "accent": "S", "path": "c",
		"landmarks": [["ruin_a", 2, 1], ["ruin_c", 12, 1], ["rock_s", 8, 11]],
		"scatter": {"rubble": 4, "rock_s": 2, "ruin_b": 2},
	},
	"vow_terrace": {
		"title": "맹세의 회랑", "chapter": 7, "grid": Vector2i(2, 6),
		"exits": {"w": "sunbleached_stair", "e": "gilded_cloister"},
		"screens": Vector2i(1, 1), "base": "c", "accent": "S", "path": "c",
		"landmarks": [["ruin_b", 2, 1], ["ruin_a", 12, 1], ["ruin_c", 8, 11]],
		"scatter": {"ruin_b": 2, "rubble": 4, "rock_s": 2},
	},
	"gilded_cloister": {
		"title": "금박 회랑", "chapter": 7, "grid": Vector2i(3, 6),
		"exits": {"w": "vow_terrace", "e": "hollow_nave"},
		"screens": Vector2i(1, 1), "base": "c", "accent": "s", "path": "c",
		"border": "K",
		"landmarks": [["ruin_c", 2, 2], ["ruin_b", 12, 2]],
		"scatter": {"ruin_c": 2, "rubble": 5, "rock_s": 2},
	},
	"hollow_nave": {
		"title": "텅 빈 성소", "chapter": 7, "grid": Vector2i(4, 6),
		"exits": {"w": "gilded_cloister", "e": "ashen_reliquary"},
		"screens": Vector2i(1, 1), "base": "S", "accent": "c", "path": "k",
		"border": "K",
		"landmarks": [["ruin_a", 2, 2], ["ruin_c", 12, 2]],
		"scatter": {"ruin_a": 2, "rubble": 6, "rock_s": 2},
	},
	"ashen_reliquary": {
		"title": "잿빛 유물고", "chapter": 7, "grid": Vector2i(5, 6),
		"exits": {"w": "hollow_nave", "e": "sanctum_of_light"},
		"screens": Vector2i(1, 1), "base": "K", "accent": "S", "path": "k",
		"border": "K",
		"landmarks": [["ruin_b", 2, 2], ["ruin_c", 9, 2]],
		"scatter": {"rubble": 4, "ruin_b": 2, "ruin_c": 1},
	},
	"sanctum_of_light": {
		"title": "빛바랜 성소", "chapter": 7, "grid": Vector2i(6, 6),
		"exits": {"w": "ashen_reliquary"}, "boss": 7,
		"screens": Vector2i(1, 1), "base": "K", "accent": "c", "path": "k",
		"border": "K",
		"landmarks": [["tower_b", 2, 2], ["tower_a", 9, 2], ["tower_c", 17, 2], ["tower_b", 13, 11]],
		"scatter": {"tower_b": 1, "ruin_a": 2, "rubble": 4},
	},
	# --- 8장 침묵의 회랑 (CHAPTER6_10_MASTERPLAN.md 2절) ---
	# "소리와 색이 지워진 공간" -- 무채색 톤. 살아있는 정착민이 없어
	# 마을 대신 빈 경유지 캠프(스폰 몹 없음)로 시작한다.
	"waystation_camp": {
		"title": "경유지 캠프 (무인)", "chapter": 8, "grid": Vector2i(0, 8),
		"exits": {"e": "threshold_stair"},
		"screens": Vector2i(1, 1), "base": "k", "accent": "K", "path": "i",
		"border": "K",
		"landmarks": [["ruin_b", 2, 2], ["ruin_c", 12, 2]],
		"scatter": {"rubble": 4, "rock_s": 2},
	},
	"threshold_stair": {
		"title": "문턱의 계단", "chapter": 8, "grid": Vector2i(1, 8),
		"exits": {"w": "waystation_camp", "e": "muted_gallery"},
		"screens": Vector2i(1, 1), "base": "k", "accent": "i", "path": "K",
		"border": "K",
		"landmarks": [["ruin_a", 2, 2], ["ruin_c", 12, 2], ["rock_s", 8, 11]],
		"scatter": {"rubble": 5, "rock_s": 2, "ruin_b": 2},
	},
	"muted_gallery": {
		"title": "소리 없는 회랑", "chapter": 8, "grid": Vector2i(2, 8),
		"exits": {"w": "threshold_stair", "e": "silent_archive"},
		"screens": Vector2i(1, 1), "base": "K", "accent": "i", "path": "k",
		"border": "K",
		"landmarks": [["ruin_b", 2, 2], ["ruin_a", 12, 2]],
		"scatter": {"ruin_b": 2, "rubble": 4, "rock_s": 2},
	},
	"silent_archive": {
		"title": "말라붙은 기록보관소", "chapter": 8, "grid": Vector2i(3, 8),
		"exits": {"w": "muted_gallery", "e": "hollow_barracks"},
		"screens": Vector2i(1, 1), "base": "i", "accent": "K", "path": "k",
		"border": "K",
		"landmarks": [["ruin_c", 2, 2], ["ruin_b", 12, 2]],
		"scatter": {"ruin_c": 2, "rubble": 6, "rock_s": 2},
	},
	"hollow_barracks": {
		"title": "텅 빈 병영", "chapter": 8, "grid": Vector2i(4, 8),
		"exits": {"w": "silent_archive", "e": "grey_reservoir"},
		"screens": Vector2i(1, 1), "base": "k", "accent": "K", "path": "i",
		"border": "K",
		"landmarks": [["ruin_a", 2, 2], ["ruin_c", 12, 2]],
		"scatter": {"ruin_a": 2, "rubble": 6, "rock_s": 2},
	},
	"grey_reservoir": {
		"title": "잿빛 저수조", "chapter": 8, "grid": Vector2i(5, 8),
		"exits": {"w": "hollow_barracks", "e": "chamber_of_wardens"},
		"screens": Vector2i(1, 1), "base": "K", "accent": "i", "path": "k",
		"border": "K",
		"pond": "w", "ponds": 1,
		"landmarks": [["ruin_b", 2, 2], ["ruin_c", 9, 2]],
		"scatter": {"rubble": 4, "ruin_b": 2, "ruin_c": 1},
	},
	"chamber_of_wardens": {
		"title": "감독관의 방", "chapter": 8, "grid": Vector2i(6, 8), "boss": 8,
		"exits": {"w": "grey_reservoir"},
		"screens": Vector2i(1, 1), "base": "K", "accent": "k", "path": "K",
		"border": "K",
		"landmarks": [["tower_b", 2, 2], ["tower_a", 9, 2], ["tower_c", 17, 2], ["tower_b", 13, 11]],
		"scatter": {"tower_b": 1, "ruin_a": 2, "rubble": 4},
	},
	# --- 9장 역전의 탑 (CHAPTER6_10_MASTERPLAN.md 2절, 가칭 -- 기존
	# 엔드게임 "tower"와 이름 겹치지 않게 지역 ID는 "rift_"로 구분) ---
	"rift_camp": {
		"title": "회고의 캠프", "chapter": 9, "grid": Vector2i(6, 4),
		"exits": {"e": "inverted_stair"},
		"screens": Vector2i(1, 1), "base": "k", "accent": "K", "path": "d",
		"border": "K",
		"landmarks": [["house_a", 3, 2], ["house_b", 11, 2], ["rock_s", 7, 2]],
		"scatter": {"rubble": 2, "rock_s": 1},
	},
	"inverted_stair": {
		"title": "거꾸로 된 계단", "chapter": 9, "grid": Vector2i(6, 4),
		"exits": {"w": "rift_camp", "e": "echo_of_forest"},
		"screens": Vector2i(1, 1), "base": "K", "accent": "i", "path": "k",
		"border": "K",
		"landmarks": [["tower_a", 3, 2], ["tower_c", 14, 11]],
		"scatter": {"tower_a": 2, "tower_b": 2, "rubble": 3},
	},
	"echo_of_forest": {
		"title": "숲의 잔향", "chapter": 9, "grid": Vector2i(7, 5),
		"exits": {"w": "inverted_stair", "e": "echo_of_captain"},
		"screens": Vector2i(1, 1), "base": "G", "accent": "K", "path": "d",
		"border": "K",
		"landmarks": [["bigtree", 3, 2], ["tower_a", 8, 2]],
		"scatter": {"bigtree": 3, "bigdead": 2, "rock": 2},
	},
	"echo_of_captain": {
		"title": "흑기사단장의 잔향", "chapter": 9, "grid": Vector2i(6, 4),
		"exits": {"w": "echo_of_forest", "e": "echo_of_frost"},
		"screens": Vector2i(1, 1), "base": "K", "accent": "i", "path": "K",
		"border": "K",
		"landmarks": [["tower_b", 4, 2], ["tower_c", 12, 11]],
		"scatter": {"tower_b": 2, "rubble": 4},
	},
	"echo_of_frost": {
		"title": "얼음 군주의 잔향", "chapter": 9, "grid": Vector2i(7, 5),
		"exits": {"w": "echo_of_captain", "e": "echo_of_abyss"},
		"screens": Vector2i(1, 1), "base": "i", "accent": "n", "path": "i",
		"border": "K",
		"landmarks": [["rock_g", 4, 2], ["rock_gs", 13, 11]],
		"scatter": {"rock_g": 2, "rock_gs": 2, "rock_s": 2},
	},
	"echo_of_abyss": {
		"title": "태초의 심연의 잔향", "chapter": 9, "grid": Vector2i(6, 4),
		"exits": {"w": "echo_of_frost", "e": "the_seam"},
		"screens": Vector2i(1, 1), "base": "K", "accent": "k", "path": "K",
		"border": "K",
		"landmarks": [["tower_a", 3, 2], ["tower_c", 11, 11]],
		"scatter": {"tower_a": 1, "rubble": 4},
	},
	"the_seam": {
		"title": "역전의 이음매", "chapter": 9, "grid": Vector2i(6, 5),
		"exits": {"w": "echo_of_abyss", "e": "throne_of_reversal"},
		"screens": Vector2i(1, 1), "base": "K", "accent": "i", "path": "k",
		"border": "K",
		"landmarks": [["tower_a", 3, 2], ["tower_b", 10, 2], ["tower_c", 17, 2]],
		"scatter": {"tower_a": 2, "tower_b": 2, "rubble": 3},
	},
	"throne_of_reversal": {
		"title": "역전의 옥좌", "chapter": 9, "grid": Vector2i(6, 6), "boss": 9,
		"exits": {"w": "the_seam"},
		"screens": Vector2i(1, 1), "base": "K", "accent": "k", "path": "K",
		"border": "K",
		"landmarks": [["tower_b", 2, 2], ["tower_a", 9, 2], ["tower_c", 17, 2], ["tower_b", 13, 11]],
		"scatter": {"tower_b": 1, "ruin_a": 2, "rubble": 4},
	},
	# --- 10장 근원 ---
	## (감독 2026-09-08) 몬스터도 NPC도 없던 근원 입구/혈맥/기억/핵 4곳을 사용자
	## 지시로 이 한 지역으로 합쳤다(키는 origin_gate 그대로 - 해금·세이브 호환).
	"origin_camp": {
		"title": "근원의 야영지", "chapter": 10, "grid": Vector2i(0, 10),
		"exits": {"e": "origin_gate"},
		"screens": Vector2i(1, 1), "base": "K", "accent": "i", "path": "k",
		"border": "K", "town": true,
		"landmarks": [["house_b", 2, 2], ["house_a", 9, 2], ["tower_a", 15, 2], ["house_c", 15, 11]],
		"scatter": {"rubble": 3, "rock_s": 2},
	},
	"origin_gate": {
		"title": "근원의 길", "chapter": 10, "grid": Vector2i(1, 10),
		"exits": {"w": "origin_camp", "e": "origin_throne"},
		"screens": Vector2i(1, 1), "base": "K", "accent": "i", "path": "k",
		"border": "K",
		"landmarks": [["tower_a", 2, 2], ["ruin_a", 8, 2], ["tower_c", 13, 2], ["tower_b", 17, 2], ["tower_a", 15, 11]],
		"scatter": {"tower_a": 1, "rubble": 3},
	},
	"origin_throne": {"title": "근원의 옥좌", "chapter": 10, "grid": Vector2i(2, 10), "boss": 10, "exits": {"w": "origin_gate"}, "screens": Vector2i(1, 1), "base": "K", "accent": "k", "path": "K", "border": "K"}
}

## 반대 방향. 옆 지역으로 넘어가면 그 반대편 끝에서 나온다.
const OPPOSITE := {"e": "w", "w": "e"}


## 그 방향으로 나갈 수 있는 지역. 없으면 빈 문자열.
static func exit_of(area: String, direction: String) -> String:
	var data: Dictionary = AREAS.get(area, {})
	return str(data.get("exits", {}).get(direction, ""))


static func title_of(area: String) -> String:
	return str(AREAS.get(area, {}).get("title", "알 수 없는 지역"))


static func chapter_of(area: String) -> int:
	return int(AREAS.get(area, {}).get("chapter", 1))


## 그 지역에서 보스가 나오는 장. 0 이면 보스가 없다.
static func boss_chapter_of(area: String) -> int:
	return int(AREAS.get(area, {}).get("boss", 0))


var _ground: TileMapLayer
var _props := Node2D.new()
var _source_ids := {}
var _grid: Array[String] = []
## (INBOX 결함, 2026-09-07 09:20 ②) `_build_walk_grid()`는 전 칸 순회 +
## 소품 순회라 지역당 1회면 충분한데 `walk_waypoints()`가 호출마다
## 새로 만들고 있었다(0.6초 `_quest_mode_tick`마다). `paint(area)`가
## 소품을 다시 깔 때만(=지역 전환·재입장 시) 무효화하고, 그 사이
## `walk_waypoints()` 호출은 같은 격자를 재사용한다.
var _walk_grid: AStarGrid2D = null
var _walk_grid_area := ""
## 보스 추격용 네브메시(NavigationRegion2D). paint() 뒤 보스가 처음
## ensure_nav()를 부를 때 그 지역 소품 충돌체로 한 번 굽는다.
var _nav_region: NavigationRegion2D = null
var _nav_built_for := ""
var _painted_area := ""


func _ready() -> void:
	_ground = TileMapLayer.new()
	_ground.tile_set = _build_tileset()
	add_child(_ground)
	add_child(_props)


func _build_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	for key in GROUND:
		var sheet: String = GROUND[key][0]
		var coord: Vector2i = GROUND[key][1]
		if not _source_ids.has(sheet):
			var source := TileSetAtlasSource.new()
			source.texture = load(SHEETS[sheet])
			source.texture_region_size = Vector2i(TILE, TILE)
			_source_ids[sheet] = tile_set.add_source(source)
		var atlas: TileSetAtlasSource = tile_set.get_source(_source_ids[sheet])
		if not atlas.has_tile(coord):
			atlas.create_tile(coord)
	for key in GROUND_VARIANTS:
		var sheet: String = GROUND[key][0]
		var atlas: TileSetAtlasSource = tile_set.get_source(_source_ids[sheet])
		for coord in GROUND_VARIANTS[key]:
			if not atlas.has_tile(coord):
				atlas.create_tile(coord)
	return tile_set


## 지역의 타일 크기.
static func size_of(area: String) -> Vector2i:
	var data: Dictionary = AREAS.get(area, AREAS["village"])
	var screens: Vector2i = data["screens"]
	return Vector2i(screens.x * SCREEN_COLS, screens.y * SCREEN_ROWS)


## 지역의 픽셀 크기. 카메라 한계와 지역 이동 판정이 이 값을 쓴다.
static func pixel_size_of(area: String) -> Vector2:
	return Vector2(size_of(area)) * TILE


## 길이 지나는 세로 위치. 플레이어는 길 위에서 시작한다.
static func path_row(area: String) -> int:
	return size_of(area).y / 2


## 길이 굽이치는 주기(칸). `_build_grid()`의 길 생성과 `path_row_at()`의
## 앞내다보기가 같은 값을 써야 굽이 타이밍이 어긋나지 않는다.
const PATH_BEND_PERIOD := 4


## 그 열에 실제로 깔린 길(path) 타일의 세로 중심. `_grid`(현재 그려진
## 지역)를 직접 읽으므로 `_build_grid()`가 굽이친 진짜 위치를 돌려준다 -
## `path_row()`(고정된 지역 중앙값)로 직선 목표를 잡으면 굽이가 있는 열에서
## 길 밖 바위 지대를 지나게 된다(INBOX 2026-09-06 20:10 질문 실측).
func path_row_at(area: String, col: int) -> int:
	if _grid.is_empty():
		return path_row(area)
	var data: Dictionary = AREAS.get(area, AREAS["village"])
	var path: String = str(data.get("path", data.get("base", "")))
	var size := size_of(area)
	var x := clampi(col, 0, size.x - 1)
	var rows: Array = []
	for y in mini(size.y, _grid.size()):
		if x < _grid[y].length() and _grid[y][x] == path:
			rows.append(y)
	if rows.is_empty():
		return path_row(area)
	var sum := 0
	for r in rows:
		sum += r
	return int(round(float(sum) / rows.size()))


## `path_row_at()`와 같은 열의 길 타일 중, 이 열이 세로로 두 번 이상 지나는
## 지역(화면이 여러 칸 세로로 이어진 곳)에서 서로 멀리 떨어진 두 지점의
## 평균은 그 사이(둘 다 아닌 바위 지대)로 떨어질 수 있다(marsh_deep 실측
## - 720px 세로 지역에서 같은 열에 길이 위아래 두 번 지나 평균이 길
## 밖으로 나감). `near_row`에 가장 가까운 실제 길 타일 행을 돌려준다.
func nearest_path_row_at(area: String, col: int, near_row: int) -> int:
	if _grid.is_empty():
		return path_row(area)
	var data: Dictionary = AREAS.get(area, AREAS["village"])
	var path: String = str(data.get("path", data.get("base", "")))
	var size := size_of(area)
	var x := clampi(col, 0, size.x - 1)
	var best := -1
	var best_dist := 2147483647
	for y in mini(size.y, _grid.size()):
		if x < _grid[y].length() and _grid[y][x] == path:
			var dist := absi(y - near_row)
			if dist < best_dist:
				best_dist = dist
				best = y
	if best == -1:
		return path_row(area)
	return best


## 씨앗을 지역 이름에서 뽑는다. 같은 지역은 항상 같은 지형이 된다.
static func _seed_of(area: String) -> int:
	var value := 0
	for i in area.length():
		value = (value * 131 + area.unicode_at(i)) % 2147483647
	return value


func _put(line: String, index: int, ch: String) -> String:
	return line.substr(0, index) + ch + line.substr(index + 1)


## 바닥을 만든다. 기본 바닥에 얼룩을 뿌리고 굽은 길을 낸다.
func _build_grid(area: String) -> Array[String]:
	var data: Dictionary = AREAS.get(area, AREAS["village"])
	var size := size_of(area)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_of(area)

	var base: String = data["base"]
	var rows: Array = []
	for y in size.y:
		rows.append(base.repeat(size.x))

	# 얼룩. 바닥이 한 가지뿐이면 넓을수록 단조롭다.
	# 맨해튼 거리로 찍으면 마름모가 되어 인위적으로 보인다. 둥글게 찍고
	# 가장자리는 확률로 흐린다.
	var accent: String = str(data.get("accent", base))
	for i in int(size.x * size.y / 70.0):
		var cx := rng.randi_range(2, size.x - 3)
		var cy := rng.randi_range(2, size.y - 3)
		var rx := rng.randi_range(2, 5)
		var ry := rng.randi_range(1, 3)
		for y in range(maxi(cy - ry - 1, 0), mini(cy + ry + 2, size.y)):
			for x in range(maxi(cx - rx - 1, 0), mini(cx + rx + 2, size.x)):
				var nx := float(x - cx) / float(rx)
				var ny := float(y - cy) / float(ry)
				var dist := nx * nx + ny * ny
				if dist <= 1.0 or (dist <= 1.6 and rng.randf() < 0.45):
					rows[y] = _put(rows[y], x, accent)

	# 물웅덩이.
	if data.has("pond"):
		for i in int(data.get("ponds", 0)):
			var px := rng.randi_range(4, size.x - 6)
			var py := rng.randi_range(3, size.y - 5)
			var rx := rng.randi_range(2, 4)
			var ry := rng.randi_range(1, 3)
			for y in range(maxi(py - ry - 1, 0), mini(py + ry + 2, size.y)):
				for x in range(maxi(px - rx - 1, 0), mini(px + rx + 2, size.x)):
					var dx := float(x - px) / float(rx)
					var dy := float(y - py) / float(ry)
					var d := dx * dx + dy * dy
					# 가장자리를 확률로 들쭉날쭉하게 만든다. 딱 떨어지면 UI 판처럼 보인다.
					if d <= 0.8 or (d <= 1.3 and rng.randf() < 0.55):
						rows[y] = _put(rows[y], x, str(data["pond"]))

	# 길. 가로로 굽이치며 지나간다. 마을은 넓게 낸다.
	var path: String = data.get("path", base)
	var width: int = 4 if data.get("town", false) else 2
	var row := path_row(area)
	for x in size.x:
		if x % PATH_BEND_PERIOD == 0:
			row = clampi(row + rng.randi_range(-2, 2), 4, size.y - 5)
		for y in range(row - width / 2, row - width / 2 + width):
			if y >= 0 and y < size.y:
				rows[y] = _put(rows[y], x, path)

	# 테두리 벽. 동굴과 신전은 밖이 막혀 있어야 한다.
	if data.has("border"):
		var wall: String = data["border"]
		for x in size.x:
			rows[0] = _put(rows[0], x, wall)
			rows[1] = _put(rows[1], x, wall)
			rows[size.y - 1] = _put(rows[size.y - 1], x, wall)
			rows[size.y - 2] = _put(rows[size.y - 2], x, wall)
		for y in size.y:
			rows[y] = _put(rows[y], 0, wall)
			rows[y] = _put(rows[y], size.x - 1, wall)

	var out: Array[String] = []
	for r in rows:
		out.append(r)
	return out


## 지역 배경을 다시 그린다.
func paint(area: String) -> void:
	var data: Dictionary = AREAS.get(area, AREAS["village"])
	var size := size_of(area)
	_grid = _build_grid(area)
	_ground.clear()
	## 무늬 변형 전용 rng. 길·흩뿌리기 rng 와 따로 둬서(시드만 다르게) 이
	## 변형 선택이 소비하는 난수 횟수가 바뀌어도 `paint()` 아래쪽 흩뿌리기
	## 순서(공격 모션·던전 안내 같은 무관한 시험까지 깨뜨린 INBOX 2026-10-20
	## 07:10 #26 실패 원인)에 전혀 영향을 주지 않는다.
	var variant_rng := RandomNumberGenerator.new()
	variant_rng.seed = _seed_of(area) + 13
	for y in size.y:
		var line: String = _grid[y]
		for x in size.x:
			var ch := line[x]
			var cell: Array = GROUND[ch]
			var coord: Vector2i = cell[1]
			if GROUND_VARIANTS.has(ch) and variant_rng.randf() < GROUND_VARIANT_CHANCE:
				var options: Array = GROUND_VARIANTS[ch]
				coord = options[variant_rng.randi_range(0, options.size() - 1)]
			_ground.set_cell(Vector2i(x, y), _source_ids[cell[0]], coord)

	for child in _props.get_children():
		child.queue_free()
	## 소품이 다시 깔리므로 캐시된 경로탐색 격자는 무효화 - 다음
	## `walk_waypoints()` 호출에서 이 지역 격자를 새로 만든다.
	_walk_grid = null
	_walk_grid_area = ""
	_painted_area = area
	_nav_built_for = ""
	var taken := {}
	for entry in data.get("landmarks", []):
		_add_prop(entry[0], int(entry[1]), int(entry[2]), taken)

	# 흩뿌리기. 길 위와 물 위는 피한다.
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_of(area) + 7
	for kind in data.get("scatter", {}):
		## (감독 2026-09-09) "쓸모없는 바위·오브젝트가 너무 많다 - 1/3로" -
		## 지역별 scatter 표는 그대로 두고 여기서 한 번만 나눈다(올림, 최소 1).
		var count := int(ceil(int(data["scatter"][kind]) / 3.0))
		var placed := 0
		var tries := 0
		while placed < count and tries < count * 40:
			tries += 1
			var x := rng.randi_range(1, size.x - 4)
			var y := rng.randi_range(1, size.y - 4)
			if _blocked(area, x, y, kind, taken):
				continue
			_add_prop(kind, x, y, taken)
			placed += 1


## 오브젝트를 놓을 수 없는 자리인지. 길·물·이미 찬 칸을 피한다.
func _blocked(area: String, x: int, y: int, kind: String, taken: Dictionary) -> bool:
	var data: Dictionary = AREAS.get(area, AREAS["village"])
	var span: Vector2i = PROPS[kind][2]
	var path: String = str(data.get("path", ""))
	var pond: String = str(data.get("pond", ""))
	var size := size_of(area)
	for dy in span.y + 1:
		for dx in span.x:
			var tx := x + dx
			var ty := y + dy
			if tx >= size.x or ty >= size.y:
				return true
			if taken.has(Vector2i(tx, ty)):
				return true
			var ch := _grid[ty][tx]
			if ch == path or (pond != "" and ch == pond):
				return true
	return false


## 그 칸이 걸어 다닐 수 있는 바닥인지. 몬스터·상자를 놓을 때 쓴다.
func walkable(area: String, cell: Vector2i) -> bool:
	var size := size_of(area)
	if cell.x < 1 or cell.y < 1 or cell.x >= size.x - 1 or cell.y >= size.y - 1:
		return false
	if _grid.is_empty():
		return true
	var data: Dictionary = AREAS.get(area, AREAS["village"])
	var ch := _grid[cell.y][cell.x]
	if data.has("pond") and ch == str(data["pond"]):
		return false
	if data.has("border") and ch == str(data["border"]):
		return false
	return true


## 랜드마크 건물이 차지하는 칸들. `walkable()`은 이걸 모른다 - 랜드마크 위에
## 스폰하면 충돌체에 밀려 다른 몬스터와 같은 칸으로 겹치는 문제가 있어
## 탑 층 스폰이 이 칸들을 따로 피한다(`_spawn_tower_floor()`).
func landmark_cells(area: String) -> Dictionary:
	var data: Dictionary = AREAS.get(area, AREAS["village"])
	var taken := {}
	for entry in data.get("landmarks", []):
		var prop: Array = PROPS[entry[0]]
		var span: Vector2i = prop[2]
		var cell_x := int(entry[1])
		var cell_y := int(entry[2])
		for dy in span.y:
			for dx in span.x:
				taken[Vector2i(cell_x + dx, cell_y + dy)] = true
	return taken


func _add_prop(prop_name: String, cell_x: int, cell_y: int, taken: Dictionary) -> void:
	var prop: Array = PROPS[prop_name]
	var size: Vector2i = prop[2]
	for dy in size.y:
		for dx in size.x:
			taken[Vector2i(cell_x + dx, cell_y + dy)] = true
	var atlas := AtlasTexture.new()
	atlas.atlas = load(SHEETS[prop[0]])
	atlas.region = Rect2(Vector2(prop[1]) * TILE, Vector2(size) * TILE)
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.centered = false
	sprite.position = Vector2(cell_x, cell_y) * TILE
	_props.add_child(sprite)
	if not prop[3]:
		return
	# 그림 아래쪽 절반만 막아 위쪽을 지나갈 때 발이 걸리지 않게 한다.
	var solid_height: float = maxf(size.y * TILE * 0.5, TILE)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size.x * TILE, solid_height)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	var body := StaticBody2D.new()
	body.name = prop_name
	body.position = sprite.position + Vector2(size.x * TILE, size.y * TILE * 2.0 - solid_height) * 0.5
	body.add_child(collision)
	_props.add_child(body)


func _ensure_walk_grid(area: String) -> void:
	if _walk_grid == null or _walk_grid_area != area:
		_walk_grid = _build_walk_grid(area)
		_walk_grid_area = area


## 픽업(드랍·상자·열쇠)을 놓을 자리 칸이 걷기 격자에서 막혀 있으면(소품
## 충돌체 안, `walkable()`은 소품을 모른다) 가장 가까운 빈 칸 중심으로 옮긴다.
## (감독 2026-09-09) hill 상자 hill_a가 나무 담(96,88) 안 (104,88)에 스폰돼
## 퀘스트모드가 그 상자를 향해 영원히 나무를 밀던 FREEZE의 스폰 쪽 원인.
func nearest_free_pos(area: String, pos: Vector2) -> Vector2:
	_ensure_walk_grid(area)
	var cell := Vector2i((pos / TILE).floor())
	if walkable(area, cell) and not _walk_grid.is_point_solid(cell):
		return pos
	for r in range(1, 4):
		var best := cell
		var best_d := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := cell + Vector2i(dx, dy)
				if not walkable(area, c) or _walk_grid.is_point_solid(c):
					continue
				var d := Vector2(c).distance_squared_to(Vector2(cell))
				if d < best_d:
					best_d = d
					best = c
		if best_d < INF:
			return Vector2(best) * TILE + Vector2(8, 8)
	return pos


## 프로브·디버그 전용(props_near와 같은 목적): auto_walk STALL 진단에
## `walk_waypoints()`가 실제로 쓰는 A* 격자의 solid 판정을 그대로
## 노출한다(§10.7 marsh cell(34,22) 결함 조사). 격자를 새로 만들지 않고
## `walk_waypoints()`와 같은 캐시(_walk_grid)를 공유한다.
func walk_grid_solid_near(area: String, center: Vector2i, radius: int) -> Dictionary:
	_ensure_walk_grid(area)
	var out := {}
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var cell := Vector2i(center.x + dx, center.y + dy)
			out[cell] = _walk_grid.is_point_solid(cell)
	return out


## 프로브·디버그 전용: 그 칸 반경 안 충돌 소품의 이름·칸 좌표(정지 원인
## 진단, 전투·이동 로직에서는 쓰지 않는다).
func props_near(cell: Vector2i, radius: int) -> Array:
	var out: Array = []
	for child in _props.get_children():
		if not (child is StaticBody2D):
			continue
		var body_cell := Vector2i(child.position / TILE)
		if absi(body_cell.x - cell.x) <= radius and absi(body_cell.y - cell.y) <= radius:
			out.append({"name": str(child.name), "cell": body_cell})
	return out


## (INBOX 답, 2026-09-07 08:10) `_auto_avoid_obstacle()`의 직진+옆걸음은
## 계단형으로 어긋나게 붙은 소품 담(hill_ridge 3,7/4,7 등, §10.7)을
## 구조적으로 못 넘는다 - auto_walk(퀘스트모드 고정 목표 이동)는 그 대신
## Godot 내장 AStarGrid2D로 실제 경로를 구해 웨이포인트를 순서대로 밟는다.
## 격자는 실제로 몸을 막는 것만 solid로 찍는다: 가장자리 0번 칸(플레이어·적
## 위치 클램프)과 `_props`의 충돌 소품(`_add_prop()`이 만든 StaticBody2D -
## 이미 있는 그 칸 좌표 개념, cell=(x,y)). 지금(현재 `paint()`된) 지역 전용.
## (감독 2026-09-09) 예전엔 `walkable()`(물·테두리 글자)도 solid로 찍었는데
## 바닥 타일엔 충돌체가 없어 물·테두리 글자 칸도 실제론 지나간다. 테두리
## 글자를 얼룩(accent)·길(path)로도 쓰는 지역(twisted_sanctum, temple 등)은
## 얼룩 칸 전부가 A*에 벽으로 보여 5칸 옆 적을 지도 한 바퀴 돌아 쫓았고,
## 그동안 적은 무덤 소품 아래로 미끄러져 따라와 영원히 못 잡았다(5장 탐침
## twisted_sanctum STALL 실측). 물리와 같은 판정으로 맞춘다.
func _build_walk_grid(area: String) -> AStarGrid2D:
	var size := size_of(area)
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, size)
	grid.cell_size = Vector2(TILE, TILE)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in size.y:
		for x in size.x:
			if x < 1 or y < 1 or x >= size.x - 1 or y >= size.y - 1:
				grid.set_point_solid(Vector2i(x, y))
	for child in _props.get_children():
		if not (child is StaticBody2D) or child.is_queued_for_deletion():
			continue
		var collision: CollisionShape2D = child.get_node("CollisionShape2D")
		var half: Vector2 = collision.shape.size * 0.5
		var top_left: Vector2 = child.position - half
		var bottom_right: Vector2 = child.position + half
		var cx0 := int(floor(top_left.x / TILE))
		var cy0 := int(floor(top_left.y / TILE))
		var cx1 := int(ceil(bottom_right.x / TILE)) - 1
		var cy1 := int(ceil(bottom_right.y / TILE)) - 1
		for gy in range(maxi(cy0, 0), mini(cy1, size.y - 1) + 1):
			for gx in range(maxi(cx0, 0), mini(cx1, size.x - 1) + 1):
				grid.set_point_solid(Vector2i(gx, gy))
	return grid


## (INBOX 결함, 2026-09-07 11:50/12:35) auto_walk가 웨이포인트/목표를 향해
## 무진행으로 계속 밀리면(격자가 모르는 실제 충돌체 등, §10.7) 캐시된
## 격자를 그대로 재사용해 봐야 같은 잘못된 경로가 또 나온다 - main.gd의
## 무진행 감지가 이걸 불러 다음 `walk_waypoints()` 호출에서 새로 짓게 한다.
## 현재 지역의 네브메시를 (없으면) 굽는다. 지역 테두리 안쪽 직사각형에서
## 소품 StaticBody2D들을 뺀 폴리곤. 성공하면 true.
func ensure_nav() -> bool:
	if _painted_area == "":
		return false
	if _nav_built_for == _painted_area and _nav_region != null:
		return true
	if _nav_region == null:
		_nav_region = NavigationRegion2D.new()
		_nav_region.name = "BossNav"
		add_child(_nav_region)
	var poly := NavigationPolygon.new()
	poly.agent_radius = 12.0
	var size := pixel_size_of(_painted_area)
	var inset := float(TILE) + 8.0
	poly.add_outline(PackedVector2Array([
		Vector2(inset, inset), Vector2(size.x - inset, inset),
		Vector2(size.x - inset, size.y - inset), Vector2(inset, size.y - inset)]))
	var src := NavigationMeshSourceGeometryData2D.new()
	NavigationServer2D.parse_source_geometry_data(poly, src, _props)
	NavigationServer2D.bake_from_source_geometry_data(poly, src)
	_nav_region.navigation_polygon = poly
	_nav_built_for = _painted_area
	return true


func invalidate_walk_grid() -> void:
	_walk_grid = null


## auto_walk 목표까지 경로를 칸 중심 좌표(다른 목표 계산과 같은 +TILE/2
## 규칙)의 웨이포인트 배열로 돌려준다. 시작/끝 칸이 solid로 찍혔으면(플레이어가
## 이미 소품 반경 안에 서 있거나 목표가 그런 경우) 그 두 칸만 뚫어 경로가
## 항상 나오게 한다. 경로가 없으면(포위됨) 빈 배열 - 호출부는 기존 직선
## 목표(auto_walk_target)로 자연히 대체한다(player.gd `_auto_walk_tick`).
## 격자는 지역당 캐시(`_walk_grid`, 위 선언부·`paint()` 참고)해 재사용하고,
## 시작/끝 칸을 뚫었던 solid 상태는 호출이 끝나면 원복해 다음 호출(다른
## 좌표)에 새는 구멍을 남기지 않는다.
func walk_waypoints(area: String, from_pos: Vector2, to_pos: Vector2) -> Array[Vector2]:
	var size := size_of(area)
	_ensure_walk_grid(area)
	var grid := _walk_grid
	var from_cell := Vector2i(clampi(int(from_pos.x / TILE), 0, size.x - 1), clampi(int(from_pos.y / TILE), 0, size.y - 1))
	var to_cell := Vector2i(clampi(int(to_pos.x / TILE), 0, size.x - 1), clampi(int(to_pos.y / TILE), 0, size.y - 1))
	var from_was_solid := grid.is_point_solid(from_cell)
	var to_was_solid := grid.is_point_solid(to_cell)
	grid.set_point_solid(from_cell, false)
	grid.set_point_solid(to_cell, false)
	var cells := grid.get_id_path(from_cell, to_cell)
	grid.set_point_solid(from_cell, from_was_solid)
	grid.set_point_solid(to_cell, to_was_solid)
	var out: Array[Vector2] = []
	for cell in cells:
		out.append(Vector2(cell) * TILE + Vector2(TILE, TILE) * 0.5)
	return out
