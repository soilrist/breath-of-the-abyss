extends Node
## 지역표(AREA_SPAWNS)의 모든 지역이 곡으로 풀리고 파일이 실제로 로드되는지.
## 65개 지역 중 대부분에 곡이 없어 제목 곡이 이어지던 결함(2026-09-08).
func _ready() -> void:
	var areas: Dictionary = load("res://scripts/main.gd").get_script_constant_map()["AREA_SPAWNS"]
	var bad: Array[String] = []
	for area in areas:
		if Audio.track_for(area) == "":
			bad.append("%s: 곡 없음" % area)
	for key in Audio.MUSIC:
		if load(Audio.MUSIC[key]) == null:
			bad.append("%s: 파일 못 읽음 %s" % [key, Audio.MUSIC[key]])
	# 마을은 village, 갈래 지역은 본 지역 곡, 5장 이후는 장별 곡.
	var ok := bad.is_empty() and Audio.track_for("lantern_village") == "village" \
		and Audio.track_for("marsh_deep") == "marsh" and Audio.track_for("hill_ridge") == "hill" \
		and Audio.track_for("silent_archive") == "corridor" and Audio.track_for("boss") == "boss"
	# 같은 곡을 쓰는 지역으로 넘어가도 곡을 다시 틀지 않는다.
	Audio.play_music("hill")
	Audio.play_music("hill_ridge")
	ok = ok and Audio.current_track == "hill"
	print("check_map_music: areas=%d music=%d bad=%s" % [areas.size(), Audio.MUSIC.size(), bad])
	print("RESULT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
