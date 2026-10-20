extends Node
## 배경음 하나와 효과음 몇 개를 돌리는 자동 로드.
## 지역이 바뀌거나 보스가 나타나면 곡을 바꾼다.

const MUSIC := {
	"title": "res://assets/audio/music/title.ogg",
	"village": "res://assets/audio/music/village.ogg",
	"forest": "res://assets/audio/music/forest.ogg",
	"dungeon": "res://assets/audio/music/dungeon.ogg",
	"harbor": "res://assets/audio/music/harbor.ogg",
	"ruins": "res://assets/audio/music/ruins.ogg",
	"citadel": "res://assets/audio/music/citadel.ogg",
	"boss": "res://assets/audio/music/boss.ogg",
	"ending": "res://assets/audio/music/ending.ogg",
	"hill": "res://assets/audio/music/hill.ogg",
	"marsh": "res://assets/audio/music/marsh.ogg",
	"snow": "res://assets/audio/music/snow.ogg",
	"ash": "res://assets/audio/music/ash.ogg",
	"sea": "res://assets/audio/music/sea.ogg",
	"temple": "res://assets/audio/music/temple.ogg",
	"corridor": "res://assets/audio/music/corridor.ogg",
	"tower": "res://assets/audio/music/tower.ogg",
	"final": "res://assets/audio/music/final.ogg",
}

## 지역 65곳 중 대부분에 곡이 없어 제목 곡이 그대로 이어졌다("음악이랑 효과음도
## 넣어야할것같아", 2026-09-08 감독). 마을은 village, 아래 지역은 지정 곡,
## 나머지는 장(章)별 곡을 쓴다.
const AREA_MUSIC := {
	"forest_w": "forest", "glade": "forest", "cave_deep": "dungeon", "shore": "harbor",
	"marsh_deep": "marsh", "citadel_gate": "citadel",
}
const CHAPTER_MUSIC := {
	1: "hill", 2: "ruins", 3: "snow", 4: "ash", 5: "ruins",
	6: "sea", 7: "temple", 8: "corridor", 9: "tower", 10: "final",
}

const SFX := {
	"attack": "res://assets/audio/sfx/attack.wav",
	"skill": "res://assets/audio/sfx/skill.wav",
	"dodge": "res://assets/audio/sfx/dodge.wav",
	"hit": "res://assets/audio/sfx/hit.wav",
	"hurt": "res://assets/audio/sfx/hurt.wav",
	"defeat": "res://assets/audio/sfx/defeat.wav",
	"potion": "res://assets/audio/sfx/potion.wav",
	"coin": "res://assets/audio/sfx/coin.wav",
	"pickup": "res://assets/audio/sfx/pickup.wav",
	"levelup": "res://assets/audio/sfx/levelup.wav",
	"gameover": "res://assets/audio/sfx/gameover.wav",
	"boss": "res://assets/audio/sfx/boss.wav",
	"accept": "res://assets/audio/sfx/accept.wav",
	"cancel": "res://assets/audio/sfx/cancel.wav",
}

const SFX_VOICES := 6
const MUSIC_DB := -12.0
# 효과음 원본이 최대 -10dB 라 폰 스피커에선 묻혔다. 0dB 로 올린다.
const SFX_DB := 0.0
const MUTE_DB := -80.0

var current_track := ""
var music_muted := false
var sfx_muted := false
var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0


func _ready() -> void:
	# 일시정지 중에도 메뉴 효과음이 나야 한다.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	_music.bus = "Master"
	add_child(_music)
	_music.finished.connect(_replay_music)
	for i in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = SFX_DB
		add_child(voice)
		_voices.append(voice)


## 음량 조절 수단이 없었다("음량 조절 수단이 없다" - HANDOFF.md).
## 슬라이더 대신 켜기/끄기만 두어 터치 한 번으로 되게 한다.
func set_music_muted(muted: bool) -> void:
	music_muted = muted
	_music.volume_db = MUTE_DB if muted else MUSIC_DB


func set_sfx_muted(muted: bool) -> void:
	sfx_muted = muted
	var db := MUTE_DB if muted else SFX_DB
	for voice in _voices:
		voice.volume_db = db


## 같은 곡이면 다시 틀지 않는다. 지역을 오갈 때 음악이 끊기면 조잡해 보인다.
func play_music(track: String) -> void:
	track = track_for(track)
	if track == current_track or not MUSIC.has(track):
		return
	current_track = track
	_music.stream = load(MUSIC[track])
	_music.play()


## 지역 이름을 곡 이름으로 바꾼다. 모르는 지역은 "" 를 돌려준다.
func track_for(area: String) -> String:
	if MUSIC.has(area):
		return area
	if World.is_town(area):
		return "village"
	if AREA_MUSIC.has(area):
		return AREA_MUSIC[area]
	if World.AREAS.has(area):
		return CHAPTER_MUSIC.get(World.chapter_of(area), "")
	return ""


func stop_music() -> void:
	current_track = ""
	_music.stop()


## 타격류(attack/hit/hurt)는 같은 소리가 연타로 반복되면 기계적으로 들린다 -
## 호출자가 pitch 를 직접 안 지정했을 때만 ±0.08 랜덤을 섞는다.
const RANDOM_PITCH_SOUNDS := ["attack", "hit", "hurt"]
const RANDOM_PITCH_RANGE := 0.08

func play_sfx(sound: String, pitch := 1.0) -> void:
	if not SFX.has(sound):
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % SFX_VOICES
	voice.stream = load(SFX[sound])
	var actual_pitch := pitch
	if pitch == 1.0 and sound in RANDOM_PITCH_SOUNDS:
		actual_pitch = pitch + randf_range(-RANDOM_PITCH_RANGE, RANDOM_PITCH_RANGE)
	voice.pitch_scale = actual_pitch
	voice.play()


## ogg 는 가져오기 설정에 따라 반복이 꺼져 있을 수 있다. 끝나면 직접 다시 튼다.
func _replay_music() -> void:
	if current_track != "":
		_music.play()
