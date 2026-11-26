extends "res://farm.gd"

const SAVE_V02 = "user://sproutlings_v02.json"
const ITEMS = ["Buğday","Havuç","Mısır","Orman meyvesi","Ejder biberi","Kristal meyve","Ay balı","Kristal tozu","Ay özü"]
const ITEM_PRICES = [5,10,13,20,35,55,60,5,15]
const RECIPES = [{0:1},{1:1},{2:1,1:1},{4:1,7:1},{5:1,8:1},{6:1,7:1,8:1}]
const FEES = [1,2,2,3,5,8]
const DECOR_NAMES = ["Çiçek bahçesi","Fenerli bank","Rüzgâr değirmeni","Kristal çeşme"]
const DECOR_PRICES = [25,45,90,150]
var stock: Array = [0,0,0,0,0,0,0,0,0]
var food_stock: Array = [0,0,0,0,0,0]
var decorations: Array = [false,false,false,false]
var store_harvest = false
var inventory_window: Window
var decor_window: Window
var reveal_window: Window
var inventory_text: Label
var item_select: OptionButton
var recipe_select: OptionButton
var decor_select: OptionButton
var decor_text: Label
var mode_button: Button
var decor_root: Node3D
var preview_world: Node3D
var preview_pet: Node3D
var reveal_label: Label
var reveal_view: SubViewportContainer
var reveal_chest: Label
var reveal_busy = false
var feed_anim = 0.0
var anim_phase = 0.0
var garden_windmill: Node3D
var inventory_open = false
var reveal_tween: Tween
var chest_root: Node3D
var chest_lid: Node3D
var chest_sparks: Node3D
var chime: AudioStreamPlayer

func _ready():
	super._ready()
	if "--visual-test" in OS.get_cmdline_user_args():
		testing=true
		call_deferred("visual_test")

func reset_data():
	super.reset_data()
	stock = [0,0,0,0,0,0,0,0,0]
	food_stock = [0,0,0,0,0,0]
	decorations = [false,false,false,false]
	store_harvest = false

func make_world():
	super.make_world()
	var world = get_child(0) as WorldEnvironment
	if world:
		world.environment.ambient_light_color = Color("#e0edeb")
		world.environment.ambient_light_energy = 0.85
		world.environment.background_color = Color("#b6dce4")
	sun.light_color = Color("#fff1d3")
	sun.shadow_bias = 0.08
	sun.directional_shadow_max_distance = 38
	cam.size = 15.4
	# Grass terraces, stone paths and farm sign.
	box_at(self,Vector3(0,-1.0,0),Vector3(15.4,0.32,13.4),Color("#52745b"))
	for i in range(11):
		var x = -5.2+i*1.0
		var stone = box_at(self,Vector3(x,0.005,3.28),Vector3(0.72,0.045,0.73),Color("#e5d6ad") if i%2==0 else Color("#c9bd99"))
		stone.rotation.y = sin(i*2.6)*0.13
	for i in range(8):
		var z = -3.3+i*0.84
		box_at(self,Vector3(-5.52,0.007,z),Vector3(0.68,0.045,0.60),Color("#d9c9a4"))
	for i in range(9):
		var x = -6.4+i*1.55
		for z in [-5.9,5.5]:
			flower_cluster(self,Vector3(x,0,z),Color("#f3a39e") if i%2==0 else Color("#f9dc7b"))
	for i in range(8):
		var a = i*TAU/8
		var p = Vector3(5.1+cos(a)*0.8,0.015,-2.9+sin(a)*0.55)
		sphere_at(self,p,Vector3(0.26,0.035,0.20),Color("#83bd64"))
		if i%3==0:
			sphere_at(self,p+Vector3(0,0.08,0),Vector3(0.15,0.12,0.15),Color("#f7bddc"))
	for z in [-2.2,2.2]:
		box_at(self,Vector3(4.0,0.32,z),Vector3(0.13,0.68,0.13),Color("#73533e"))
		box_at(self,Vector3(4.0,0.70,z),Vector3(0.23,0.29,0.23),Color("#f5d88b"))
		cone_at(self,Vector3(4.0,0.91,z),0.18,0.18,Color("#53635a"))
	for i in range(4):
		var x = -4.7+i*0.29
		box_at(self,Vector3(x,0.14,-1.9),Vector3(0.26,0.30,0.29),Color("#ba8551"))
	box_at(self,Vector3(0,0.45,5.0),Vector3(0.12,0.90,0.12),Color("#79553d"))
	box_at(self,Vector3(0,0.83,5.0),Vector3(1.55,0.45,0.15),Color("#d7b17a"))
	var sign_text = Label3D.new()
	sign_text.text = "SPROUTLINGS"
	sign_text.font_size = 38
	sign_text.pixel_size = 0.008
	sign_text.modulate = Color("#493b32")
	sign_text.outline_size = 0
	sign_text.position = Vector3(0,0.83,5.09)
	add_child(sign_text)
	decor_root = Node3D.new()
	add_child(decor_root)
	rebuild_decor()

func flower_cluster(parent: Node3D, pos: Vector3, color: Color):
	for i in range(3):
		var p = pos+Vector3((i-1)*0.15,0,0.09*sin(i*2))
		box_at(parent,p+Vector3(0,0.12,0),Vector3(0.035,0.24,0.035),Color("#4c9356"))
		sphere_at(parent,p+Vector3(0,0.26,0),Vector3(0.18,0.10,0.18),color)
		sphere_at(parent,p+Vector3(0,0.30,0),Vector3(0.07,0.055,0.07),Color("#e5b94a"))

func rebuild_decor():
	if not is_instance_valid(decor_root):
		return
	for c in decor_root.get_children():
		decor_root.remove_child(c)
		c.queue_free()
	garden_windmill = null
	if decorations[0]:
		box_at(decor_root,Vector3(5.35,0.025,0.2),Vector3(2.0,0.16,1.8),Color("#936744"))
		for i in range(9):
			flower_cluster(decor_root,Vector3(4.65+(i%3)*0.65,0.10,-0.4+int(i/3.0)*0.62),[Color("#ec8299"),Color("#d7a8ee"),Color("#f6d46f")][i%3])
	if decorations[1]:
		var p = Vector3(-5.0,0,4.55)
		box_at(decor_root,p+Vector3(0,0.36,0),Vector3(1.5,0.12,0.5),Color("#c69763"))
		box_at(decor_root,p+Vector3(0,0.68,-0.21),Vector3(1.5,0.38,0.1),Color("#c69763"))
		for x in [-0.56,0.56]:
			box_at(decor_root,p+Vector3(x,0.16,0),Vector3(0.12,0.32,0.48),Color("#53645b"))
		box_at(decor_root,p+Vector3(1.05,0.55,0),Vector3(0.12,1.1,0.12),Color("#53645b"))
		sphere_at(decor_root,p+Vector3(1.05,1.18,0),Vector3(0.35,0.38,0.35),Color("#ffe5a1"))
	if decorations[2]:
		var p = Vector3(3.3,0,-4.7)
		var tower = CylinderMesh.new()
		tower.top_radius = 0.43
		tower.bottom_radius = 0.70
		tower.height = 2.2
		tower.radial_segments = 8
		mesh_at(decor_root,tower,p+Vector3(0,1.1,0),Color("#f1dfbf"))
		cone_at(decor_root,p+Vector3(0,2.5,0),0.7,0.8,Color("#9f6052"))
		garden_windmill = Node3D.new()
		decor_root.add_child(garden_windmill)
		garden_windmill.position = p+Vector3(0,1.8,0.54)
		for i in range(4):
			var arm = Node3D.new()
			garden_windmill.add_child(arm)
			arm.rotation.z = i*PI/2
			box_at(arm,Vector3(0,0.65,0),Vector3(0.13,1.3,0.08),Color("#6d5544"))
			box_at(arm,Vector3(0.16,0.95,0),Vector3(0.32,0.72,0.08),Color("#e8d8b8"))
	if decorations[3]:
		var p = Vector3(5.25,0,3.6)
		var basin = CylinderMesh.new()
		basin.top_radius=0.83
		basin.bottom_radius=0.75
		basin.height=0.24
		basin.radial_segments=12
		mesh_at(decor_root,basin,p+Vector3(0,0.12,0),Color("#a9c5bc"))
		sphere_at(decor_root,p+Vector3(0,0.25,0),Vector3(1.28,0.1,1.28),Color("#6ed2dd"))
		gem(decor_root,p+Vector3(0,0.74,0),0.38,0.95,Color("#a5e6f3"))
		for i in range(6):
			var a=i*TAU/6
			gem(decor_root,p+Vector3(cos(a)*0.51,0.43,sin(a)*0.51),0.12,0.33,Color("#d4b6f4"))

func gem(parent: Node3D, p: Vector3, radius: float, height: float, color: Color):
	var shape = CylinderMesh.new()
	shape.top_radius=0.0
	shape.bottom_radius=radius
	shape.height=height*0.58
	shape.radial_segments=5
	mesh_at(parent,shape,p+Vector3(0,height*0.18,0),color)
	var lower = mesh_at(parent,shape,p-Vector3(0,height*0.18,0),color.darkened(0.18))
	lower.rotation.x=PI

func pet_model(parent: Node3D, species: int, shiny: bool) -> Node3D:
	var root=Node3D.new()
	parent.add_child(root)
	var palette = [Color("#b9a27a"),Color("#f2a19b"),Color("#72cddb"),Color("#81bd67"),Color("#db7650"),Color("#87b9dd"),Color("#665d99"),Color("#d0e8e9"),Color("#edb74d"),Color("#adbde8"),Color("#6261bd"),Color("#6aa47c")]
	var color: Color=palette[species]
	if shiny: color=Color("#ef91cc").lerp(color,0.25)
	var body_scale = Vector3(0.78,0.70,0.84)
	if species in [1,2,6,9,10]: body_scale=Vector3(0.73,0.82,0.68)
	if species==11: body_scale=Vector3(1.0,0.52,0.96)
	if species==5: body_scale=Vector3(0.90,0.55,0.75)
	sphere_at(root,Vector3(0,0.43,0),body_scale,color)
	sphere_at(root,Vector3(0,0.61,0.34),Vector3(0.63,0.56,0.58),color.lightened(0.10))
	for x in [-0.17,0.17]:
		sphere_at(root,Vector3(x,0.66,0.59),Vector3(0.175,0.20,0.115),Color("#25353c"))
		sphere_at(root,Vector3(x-0.029,0.705,0.64),Vector3(0.062,0.067,0.036),Color.WHITE)
		sphere_at(root,Vector3(x,0.55,0.60),Vector3(0.13,0.06,0.035),color.lightened(0.4))
	for x in [-0.24,0.24]:
		for z in [-0.24,0.24]:
			var foot=sphere_at(root,Vector3(x,0.10,z),Vector3(0.24,0.19,0.27),color.darkened(0.18))
			foot.name="Foot"+str(root.get_child_count())
	match species:
		0:
			box_at(root,Vector3(0,0.85,0),Vector3(0.07,0.34,0.07),Color("#5d9854"))
			for x in [-0.16,0.16]:
				var leaf=sphere_at(root,Vector3(x,1.0,0),Vector3(0.30,0.11,0.18),Color("#7bc763"))
				leaf.rotation.z=x*2.0
		1:
			sphere_at(root,Vector3(0,0.88,-0.04),Vector3(1.03,0.31,0.93),Color("#c85b67") if not shiny else Color("#a178e4"))
			for i in range(5):
				var a=i*TAU/5
				sphere_at(root,Vector3(cos(a)*0.31,1.015,sin(a)*0.27),Vector3(0.16,0.07,0.14),Color("#ffe7cc"))
		2:
			cone_at(root,Vector3(0,0.98,0),0.24,0.44,color.lightened(0.2))
			for x in [-0.38,0.38]:
				var fin=sphere_at(root,Vector3(x,0.53,0),Vector3(0.17,0.42,0.25),Color("#a5e5e9"))
				fin.rotation.z=x
		3:
			for x in [-0.28,0.28]:
				var ear=sphere_at(root,Vector3(x,0.94,0.18),Vector3(0.18,0.56,0.17),color.lightened(0.3))
				ear.rotation.z=x*-1.1
			for i in range(3):
				var tail=sphere_at(root,Vector3((i-1)*0.18,0.58,-0.59),Vector3(0.25,0.15,0.55),Color("#4b9960"))
				tail.rotation.y=(i-1)*0.45
		4:
			for i in range(3):
				cone_at(root,Vector3(0,0.77,-0.35+i*0.22),0.16,0.43,Color("#f5b34e"))
			cone_at(root,Vector3(0,0.46,-0.62),0.21,0.52,Color("#ed6748"))
		5:
			for i in range(5):
				gem(root,Vector3((i%2-0.5)*0.42,0.77,-0.34+i*0.17),0.20,0.52,Color("#a6dfe9") if i%2==0 else Color("#8c87e6"))
		6:
			for x in [-0.48,0.48]:
				var wing=sphere_at(root,Vector3(x,0.56,-0.08),Vector3(0.70,0.14,0.49),Color("#514b87"))
				wing.name="WingL" if x<0 else "WingR"
				wing.rotation.z=x*0.4
			for x in [-0.2,0.2]:
				cone_at(root,Vector3(x,0.94,0.17),0.12,0.37,Color("#c4b9ef"))
		7:
			for i in range(5):
				sphere_at(root,Vector3((i-2)*0.17,0.82,-0.08),Vector3(0.32,0.30,0.34),Color("#f5faf2"))
			for x in [-0.24,0.24]:
				cone_at(root,Vector3(x,1.02,0.20),0.12,0.47,Color("#c7b5a4"))
		8:
			var disc=CylinderMesh.new()
			disc.top_radius=0.46
			disc.bottom_radius=0.46
			disc.height=0.10
			disc.radial_segments=12
			var halo=mesh_at(root,disc,Vector3(0,0.88,-0.31),Color("#ffd97a"))
			halo.rotation.x=PI/2
			for i in range(8):
				var a=i*TAU/8
				gem(root,Vector3(cos(a)*0.57,0.88+sin(a)*0.57,-0.31),0.08,0.19,Color("#ffb745"))
		9:
			for i in range(7):
				var a=-PI*0.72+i*PI*1.44/6
				sphere_at(root,Vector3(cos(a)*0.43-0.13,0.77+sin(a)*0.43,-0.28),Vector3(0.22,0.22,0.19),Color("#e0e4f8"))
		10:
			var ring=TorusMesh.new()
			ring.inner_radius=0.48
			ring.outer_radius=0.57
			ring.rings=24
			var n=mesh_at(root,ring,Vector3(0,0.58,0),Color("#c5a6f7"))
			n.rotation.z=0.55
			for i in range(5):
				var a=i*TAU/5
				gem(root,Vector3(cos(a)*0.5,0.68,sin(a)*0.5),0.08,0.21,Color("#f8d7f1"))
		11:
			for i in range(3):
				var p=Vector3((i-1)*0.24,0.65,-0.26)
				box_at(root,p+Vector3(0,0.12,0),Vector3(0.08,0.24,0.08),Color("#795d45"))
				cone_at(root,p+Vector3(0,0.42,0),0.24,0.43,Color("#9ac775"))
	if species>=6:
		var orbit=Node3D.new()
		orbit.name="Orbit"
		root.add_child(orbit)
		for i in range(3 if species<8 else 5):
			var a=i*TAU/(3 if species<8 else 5)
			var spark=sphere_at(orbit,Vector3(cos(a)*0.67,0.8+0.12*sin(a*2),sin(a)*0.67),Vector3(0.11,0.11,0.11),color.lightened(0.65))
			var m=spark.material_override as StandardMaterial3D
			m.emission_enabled=true
			m.emission=color.lightened(0.3)
			m.emission_energy_multiplier=1.1
	return root

func make_ui():
	super.make_ui()
	var layer=get_node("HUD")
	var bar=HBoxContainer.new()
	layer.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bar.offset_left=-235
	bar.offset_right=235
	bar.offset_top=12
	bar.offset_bottom=52
	bar.alignment=BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation",8)
	btn(bar,"Envanter [I]",func(): show_inventory())
	btn(bar,"Dekorasyon [B]",func(): show_decor())
	mode_button=btn(bar,"Hasat: Sat",func(): store_harvest=not store_harvest; refresh_ui())
	# Rewrite the old sidebar labels and use inventory workshop.
	for n in layer.get_children():
		if n is PanelContainer:
			for child in n.get_child(0).get_children():
				if child is Label:
					if child.text.begins_with("V0.1"):
						child.text="V0.2  /  YEŞİL VADİ" if child.text.contains("V0.1  /") else "Yerel prototip • Pazar ve takas sonraki sürüm."
	inventory_window=Window.new()
	inventory_window.title="Çiftlik envanteri ve yem atölyesi"
	inventory_window.size=Vector2i(620,610)
	inventory_window.exclusive=true
	inventory_window.unresizable=true
	layer.add_child(inventory_window)
	inventory_window.hide()
	inventory_window.close_requested.connect(func(): inventory_window.hide())
	var iv=window_content(inventory_window)
	lbl(iv,"DEPO & YEM ATÖLYESİ",24,true)
	inventory_text=lbl(iv,"",15)
	separator(iv)
	item_select=menu(iv,func(_i): pass)
	for i in range(ITEMS.size()):
		item_select.add_item(ITEMS[i])
	var actions=HBoxContainer.new()
	iv.add_child(actions)
	btn(actions,"1 sat",func(): sell_item(item_select.selected,1))
	btn(actions,"Tümünü sat",func(): sell_item(item_select.selected,9999))
	btn(actions,"NPC'den 1 al",func(): buy_item(item_select.selected))
	lbl(iv,"Üretim: malzemeler + atölye ücreti",15,true)
	recipe_select=menu(iv,func(_i): pass)
	for i in range(6):
		var parts=[]
		for k in RECIPES[i]:
			parts.append(str(RECIPES[i][k])+" "+ITEMS[k])
		recipe_select.add_item(FEED_NAMES[i]+" | "+", ".join(parts)+" + "+str(FEES[i])+" G")
	btn(iv,"Seçilen yemi üret",func(): craft_recipe(recipe_select.selected))
	btn(iv,"Kapat",func(): inventory_window.hide())
	decor_window=Window.new()
	decor_window.title="Çiftlik dekorasyonları"
	decor_window.size=Vector2i(450,315)
	decor_window.exclusive=true
	layer.add_child(decor_window)
	decor_window.hide()
	decor_window.close_requested.connect(func(): decor_window.hide())
	var dv=window_content(decor_window)
	lbl(dv,"ÇİFTLİĞİNİ KİŞİSELLEŞTİR",21,true)
	decor_text=lbl(dv,"",15)
	decor_select=menu(dv,func(_i): pass)
	for i in range(4):
		decor_select.add_item(DECOR_NAMES[i]+" • "+str(DECOR_PRICES[i])+" G")
	btn(dv,"Satın al ve yerleştir",func(): purchase_decor(decor_select.selected))
	btn(dv,"Kapat",func(): decor_window.hide())
	reveal_window=Window.new()
	reveal_window.title="Yeni yaratık keşfedildi!"
	reveal_window.size=Vector2i(480,500)
	reveal_window.exclusive=true
	reveal_window.unresizable=true
	layer.add_child(reveal_window)
	reveal_window.hide()
	reveal_window.close_requested.connect(close_reveal)
	var rv=window_content(reveal_window)
	reveal_chest=lbl(rv,"KASA AÇILIYOR",25,true)
	reveal_chest.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	reveal_view=SubViewportContainer.new()
	reveal_view.custom_minimum_size=Vector2(400,280)
	reveal_view.stretch=true
	rv.add_child(reveal_view)
	var viewport=SubViewport.new()
	viewport.own_world_3d=true
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
	reveal_view.add_child(viewport)
	preview_world=Node3D.new()
	viewport.add_child(preview_world)
	var light=DirectionalLight3D.new()
	preview_world.add_child(light)
	light.rotation_degrees=Vector3(-45,-30,0)
	light.light_energy=1.7
	var env=WorldEnvironment.new()
	var environment=Environment.new()
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("#f5e1d8")
	environment.ambient_light_energy=0.85
	env.environment=environment
	preview_world.add_child(env)
	var camera=Camera3D.new()
	preview_world.add_child(camera)
	camera.position=Vector3(2,1.7,3.4)
	camera.look_at(Vector3(0,0.65,0))
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=2.3
	camera.current=true
	chime=AudioStreamPlayer.new()
	add_child(chime)
	chime.volume_db=-14
	reveal_label=lbl(rv,"",22,true)
	reveal_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	btn(rv,"Koleksiyona dön / Atla",close_reveal)

func window_content(w: Window) -> VBoxContainer:
	var panel=PanelContainer.new()
	w.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style=StyleBoxFlat.new()
	style.bg_color=Color("#203b35")
	style.content_margin_left=20
	style.content_margin_right=20
	style.content_margin_top=16
	style.content_margin_bottom=16
	panel.add_theme_stylebox_override("panel",style)
	var v=VBoxContainer.new()
	panel.add_child(v)
	v.add_theme_constant_override("separation",10)
	return v

func show_inventory():
	refresh_ui()
	inventory_window.popup_centered()

func show_decor():
	refresh_ui()
	decor_window.popup_centered()

func quantity(i: int) -> int:
	if i==7: return crystal_dust
	if i==8: return moon_essence
	return int(stock[i])

func change_item(i: int, delta: int):
	if i==7: crystal_dust+=delta
	elif i==8: moon_essence+=delta
	else: stock[i]+=delta

func sell_item(i: int, amount: int):
	var n=mini(quantity(i),amount)
	if n<=0: return
	change_item(i,-n)
	gold+=n*ITEM_PRICES[i]
	refresh_ui()
	notify("%s satıldı: +%d G" % [ITEMS[i],n*ITEM_PRICES[i]])

func buy_item(i: int):
	var price=ceili(ITEM_PRICES[i]*1.25)
	if gold<price:
		notify("Altın yetersiz.")
		return
	gold-=price
	change_item(i,1)
	refresh_ui()

func craft_recipe(r: int):
	if level<3 or gold<FEES[r]:
		notify("Yem atölyesi için seviye 3 ve altın gerekli.")
		return
	for k in RECIPES[r]:
		if quantity(k)<RECIPES[r][k]:
			notify("Eksik malzeme: "+ITEMS[k])
			return
	for k in RECIPES[r]:
		change_item(k,-RECIPES[r][k])
	gold-=FEES[r]
	food_stock[r]+=1
	refresh_ui()
	notify(FEED_NAMES[r]+" üretildi.")

func craft_feed():
	if is_instance_valid(inventory_window):
		show_inventory()

func purchase_decor(i: int):
	if decorations[i] or gold<DECOR_PRICES[i]:
		notify("Zaten satın alındı veya altın yetersiz.")
		return
	gold-=DECOR_PRICES[i]
	decorations[i]=true
	rebuild_decor()
	refresh_ui()
	notify(DECOR_NAMES[i]+" yerleştirildi!")

func plot_action(i: int):
	var old_h=harvests
	var crop=int(plots[i].crop)
	super.plot_action(i)
	if harvests>old_h and crop>=0 and store_harvest:
		gold-=int(CROPS[crop].sale)
		stock[crop]+=1
		notify(CROPS[crop].name+" depoya eklendi.")
		refresh_ui()

func feed_pet(i: int):
	if i>=creatures.size(): return
	var p=creatures[i]
	var r=species_rarity(int(p.species))
	if starter_feed<=0 and p.hunger<=0 and food_stock[r]>0:
		food_stock[r]-=1
		p.hunger=1800.0
		refresh_all()
		notify(SPECIES[int(p.species)]+" beslendi!")
		feed_anim=2.5
	else:
		var before=float(p.hunger)
		super.feed_pet(i)
		if p.hunger>before: feed_anim=2.5

func refresh_ui():
	super.refresh_ui()
	if not is_instance_valid(mode_button): return
	mode_button.text="Hasat: Depola" if store_harvest else "Hasat: Sat"
	craft_button.text="Yem atölyesini aç"
	craft_button.disabled=false
	if is_instance_valid(inventory_text):
		var lines=[]
		for i in range(ITEMS.size()):
			lines.append(ITEMS[i]+": "+str(quantity(i)))
		var food=[]
		for i in range(6):
			food.append(FEED_NAMES[i]+": "+str(food_stock[i]))
		inventory_text.text="Altın: %d G  •  Başlangıç yemi: %d\n%s\n\n%s" % [gold,starter_feed,"  |  ".join(lines),"  |  ".join(food)]
	if is_instance_valid(decor_text):
		var lines=[]
		for i in range(4):
			lines.append(DECOR_NAMES[i]+(" — Yerleştirildi" if decorations[i] else " — "+str(DECOR_PRICES[i])+" G"))
		decor_text.text="Altın: "+str(gold)+" G\n"+"\n".join(lines)
	if not creatures.is_empty() and starter_feed<=0:
		var r=species_rarity(int(creatures[selected_creature].species))
		if food_stock[r]>0:
			feed_button.text="Besle (depoda %d)" % food_stock[r]

func open_crate(t: int):
	if reveal_busy: return
	var previous=creatures.size()
	super.open_crate(t)
	if creatures.size()==previous or testing: return
	show_reveal(creatures.back())

func make_chest(r: int):
	if is_instance_valid(chest_root):
		chest_root.queue_free()
	chest_root=Node3D.new()
	preview_world.add_child(chest_root)
	var wood=Color("#785638")
	var trim: Color=COLORS[r]
	box_at(chest_root,Vector3(0,0.25,0),Vector3(1.18,0.50,0.86),wood)
	for x in [-0.47,0.47]:
		box_at(chest_root,Vector3(x,0.25,0.445),Vector3(0.10,0.49,0.045),trim)
	box_at(chest_root,Vector3(0,0.33,0.45),Vector3(0.19,0.21,0.065),trim)
	chest_lid=Node3D.new()
	chest_root.add_child(chest_lid)
	chest_lid.position=Vector3(0,0.52,-0.43)
	box_at(chest_lid,Vector3(0,0.11,0.43),Vector3(1.21,0.22,0.88),wood.lightened(0.13))
	for x in [-0.47,0.47]:
		box_at(chest_lid,Vector3(x,0.23,0.43),Vector3(0.10,0.035,0.89),trim)
	chest_sparks=Node3D.new()
	preview_world.add_child(chest_sparks)
	for i in range(12):
		var a=i*TAU/12
		gem(chest_sparks,Vector3(cos(a)*0.85,0.50+0.30*sin(a*3),sin(a)*0.85),0.055,0.14,trim.lightened(0.4))
	chest_sparks.scale=Vector3.ONE*0.01

func play_chime(r: int):
	var rate=22050
	var samples=PackedByteArray()
	var duration=0.42+0.08*r
	var count=int(rate*duration)
	samples.resize(count*2)
	var frequency=440.0*pow(1.12246,r)
	for i in range(count):
		var t=float(i)/rate
		var envelope=sin(PI*minf(t/0.025,1.0)*0.5)*exp(-t*6.0)
		var note=sin(TAU*frequency*t)+0.35*sin(TAU*frequency*1.5*t)+0.18*sin(TAU*frequency*2*t)
		var sample=int(clampf(note*envelope*0.4,-1.0,1.0)*32767)
		samples.encode_s16(i*2,sample)
	var stream=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=rate
	stream.data=samples
	chime.stream=stream
	chime.play()

func show_reveal(p: Dictionary):
	if is_instance_valid(reveal_tween): reveal_tween.kill()
	reveal_busy=true
	if is_instance_valid(preview_pet):
		preview_pet.queue_free()
	if is_instance_valid(chest_sparks):
		chest_sparks.queue_free()
	preview_pet=pet_model(preview_world,int(p.species),bool(p.shiny))
	var r=species_rarity(int(p.species))
	make_chest(r)
	preview_pet.scale=Vector3.ONE*0.01
	preview_pet.visible=false
	reveal_label.text=""
	reveal_chest.text="KASA AÇILIYOR..."
	reveal_chest.add_theme_color_override("font_color",COLORS[r])
	reveal_window.popup_centered()
	reveal_tween=create_tween()
	reveal_tween.tween_property(chest_root,"rotation:z",-0.11,0.14)
	reveal_tween.tween_property(chest_root,"rotation:z",0.11,0.14)
	reveal_tween.tween_property(chest_root,"rotation:z",0.0,0.13)
	reveal_tween.tween_property(chest_lid,"rotation:x",-1.65,0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_callback(func():
		play_chime(r)
		chest_root.visible=false
		preview_pet.visible=true)
	reveal_tween.tween_property(preview_pet,"scale",Vector3.ONE,0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal_tween.parallel().tween_property(chest_sparks,"scale",Vector3.ONE,0.45)
	reveal_tween.tween_callback(func():
		reveal_chest.text=RARITIES[r].to_upper()+("  ★ SHINY" if p.shiny else "")
		reveal_label.text=SPECIES[int(p.species)]+"  /  "+ELEMENTS[int(p.species)])
	reveal_tween.tween_callback(func(): reveal_busy=false)

func close_reveal():
	if is_instance_valid(reveal_tween): reveal_tween.kill()
	reveal_window.hide()
	reveal_busy=false

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_I:
			show_inventory()
			return
		if event.keycode==KEY_B:
			show_decor()
			return
	super._unhandled_input(event)

func decorative_motion_enabled() -> bool:
	return true

func _process(delta):
	super._process(delta)
	if testing or not decorative_motion_enabled(): return
	anim_phase+=delta
	feed_anim=maxf(0.0,feed_anim-delta)
	if is_instance_valid(garden_windmill):
		garden_windmill.rotation.z+=delta*0.7
	if is_instance_valid(preview_pet) and reveal_window.visible:
		preview_pet.rotation.y+=delta*0.7
		if is_instance_valid(chest_sparks): chest_sparks.rotation.y+=delta*0.9
	var i=0
	for p in creatures:
		if not p.active: continue
		if i>=pet_nodes.size(): break
		var n: Node3D=pet_nodes[i]
		var phase=anim_phase*1.8+i*2.0
		var asleep=p.hunger<=0
		n.position.x=-1.1+i*1.65+(0.0 if asleep else sin(phase)*0.22)
		n.position.z=3.35+(0.0 if asleep else cos(phase)*0.14)
		n.position.y=0.01 if asleep else 0.06+absf(sin(phase*2))*0.10
		n.rotation.z=0.10 if asleep else sin(phase*2)*0.045
		if feed_anim>0: n.rotation.x=sin(anim_phase*13)*0.12
		else: n.rotation.x=0.0
		for child in n.get_children():
			if child.name.begins_with("Foot"):
				child.rotation.x=0.0 if asleep else sin(phase*3+child.get_index())*0.40
			if child.name.begins_with("Wing"):
				child.rotation.z=sin(phase*2.2)*(0.4 if child.name=="WingL" else -0.4)
			if child.name=="Orbit":
				child.rotation.y+=delta*0.9
		i+=1

func save_game(path: String = SAVE_V02, allow_testing: bool = false):
	super.save_game(path,allow_testing)
	if testing and not allow_testing: return
	var f=FileAccess.open(path,FileAccess.READ)
	if not f: return
	var data=JSON.parse_string(f.get_as_text())
	f.close()
	if not data is Dictionary: return
	data["stock"]=stock
	data["food_stock"]=food_stock
	data["decorations"]=decorations
	data["store_harvest"]=store_harvest
	f=FileAccess.open(path,FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(data))

func load_game(path: String = SAVE_V02):
	super.load_game(path)
	var f=FileAccess.open(path,FileAccess.READ)
	if not f: return
	var data=JSON.parse_string(f.get_as_text())
	if not data is Dictionary: return
	stock=data.get("stock",[0,0,0,0,0,0,0,0,0])
	food_stock=data.get("food_stock",[0,0,0,0,0,0])
	decorations=data.get("decorations",[false,false,false,false])
	store_harvest=bool(data.get("store_harvest",false))
	if is_instance_valid(decor_root): rebuild_decor()

func visual_test():
	reset_data()
	decorations=[true,true,true,true]
	for s in [0,8]:
		creatures.append({"species":s,"shiny":false,"growth":300.0,"hunger":1800.0,"active":true,"production":0.0})
	rebuild_decor()
	refresh_all()
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	show_inventory()
	await get_tree().create_timer(0.25).timeout
	inventory_window.hide()
	show_decor()
	await get_tree().create_timer(0.25).timeout
	decor_window.hide()
	show_reveal(creatures.back())
	await get_tree().create_timer(1.8).timeout
	if not preview_pet.visible or not reveal_label.text.contains("Solvaris"):
		push_error("VISUAL TEST: reveal failed")
		get_tree().quit(1)
		return
	close_reveal()
	await get_tree().process_frame
	print("V0.2 VISUAL PASS: 3D scene, 4 decorations, inventory/decor windows, animated chest reveal")
	get_tree().quit(0)

func run_tests():
	var errors=[]
	# Inventory harvest keeps task reward and stores one crop.
	store_harvest=true
	plot_action(0)
	plot_action(0)
	plots[0].remaining=0
	plot_action(0)
	if stock[0]!=1 or gold!=138: errors.append("inventory harvest")
	level=3
	craft_recipe(0)
	if food_stock[0]!=1 or stock[0]!=0 or gold!=137: errors.append("recipe")
	buy_item(1)
	if stock[1]!=1 or gold!=124: errors.append("buy")
	sell_item(1,1)
	if stock[1]!=0 or gold!=134: errors.append("sell")
	purchase_decor(0)
	if not decorations[0] or gold!=109: errors.append("decor")
	for s in range(12):
		var sample=pet_model(pets_root,s,false)
		if sample.get_child_count()<10: errors.append("model "+str(s))
		sample.queue_free()
	var path="user://sproutlings_v02_test_"+str(Time.get_ticks_usec())+".json"
	save_game(path,true)
	reset_data()
	load_game(path)
	if not decorations[0] or food_stock[0]!=1 or not store_harvest or gold!=109: errors.append("v02 save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not errors.is_empty():
		push_error("V0.2 FAIL "+str(errors))
		get_tree().quit(1)
		return
	print("V0.2 PASS: inventory, recipe, buy/sell, decor, 12 models, extended save")
	reset_data()
	rebuild_decor()
	refresh_all()
	super.run_tests()
