extends Node
## Musique (une piste par île, fondu enchaîné) et bruitages.
## Sons : Kenney (CC0). Musiques : OpenGameArt (CC0), voir assets/audio/CREDITS.txt.

const SFX_DIR := "res://assets/audio/sfx/%s_%d.ogg"
const SFX := {
	"break_soft": 3, "break_stone": 3, "break_wood": 3,
	"place": 3, "place_wood": 3,
	"step_grass": 5, "step_snow": 5, "step_wood": 5, "step_stone": 5,
	"bloom": 2, "tree": 1,
	"click": 1, "open": 1, "close": 1, "select": 1, "error": 1, "confirm": 1,
	"talk": 2, "book": 1, "coins": 1, "shake": 1, "capsule": 1,
	"jingle_friend": 1, "jingle_common": 1, "jingle_rare": 1, "jingle_legend": 1, "jingle_island": 1,
}
const MUSIC := {
	"prairie": "res://assets/audio/music/prairie.mp3",
	"corail": "res://assets/audio/music/corail.mp3",
	"givree": "res://assets/audio/music/givree.ogg",
	"braise": "res://assets/audio/music/braise.ogg",
}
const POOL_SIZE := 14

var _streams := {}  # nom -> Array[AudioStream]
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_music := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_bus("Music")
	_setup_bus("SFX")
	for name in SFX:
		var list: Array[AudioStream] = []
		for i in int(SFX[name]):
			var s := load(SFX_DIR % [name, i]) as AudioStream
			if s:
				list.append(s)
		_streams[name] = list
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	apply_volumes()


func _setup_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


func apply_volumes() -> void:
	_set_bus_volume("Music", Game.music_volume)
	_set_bus_volume("SFX", Game.sfx_volume)


func _set_bus_volume(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, v <= 0.001)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


## Joue un bruitage (variante aléatoire, légère variation de hauteur).
func play(sfx: String, volume_db := 0.0, pitch_var := 0.08, pitch := 1.0) -> void:
	var list: Array = _streams.get(sfx, [])
	if list.is_empty():
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = list.pick_random()
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	p.play()


func play_music(island_id: String) -> void:
	if island_id == _current_music or not MUSIC.has(island_id):
		return
	_current_music = island_id
	var stream := load(MUSIC[island_id]) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	# Fondu enchaîné : B devient la nouvelle piste.
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	_music_a.stream = stream
	_music_a.volume_db = -40.0
	_music_a.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_music_a, "volume_db", -8.0, 2.0)
	tw.tween_property(_music_b, "volume_db", -60.0, 1.5)
	tw.chain().tween_callback(_music_b.stop)
