extends Node3D

const SAVE = "user://sproutlings_v01.json"
const RARITIES = ["Common","Uncommon","Rare","Epic","Legendary","Mythic"]
const COLORS = [Color("#b9c7ad"),Color("#70ce88"),Color("#6cb8f4"),Color("#bd88ef"),Color("#ffcb65"),Color("#f9a5e2")]
const SPECIES = ["Filizburun","Pofmantar","Damlaç","Yaprakuyruk","Kıvılkın","Kristip","Gecekanat","Gökboynuz","Solvaris","Lunareth","Aetherion","Verdalux"]
const ELEMENTS = ["Toprak","Orman","Su","Orman","Ateş","Kristal","Gece","Hava","Güneş","Ay","Kozmik","Doğa"]
const TRAITS = ["Çalışkan","Tembel","Meraklı","Oyuncu","Enerjik","Sabırlı","Utangaç","Gururlu","Cesur","Sakin","Bilge","Koruyucu"]
const TIERS = ["Ahşap","Demir","Altın","Kristal","Efsanevi","Etkinlik"]
const ODDS = [[70,25,5,0,0,0],[45,35,17,3,0,0],[20,35,33,11,1,0],[5,20,40,29,6,0],[0,5,30,50,15,0],[15,30,35,15,4.5,0.5]]
const PITY_R = [10,7,5,3,2,3]
const PITY_L = [0,0,20,12,8,20]
const LOCK_LEVEL = [1,5,12,25,40,5]
const FEED_COST = [8,15,32,55,95,115]
const FEED_NAMES = ["Tahıl","Meyve yemi","Baharatlı yem","Kristal karışım","Göksel ziyafet","Yıldız nektarı"]
const CROPS = [
	{"name":"Buğday","cost":2,"sale":5,"time":12.0,"level":1,"color":"#e9c768"},
	{"name":"Havuç","cost":3,"sale":10,"time":25.0,"level":2,"color":"#f29145"},
	{"name":"Mısır","cost":5,"sale":13,"time":35.0,"level":4,"color":"#e7ca42"},
	{"name":"Orman meyvesi","cost":8,"sale":20,"time":48.0,"level":5,"color":"#bc71d5"},
	{"name":"Ejder biberi","cost":14,"sale":35,"time":65.0,"level":8,"color":"#ee7150"},
	{"name":"Kristal meyve","cost":22,"sale":55,"time":85.0,"level":12,"color":"#79d8ef"},
	{"name":"Ay balı","cost":20,"sale":60,"time":100.0,"level":16,"color":"#f8dda0"}
]
var gold = 100
var xp = 0
var level = 1
var harvests = 0
var unlocked = 4
var starter_feed = 3
var plots: Array = []
var creatures: Array = []
var crates = [0,0,0,0,0,0]
var pity_r = [0,0,0,0,0,0]
var pity_l = [0,0,0,0,0,0]
var pity_m = 0
var selected_crop = 0
var selected_plot = 0
var selected_crate = 0
var selected_creature = 0
var rng = RandomNumberGenerator.new()
var cam: Camera3D
var sun: DirectionalLight3D
var plot_nodes: Array = []
var crop_nodes: Array = []
var pet_nodes: Array = []
var pets_root: Node3D
var selection_ring: MeshInstance3D
var stats: Label
var goal: Label
var plot_info: Label
var odds_label: Label
var pet_info: Label
var toast: Label
var crop_menu: OptionButton
var crate_menu: OptionButton
var pet_menu: OptionButton
var expand_button: Button
var feed_button: Button
var active_button: Button
var open_button: Button
var craft_button: Button
var action_button: Button
var day_time = 0.0
var update_clock = 0.0
var visual_clock = 0.0
var save_clock = 0.0
var testing = false
var toast_time = 0.0
var saved_feed = 0
var crystal_dust = 0
var moon_essence = 0
var yield_carry = 0.0

func _ready():
	rng.randomize()
	testing = "--self-test" in OS.get_cmdline_user_args()
	reset_data()
	if not testing:
		load_game()
	make_world()
	make_ui()
	refresh_all()
	if testing:
		run_tests()
	else:
		notify("Hoş geldin! Bir tarlaya tıkla, ek ve sula.")

func reset_data():
	gold = 100
	xp = 0
	level = 1
	harvests = 0
	unlocked = 4
	starter_feed = 3
	saved_feed = 0
	crystal_dust = 0
	moon_essence = 0
	yield_carry = 0.0
	crates = [0,0,0,0,0,0]
	pity_r = [0,0,0,0,0,0]
	pity_l = [0,0,0,0,0,0]
	pity_m = 0
	creatures = []
	plots = []
	for i in range(12):
		plots.append({"crop":-1,"remaining":0.0,"watered":false})

func mat(color: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m

func mesh_at(parent: Node3D, mesh: Mesh, pos: Vector3, col: Color) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat(col)
	parent.add_child(n)
	n.position = pos
	return n

func box_at(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	return mesh_at(parent,mesh,pos,col)

func sphere_at(parent: Node3D, pos: Vector3, scale_v: Vector3, col: Color) -> MeshInstance3D:
	var mesh = SphereMesh.new()
	mesh.radial_segments = 10
	mesh.rings = 5
	var n = mesh_at(parent,mesh,pos,col)
	n.scale = scale_v
	return n

func cone_at(parent: Node3D, pos: Vector3, radius: float, height: float, col: Color) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 7
	return mesh_at(parent,mesh,pos,col)

func plot_pos(i: int) -> Vector3:
	return Vector3((i % 4 - 1.5)*1.75,0.12,(int(i/4.0)-1)*1.75)

func make_world():
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#b7d9d8")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#f5e5c9")
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.light_color = Color("#fff1d4")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	cam = Camera3D.new()
	add_child(cam)
	cam.position = Vector3(11,13,14)
	cam.look_at(Vector3(0,0,-0.6))
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 15.7
	cam.current = true
	box_at(self,Vector3(0,-0.75,0),Vector3(15,1.1,13),Color("#5c8460"))
	box_at(self,Vector3(0,-0.2,0),Vector3(15,0.2,13),Color("#88b66e"))
	box_at(self,Vector3(0,-0.075,3.3),Vector3(11,0.08,1.0),Color("#d6b987"))
	box_at(self,Vector3(-5.5,-0.07,0),Vector3(0.9,0.1,7),Color("#d6b987"))
	for i in range(12):
		var tile = box_at(self,plot_pos(i),Vector3(1.55,0.24,1.55),Color("#8f5f40"))
		plot_nodes.append(tile)
		var crops_root = Node3D.new()
		add_child(crops_root)
		crops_root.position = plot_pos(i)+Vector3(0,0.15,0)
		crop_nodes.append(crops_root)
		for j in range(3):
			box_at(crops_root,Vector3(-0.5+j*0.5,-0.01,0),Vector3(0.035,0.025,1.25),Color("#5e412e"))
	# Barn, pond, trees and fences: procedural, no external assets.
	box_at(self,Vector3(-4.9,0.68,-3.6),Vector3(2.2,1.55,1.9),Color("#c68154"))
	var roof = PrismMesh.new()
	roof.size = Vector3(2.55,0.85,2.2)
	mesh_at(self,roof,Vector3(-4.9,1.82,-3.6),Color("#79544d"))
	box_at(self,Vector3(-4.9,0.38,-2.62),Vector3(0.72,0.9,0.05),Color("#754d37"))
	for x in [-5.5,-4.3]:
		box_at(self,Vector3(x,0.95,-2.61),Vector3(0.35,0.37,0.08),Color("#f9df9b"))
	var pond = CylinderMesh.new()
	pond.top_radius = 1.25
	pond.bottom_radius = 1.25
	pond.height = 0.08
	pond.radial_segments = 14
	var water = mesh_at(self,pond,Vector3(5.1,-0.04,-2.9),Color("#69bfc4"))
	water.scale.z = 0.75
	for i in range(10):
		var a = i*TAU/10
		sphere_at(self,Vector3(5.1+cos(a)*1.28,0.06,-2.9+sin(a)*0.96),Vector3(0.42,0.23,0.35),Color("#b0ae96"))
	for p in [Vector3(-6,0,-5.2),Vector3(-2.9,0,-5.2),Vector3(0.1,0,-5.35),Vector3(3.1,0,-5.3),Vector3(6.2,0,4.5),Vector3(-6.1,0,4.8)]:
		box_at(self,p+Vector3(0,0.65,0),Vector3(0.24,1.3,0.24),Color("#7f583b"))
		cone_at(self,p+Vector3(0,1.4,0),0.82,1.5,Color("#4e8d55"))
		cone_at(self,p+Vector3(0,1.95,0),0.58,1.15,Color("#68a763"))
	for i in range(13):
		var x = -6.6+i*1.1
		box_at(self,Vector3(x,0.28,5.75),Vector3(0.12,0.65,0.12),Color("#e4d0a6"))
		if i < 12:
			box_at(self,Vector3(x+0.55,0.35,5.75),Vector3(1.1,0.12,0.1),Color("#d8c69c"))
	for i in range(24):
		var p = Vector3(-6.8+fmod(i*2.71,13.5),0.04,-4.5 if i%2==0 else 4.6)
		sphere_at(self,p,Vector3(0.17,0.15,0.17),Color("#f4db81") if i%3==0 else Color("#f5aeb1"))
	pets_root = Node3D.new()
	add_child(pets_root)
	var ring = TorusMesh.new()
	ring.inner_radius = 0.78
	ring.outer_radius = 0.85
	ring.rings = 24
	ring.ring_segments = 8
	selection_ring = mesh_at(self,ring,plot_pos(0)+Vector3(0,0.16,0),Color("#fff0a0"))

func panel_at(left: bool) -> VBoxContainer:
	var layer = get_node("HUD")
	var p = PanelContainer.new()
	layer.add_child(p)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#172d2bea")
	style.border_color = Color("#537e65")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel",style)
	p.set_anchors_preset(Control.PRESET_TOP_LEFT if left else Control.PRESET_TOP_RIGHT)
	p.offset_left = 16 if left else -292
	p.offset_right = 292 if left else -16
	p.offset_top = 16
	p.offset_bottom = 755
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation",8)
	p.add_child(v)
	return v

func lbl(parent: Control, content: String, size: int = 15, accent: bool = false) -> Label:
	var l = Label.new()
	l.text = content
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",Color("#f4dda1") if accent else Color("#e8f0e6"))
	parent.add_child(l)
	return l

func btn(parent: Control, content: String, action: Callable) -> Button:
	var b = Button.new()
	b.text = content
	b.custom_minimum_size.y = 37
	b.add_theme_font_size_override("font_size",15)
	parent.add_child(b)
	b.pressed.connect(action)
	return b

func menu(parent: Control, callback: Callable) -> OptionButton:
	var m = OptionButton.new()
	m.custom_minimum_size.y = 35
	parent.add_child(m)
	m.item_selected.connect(callback)
	return m

func separator(parent: Control):
	parent.add_child(HSeparator.new())

func make_ui():
	var layer = CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	var left = panel_at(true)
	lbl(left,"SPROUTLINGS",23,true)
	lbl(left,"V0.1  /  YEŞİL VADİ",13)
	stats = lbl(left,"",17,true)
	goal = lbl(left,"",14)
	separator(left)
	lbl(left,"TARLA",19,true)
	crop_menu = menu(left,func(i): selected_crop=i; refresh_ui())
	for c in CROPS:
		crop_menu.add_item(c.name)
	plot_info = lbl(left,"",15)
	action_button = btn(left,"Ekim / Sulama / Hasat",func(): plot_action(selected_plot))
	btn(left,"Tüm açık tarlaları işle",func(): for_all_plots())
	expand_button = btn(left,"4 tarla aç",func(): expand_farm())
	separator(left)
	lbl(left,"YEM ATÖLYESİ",19,true)
	craft_button = btn(left,"Tahıl üret (6 altın)",func(): craft_feed())
	lbl(left,"Kamera: Q/E döndür • Fare tekeri yakınlaş • 1-4 ürün seç",13)
	btn(left,"Kaydet",func(): save_game(); notify("Çiftlik kaydedildi."))
	btn(left,"Yeniden yükle",func(): load_game(); refresh_all(); notify("Kayıt yüklendi."))
	var right = panel_at(false)
	lbl(right,"YARATIKLAR",21,true)
	lbl(right,"Kasalar görev ve seviyelerle kazanılır.",13)
	crate_menu = menu(right,func(i): selected_crate=i; refresh_ui())
	for t in TIERS:
		crate_menu.add_item(t)
	odds_label = lbl(right,"",13)
	open_button = btn(right,"Kasayı aç",func(): open_crate(selected_crate))
	separator(right)
	lbl(right,"KOLEKSİYON",19,true)
	pet_menu = menu(right,func(i): selected_creature=i; refresh_ui())
	pet_info = lbl(right,"",14)
	feed_button = btn(right,"Besle",func(): feed_pet(selected_creature))
	active_button = btn(right,"Görevlendir",func(): toggle_pet(selected_creature))
	lbl(right,"En fazla 2 aktif yaratık. Aç kalırlarsa ölmezler, bonus durur.",13)
	separator(right)
	lbl(right,"V0.1 yerel prototip • Pazar ve takas sonraki sürüm.",13)
	toast = Label.new()
	layer.add_child(toast)
	toast.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast.offset_left = 300
	toast.offset_right = -300
	toast.offset_top = -65
	toast.offset_bottom = -12
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.add_theme_font_size_override("font_size",18)
	toast.add_theme_color_override("font_color",Color("#fff0ba"))
	toast.add_theme_color_override("font_outline_color",Color("#172d2b"))
	toast.add_theme_constant_override("outline_size",7)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE

func notify(message: String):
	if is_instance_valid(toast):
		toast.text = message
		toast_time = 5.0

func refresh_all():
	for i in range(12):
		refresh_plot(i)
	rebuild_pets()
	refresh_ui()

func refresh_plot(i: int):
	var root: Node3D = crop_nodes[i]
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	var p = plots[i]
	var tile: MeshInstance3D = plot_nodes[i]
	tile.material_override = mat(Color("#807c60") if i>=unlocked else (Color("#614630") if p.watered else Color("#9d6a48")))
	if i>=unlocked:
		box_at(root,Vector3(0,0.06,0),Vector3(1.25,0.12,1.25),Color("#8a9a70"))
		return
	for j in range(3):
		box_at(root,Vector3(-0.5+j*0.5,-0.01,0),Vector3(0.035,0.025,1.25),Color("#63432e"))
	if p.crop < 0:
		return
	var c = CROPS[int(p.crop)]
	var ripe = p.remaining <= 0
	var growth = 1.0 if ripe else (0.25+0.75*(1.0-float(p.remaining)/float(c.time)))
	for x in [-0.42,0.42]:
		for z in [-0.42,0.42]:
			var stem = Vector3(x,0.22*growth,z)
			box_at(root,stem,Vector3(0.09,0.44*growth,0.09),Color("#498a46"))
			var leaf = sphere_at(root,stem+Vector3(0.12,0.07,0),Vector3(0.30,0.10,0.13),Color("#6eae54"))
			leaf.rotation_degrees.z = 25
			sphere_at(root,Vector3(x,0.44*growth,z),Vector3(0.30,0.42,0.28)*growth,Color(c.color) if ripe else Color("#91bf64"))
	if ripe:
		sphere_at(root,Vector3(0,0.65,0),Vector3(0.18,0.18,0.18),Color("#fff4a1"))

func pet_model(parent: Node3D, species: int, shiny: bool) -> Node3D:
	var root = Node3D.new()
	parent.add_child(root)
	var r = int(species/2.0)
	var color: Color = COLORS[r]
	if shiny:
		color = Color("#ff9ad6")
	sphere_at(root,Vector3(0,0.38,0),Vector3(0.76,0.66,0.85),color)
	sphere_at(root,Vector3(0,0.58,0.34),Vector3(0.62,0.56,0.55),color.lightened(0.12))
	for x in [-0.18,0.18]:
		sphere_at(root,Vector3(x,0.62,0.58),Vector3(0.16,0.19,0.12),Color("#24363c"))
		sphere_at(root,Vector3(x-0.025,0.66,0.635),Vector3(0.055,0.06,0.04),Color.WHITE)
		sphere_at(root,Vector3(x,0.1,0.28),Vector3(0.23,0.20,0.28),color.darkened(0.15))
		sphere_at(root,Vector3(x,0.1,-0.28),Vector3(0.23,0.20,0.28),color.darkened(0.15))
	if species==0:
		cone_at(root,Vector3(0,0.89,0),0.18,0.42,Color("#60b55b"))
	elif species==1:
		sphere_at(root,Vector3(0,0.83,0),Vector3(0.87,0.29,0.80),Color("#e88a80"))
	elif species%2==0:
		for x in [-0.26,0.26]:
			cone_at(root,Vector3(x,0.86,0.14),0.13,0.45,color.lightened(0.3))
	else:
		for x in [-0.30,0.30]:
			var ear = sphere_at(root,Vector3(x,0.82,0.12),Vector3(0.18,0.53,0.19),color.lightened(0.2))
			ear.rotation_degrees.z = x*75
	if r>=3:
		for j in range(3):
			var a = j*TAU/3
			sphere_at(root,Vector3(cos(a)*0.55,0.8,sin(a)*0.55),Vector3(0.12,0.12,0.12),color.lightened(0.5))
	return root

func rebuild_pets():
	for child in pets_root.get_children():
		child.queue_free()
	pet_nodes.clear()
	var j = 0
	for p in creatures:
		if not p.active:
			continue
		var n = pet_model(pets_root,int(p.species),bool(p.shiny))
		n.position = Vector3(-1.1+j*1.65,0,3.35)
		n.rotation_degrees.y = 35+j*20
		n.scale = Vector3.ONE*(0.75 if p.growth<100 else (0.9 if p.growth<300 else 1.05))
		pet_nodes.append(n)
		j += 1
	pet_menu.clear()
	for i in range(creatures.size()):
		var p = creatures[i]
		pet_menu.add_item(SPECIES[int(p.species)]+(" ★" if p.shiny else ""))
	if creatures.size()>0:
		selected_creature = clampi(selected_creature,0,creatures.size()-1)
		pet_menu.select(selected_creature)

func active_capacity() -> int:
	return 2

func crop_speed_modifier(_i: int) -> float:
	return 1.0

func bonus(kind: String) -> float:
	var total = 0.0
	var same = {}
	for p in creatures:
		if not p.active or p.hunger<=0:
			continue
		var id = int(p.species)
		var mode = "speed" if id in [0,4,7,10] else ("yield" if id in [1,3,6,8,11] else "other")
		if mode!=kind:
			continue
		if id==6 and day_time<600:
			continue
		var r = int(id/2.0)
		var value = [0.05,0.08,0.12,0.16,0.20,0.24][r]
		var stage = 0.5 if p.growth<100 else (0.75 if p.growth<300 else 1.0)
		var n = int(same.get(id,0))
		same[id] = n+1
		total += value*stage*(1.0 if n==0 else (0.5 if n==1 else 0.25))
	return minf(total,0.4)

func refresh_ui():
	stats.text = "ALTIN  %d G\nSEVİYE  %d  •  XP %d/%d\nTARLA  %d/12   Hasat %d" % [gold,level,xp,100+30*(level-1),unlocked,harvests]
	goal.text = "Görev: İlk hasadı yap! (+40 G, Ahşap kasa)" if harvests==0 else ("Görev: 4 hasat tamamla! (+25 G, kasa)" if harvests<4 else "Hedef: Çiftliği büyüt • Seviye 5'te Demir kasa")
	var p = plots[selected_plot]
	plot_info.text = "Tarla %d  •  " % (selected_plot+1)
	if selected_plot>=unlocked:
		plot_info.text += "Kilitli"
		action_button.text = "Önce tarlayı aç"
	elif p.crop<0:
		plot_info.text += "Boş"
		action_button.text = "%s ek (%d G)" % [CROPS[selected_crop].name,CROPS[selected_crop].cost]
	elif not p.watered:
		plot_info.text += "Su bekliyor"
		action_button.text = "Sula"
	elif p.remaining>0:
		plot_info.text += "%s • %ds" % [CROPS[int(p.crop)].name,ceili(p.remaining)]
		action_button.text = "Büyüyor..."
	else:
		plot_info.text += "Hasada hazır"
		action_button.text = "Hasat et"
	action_button.disabled = selected_plot>=unlocked or (p.crop>=0 and p.watered and p.remaining>0)
	expand_button.text = "4 tarla aç (%d G)" % (60 if unlocked==4 else 140)
	expand_button.disabled = unlocked>=12 or gold<(60 if unlocked==4 else 140)
	for i in range(CROPS.size()):
		crop_menu.set_item_disabled(i,level<CROPS[i].level)
	for i in range(TIERS.size()):
		crate_menu.set_item_text(i,"%s kasa  ×%d" % [TIERS[i],crates[i]])
		crate_menu.set_item_disabled(i,level<LOCK_LEVEL[i])
	var t = selected_crate
	var parts = []
	var weights = effective_odds(t)
	var total = 0.0
	for w in weights:
		total += w
	for i in range(6):
		if weights[i]>0:
			parts.append("%s %.1f%%" % [RARITIES[i],100.0*weights[i]/total])
	odds_label.text = " / ".join(parts)+"\nRare+ garanti: %d/%d" % [pity_r[t],PITY_R[t]]
	if PITY_L[t]>0:
		odds_label.text += "  L: %d/%d" % [pity_l[t],PITY_L[t]]
	if t==5:
		odds_label.text += "  M: %d/40" % pity_m
	open_button.disabled = crates[t]<=0 or level<LOCK_LEVEL[t]
	craft_button.disabled = gold<6 or level<3
	craft_button.text = "Tahıl üret (6 G) • %d" % saved_feed
	feed_button.disabled = creatures.is_empty()
	active_button.disabled = creatures.is_empty()
	if creatures.is_empty():
		pet_info.text = "Henüz yaratık yok. İlk hasadını tamamla!"
	else:
		var c = creatures[selected_creature]
		var id = int(c.species)
		var r = int(id/2.0)
		var stage = "Yavru" if c.growth<100 else ("Genç" if c.growth<300 else "Yetişkin")
		pet_info.text = "%s • %s\n%s / %s\n%s • XP %d\n%s • Tokluk %ds\nHız +%d%% • Verim +%d%%" % [SPECIES[id],RARITIES[r],ELEMENTS[id],TRAITS[id],stage,int(c.growth),"Aktif" if c.active else "Koleksiyon",ceili(c.hunger),roundi(bonus("speed")*100),roundi(bonus("yield")*100)]
		feed_button.text = "Besle (%s)" % ("başlangıç yemi: "+str(starter_feed) if starter_feed>0 else (FEED_NAMES[r]+" "+str(FEED_COST[r])+" G"))
		active_button.text = "Görevden al" if c.active else "Görevlendir"
	selection_ring.position = plot_pos(selected_plot)+Vector3(0,0.16,0)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT:
			var o = cam.project_ray_origin(event.position)
			var d = cam.project_ray_normal(event.position)
			var point = Plane(Vector3.UP,0.24).intersects_ray(o,d)
			if point!=null:
				for i in range(12):
					var p = plot_pos(i)
					if absf(point.x-p.x)<0.8 and absf(point.z-p.z)<0.8:
						selected_plot = i
						refresh_ui()
						break
		elif event.button_index==MOUSE_BUTTON_WHEEL_UP:
			cam.size = maxf(10,cam.size-0.8)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			cam.size = minf(23,cam.size+0.8)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_Q,KEY_E]:
			cam.position = cam.position.rotated(Vector3.UP,0.25 if event.keycode==KEY_Q else -0.25)
			cam.look_at(Vector3(0,0,-0.6))
		if event.keycode>=KEY_1 and event.keycode<=KEY_4:
			var i = event.keycode-KEY_1
			if level>=CROPS[i].level:
				selected_crop=i
				crop_menu.select(i)
				refresh_ui()
		if event.keycode==KEY_SPACE:
			plot_action(selected_plot)

func plot_action(i: int):
	if i>=unlocked:
		notify("Bu tarla kilitli.")
		return
	var p = plots[i]
	if p.crop<0:
		var c = CROPS[selected_crop]
		if level<c.level or gold<c.cost:
			notify("Seviye veya altın yetersiz.")
			return
		gold -= c.cost
		p.crop = selected_crop
		p.remaining = c.time
		p.watered = false
	elif not p.watered:
		p.watered = true
	elif p.remaining<=0:
		var c = CROPS[int(p.crop)]
		yield_carry += c.sale*bonus("yield")
		var extra = floori(yield_carry)
		yield_carry -= extra
		var value = int(c.sale)+extra
		gold += value
		harvests += 1
		xp += 25
		p.crop = -1
		p.watered = false
		if harvests==1:
			gold += 40
			crates[0] += 1
			notify("İlk hasat! +40 altın ve Ahşap kasa.")
		elif harvests==4:
			gold += 25
			crates[0] += 1
			notify("Görev tamamlandı! +25 altın ve kasa.")
		elif harvests%10==0:
			crates[0] += 1
			notify("Hasat görevi: Ahşap kasa kazandın.")
		else:
			notify("+%d altın • Hasat!" % value)
		while xp>=100+30*(level-1):
			xp-=100+30*(level-1)
			level+=1
			for t in range(5):
				if level==LOCK_LEVEL[t]:
					crates[t]+=1
			if level%3==0:
				crates[0]+=1
			notify("Seviye %d! Yeni ödüller açıldı." % level)
	refresh_plot(i)
	refresh_ui()

func for_all_plots():
	for i in range(unlocked):
		plot_action(i)

func expand_farm():
	var cost = 60 if unlocked==4 else 140
	if unlocked>=12 or gold<cost:
		return
	gold-=cost
	unlocked+=4
	refresh_all()
	notify("4 yeni tarla açıldı!")

func effective_odds(t: int) -> Array:
	var min_r = 0
	if pity_r[t]+1>=PITY_R[t]:
		min_r=2
	if PITY_L[t]>0 and pity_l[t]+1>=PITY_L[t]:
		min_r=4
	if t==5 and pity_m+1>=40:
		min_r=5
	var w = ODDS[t].duplicate()
	for i in range(min_r):
		w[i]=0
	return w

func open_crate(t: int):
	if crates[t]<=0 or level<LOCK_LEVEL[t]:
		return
	var w = effective_odds(t)
	var r = rng.rand_weighted(PackedFloat32Array(w))
	crates[t]-=1
	pity_r[t]=0 if r>=2 else pity_r[t]+1
	pity_l[t]=0 if r>=4 else pity_l[t]+1
	if t==5:
		pity_m=0 if r==5 else pity_m+1
	var id = r*2+rng.randi_range(0,1)
	var active_count = 0
	for p in creatures:
		if p.active:
			active_count+=1
	var shiny = rng.randf()<0.01
	creatures.append({"species":id,"shiny":shiny,"growth":0.0,"hunger":0.0,"active":active_count<active_capacity(),"production":0.0})
	selected_creature=creatures.size()-1
	refresh_all()
	notify("KASA AÇILDI: %s • %s%s" % [SPECIES[id],RARITIES[r]," ★ SHINY" if shiny else ""])
	var flash = ColorRect.new()
	flash.color = Color(COLORS[r],0.25)
	flash.mouse_filter=Control.MOUSE_FILTER_IGNORE
	get_node("HUD").add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tw = create_tween()
	tw.tween_property(flash,"modulate:a",0.0,0.7)
	tw.tween_callback(flash.queue_free)

func craft_feed():
	if level<3 or gold<6:
		return
	gold-=6
	saved_feed+=1
	refresh_ui()
	notify("Tahıl yemi üretildi.")

func feed_pet(i: int):
	if i>=creatures.size():
		return
	var p = creatures[i]
	if p.hunger>0:
		notify("Yaratık zaten tok.")
		return
	var r = int(p.species/2.0)
	if starter_feed>0:
		starter_feed-=1
		if p.growth==0:
			p.growth+=50
	elif r==0 and saved_feed>0:
		saved_feed-=1
	elif gold>=FEED_COST[r]:
		gold-=FEED_COST[r]
	else:
		notify("Yem için altın yetersiz.")
		return
	p.hunger=1800.0
	refresh_all()
	notify(SPECIES[int(p.species)]+" beslendi!")

func toggle_pet(i: int):
	if i>=creatures.size():
		return
	var p = creatures[i]
	if p.active:
		p.active=false
	else:
		var count = 0
		for c in creatures:
			if c.active:
				count+=1
		if count>=active_capacity():
			notify("Aktif yuvalar dolu (%d)." % active_capacity())
			return
		p.active=true
	refresh_all()

func _process(delta):
	if testing:
		return
	day_time=fmod(day_time+delta,1200.0)
	sun.light_energy=0.65+0.65*maxf(0.0,sin(day_time/1200.0*TAU))
	for i in range(unlocked):
		var p=plots[i]
		if p.crop>=0 and p.watered and p.remaining>0:
			p.remaining=maxf(0.0,p.remaining-delta*(1.0+bonus("speed"))*crop_speed_modifier(i))
			if p.remaining<=0:
				refresh_plot(i)
	var changed_stage = false
	for p in creatures:
		if p.hunger>0 and p.active:
			var old_stage = 0 if p.growth<100 else (1 if p.growth<300 else 2)
			p.hunger=maxf(0.0,p.hunger-delta)
			p.growth+=delta*25.0/1800.0
			var new_stage = 0 if p.growth<100 else (1 if p.growth<300 else 2)
			if old_stage!=new_stage: changed_stage=true
			p.production=float(p.get("production",0))+delta
			if p.production>=1800.0:
				p.production-=1800.0
				if p.species==5: crystal_dust+=1
				if p.species==9: moon_essence+=1
	if changed_stage:
		rebuild_pets()
	visual_clock+=delta
	if visual_clock>=5.0:
		visual_clock=0.0
		for i in range(unlocked):
			if plots[i].crop>=0 and plots[i].watered and plots[i].remaining>0:
				refresh_plot(i)
	for i in range(pet_nodes.size()):
		var n = pet_nodes[i]
		n.position.y=0.06+sin(Time.get_ticks_msec()/500.0+i)*0.055
		n.rotation.y=0.65+sin(Time.get_ticks_msec()/1200.0+i)*0.25
	update_clock+=delta
	save_clock+=delta
	if update_clock>=0.5:
		update_clock=0
		refresh_ui()
	if save_clock>=10:
		save_clock=0
		save_game()
	if toast_time>0:
		toast_time-=delta
		if toast_time<=0:
			toast.text=""

func save_game(path: String = SAVE, allow_testing: bool = false):
	if testing and not allow_testing:
		return
	var f=FileAccess.open(path,FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version":1,"gold":gold,"level":level,"xp":xp,"harvests":harvests,"unlocked":unlocked,"starter_feed":starter_feed,"saved_feed":saved_feed,"crates":crates,"pity_r":pity_r,"pity_l":pity_l,"pity_m":pity_m,"plots":plots,"creatures":creatures,"crystal_dust":crystal_dust,"moon_essence":moon_essence,"yield_carry":yield_carry}))

func load_game(path: String = SAVE):
	if not FileAccess.file_exists(path):
		return
	var f=FileAccess.open(path,FileAccess.READ)
	if not f:
		return
	var data=JSON.parse_string(f.get_as_text())
	if not data is Dictionary or data.get("version")!=1 or data.get("plots",[]).size()!=12:
		return
	gold=int(data.get("gold",100))
	level=int(data.get("level",1))
	xp=int(data.get("xp",0))
	harvests=int(data.get("harvests",0))
	unlocked=int(data.get("unlocked",4))
	starter_feed=int(data.get("starter_feed",3))
	saved_feed=int(data.get("saved_feed",0))
	crates=data.get("crates",[0,0,0,0,0,0])
	pity_r=data.get("pity_r",[0,0,0,0,0,0])
	pity_l=data.get("pity_l",[0,0,0,0,0,0])
	pity_m=int(data.get("pity_m",0))
	plots=data.plots
	creatures=data.get("creatures",[])
	crystal_dust=int(data.get("crystal_dust",0))
	moon_essence=int(data.get("moon_essence",0))
	yield_carry=float(data.get("yield_carry",0.0))

func _notification(what):
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func run_tests():
	var failures = []
	for i in range(6):
		var sum = 0.0
		for w in ODDS[i]:
			sum+=w
		if not is_equal_approx(sum,100.0): failures.append("odds "+str(i))
	plot_action(0)
	if plots[0].crop!=0 or gold!=98: failures.append("plant")
	plot_action(0)
	if not plots[0].watered: failures.append("water")
	plots[0].remaining=0
	plot_action(0)
	if harvests!=1 or crates[0]!=1 or gold!=143: failures.append("harvest reward")
	pity_r[0]=9
	open_crate(0)
	if creatures.size()!=1 or int(creatures[0].species/2.0)<2 or pity_r[0]!=0: failures.append("rare pity")
	feed_pet(0)
	if creatures[0].hunger!=1800 or starter_feed!=2: failures.append("feed")
	expand_farm()
	if unlocked!=8 or gold!=83: failures.append("expand")
	level=40
	crates[4]=1
	pity_l[4]=7
	open_crate(4)
	if int(creatures.back().species/2.0)!=4: failures.append("legendary pity")
	crates[5]=1
	pity_m=39
	open_crate(5)
	if int(creatures.back().species/2.0)!=5: failures.append("mythic pity")
	if creatures.back().active: failures.append("active limit")
	var test_path = "user://sproutlings_selftest_"+str(Time.get_ticks_usec())+".json"
	save_game(test_path,true)
	reset_data()
	load_game(test_path)
	if gold!=83 or unlocked!=8 or creatures.size()!=3 or level!=40: failures.append("save reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	if failures.is_empty():
		print("SPROUTLINGS SELF-TEST PASS: odds, plant, water, harvest, rewards, rare/legendary/mythic pity, feed, expansion, slots, save/reload")
		get_tree().quit(0)
	else:
		push_error("SELF-TEST FAIL: "+str(failures))
		get_tree().quit(1)
