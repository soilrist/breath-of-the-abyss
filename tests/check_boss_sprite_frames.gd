extends Node
## 몬스터 시트가 hframes 대로 잘리는지: 각 프레임의 좌우 끝 열에 불투명
## 픽셀이 있으면 프레임 폭이 틀린 것(boss_captain.png 96×48을 48로 잘라
## 흑기사단장·감독관이 반쪽만 그려진 결함, 2026-09-08).
func _ready() -> void:
	var consts: Dictionary = load("res://scripts/enemy.gd").get_script_constant_map()
	var defaults: Dictionary = consts["MOB_DEFAULTS"]
	var bad: Array[String] = []
	var checked := 0
	for id in consts["KINDS"]:
		var kind: Dictionary = defaults.merged(consts["KINDS"][id], true)
		# 16px 잡몹은 칸을 꽉 채우므로 여백이 있는 보스 시트만 본다.
		if not str(kind["texture"]).get_file().begins_with("boss_"):
			continue
		var tex: Texture2D = load(kind["texture"])
		var img: Image = tex.get_image()
		var hf := int(kind["hframes"])
		var fw := img.get_width() / hf
		checked += 1
		if img.get_width() % hf != 0:
			bad.append("%s width %d %% hframes %d" % [id, img.get_width(), hf])
			continue
		for f in hf:
			for x in [f * fw, f * fw + fw - 1]:
				for y in img.get_height():
					if img.get_pixel(x, y).a > 0.0:
						bad.append("%s frame %d edge col %d opaque" % [id, f, x])
						break
	var ok := bad.is_empty()
	print("checked=%d bad=%s" % [checked, bad])
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
