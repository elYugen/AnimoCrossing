class_name SkyCycle
extends Node
## Cycle jour / nuit et météo. Une journée de jeu dure 24 minutes réelles
## (une heure par minute). Le soleil se lève vers 6 h et se couche vers 20 h ;
## la nuit, une lune bleutée éclaire faiblement l'île. La météo change toutes
## les quelques heures : beau temps, nuageux, brouillard, pluie, orage, neige.

signal hour_changed(hour: int)
signal weather_changed(weather: String)

const REAL_SECONDS_PER_HOUR := 60.0

## Réglages par météo : lumière, ciel, brouillard ajouté, pluie, neige.
const WEATHERS := {
	"clear": {"name": "Beau temps", "light": 1.0, "sky": 1.0, "fog": 0.0, "rain": 0.0, "snow": 0.0},
	"cloudy": {"name": "Nuageux", "light": 0.72, "sky": 0.78, "fog": 0.002, "rain": 0.0, "snow": 0.0},
	"fog": {"name": "Brouillard", "light": 0.78, "sky": 0.85, "fog": 0.016, "rain": 0.0, "snow": 0.0},
	"rain": {"name": "Pluie", "light": 0.55, "sky": 0.58, "fog": 0.005, "rain": 0.7, "snow": 0.0},
	"storm": {"name": "Orage", "light": 0.38, "sky": 0.42, "fog": 0.007, "rain": 1.0, "snow": 0.0},
	"snow": {"name": "Neige", "light": 0.8, "sky": 0.85, "fog": 0.006, "rain": 0.0, "snow": 1.0},
}

## Probabilités de chaque temps selon le biome de l'île.
const CLIMATES := {
	"prairie": {"clear": 45, "cloudy": 20, "rain": 18, "fog": 9, "storm": 8},
	"plage": {"clear": 60, "cloudy": 15, "rain": 13, "storm": 12},
	"givre": {"clear": 30, "cloudy": 25, "snow": 35, "fog": 10},
	"braise": {"clear": 50, "cloudy": 25, "fog": 12, "rain": 13},
}

const NIGHT_FOG := Color("1d2540")
const DUSK_SUN := Color("ffb070")
const MOON := Color("9fb6ff")

var env: Environment
var sky_mat: PanoramaSkyMaterial
var sun: DirectionalLight3D
var follow: Node3D  # ce que la pluie suit (la caméra)
var ambience: Ambience
var island := {}
## Dans une maison : pas de pluie à l'écran, son étouffé.
var indoor := false

var _cur := {}  # réglages météo actuels (interpolés)
var _rain: GPUParticles3D
var _snow: GPUParticles3D
var _pano := ""
var _last_hour := -1
var _flash := 0.0
var _next_flash := 8.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_cur = (WEATHERS[Game.weather] as Dictionary).duplicate()
	_rain = _make_particles(1400, 1.1, Vector3(0.025, 0.7, 0.025), Color(0.75, 0.82, 0.95, 0.55), 20.0, 1.5)
	_snow = _make_particles(900, 7.0, Vector3(0.09, 0.09, 0.09), Color(1, 1, 1, 0.9), 1.8, 0.6)
	add_child(_rain)
	add_child(_snow)


func _make_particles(n: int, life: float, size: Vector3, col: Color, speed: float, spread: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-30, -40, -30), Vector3(60, 60, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(20, 0.5, 20)
	pm.direction = Vector3(0.08, -1, 0)
	pm.spread = spread * 4.0
	pm.initial_velocity_min = speed * 0.9
	pm.initial_velocity_max = speed * 1.1
	pm.gravity = Vector3(0, -2.0 if speed > 5.0 else -0.3, 0)
	if speed < 5.0:
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.6
	p.process_material = pm
	var m := BoxMesh.new()
	m.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	m.material = mat
	p.draw_pass_1 = m
	return p


## Nouvelle île : nouveau climat (la météo en cours est conservée).
func set_island(isl: Dictionary) -> void:
	island = isl
	if not (CLIMATES[isl["biome"]] as Dictionary).has(Game.weather):
		roll_weather()
	apply(true)


## Réveil : 7 h du matin et un nouveau temps.
func morning() -> void:
	Game.time = 7.0
	roll_weather()
	apply(true)


func roll_weather() -> void:
	var climate: Dictionary = CLIMATES.get(island.get("biome", "prairie"), CLIMATES["prairie"])
	var total := 0
	for w in climate:
		total += int(climate[w])
	var r := _rng.randi_range(0, total - 1)
	for w in climate:
		r -= int(climate[w])
		if r < 0:
			Game.weather = w
			break
	Game.weather_left = _rng.randf_range(2.0, 6.0)
	weather_changed.emit(Game.weather)


func weather_name() -> String:
	return WEATHERS[Game.weather]["name"]


func is_night() -> bool:
	return Game.time >= 21.0 or Game.time < 6.5


func is_wet() -> bool:
	return Game.weather in ["rain", "storm"]


func clock_text() -> String:
	var h := int(Game.time)
	var m := int((Game.time - h) * 60.0) / 10 * 10
	return "Jour %d · %dh%02d · %s" % [Game.day, h, m, weather_name()]


func _process(delta: float) -> void:
	Game.time += delta / REAL_SECONDS_PER_HOUR
	if Game.time >= 24.0:
		Game.time -= 24.0
		Game.day += 1
	Game.weather_left -= delta / REAL_SECONDS_PER_HOUR
	if Game.weather_left <= 0.0:
		roll_weather()
	var h := int(Game.time)
	if h != _last_hour:
		_last_hour = h
		hour_changed.emit(h)
	# Éclairs pendant l'orage.
	if Game.weather == "storm" and not indoor:
		_next_flash -= delta
		if _next_flash <= 0.0:
			_next_flash = _rng.randf_range(6.0, 16.0)
			_flash = 1.0
			if ambience:
				get_tree().create_timer(_rng.randf_range(0.4, 1.6)).timeout.connect(func():
					if ambience:
						ambience.thunder(_rng.randf_range(0.6, 1.0)))
	_flash = maxf(0.0, _flash - delta * 5.0)
	apply(false, delta)


## Met à jour soleil, ciel, brouillard, pluie selon l'heure et la météo.
func apply(instant := false, delta := 0.0) -> void:
	if env == null or sun == null:
		return
	var target: Dictionary = WEATHERS[Game.weather]
	var k := 1.0 if instant else minf(1.0, delta * 0.25)
	for key in ["light", "sky", "fog", "rain", "snow"]:
		_cur[key] = lerpf(float(_cur.get(key, target[key])), float(target[key]), k)
	var t := Game.time
	var day := smoothstep(5.3, 7.3, t) * (1.0 - smoothstep(18.8, 20.8, t))
	var dusk := maxf(1.0 - absf(t - 6.6) / 1.4, 1.0 - absf(t - 19.6) / 1.4)
	dusk = clampf(dusk, 0.0, 1.0)
	var base_sun: Color = island.get("sun", Color.WHITE)
	var base_fog: Color = island.get("fog", Color("cfeaff"))
	# Soleil (jour) ou lune (nuit).
	if day > 0.02:
		var p := clampf((t - 5.5) / 15.0, 0.0, 1.0)
		var elev := sin(p * PI)
		sun.rotation_degrees = Vector3(-6.0 - elev * 62.0, lerpf(-95.0, 95.0, p), 0)
		sun.light_color = base_sun.lerp(DUSK_SUN, dusk * 0.8)
		sun.light_energy = lerpf(0.15, 1.0, day) * float(_cur["light"])
	else:
		sun.rotation_degrees = Vector3(-55, 30, 0)
		sun.light_color = MOON
		sun.light_energy = 0.16 * float(_cur["light"])
	sun.light_energy += _flash * 2.5
	env.ambient_light_energy = lerpf(0.3, 0.75, day) * lerpf(0.75, 1.0, float(_cur["light"])) + _flash * 0.8
	env.background_energy_multiplier = lerpf(0.55, 1.0, day) * float(_cur["sky"]) + _flash
	env.fog_light_color = NIGHT_FOG.lerp(base_fog, day).lerp(Color("8a8f98"), 1.0 - float(_cur["sky"]))
	env.fog_density = 0.0025 + float(_cur["fog"])
	# Ciel : nuit, aube / crépuscule, ou jour (Braise garde son ciel du matin).
	var pano := "day"
	if day < 0.2:
		pano = "night"
	elif dusk > 0.45 or island.get("biome", "") == "braise":
		pano = "morning"
	if pano != _pano and sky_mat:
		_pano = pano
		sky_mat.panorama = load("res://assets/sky/skybox-%s.png" % pano)
	# Pluie et neige autour de la caméra.
	var raining := float(_cur["rain"]) > 0.15 and not indoor
	var snowing := float(_cur["snow"]) > 0.15 and not indoor
	if _rain.emitting != raining:
		_rain.emitting = raining
	if _snow.emitting != snowing:
		_snow.emitting = snowing
	_rain.amount_ratio = clampf(float(_cur["rain"]), 0.1, 1.0)
	if follow:
		var fp := follow.global_position
		_rain.global_position = fp + Vector3(0, 14, 0)
		_snow.global_position = fp + Vector3(0, 10, 0)
	if ambience:
		ambience.rain = float(_cur["rain"]) * (0.35 if indoor else 1.0)
		ambience.wind = 0.08 + float(_cur["rain"]) * 0.25 + (0.2 if Game.weather == "snow" else 0.0)
