extends Control
## 대륙 이동도. 챕터별 탭으로 나눠 텍스트 목록을 보여주고, 골라서 바로
## 이동한다. 보스를 잡고 마을까지 걸어서 되돌아가는 지루함을 없애기
## 위한 화면이다. 좌표 그래프가 아니라 순서대로 나열한 목록으로
## 보여준다 - 사용자 요청("맵은 텍스트 리스트로 무조건").
## 챕터가 늘어나며 한 목록에 다 넣기 어려워져 좌우 키로 챕터 탭을
## 넘기게 했다 - 사용자 요청("1챕터는 1장 맵만 2챕터 2장맵 이런식으로
## 탭을 만들어줘야지").

signal travel_requested(map_name: String)

## 화면에 한 번에 보여줄 줄 수. 인벤토리 목록과 같은 스크롤 창 방식.
## (INBOX 04:35 HUD 전수 점검) 6이면 최악 데이터(8곳짜리 챕터, "더보기"
## 줄까지 포함해 10줄)에서 Info 라벨이 StatBar 영역까지 넘쳤다 - 4로
## 줄여 최악 8줄(제목+탭+구분선+4줄+더보기)로 맞춤.
const WINDOW := 4

var cursor := 0
var chapter := 1
var _order: Array[String] = []
var _chapter_lists: Dictionary = {}
@onready var atlas: Control = $Atlas
@onready var mobile_controls: Control = $"../../MobileControls"


## 목록에 나열할 전체 순서. 지역 정의(world.gd)에 적힌 순서를 그대로
## 쓴다. 심연의 탑("tower")은 별도 진입 화면(TowerSelect)이 있지만,
## 고르는 창구 자체는 이 지도다(_travel_to()에서 "tower"만 예외 처리해
## TowerSelect를 연다). 장 탭·목록에는 넣지 않고 오른쪽 대륙 개관도의
## 탑 표식(world_atlas.gd TOWER_RECT)을 눌러 바로 간다 - 감독 지시
## (2026-09-10 "10장 뒤에 넣지 말고 바로 눌러서 갈 수 있게"). try_travel_tower().
func order() -> Array[String]:
	if _order.is_empty():
		for key in World.AREAS:
			_order.append(str(key))
	return _order


## 장별 목록. 등장 순서를 그대로 유지하고 탑은 뺀다(개관도 표식 전용).
func order_for_chapter(ch: int) -> Array[String]:
	if not _chapter_lists.has(ch):
		var list: Array[String] = []
		for area in order():
			if area != "tower" and World.chapter_of(area) == ch:
				list.append(area)
		_chapter_lists[ch] = list
	return _chapter_lists[ch]


## 등장하는 최대 챕터 번호.
func max_chapter() -> int:
	var top := 1
	for area in order():
		top = maxi(top, World.chapter_of(area))
	return top


## 열 때마다 현재 위치가 속한 챕터·줄에 커서를 맞춘다.
func focus_current() -> void:
	chapter = World.chapter_of(GameState.current_map)
	cursor = maxi(order_for_chapter(chapter).find(GameState.current_map), 0)
	_refresh()


func move_cursor(step: int) -> void:
	var list := order_for_chapter(chapter)
	if list.is_empty():
		return
	cursor = wrapi(cursor + step, 0, list.size())
	_refresh()


## 좌우로 챕터 탭을 넘긴다. 커서는 새 챕터의 맨 위로 되돌린다.
func change_chapter(step: int) -> void:
	chapter = wrapi(chapter - 1 + step, 0, max_chapter()) + 1
	cursor = 0
	_refresh()


func selected_map() -> String:
	var list := order_for_chapter(chapter)
	if list.is_empty():
		return ""
	return list[cursor]


func can_travel() -> bool:
	var target := selected_map()
	return target != "" and GameState.unlocked_maps.has(target) and target != GameState.current_map


## 커서가 가리키는 곳으로 이동한다. 못 가면 이유를 돌려준다.
func try_travel() -> String:
	var target := selected_map()
	if target == "":
		return "이 챕터에는 지역이 없다."
	if not GameState.unlocked_maps.has(target):
		return "아직 가 본 적 없는 곳이다."
	if target == GameState.current_map:
		return "이미 이곳에 있다."
	# (감독 2026-09-10) 지도 이동은 이동주문서를 쓴다.
	if GameState.scrolls <= 0:
		return "이동주문서가 없다. 상점에서 살 수 있다."
	travel_requested.emit(target)
	return ""


## 개관도의 탑 표식을 눌렀다(또는 T키). 탑 입장은 별도 난이도 선택 화면이라
## 이동주문서를 쓰지 않는다. 못 가면 이유를 돌려준다.
func try_travel_tower() -> String:
	if not GameState.unlocked_maps.has("tower"):
		return "심연의 탑은 아직 열리지 않았다."
	if GameState.current_map == "tower":
		return "이미 이곳에 있다."
	travel_requested.emit("tower")
	return ""


func _refresh() -> void:
	var list := order_for_chapter(chapter)
	var count := list.size()
	cursor = clampi(cursor, 0, maxi(count - 1, 0))
	var start := clampi(cursor - WINDOW / 2, 0, maxi(count - WINDOW, 0))
	var lines: Array[String] = []
	for pos in range(start, mini(start + WINDOW, count)):
		var area: String = list[pos]
		var known: bool = GameState.unlocked_maps.has(area)
		var marker := "▶" if pos == cursor else "   "
		var name := World.title_of(area) if known else "???"
		var boss_mark := " ★" if World.boss_chapter_of(area) > 0 and known else ""
		var tag := ""
		if area == GameState.current_map:
			tag = " [현재 위치]"
		elif not known:
			tag = " [미개척]"
		lines.append("%s %s%s%s" % [marker, name, boss_mark, tag])
	var more := "\n   … %d곳 더" % (count - start - WINDOW) if count > start + WINDOW else ""
	var body := "\n".join(lines) if count > 0 else "   (이 챕터에는 지역이 없다)"
	var tabs := "≪ %d장 / %d장 ≫" % [chapter, max_chapter()]
	$Info.text = "대륙 이동도  (이동주문서 %d장)\n%s\n──────────\n%s%s" % [GameState.scrolls, tabs, body, more]

	var target := selected_map()
	var target_known: bool = target != "" and GameState.unlocked_maps.has(target)
	## 모바일(가상 조이스틱 표시 중)에는 데스크톱 키(Enter/J, ◀▶) 대신
	## 실제 조작(목록 탭·탭 줄 좌우 탭)을 가리키는 문구를 보여준다
	## - 49f572a(가이드 창)와 같은 분기.
	var mobile: bool = is_instance_valid(mobile_controls) and mobile_controls.visible
	if target == "":
		$Hint.text = "탭 줄 좌우 탭으로 챕터 전환" if mobile else "◀▶ 챕터 전환"
	elif not target_known:
		$Hint.text = "가 본 적 없는 지역 · 탭 줄 좌우로 챕터 전환" if mobile else "가 본 적 없는 지역 · ◀▶ 챕터 전환"
	elif target == GameState.current_map:
		$Hint.text = "현재 위치 · 탭 줄 좌우로 챕터 전환" if mobile else "현재 위치 · ◀▶ 챕터 전환"
	else:
		$Hint.text = "다시 탭해 이동 · 탭 줄 좌우로 챕터 전환" if mobile else "Enter/J 이동 · ◀▶ 챕터 전환"
	## (INBOX 지시, 2026-09-07 14:00, #157) 창 맨 아래 도움줄(HUD/WorldMap/Help,
	## Graph의 형제 노드)은 위 $Hint와 달리 정적 텍스트라 모바일에서도
	## 키보드 안내가 그대로 나갔다 - 같은 mobile 분기로 맞춘다.
	var help: Label = get_node_or_null("../Help")
	if is_instance_valid(help):
		help.text = "▲▼ 선택 · 줄 탭/이동 버튼 · ✕ 닫기" if mobile else "↑↓ 선택   Enter/J 이동   T 탑   M/Esc 닫기"
	if is_instance_valid(atlas):
		atlas.set_location(chapter, selected_map())
