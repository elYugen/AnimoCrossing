class_name Mystery
extends Node
## Le mystère de la plage, raconté par petites touches et jamais expliqué :
##   1. un habitant : « ces vieilles caisses ne viennent pas de ton bateau... »
##   2. une vieille caisse sur la plage : une carte de l'archipel, très ancienne
##   3. parmi les outils rouillés du campement : un vieux carnet
##   4. le lendemain, une seule pensée : qu'est-il arrivé à cette personne ?
## Les découvertes se relisent dans le carnet (onglet Découvertes).

## Pages du vieux carnet (relues dans le carnet du joueur).
const NOTEBOOK := [
	"Jour 12 — La barque tient encore. Demain, je pars voir les îles du sud.",
	"Jour 40 — Les fleurs ont repoussé près de la mare. Il n'y a que moi ici, mais l'île me parle.",
	"Jour 73 — J'ai allumé le feu du phare. Une lueur rouge m'a répondu, à l'ouest.",
	"Jour ?? — Si quelqu'un trouve ce carnet... prends soin de l'île. Elle te le rendra.",
]

## Découvertes affichées dans le carnet, dans l'ordre où on les fait.
const DISCOVERIES := [
	{"flag": "camp", "title": "Le campement abandonné", "text": "Une tente, un établi, un vieux coffre. Quelqu'un a vécu ici, il y a longtemps."},
	{"flag": "mystery_doute", "title": "Les caisses de la plage", "text": "Elles étaient déjà là bien avant l'arrivée des habitants. Elles ne viennent pas de mon bateau..."},
	{"flag": "mystery_carte", "title": "La carte ancienne", "text": "Trouvée dans une caisse bien plus vieille que mon naufrage. Toutes les îles y sont dessinées, et une tour est entourée."},
	{"flag": "unlock_corail", "title": "La vieille barque", "text": "Réparée ! Elle m'a menée jusqu'à l'Île Corail."},
	{"flag": "mystery_carnet", "title": "Le vieux carnet", "text": "Caché parmi les outils rouillés du campement.", "pages": NOTEBOOK},
	{"flag": "unlock_braise", "title": "Le phare", "text": "Son feu brille de nouveau. Une lueur rouge lui répond, à l'ouest."},
]

var main: Main


## Objets à examiner (la vieille caisse), pour Main.nearest_interactable.
func interactables() -> Array:
	var out := []
	if Game.current_island != "prairie":
		return out
	for id in main.props.items:
		if main.props.key_of(id) == "g:oldcrate":
			var opened := Game.has_flag("mystery_carte")
			out.append({"node": main.props.items[id]["node"], "prompt": "[E] Examiner" if opened or not Game.has_flag("mystery_doute") else "[E] Fouiller la vieille caisse", "action": open_crate})
	return out


## Étape 1 : un habitant en parle (appelé par ResidentTalk, une fois).
func resident_doubt() -> bool:
	if Game.has_flag("mystery_doute") or Game.day < 3:
		return false
	Game.set_flag("mystery_doute")
	return true


## Étape 2 : la vieille caisse de la plage.
func open_crate() -> void:
	if not Game.has_flag("mystery_doute"):
		main.story.think("caisse")
		return
	if Game.has_flag("mystery_carte"):
		main.story.think("caisse_vide")
		return
	main.busy = true
	main.player.play_action("open")
	Audio.play("open", -2.0, 0.0, 0.7)
	await get_tree().create_timer(0.6).timeout
	Game.set_flag("mystery_carte")
	Game.save_game()
	main.hud.show_item_popup("Une carte ancienne de l'archipel", "Notée dans ton carnet (Découvertes).", false)
	Audio.play("book", -4.0)
	await get_tree().create_timer(1.5).timeout
	await main.story.think("carte")
	main.busy = false


## Étape 3 : les outils rouillés du campement cachent un carnet.
func examine_tools() -> void:
	if not Game.has_flag("mystery_carte") or Game.has_flag("mystery_carnet"):
		main.story.think("rouille")
		return
	main.busy = true
	Game.flags["mystery_carnet"] = Game.day  # (le jour de la découverte)
	Game.save_game()
	Audio.play("book", -2.0)
	main.hud.show_item_popup("Un vieux carnet", "Ses pages se relisent dans ton carnet (Découvertes).", false)
	await get_tree().create_timer(1.5).timeout
	await main.story.think("carnet")
	main.busy = false


## Étape 4 : le lendemain matin (appelé par DayCycle).
func on_morning() -> void:
	if Game.has_flag("mystery_carnet") and not Game.has_flag("mystery_fin") and Game.day > int(Game.flags["mystery_carnet"]):
		Game.set_flag("mystery_fin")
		await main.story.think("mystere_fin")
