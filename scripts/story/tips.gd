class_name Tips
extends Node
## Mini-tutos : une fiche « Astuce » la première fois que le joueur arrive à
## un moment clé (le Façonneur, la table d'artisan, la nuit, le premier
## habitant, le premier chantier...). Chacune ne s'affiche qu'une fois
## (Game.flags « tip_<id> »), sans bloquer le jeu.

const TIPS := {
	"faconneur": {"title": "Le Façonneur", "lines": [
		"1 à 4 : choisir un pouvoir (Casser, Poser, Fleurir, Planter).",
		"Clic gauche : utiliser le pouvoir sur ce que vise le viseur.",
		"Clic droit : retirer un bloc ou un objet, quel que soit le pouvoir.",
		"Commence par retirer les déchets : l'île respire déjà mieux."]},
	"poser": {"title": "Poser", "lines": [
		"Molette : choisir quoi poser.   F : changer de catégorie.",
		"R : tourner les constructions et les meubles.",
		"Garde le clic enfoncé pour poser plusieurs blocs d'affilée.",
		"On ne pose que ce qu'on a : casse des blocs ou fabrique-en."]},
	"fleurir": {"title": "Fleurir et planter", "lines": [
		"Fleurir (3) fait pousser fleurs et herbe autour du viseur.",
		"Planter (4) fait pousser un arbre : il grandit pendant quelques jours.",
		"Arbres et fleurs rendent l'île plus vivante."]},
	"artisan": {"title": "La table d'artisan", "lines": [
		"Ressources ramassées → composants (poutres, cordes...) → blocs, constructions et meubles.",
		"Ce que tu fabriques est prêt à poser tout de suite.",
		"De nouvelles recettes arrivent quand l'île revit et que des habitants s'installent.",
		"I (ou Tab) : ouvrir l'inventaire n'importe où."]},
	"nuit": {"title": "La nuit tombe", "lines": [
		"Une journée dure 24 minutes. La nuit, on y voit moins bien.",
		"Dors dans la tente (E) pour passer au lendemain.",
		"Chaque matin, l'île change : ce qui a été ramassé repousse, les arbres grandissent...",
		"... et si l'île est assez accueillante, quelqu'un arrive."]},
	"vitalite": {"title": "L'île revit", "lines": [
		"Plus l'île est belle et propre, plus elle vit : oiseaux, papillons, animaux...",
		"Arbres, fleurs, eau et déchets nettoyés, constructions : tout compte.",
		"La jauge en haut à droite montre où en est l'île."]},
	"habitant": {"title": "Ton premier habitant", "lines": [
		"E : parler (une fois par jour, l'amitié grandit).",
		"Après la discussion, tu peux lui offrir un objet ou lui demander un coup de main.",
		"Construis-lui une maison : il s'y installera."]},
	"chantier": {"title": "Un chantier", "lines": [
		"Les grosses constructions sont bâties par les habitants libres.",
		"E près du chantier : choisir qui y travaille.",
		"Sans habitant, le chantier attend : rends l'île accueillante d'abord."]},
	"maison": {"title": "Une maison", "lines": [
		"E devant la porte : entrer.   G : choisir qui y habite.",
		"À l'intérieur, Poser ne propose que les meubles.",
		"Les habitants remarquent les nouveaux meubles chez eux."]},
	"carte": {"title": "Explorer l'archipel", "lines": [
		"M : ouvrir la carte et voyager vers une île découverte.",
		"Chaque île a ses habitants, ses fleurs et son climat.",
		"Les autres îles se découvrent en réparant ce qu'on trouve sur la Prairie."]},
	"carnet": {"title": "Le carnet", "lines": [
		"C : ouvrir le carnet.",
		"Il se remplit tout seul : habitants, animaux, herbier, meubles, îles et souvenirs."]},
}

var main: Main
var _timer := 1.0


## Affiche une astuce (une seule fois).
func tip(id: String) -> void:
	if not TIPS.has(id) or Game.has_flag("tip_" + id):
		return
	Game.set_flag("tip_" + id)
	main.hud.queue_tip(TIPS[id]["title"], TIPS[id]["lines"])


## Quelques moments repérés en surveillant le jeu (les autres sont signalés
## directement là où ils arrivent).
func _process(delta: float) -> void:
	if main == null or main.in_title or main.cinematic:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	if not Game.has_flag("chest"):
		return
	if main.is_placing():
		tip("poser")
	elif main.power >= 2 and main.hud.power_unlocked(main.power):
		tip("fleurir")
	if main.sky.is_night() and main.interior == null:
		tip("nuit")
	if Game.resident_count() > 0 and not main.busy:
		tip("habitant")
	if main.life.tier >= 1:
		tip("vitalite")
	if Game.has_flag("unlock_corail"):
		tip("carte")
	if Game.species_seen.size() > 0 and Game.day >= 2:
		tip("carnet")
