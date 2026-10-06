extends Node
## Statut Discord (Rich Presence) : ce que fait le joueur dans Evergrove.
##   « Sur l'Île Prairie »  ·  « Une île pleine de vie · 4 habitants »
## Utilise l'addon DiscordRichPresence (aucun effet si Discord n'est pas
## lancé, ni en mode headless). Les images (« logo ») se téléversent dans le
## portail développeur Discord : Rich Presence > Art Assets.

## Identifiant de l'application Discord « Evergrove » (Developer Portal).
const APP_ID := "1556957922293055539"
## Nom de l'image téléversée dans les Art Assets de l'application.
const LARGE_IMAGE := "logo"

## La scène principale (Main), donnée par Main au démarrage.
var main: Node
var _rpc: DiscordRichPresence
var _last := {}
var _timer := 0.0
var _start := 0


func _ready() -> void:
	_start = int(Time.get_unix_time_from_system())
	_rpc = DiscordRichPresence.new()
	_rpc.app_id = APP_ID
	add_child(_rpc)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 3.0
	var activity := _activity()
	if activity != _last:
		_last = activity
		_rpc.set_activity(activity)


func _activity() -> Dictionary:
	var details := "Au menu principal"
	var state := "Un archipel à faire revivre"
	if main and is_instance_valid(main) and not main.in_title:
		var isl: Dictionary = IslandDB.get_island(Game.current_island)
		details = "Sur l'%s" % isl["name"]
		if main.cinematic and Game.resident_count() == 0 and Game.day == 1:
			details = "Vient de faire naufrage"
		elif main.interior != null:
			var owner: String = Game.homes.get(main.interior.house_key, "")
			if owner != "" and owner != "player":
				details = "Chez %s" % ResidentDB.get_resident(owner).get("name", "un habitant")
			else:
				details = "Décore sa maison"
		var n := Vitality.residents(Game.current_island)
		state = "%s · %d habitant%s" % [Vitality.tier_name(Vitality.percent(Game.current_island)), n, "s" if n > 1 else ""]
	# (Discord refuse les textes vides ou trop courts.)
	return {
		"details": details,
		"state": state,
		"timestamps": {"start": _start},
		"assets": {"large_image": LARGE_IMAGE, "large_text": "Evergrove"},
	}
