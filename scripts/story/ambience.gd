class_name Ambience
extends Node
## Ambiance sonore synthétisée en temps réel (aucun fichier audio) :
## vagues (bruit brun modulé par la houle), vent (bruit filtré qui siffle)
## et craquements de bois (frottements excitant des résonateurs).
## Les niveaux se règlent avec `fade_to()`.

const RATE := 22050.0

var waves := 0.0
var wind := 0.0
var creaks := 0.0  # 0 = aucun craquement, 1 = fréquents
var rain := 0.0  # pluie (bruissement + gouttes)
var _r_lp := 0.0
var _r_lp2 := 0.0
var _thunder := 0.0
var _th_brown := 0.0

var _player: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _seed := 12345
var _buf := PackedVector2Array()
# Vagues
var _brown := 0.0
var _hiss := 0.0
var _ph_a := 0.0
var _ph_b := 0.37
# Vent
var _w_low := 0.0
var _w_band := 0.0
var _w_freq := 600.0
var _w_gust := 0.5
var _w_gust_goal := 0.5
var _w_t := 0.0
# Craquements
var _ck_left := -1.0  # durée restante du craquement (s)
var _ck_len := 1.0
var _ck_f0 := 30.0
var _ck_f1 := 60.0
var _ck_ph := 0.0
var _ck_amp := 1.0
var _ck_pan := 0.5
var _ck_wait := 2.0
var _r1 := [0.0, 0.0]
var _r2 := [0.0, 0.0]
var _r1c := Vector2.ZERO  # (2 r cos w, r²)
var _r2c := Vector2.ZERO


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.25
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.bus = "SFX"
	_player.volume_db = -4.0
	add_child(_player)
	_player.play()
	_pb = _player.get_stream_playback()
	_r1c = _resonator(310.0, 0.9965)
	_r2c = _resonator(870.0, 0.994)


## Fait évoluer les niveaux en douceur.
func fade_to(w_waves: float, w_wind: float, w_creaks: float, duration: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "waves", w_waves, duration)
	tw.tween_property(self, "wind", w_wind, duration)
	tw.tween_property(self, "creaks", w_creaks, duration)


## Coup de tonnerre (grondement grave qui s'éteint en quelques secondes).
func thunder(strength := 1.0) -> void:
	_thunder = maxf(_thunder, strength)


## Coupe tout puis se supprime.
func fade_out_and_free(duration: float) -> void:
	fade_to(0.0, 0.0, 0.0, duration)
	get_tree().create_timer(duration + 0.3).timeout.connect(queue_free)


static func _resonator(freq: float, r: float) -> Vector2:
	return Vector2(2.0 * r * cos(TAU * freq / RATE), r * r)


func _noise() -> float:
	_seed = (_seed * 1103515245 + 12345) & 0x7fffffff
	return float(_seed) / 1073741823.5 - 1.0


func _process(delta: float) -> void:
	if _pb == null:
		return
	var n := _pb.get_frames_available()
	if n <= 0:
		return
	_pb.push_buffer(render(n, delta))


## Synthétise `n` échantillons stéréo (`delta` : temps écoulé depuis l'appel précédent).
func render(n: int, delta: float) -> PackedVector2Array:
	# Paramètres lents, mis à jour une fois par bloc.
	_w_t += delta
	if randf() < delta * 0.4:
		_w_gust_goal = randf_range(0.25, 1.0)
	_w_gust = lerpf(_w_gust, _w_gust_goal, minf(1.0, delta * 0.6))
	_w_freq = 520.0 + sin(_w_t * 0.31) * 160.0 + sin(_w_t * 0.83) * 70.0 + _w_gust * 220.0
	var wf := 2.0 * sin(PI * _w_freq / RATE)
	var wq := 0.18
	var wind_amp := wind * (0.25 + 0.75 * _w_gust)
	_ck_wait -= delta
	if creaks > 0.01 and _ck_left <= -0.4 and _ck_wait <= 0.0:
		_ck_len = randf_range(0.45, 1.3)
		_ck_left = _ck_len
		_ck_f0 = randf_range(14.0, 30.0)
		_ck_f1 = _ck_f0 * randf_range(1.4, 2.6)
		_ck_amp = randf_range(0.5, 1.0) * creaks
		_ck_pan = randf_range(0.2, 0.8)
		_ck_wait = _ck_len + randf_range(1.5, 6.0) / maxf(creaks, 0.15)
		_r1c = _resonator(randf_range(260.0, 380.0), 0.9965)
		_r2c = _resonator(randf_range(700.0, 1050.0), 0.994)

	_buf.resize(n)
	var inv := 1.0 / RATE
	for i in n:
		var white := _noise()
		# --- Vagues : deux houles décalées, bruit brun + écume plus claire.
		_ph_a = fmod(_ph_a + inv / 7.3, 1.0)
		_ph_b = fmod(_ph_b + inv / 9.7, 1.0)
		var sa := sin(PI * _ph_a)
		var sb := sin(PI * _ph_b)
		var swell := maxf(sa * sa * sa, sb * sb * sb * 0.8)
		_brown = (_brown + 0.02 * white) / 1.02
		_hiss += (white - _hiss) * (0.05 + 0.25 * swell)
		var wave := (_brown * 3.2 * (0.25 + 0.75 * swell) + _hiss * 0.22 * swell * swell) * waves
		# --- Vent : filtre résonant (sifflement) sur du bruit blanc.
		var high := white - _w_low - wq * _w_band
		_w_band += wf * high
		_w_low += wf * _w_band
		var wnd := _w_band * 0.33 * wind_amp
		# --- Craquement : impulsions de frottement à fréquence glissante.
		var ck := 0.0
		if _ck_left > -0.4:  # (laisse résonner la fin)
			var p := clampf(1.0 - _ck_left / _ck_len, 0.0, 1.0)
			var f := lerpf(_ck_f0, _ck_f1, p) * (1.0 + 0.15 * sin(p * 37.0))
			_ck_ph += f * inv
			var x := 0.0
			if _ck_ph >= 1.0 and _ck_left > 0.0:
				_ck_ph -= 1.0
				x = (0.6 + 0.4 * absf(white)) * sin(PI * p)
			var y1: float = _r1c.x * _r1[0] - _r1c.y * _r1[1] + x
			_r1[1] = _r1[0]
			_r1[0] = y1
			var y2: float = _r2c.x * _r2[0] - _r2c.y * _r2[1] + x
			_r2[1] = _r2[0]
			_r2[0] = y2
			ck = (y1 * 0.07 + y2 * 0.035) * _ck_amp
			_ck_left -= inv
		# --- Pluie : bruit blanc adouci (bruissement) + grondement de l'orage.
		var rn := 0.0
		if rain > 0.001:
			_r_lp += (white - _r_lp) * 0.45
			_r_lp2 += (_r_lp - _r_lp2) * 0.08
			rn = (_r_lp - _r_lp2) * 0.55 * rain
		if _thunder > 0.001:
			_th_brown = (_th_brown + 0.02 * white) / 1.02
			rn += _th_brown * 6.0 * _thunder
			_thunder *= 0.99996
		var mono := wave + wnd + rn
		_buf[i] = Vector2(clampf(mono + ck * (1.0 - _ck_pan), -1.0, 1.0), clampf(mono + ck * _ck_pan, -1.0, 1.0))
	return _buf
