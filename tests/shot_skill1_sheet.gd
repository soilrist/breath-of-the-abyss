extends Node
## INBOX 결함(감독, 2026-09-06 00:55) ③: skill1 이펙트 8종을 4배 확대해
## 한 장의 시트로 모아 저장한다 — 검사 통과만 믿지 않고 눈으로 판 잔존을
## 직접 확인하기 위함이다. 배경을 회색으로 깔아 흰 원판/자홍 판이 있으면
## 바로 도드라져 보이게 한다.
## 참고(2026-09-06 INBOX 지시): 이 스크립트는 Image.load_from_file로 원본
## PNG를 직접 읽어 .godot/imported 캐시(ResourceLoader)를 거치지 않으므로
## --import 여부와 무관하게 항상 최신 그림을 찍는다. 그래도 shot_skill1_fx.gd
## (게임 실행 경로, ResourceLoader 경유)와 비교할 때는 먼저
## `godot --headless --path . --import`를 돌려 두 결과가 같은 그림을
## 보고 있는지 맞춰라.

const SKILL_IDS := ["shield_charge", "warcry", "undying", "ice_spear", "mana_burst", "shuriken", "stealth", "swift_step"]
const CELL := 256
const COLS := 4

func _ready() -> void:
	var rows := int(ceil(float(SKILL_IDS.size()) / COLS))
	var sheet := Image.create(CELL * COLS, CELL * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.4, 0.4, 0.4, 1.0))

	for i in SKILL_IDS.size():
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/fx/skill1/%s.png" % SKILL_IDS[i]))
		img.resize(CELL, CELL, Image.INTERPOLATE_NEAREST)
		var col := i % COLS
		var row := i / COLS
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(col * CELL, row * CELL))

	sheet.save_png("user://skill1_sheet.png")
	print("SAVED ", ProjectSettings.globalize_path("user://skill1_sheet.png"))
	get_tree().quit()
