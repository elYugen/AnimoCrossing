class_name Memories
extends Node
## Souvenirs : le carnet garde les premiers grands moments de la vie sur
## l'île, avec une petite image prise sur le moment (sans l'interface).
## Ils se relisent dans le carnet (onglet Souvenirs), avec ceux du mystère.

const MOMENTS := {
	"sunrise": {"title": "Premier lever de soleil", "text": "Le premier matin sur l'île, après une nuit sous une vieille tente."},
	"storm": {"title": "Première tempête", "text": "Le ciel s'est déchiré au-dessus de l'île. Elle a tenu bon."},
	"resident": {"title": "Premier habitant", "text": "Quelqu'un est venu s'installer sur l'île. Il y a enfin une autre voix que la mienne."},
	"house": {"title": "Première maison", "text": "Les habitants ont bâti la première maison de l'île."},
	"crossing": {"title": "Première traversée", "text": "La barque a tenu la mer : une nouvelle île, au bout de l'horizon."},
	"bloom": {"title": "L'île en fleurs", "text": "Des fleurs partout où l'on regarde. Difficile de croire qu'il n'y avait rien."},
	"butterflies": {"title": "Les premiers papillons", "text": "Ils dansaient au-dessus des fleurs, comme s'ils avaient toujours été là."},
	"fire_evening": {"title": "Une soirée au coin du feu", "text": "Les habitants se sont retrouvés autour du feu pour parler jusqu'à la nuit."},
	"friend": {"title": "Un véritable ami", "text": "Une amitié est née sur cette île."},
	"deer": {"title": "Le cerf des brumes", "text": "Il m'a regardé un long moment dans le brouillard, puis il a disparu."},
}
const DIR := "user://memories"
## Fleurs à faire pousser pour « L'île en fleurs ».
const BLOOM_FLOWERS := 60

var main: Main
var _timer := 3.0
var _busy := false


## Note un souvenir (une seule fois), avec une image du moment.
func record(id: String) -> void:
	if not MOMENTS.has(id) or Game.memories.has(id) or _busy:
		return
	_busy = true
	Game.memories[id] = {"day": Game.day, "island": Game.current_island, "img": ""}
	var img := await _capture()
	if img != null:
		DirAccess.make_dir_recursive_absolute(DIR)
		var path := "%s/%s.png" % [DIR, id]
		if img.save_png(path) == OK:
			Game.memories[id]["img"] = path
	Game.save_game()
	main.hud.toast("Nouveau souvenir : %s" % MOMENTS[id]["title"], UIStyle.FRAME)
	Audio.play("book", -6.0)
	_busy = false


## Une image de l'écran, sans l'interface, réduite pour le carnet.
func _capture() -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	var hud_was := main.hud.visible
	main.hud.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	main.hud.visible = hud_was
	if img == null or img.is_empty():
		return null
	img.resize(480, int(480.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
	return img


## Image d'un souvenir (null si aucune).
static func texture_of(id: String) -> Texture2D:
	var m: Dictionary = Game.memories.get(id, {})
	var path: String = m.get("img", "")
	if path == "" or not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	return ImageTexture.create_from_image(img) if img else null


## Les moments qu'on repère en surveillant le jeu.
func _process(delta: float) -> void:
	if main == null or main.in_title or main.cinematic or main.loading:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 1.5
	if Game.weather == "storm" and main.interior == null:
		record("storm")
	elif int(Vitality.measures(Game.current_island).get("flowers", 0)) >= BLOOM_FLOWERS and main.interior == null:
		record("bloom")
