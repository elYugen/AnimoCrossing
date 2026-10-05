class_name Dialogues
extends RefCounted
## Lecture des fichiers .dialogue (plugin Dialogue Manager) : on déroule une
## séquence de répliques pour l'afficher avec nos propres bulles.

const INTRO := "res://dialogue/intro.dialogue"
const STORY := "res://dialogue/story.dialogue"
const ARRIVALS := "res://dialogue/arrivals.dialogue"
const RESIDENTS := "res://dialogue/residents.dialogue"


## Renvoie les répliques d'une séquence : [{"speaker", "text", "tags"}, ...].
static func fetch(path: String, cue: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var res := load(path) as DialogueResource
	if res == null:
		push_warning("Dialogue introuvable : %s" % path)
		return out
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(res, cue)
	while line != null:
		out.append({"speaker": line.character, "text": line.text, "tags": line.tags})
		line = await DialogueManager.get_next_dialogue_line(res, line.next_id)
	return out


## Uniquement les textes, pour les bulles du HUD.
static func texts(path: String, cue: String) -> Array:
	var out := []
	for l in await fetch(path, cue):
		out.append(l["text"])
	return out
