extends Node
## INBOX 결함(감독, 2026-09-06 09:50) — Auto/Quest 버튼이 SkillBar
## Skill3/Skill4/5 아이콘과 겹쳤다("가방" 버튼과 같은 자리에 "캐릭" 버튼을
## 새로 달면서 재배치). set_modal_mode()가 받는 모든 모드 문자열에서, 실제로
## 화면에 보이는(is_visible_in_tree()) MobileControls 버튼 전부가 서로,
## SkillBar 6칸, StatBar, Area, Message와 rect.grow(4)로 무교집합인지 확인한다.
## HUD/Area·Message·SkillBar의 가시성은 main.gd:_sync_modal_hud_visibility()가
## *_open 플래그로 매 physics_process마다 정하므로, 모드마다 대응하는 플래그를
## 직접 세팅해 실제 조건을 그대로 재현한다.

const MODE_FLAG := {
	"character": "character_open", "dialogue": "dialogue_open", "forge": "forge_open",
	"guide": "guide_open", "inventory": "menu_open", "map": "world_map_open",
	"pause": "pause_open", "perk": "perk_open", "quest": "quest_open",
	"shop": "shop_open", "skills": "skills_open", "storage": "storage_open",
	"tower_select": "tower_select_open",
}
const ALL_FLAGS := ["character_open", "dialogue_open", "forge_open", "guide_open",
	"menu_open", "world_map_open", "pause_open", "perk_open", "quest_open",
	"shop_open", "skills_open", "storage_open", "tower_select_open"]
const MODES := ["", "character", "dialogue", "forge", "guide", "inventory", "map",
	"pause", "perk", "quest", "shop", "skills", "storage", "tower_select"]

var _ok := true

func _check(label: String, cond: bool) -> bool:
	if cond:
		print("PASS: ", label)
	else:
		print("FAIL: ", label)
	return cond

func _visible_leaf_buttons(controls: Node) -> Array:
	var out := []
	for child in controls.get_children():
		# SkillTouch0~5, Buy1~5는 StyleBoxEmpty(투명)로 SkillBar 칸/상점 목록 줄
		# 위에 그대로 얹혀 탭을 받는 히트박스일 뿐, 화면에 그려지는 버튼이
		# 아니다 - 자기 자리(또는 옆 줄)에 맞닿는 게 정상이므로 겹침 검사
		# 대상에서 뺀다.
		if child is Button and child.is_visible_in_tree() \
				and not child.name.begins_with("SkillTouch") \
				and not child.name.begins_with("Buy"):
			out.append(child)
	return out

func _fixed_rects(main: Node) -> Dictionary:
	var out := {}
	var names := ["HUD/StatBar", "HUD/Area", "HUD/Message"]
	for n in names:
		var node: Control = main.get_node(n)
		if node.is_visible_in_tree():
			out[n] = Rect2(node.global_position, node.size)
	var bar: Control = main.get_node("HUD/SkillBar")
	for i in range(6):
		var slot: Control = bar.get_node_or_null("Skill%d" % i)
		if slot != null and slot.is_visible_in_tree():
			out["HUD/SkillBar/Skill%d" % i] = Rect2(slot.global_position, slot.size)
	return out

func _check_mode(main: Node, controls: Node, mode: String) -> void:
	for f in ALL_FLAGS:
		main.set(f, false)
	if MODE_FLAG.has(mode):
		main.set(MODE_FLAG[mode], true)
	controls.set_modal_mode(mode)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var buttons := _visible_leaf_buttons(controls)
	var fixed := _fixed_rects(main)

	for i in range(buttons.size()):
		for j in range(i + 1, buttons.size()):
			var a: Button = buttons[i]
			var b: Button = buttons[j]
			var ra := Rect2(a.global_position, a.size).grow(4)
			var rb := Rect2(b.global_position, b.size)
			_ok = _check("모드 '%s': %s vs %s 안 겹침" % [mode, a.name, b.name],
				not ra.intersects(rb)) and _ok

	for b in buttons:
		var rb := Rect2(b.global_position, b.size).grow(4)
		for key in fixed:
			_ok = _check("모드 '%s': %s vs %s 안 겹침" % [mode, b.name, key],
				not rb.intersects(fixed[key])) and _ok

	# Joystick은 Control이라 _visible_leaf_buttons(Button만 취급)에서 빠진다.
	# INBOX 11:40: StatBar와 맞닿는 결함이 버튼 검사망을 피해 갔다.
	var joystick: Control = controls.get_node("Joystick")
	if joystick.is_visible_in_tree():
		var rj := Rect2(joystick.global_position, joystick.size).grow(4)
		for key in fixed:
			_ok = _check("모드 '%s': Joystick vs %s 안 겹침" % [mode, key],
				not rj.intersects(fixed[key])) and _ok

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		main._advance_dialogue()
		await get_tree().process_frame

	GameState.reset()
	GameState.job = "mage"
	GameState.second_job = "elementalist"
	GameState.level = 40

	var controls: Node = main.get_node("HUD/MobileControls")

	for mode in MODES:
		await _check_mode(main, controls, mode)

	print("RESULT ", "PASS" if _ok else "FAIL")
	get_tree().quit()
