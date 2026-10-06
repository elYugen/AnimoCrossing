class_name CarnetPanel
extends Control
## Carnet (touche C) : le journal de la vie sur l'île, rempli au fil des
## découvertes, sans objectif imposé.
##   Habitants (portrait, maison, amitié, goûts) · Animaux (dont les rares) ·
##   Herbier (fleurs, arbres) · Meubles · Îles · Souvenirs (le mystère)

signal closed

const TABS := [["residents", "Habitants"], ["animals", "Animaux"], ["herbarium", "Herbier"],
	["furniture", "Meubles"], ["islands", "Îles"], ["memories", "Souvenirs"]]
## Noms des collections (aussi pour le petit mot quand on en découvre une entrée).
const CATEGORY_NAMES := {"flowers": "Herbier", "trees": "Herbier", "furniture": "Meubles", "islands": "Îles"}
const HAB_COLORS := {"forest": Color("6cbf4a"), "garden": Color("f07fb0"), "marine": Color("6aa8f2"), "mountain": Color("a7adb5"), "village": Color("f29a45")}
## Arbres de l'herbier (un par espèce) : type d'objet -> nom.
const TREES := {"town_tree": "Chêne", "town_crooked": "Arbre tordu", "town_round": "Arbre boule",
	"town_high": "Grand arbre", "survival_tree": "Feuillu", "survival_tall": "Haut feuillu",
	"autumn": "Érable d'automne", "autumn_tall": "Grand érable", "palm": "Palmier", "palm_bend": "Palmier penché",
	"palm_detailed": "Cocotier", "palm_detailed_bend": "Cocotier penché", "pine": "Pin", "pine_snow_a": "Sapin enneigé"}
## Variantes rangées sous la même espèce.
const TREE_ALIAS := {"town_high_crooked": "town_high", "pine_snow_b": "pine_snow_a", "pine_snow_c": "pine_snow_a"}

var _grid: GridContainer
var _preview: ResidentPreview
var _thumb: TextureRect
var _swatch: ColorRect
var _name: Label
var _info: Label
var _desc: Label
var _req: Label
var _count: Label
var _tab := "residents"
var _tab_buttons := {}


static func tree_species(kind: String) -> String:
	return TREE_ALIAS.get(kind, kind)


## Nom d'une entrée de collection.
static func entry_name(category: String, id: String) -> String:
	match category:
		"flowers":
			return Blocks.block_name(int(id))
		"trees":
			return TREES.get(tree_species(id), id)
		"furniture":
			return Interior.label_of(id)
		"islands":
			return IslandDB.get_island(id)["name"]
	return id


static func _tree_seen(kind: String) -> bool:
	for k in (Game.collections.get("trees", {}) as Dictionary):
		if tree_species(k) == kind:
			return true
	return false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := UIStyle.modal("Carnet", Vector2(1000, 620))
	add_child(m["root"])
	(m["close"] as Button).pressed.connect(func(): closed.emit())
	var body: VBoxContainer = m["body"]
	_count = UIStyle.label("", 16, UIStyle.TEXT_SOFT)
	body.add_child(_count)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	body.add_child(tabs)
	for t in TABS:
		_add_tab(tabs, t[0], t[1])

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 450)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)

	var detail := PanelContainer.new()
	detail.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.CREAM, 20, UIStyle.BORDER, 3, 16))
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	var dscroll := ScrollContainer.new()
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail.add_child(dscroll)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dscroll.add_child(dv)
	_preview = ResidentPreview.new()
	_preview.custom_minimum_size = Vector2(320, 200)
	dv.add_child(_preview)
	_thumb = TextureRect.new()
	_thumb.custom_minimum_size = Vector2(320, 170)
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dv.add_child(_thumb)
	_swatch = ColorRect.new()
	_swatch.custom_minimum_size = Vector2(90, 90)
	_swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dv.add_child(_swatch)
	_name = UIStyle.title("", 26)
	dv.add_child(_name)
	_info = UIStyle.label("", 16, UIStyle.TEXT_SOFT)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size.x = 320
	dv.add_child(_info)
	_desc = UIStyle.label("", 17)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size.x = 320
	dv.add_child(_desc)
	_req = UIStyle.label("", 16, UIStyle.GREEN_DARK)
	_req.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_req.custom_minimum_size.x = 320
	dv.add_child(_req)


func _add_tab(parent: Control, id: String, text: String) -> void:
	var b := UIStyle.button(text, 16)
	b.toggle_mode = true
	b.pressed.connect(func(): _select_tab(id))
	parent.add_child(b)
	_tab_buttons[id] = b


## Combien d'entrées découvertes dans chaque partie : [vues, total].
static func progress() -> Dictionary:
	var flowers := 0
	for f in Blocks.FLOWERS:
		if Game.has_collected("flowers", str(f)):
			flowers += 1
	var trees := 0
	for t in TREES:
		if _tree_seen(t):
			trees += 1
	var furn := 0
	for f in Interior.FURNITURE:
		if Game.has_collected("furniture", f):
			furn += 1
	var islands := 0
	for isl in IslandDB.ISLANDS:
		if Game.has_collected("islands", isl["id"]):
			islands += 1
	var memories := 0
	for d in Mystery.DISCOVERIES:
		if Game.has_flag(d["flag"]):
			memories += 1
	var animals := 0
	for sp in Game.species_seen:
		if Fauna.SPECIES.has(sp) or Fauna.RARE.has(sp):
			animals += 1
	return {
		"residents": [Game.resident_count(), ResidentDB.ALL.size()],
		"animals": [animals, Fauna.SPECIES.size() + Fauna.RARE.size()],
		"herbarium": [flowers + trees, Blocks.FLOWERS.size() + TREES.size()],
		"furniture": [furn, Interior.FURNITURE.size()],
		"islands": [islands, IslandDB.ISLANDS.size()],
		"memories": [memories, Mystery.DISCOVERIES.size()],
	}


func open() -> void:
	var p := progress()
	var parts := []
	for t in TABS:
		parts.append("%s %d/%d" % [t[1], p[t[0]][0], p[t[0]][1]])
	_count.text = "   ·   ".join(parts)
	_select_tab(_tab)


func _select_tab(id: String) -> void:
	_tab = id
	for k in _tab_buttons:
		(_tab_buttons[k] as Button).button_pressed = (k == id)
	for c in _grid.get_children():
		c.queue_free()
	var first := Callable()
	match id:
		"residents":
			for h in ResidentDB.HABITATS:
				for c in ResidentDB.habitat_residents(h):
					var known := Game.residents.has(c["id"])
					_grid.add_child(_card(c["name"] if known else "???", null, HAB_COLORS[h] if known else Color("cfc4b4"), func(): _show_resident(c)))
			first = func(): _show_resident(ResidentDB.ALL[0])
		"animals":
			for sp in Fauna.SPECIES.keys() + Fauna.RARE.keys():
				var known := Game.species_seen.has(sp)
				var model: String = Fauna.RARE[sp]["model"] if Fauna.RARE.has(sp) else sp
				_grid.add_child(_card(Fauna.name_of(sp) if known else "???", Thumbs.of("pet_" + model) if known else null, Color("cfc4b4"), func(): _show_animal(sp)))
			first = func(): _show_animal(Fauna.SPECIES.keys()[0])
		"herbarium":
			for f in Blocks.FLOWERS:
				var known := Game.has_collected("flowers", str(f))
				_grid.add_child(_card(Blocks.block_name(f) if known else "???", null, Blocks.main_color(f) if known else Color("cfc4b4"), func(): _show_flower(f)))
			for t in TREES:
				var known := _tree_seen(t)
				_grid.add_child(_card(TREES[t] if known else "???", Thumbs.of(t) if known else null, Color("cfc4b4"), func(): _show_tree(t)))
			first = func(): _show_flower(Blocks.FLOWERS[0])
		"furniture":
			for f in Interior.FURNITURE:
				var known := Game.has_collected("furniture", f)
				_grid.add_child(_card(Interior.label_of(f) if known else "???", Thumbs.of("f_" + f) if known else null, Color("cfc4b4"), func(): _show_furniture(f)))
			first = func(): _show_furniture(Interior.FURNITURE.keys()[0])
		"islands":
			for isl in IslandDB.ISLANDS:
				var known := Game.has_collected("islands", isl["id"])
				_grid.add_child(_card(isl["name"] if known else "???", null, isl["water_shallow"] if known else Color("cfc4b4"), func(): _show_island(isl)))
			first = func(): _show_island(IslandDB.ISLANDS[0])
		"memories":
			for d in Mystery.DISCOVERIES:
				var known := Game.has_flag(d["flag"])
				_grid.add_child(_card(d["title"] if known else "???", null, Color("e8d8b8") if known else Color("cfc4b4"), func(): _show_memory(d)))
			first = func(): _show_memory(Mystery.DISCOVERIES[0])
	first.call()


## Carte de la grille : miniature (ou pastille de couleur) et nom.
func _card(title: String, tex: Texture2D, col: Color, on_click: Callable) -> Button:
	var b := UIStyle.button("", 15)
	b.custom_minimum_size = Vector2(128, 124)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(vb)
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(70, 64)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(tr)
	else:
		var sw := PanelContainer.new()
		sw.custom_minimum_size = Vector2(56, 56)
		sw.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sw.add_theme_stylebox_override("panel", UIStyle.box(col, 28, col.darkened(0.2), 3, 4))
		vb.add_child(sw)
		if title == "???":
			var q := UIStyle.label("?", 26, Color("8a7563"))
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			q.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sw.add_child(q)
	var n := UIStyle.label(title, 14)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size.x = 118
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(n)
	b.pressed.connect(on_click)
	return b


## Prépare le panneau de détail : aperçu 3D, miniature ou pastille.
func _detail(title: String, info: String, desc: String, req := "", tex: Texture2D = null, col := Color(0, 0, 0, 0)) -> void:
	_preview.visible = false
	_preview.clear()
	_thumb.visible = tex != null
	_thumb.texture = tex
	_swatch.visible = col.a > 0.0
	_swatch.color = col
	_name.text = title
	_info.text = info
	_desc.text = desc
	_req.text = req


func _show_resident(c: Dictionary) -> void:
	var id: String = c["id"]
	var known := Game.residents.has(id)
	var hab: String = ResidentDB.HABITAT_NAMES[c["habitat"]]
	if not known:
		_detail("???", "Habitat : %s" % hab, "Tu n'as pas encore rencontré cet habitant.",
			"Peut venir quand l'environnement « %s » se développe et que l'île est assez accueillante." % hab)
		_preview.visible = true
		_preview.set_creature(c["look"], true)
		return
	var home_isl: String = (Game.residents[id] as Dictionary).get("island", "")
	var house := "a sa maison" if Game.home_of(id) != "" else "n'a pas encore de maison"
	var likes: Dictionary = Friendship.LIKES[c["habitat"]]
	var items := []
	for k in likes["items"]:
		items.append(Items.name_of(k, 2).to_lower())
	var furn := []
	for f in likes["furniture"]:
		furn.append(Interior.label_of(f).to_lower())
	_detail(c["name"], "%s   ·   %s" % [hab, Friendship.hearts_text(id)],
		"%s\n\nVit sur l'%s, %s." % [c["desc"], IslandDB.get_island(home_isl)["name"], house],
		"Aime : %s\nMeubles préférés : %s" % [", ".join(items), ", ".join(furn)])
	_preview.visible = true
	_preview.set_creature(c["look"], false)


func _show_animal(sp: String) -> void:
	var known := Game.species_seen.has(sp)
	if Fauna.RARE.has(sp):
		var r: Dictionary = Fauna.RARE[sp]
		_detail(Fauna.name_of(sp) if known else "???", "Rencontre rare", r["desc"] if known else "On raconte qu'une silhouette erre dans les bois, certains jours de brouillard...",
			"", Thumbs.of("pet_" + str(r["model"])) if known else null)
		return
	var d: Dictionary = Fauna.SPECIES[sp]
	var hab: String = ResidentDB.HABITAT_NAMES[d["habitat"]]
	_detail(Fauna.name_of(sp) if known else "???", "Habitat : %s" % hab, "Il vit sur l'île." if known else "Pas encore aperçu.",
		"" if known else "Apparaît quand l'environnement « %s » se développe." % hab, Thumbs.of("pet_" + sp) if known else null)


func _show_flower(f: int) -> void:
	var known := Game.has_collected("flowers", str(f))
	_detail(Blocks.block_name(f) if known else "???", "Fleur", "Pousse quand on fait fleurir l'île." if known else "Pas encore vue.",
		"" if known else "Fais fleurir l'île (pouvoir 3) : chaque île a ses fleurs.", null, Blocks.main_color(f) if known else Color("cfc4b4"))


func _show_tree(t: String) -> void:
	var known := _tree_seen(t)
	_detail(TREES[t] if known else "???", "Arbre", "Planté ou coupé sur l'archipel." if known else "Pas encore croisé.",
		"" if known else "Plante ou coupe des arbres, sur chaque île.", Thumbs.of(t) if known else null)


func _show_furniture(f: String) -> void:
	var known := Game.has_collected("furniture", f)
	_detail(Interior.label_of(f) if known else "???", "Meuble", "Se pose dans les maisons... ou dehors." if known else "Pas encore fabriqué.",
		"" if known else "À fabriquer à la table d'artisan, ou à recevoir d'un habitant.", Thumbs.of("f_" + f) if known else null)


func _show_island(isl: Dictionary) -> void:
	var known := Game.has_collected("islands", isl["id"])
	if not known:
		_detail("???", "Île pas encore visitée", isl.get("hint", ""), "", null, Color("cfc4b4"))
		return
	_detail(isl["name"], "Habitants : %d   ·   %s" % [Vitality.residents(isl["id"]), Vitality.tier_name(Vitality.percent(isl["id"]))],
		isl["desc"], "", null, isl["water_shallow"])


func _show_memory(d: Dictionary) -> void:
	if not Game.has_flag(d["flag"]):
		_detail("???", "Souvenir", "Pas encore découvert.", "")
		return
	var pages := ""
	for p in d.get("pages", []):
		pages += "\n\n" + p
	_detail(d["title"], "Souvenir", d["text"] + pages, "")
