extends Sprite2D
class_name SkillFx
## 스킬마다 다른 이펙트를 재생하는 범용 노드. 텍스처와 프레임 수만 넣으면 된다.
## 참격 궤적 하나로 스킬 네 개를 전부 덮던 것을 스킬별로 나눈다.

## 광역 스킬(메테오·연쇄번개 등)이 같은 화면에 여러 장 겹치면 화면을 다 덮어
## 손맛이 아니라 눈 피로가 된다 - 동시에 이 숫자를 넘으면 새로 뜨는 이펙트는
## 크기를 상한값으로 깎는다(이미 떠 있는 것은 그대로).
const OVERLAP_CAP_COUNT := 3
const OVERLAP_MAX_SIZE_UP := 1.6
## 팝인·페이드 각각 최대 길이. 이펙트 총 길이가 더 짧으면 절반씩 나눠 쓴다.
const POP_FADE_TIME := 0.1

static var _active_count := 0

var frames := 4
var frame_time := 0.05
var _tick := 0.0


## instant 면 팝인·페이드 트윈 없이 처음부터 target_size·전체 불투명으로
## 나타났다가 frame_count*time_per_frame 뒤(_process) 페이드 없이 바로 사라진다.
func play(path: String, frame_count: int, time_per_frame: float, tint: Color, size_up := 1.0, instant := false) -> void:
	texture = load(path)
	hframes = frame_count
	frame = 0
	frames = frame_count
	frame_time = time_per_frame
	z_index = 10

	_active_count += 1
	var target_size := size_up
	if _active_count > OVERLAP_CAP_COUNT:
		target_size = minf(target_size, OVERLAP_MAX_SIZE_UP)

	if instant:
		scale = Vector2.ONE * target_size
		modulate = tint
		return

	var total_time := frame_count * time_per_frame
	var pop_time := minf(POP_FADE_TIME, total_time * 0.4)
	var fade_time := minf(POP_FADE_TIME, total_time * 0.4)

	scale = Vector2.ZERO
	modulate = Color(tint.r, tint.g, tint.b, 0.0)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * target_size, pop_time)
	tween.parallel().tween_property(self, "modulate:a", tint.a, pop_time)
	var hold_time := total_time - pop_time - fade_time
	if hold_time > 0.0:
		tween.tween_interval(hold_time)
	tween.tween_property(self, "modulate:a", 0.0, fade_time)


func _exit_tree() -> void:
	_active_count -= 1


func _process(delta: float) -> void:
	_tick += delta
	var step := int(_tick / frame_time)
	if step >= frames:
		queue_free()
		return
	frame = step
