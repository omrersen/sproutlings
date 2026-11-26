extends "res://farm_v02.gd"

const SAVE_V03="user://sproutlings_v03.json"
const ZONES=["Yeşil Vadi","Fısıldayan Orman","Safir Gölü","Köz Toprakları","Kristal Vadisi","Ay Bahçesi"]
const ZLEVEL=[1,5,6,8,12,16]
const ZCOST=[0,100,160,220,350,500]
const ZCOLOR=["#88b66e","#568a5b","#72adb0","#c08a60","#a49ad1","#555e92"]
const SEASONS=["İlkbahar","Yaz","Sonbahar","Kış"]
const BUILDINGS=["Depo","Otomatik sulama","Gelişmiş barınak","Sera"]
const BUILD_COST=[100,150,200,250]
const BUILD_LEVEL=[3,5,6,8]
const DEFAULT_POS=[Vector3(5.35,0,0.2),Vector3(-5.0,0,4.55),Vector3(3.3,0,-4.7),Vector3(5.25,0,3.6)]
const GOAL_NAMES=["İlk 10 hasat","Koleksiyonda 3 tür","İkinci biyomu aç","İlk binanı kur","İlk evrim","50 hasat"]
var zone=0
var zone_open=[true,false,false,false,false,false]
var zone_plots=[]
var zone_land=[4,4,4,4,4,4]
var buildings=[false,false,false,false]
var decor_positions=[]
var claimed=[false,false,false,false,false,false]
var processed=[0,0]
var season_time=0.0
var season=0
var motion=true
var quality=true
var volume=0.8
var manager: Window
var manager_tabs: TabContainer
var region_choice: OptionButton
var region_info: Label
var building_choice: OptionButton
var building_info: Label
var quest_info: Label
var quest_choice: OptionButton
var dex_info: Label
var evolution_info: Label
var production_info: Label
var production_choice: OptionButton
var status_line: Label
var region_root: Node3D
var construction_root: Node3D
var home_meshes=[]
var decor_groups=[]
var drag_mode=false
var dragging=-1
var drag_origin=Vector3.ZERO
var last_manager_text=""
var manager_tick=0.0
var detail_refresh=0.0
var seen_species=[]
var total_play=0.0

func reset_data():
	super.reset_data()
	zone=0
	zone_open=[true,false,false,false,false,false]
	zone_plots=[]
	zone_land=[4,4,4,4,4,4]
	for z in range(6):
		var a=[]
		for i in range(12):
			a.append({"crop":-1,"remaining":0.0,"watered":false})
		zone_plots.append(a)
	zone_plots[0]=plots
	buildings=[false,false,false,false]
	decor_positions=DEFAULT_POS.duplicate()
	claimed=[false,false,false,false,false,false]
	processed=[0,0]
	season_time=0.0
	season=0
	total_play=0.0
	seen_species=[]
	motion=true
	quality=true
	volume=0.8
	drag_mode=false
	dragging=-1

func active_capacity() -> int:
	return 4 if buildings[2] else 2

func crop_speed_modifier(_i: int) -> float:
	return 1.0 if buildings[3] else [1.12,1.20,1.0,0.78][season]

func make_world():
	super.make_world()
	for n in get_children():
		if n is MeshInstance3D and not n in plot_nodes and n!=selection_ring:
			home_meshes.append(n)
		if n is Label3D:
			home_meshes.append(n)
	region_root=Node3D.new()
	add_child(region_root)
	construction_root=Node3D.new()
	add_child(construction_root)
	rebuild_region()
	rebuild_buildings()
	apply_settings()

func clear_node(n: Node3D):
	if not is_instance_valid(n): return
	for child in n.get_children():
		n.remove_child(child)
		child.queue_free()

func rebuild_region():
	if not is_instance_valid(region_root): return
	clear_node(region_root)
	for n in home_meshes:
		n.visible=zone==0
	decor_root.visible=zone==0
	if zone!=0:
		var base=Color(ZCOLOR[zone])
		box_at(region_root,Vector3(0,-0.75,0),Vector3(15,1.1,13),base.darkened(0.30))
		box_at(region_root,Vector3(0,-0.2,0),Vector3(15,0.2,13),base)
		box_at(region_root,Vector3(0,-1.0,0),Vector3(15.4,0.32,13.4),base.darkened(0.42))
		for i in range(12):
			var x=-5.5+i*1.0
			box_at(region_root,Vector3(x,0.01,3.35),Vector3(0.8,0.05,0.72),base.lightened(0.37))
		for i in range(12):
			var x=-6.3+(i%6)*2.5
			var z=-5.1 if i<6 else 5.4
			var p=Vector3(x,0,z)
			match zone:
				1:
					box_at(region_root,p+Vector3(0,0.42,0),Vector3(0.23,0.84,0.23),Color("#79543d"))
					sphere_at(region_root,p+Vector3(0,1.25,0),Vector3(1.25,1.35,1.15),Color("#346e49"))
					sphere_at(region_root,p+Vector3(0.2,1.58,0),Vector3(0.8,0.85,0.8),Color("#68ad62"))
					flower_cluster(region_root,p+Vector3(0.45,0,0.35),Color("#df9cdb"))
				2:
					sphere_at(region_root,p,Vector3(1.2,0.06,0.83),Color("#5ac5d1"))
					for j in range(3):
						box_at(region_root,p+Vector3((j-1)*0.19,0.35,0.3),Vector3(0.04,0.7,0.04),Color("#60915c"))
					sphere_at(region_root,p+Vector3(0,0.73,0.3),Vector3(0.20,0.3,0.17),Color("#d9ad70"))
				3:
					cone_at(region_root,p+Vector3(0,0.55,0),0.65,1.15,Color("#684842"))
					gem(region_root,p+Vector3(0,0.8,0),0.18,0.55,Color("#fc9560"))
				4:
					gem(region_root,p+Vector3(0,0.7,0),0.48,1.4,Color("#a6e8fa"))
					gem(region_root,p+Vector3(0.45,0.35,0.2),0.24,0.7,Color("#e0b3f7"))
				5:
					box_at(region_root,p+Vector3(0,0.48,0),Vector3(0.2,0.96,0.2),Color("#555879"))
					sphere_at(region_root,p+Vector3(0,1.12,0),Vector3(1.10,0.75,0.95),Color("#99a0df"))
					gem(region_root,p+Vector3(0,1.6,0),0.13,0.4,Color("#f4e8af"))
		var sign_label=Label3D.new()
		sign_label.text=ZONES[zone]
		sign_label.position=Vector3(0,1.5,4.9)
		sign_label.font_size=44
		sign_label.pixel_size=0.012
		sign_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		region_root.add_child(sign_label)
	# Seasonal accents on every map, including the home farm.
	var accents=[Color("#f2b7cb"),Color("#f3dc72"),Color("#e99d5f"),Color("#e4f0f5")]
	for i in range(8):
		var x=-6.4+i*1.8
		var p=Vector3(x,0.025,-3.9)
		if season==3:
			sphere_at(region_root,p,Vector3(0.55,0.055,0.42),accents[season])
		else:
			flower_cluster(region_root,p,accents[season])
	rebuild_buildings()

func rebuild_buildings():
	if not is_instance_valid(construction_root): return
	clear_node(construction_root)
	if zone!=0: return
	for i in range(4):
		if not buildings[i]: continue
		var p=Vector3(-6.0,0,-1.0+i*1.85)
		match i:
			0:
				box_at(construction_root,p+Vector3(0,0.50,0),Vector3(1.15,1.05,1.0),Color("#c5a372"))
				box_at(construction_root,p+Vector3(0,1.12,0),Vector3(1.3,0.18,1.14),Color("#7a6152"))
				box_at(construction_root,p+Vector3(0,0.35,0.52),Vector3(0.55,0.65,0.07),Color("#775541"))
			1:
				var pipe=CylinderMesh.new()
				pipe.top_radius=0.08
				pipe.bottom_radius=0.08
				pipe.height=0.85
				mesh_at(construction_root,pipe,p+Vector3(0,0.43,0),Color("#b4c8c6"))
				sphere_at(construction_root,p+Vector3(0,0.85,0),Vector3(0.46,0.25,0.42),Color("#68c7dd"))
			2:
				box_at(construction_root,p+Vector3(0,0.43,0),Vector3(1.2,0.9,1.1),Color("#e0b27d"))
				var roof=PrismMesh.new()
				roof.size=Vector3(1.35,0.55,1.25)
				mesh_at(construction_root,roof,p+Vector3(0,1.15,0),Color("#bf7561"))
			3:
				var glass=box_at(construction_root,p+Vector3(0,0.65,0),Vector3(1.2,1.3,1.12),Color("#a1d7c8"))
				var m=glass.material_override as StandardMaterial3D
				m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
				m.albedo_color=Color("#a1d7c888")
				for x in [-0.55,0.55]:
					box_at(construction_root,p+Vector3(x,0.65,0.55),Vector3(0.07,1.3,0.07),Color("#e8e2c1"))
				cone_at(construction_root,p+Vector3(0,0.33,0),0.25,0.65,Color("#65ae61"))

func sync_zone():
	if zone_plots.size()!=6: return
	zone_plots[zone]=plots
	zone_land[zone]=unlocked

func travel(z: int):
	if z<0 or z>=6: return
	if not zone_open[z]:
		if level<ZLEVEL[z] or gold<ZCOST[z]:
			notify("Biyom için seviye/altın yetersiz.")
			return
		gold-=ZCOST[z]
		zone_open[z]=true
	sync_zone()
	zone=z
	plots=zone_plots[z]
	unlocked=int(zone_land[z])
	selected_plot=0
	selected_crop=0
	if is_instance_valid(crop_menu): crop_menu.select(0)
	rebuild_region()
	refresh_all()
	notify(ZONES[z]+" bölgesine geçildi.")

func build(i: int):
	if i<0 or i>=4 or buildings[i] or level<BUILD_LEVEL[i] or gold<BUILD_COST[i]:
		notify("Bina için koşullar karşılanmadı.")
		return
	gold-=BUILD_COST[i]
	buildings[i]=true
	rebuild_buildings()
	refresh_ui()
	notify(BUILDINGS[i]+" inşa edildi.")

func storage_used() -> int:
	var n=0
	for i in range(ITEMS.size()): n+=quantity(i)
	for x in food_stock: n+=int(x)
	for x in processed: n+=int(x)
	return n

func storage_capacity() -> int:
	return 120 if buildings[0] else 40

func buy_item(i: int):
	if storage_used()>=storage_capacity():
		notify("Depo dolu.")
		return
	super.buy_item(i)

func plot_action(i: int):
	var p=plots[i]
	if i<unlocked and p.crop<0:
		var required_zone=[0,0,0,1,3,4,5][selected_crop]
		if required_zone>0 and zone!=required_zone and not buildings[3]:
			notify("Bu ürün "+ZONES[required_zone]+" bölgesinde yetişir. Sera istisnadır.")
			return
	if store_harvest and i<unlocked and p.crop>=0 and p.watered and p.remaining<=0 and storage_used()>=storage_capacity():
		notify("Depo dolu: satış moduna geç veya boşalt.")
		return
	super.plot_action(i)
	if buildings[1] and i<unlocked and p.crop>=0 and not p.watered:
		p.watered=true
		refresh_plot(i)
		refresh_ui()

func process_goods(i: int):
	var recipe={3:2,1:1} if i==0 else {5:1,7:1}
	var fee=3 if i==0 else 5
	if level<5 or gold<fee:
		notify("Üretim için seviye 5 ve altın gerekli.")
		return
	for k in recipe:
		if quantity(k)<recipe[k]:
			notify("Eksik malzeme: "+ITEMS[k])
			return
	for k in recipe: change_item(k,-recipe[k])
	gold-=fee
	processed[i]+=1
	refresh_ui()
	notify("Ürün işlendi.")

func sell_processed(i: int):
	if processed[i]<=0: return
	processed[i]-=1
	gold+=[58,82][i]
	refresh_ui()

func goal_ready(i: int) -> bool:
	match i:
		0: return harvests>=10
		1: return seen_species.size()>=3
		2: return zone_open.count(true)>=2
		3: return buildings.has(true)
		4:
			for p in creatures:
				if p.get("evolved",false): return true
			return false
		5: return harvests>=50
	return false

func claim_goal(i: int):
	if claimed[i] or not goal_ready(i): return
	claimed[i]=true
	gold+=[35,60,80,75,150,120][i]
	var t=[0,1,1,1,2,5][i]
	crates[t]+=1
	refresh_ui()
	notify("Başarı ödülü alındı: "+GOAL_NAMES[i])

func evolve_pet(i: int):
	if i>=creatures.size(): return
	var p=creatures[i]
	if p.get("evolved",false) or p.growth<300 or level<8 or gold<150 or crystal_dust<3:
		notify("Evrim: L8, yetişkin, 150 G ve 3 kristal tozu gerekir.")
		return
	gold-=150
	crystal_dust-=3
	p["evolved"]=true
	rebuild_pets()
	refresh_ui()
	notify(SPECIES[int(p.species)]+" evrimleşti!")

func rebuild_pets():
	super.rebuild_pets()
	var i=0
	for p in creatures:
		if not p.active: continue
		if i>=pet_nodes.size(): break
		if p.get("evolved",false):
			var n: Node3D=pet_nodes[i]
			n.scale*=1.2
			var aura=TorusMesh.new()
			aura.inner_radius=0.48
			aura.outer_radius=0.55
			var ring=mesh_at(n,aura,Vector3(0,0.08,0),Color("#ffe5a0"))
			var m=ring.material_override as StandardMaterial3D
			m.emission_enabled=true
			m.emission=Color("#ffcf75")
		i+=1

func open_crate(t: int):
	var before=creatures.size()
	super.open_crate(t)
	if creatures.size()>before:
		var id=int(creatures.back().species)
		if not seen_species.has(id): seen_species.append(id)
		refresh_ui()

func rebuild_decor():
	if not is_instance_valid(decor_root): return
	clear_node(decor_root)
	decor_groups=[]
	garden_windmill=null
	for i in range(4):
		if not decorations[i]:
			decor_groups.append(null)
			continue
		var group=Node3D.new()
		decor_root.add_child(group)
		group.position=decor_positions[i]
		decor_groups.append(group)
		match i:
			0:
				box_at(group,Vector3(0,0.04,0),Vector3(1.6,0.14,1.4),Color("#936744"))
				for j in range(9):
					flower_cluster(group,Vector3(-0.52+(j%3)*0.52,0.11,-0.42+int(j/3.0)*0.42),[Color("#ec8299"),Color("#d7a8ee"),Color("#f6d46f")][j%3])
			1:
				box_at(group,Vector3(0,0.36,0),Vector3(1.45,0.12,0.5),Color("#c69763"))
				box_at(group,Vector3(0,0.68,-0.21),Vector3(1.45,0.38,0.1),Color("#c69763"))
				for x in [-0.5,0.5]:
					box_at(group,Vector3(x,0.16,0),Vector3(0.12,0.32,0.48),Color("#53645b"))
				box_at(group,Vector3(0.86,0.55,0),Vector3(0.12,1.1,0.12),Color("#53645b"))
				sphere_at(group,Vector3(0.86,1.18,0),Vector3(0.35,0.38,0.35),Color("#ffe5a1"))
			2:
				var tower=CylinderMesh.new()
				tower.top_radius=0.43
				tower.bottom_radius=0.65
				tower.height=2.0
				tower.radial_segments=8
				mesh_at(group,tower,Vector3(0,1,0),Color("#f1dfbf"))
				cone_at(group,Vector3(0,2.35,0),0.7,0.8,Color("#9f6052"))
				garden_windmill=Node3D.new()
				group.add_child(garden_windmill)
				garden_windmill.position=Vector3(0,1.65,0.53)
				for j in range(4):
					var arm=Node3D.new()
					garden_windmill.add_child(arm)
					arm.rotation.z=j*PI/2
					box_at(arm,Vector3(0,0.50,0),Vector3(0.11,1.0,0.08),Color("#6d5544"))
					box_at(arm,Vector3(0.15,0.75,0),Vector3(0.29,0.64,0.08),Color("#e8d8b8"))
			3:
				var basin=CylinderMesh.new()
				basin.top_radius=0.72
				basin.bottom_radius=0.65
				basin.height=0.24
				basin.radial_segments=12
				mesh_at(group,basin,Vector3(0,0.12,0),Color("#a9c5bc"))
				sphere_at(group,Vector3(0,0.25,0),Vector3(1.15,0.1,1.15),Color("#6ed2dd"))
				gem(group,Vector3(0,0.74,0),0.36,0.95,Color("#a5e6f3"))
				for j in range(6):
					var a=j*TAU/6
					gem(group,Vector3(cos(a)*0.46,0.43,sin(a)*0.46),0.11,0.33,Color("#d4b6f4"))
	decor_root.visible=zone==0

func valid_decor_position(i: int,p: Vector3) -> bool:
	if absf(p.x)>6.25 or absf(p.z)>5.0: return false
	if absf(p.x)<4.2 and absf(p.z)<4.1: return false
	if p.x< -4.2 and p.z<2.9: return false
	if p.x>3.6 and p.z< -1.2: return false
	for j in range(4):
		if j!=i and decorations[j] and p.distance_to(decor_positions[j])<1.65: return false
	return true

func toggle_drag():
	if zone!=0:
		notify("Dekorasyon düzenleme Yeşil Vadi'de.")
		return
	drag_mode=not drag_mode
	if drag_mode:
		notify("Dekorasyona basılı tut, dış kenarda boş alana sürükle.")
	else: notify("Dekorasyon düzenleme kapalı.")
	refresh_ui()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_M:
			show_manager(0)
			return
		if event.keycode==KEY_D:
			toggle_drag()
			return
	if drag_mode and zone==0:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				var point=Plane(Vector3.UP,0.1).intersects_ray(cam.project_ray_origin(event.position),cam.project_ray_normal(event.position))
				if point!=null:
					for i in range(decor_groups.size()):
						if is_instance_valid(decor_groups[i]) and Vector3(point.x,0,point.z).distance_to(decor_positions[i])<1.4:
							dragging=i
							drag_origin=decor_positions[i]
							return
			elif dragging>=0:
				var pos: Vector3=decor_groups[dragging].position
				if valid_decor_position(dragging,pos):
					decor_positions[dragging]=pos
					notify("Dekorasyon taşındı.")
				else:
					decor_groups[dragging].position=drag_origin
					notify("Bu konuma yerleştirilemez.")
				dragging=-1
				return
		if event is InputEventMouseMotion and dragging>=0:
			var point=Plane(Vector3.UP,0.1).intersects_ray(cam.project_ray_origin(event.position),cam.project_ray_normal(event.position))
			if point!=null:
				decor_groups[dragging].position=Vector3(snappedf(point.x,0.25),0,snappedf(point.z,0.25))
			return
	super._unhandled_input(event)

func make_ui():
	super.make_ui()
	var layer=get_node("HUD")
	for n in layer.get_children():
		if n is PanelContainer:
			for c in n.get_child(0).get_children():
				if c is Label:
					if c.text.begins_with("V0.2"):
						status_line=c
					if c.text.begins_with("En fazla 2"):
						c.text="Barınak: 2 veya 4 aktif yuva. Açlıkta bonus durur."
					if c.text.begins_with("Kamera:"):
						c.text="Q/E kamera • Tekerlek zoom • M yönetim • D dekor taşı"
	var bar=HBoxContainer.new()
	layer.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bar.offset_left=-275
	bar.offset_right=275
	bar.offset_top=58
	bar.offset_bottom=98
	bar.alignment=BoxContainer.ALIGNMENT_CENTER
	btn(bar,"Harita [M]",func(): show_manager(0))
	btn(bar,"Binalar",func(): show_manager(1))
	btn(bar,"Görevler",func(): show_manager(2))
	btn(bar,"Koleksiyon",func(): show_manager(3))
	btn(bar,"Taşı [D]",toggle_drag)
	manager=Window.new()
	manager.title="Sproutlings • Çiftlik yönetimi"
	manager.size=Vector2i(760,610)
	manager.exclusive=true
	layer.add_child(manager)
	manager.hide()
	manager.close_requested.connect(func(): manager.hide())
	var outer=window_content(manager)
	lbl(outer,"ÇİFTLİK YÖNETİMİ   /   V0.3",24,true)
	manager_tabs=TabContainer.new()
	manager_tabs.custom_minimum_size=Vector2(700,465)
	manager_tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL
	outer.add_child(manager_tabs)
	var v=new_tab("Harita")
	region_info=lbl(v,"",16)
	region_choice=menu(v,func(_i): pass)
	for z in ZONES: region_choice.add_item(z)
	btn(v,"Biyomu aç / seyahat et",func(): travel(region_choice.selected); if zone==region_choice.selected: manager.hide())
	lbl(v,"Her biyomun kendi 12 tarla kapasitesi ve bağımsız hasat kayıtları vardır. Uzak bölgelerde bitkilerin büyümesi bekler.",14)
	v=new_tab("Binalar")
	building_info=lbl(v,"",16)
	building_choice=menu(v,func(_i): pass)
	for b in BUILDINGS: building_choice.add_item(b)
	btn(v,"İnşa et",func(): build(building_choice.selected))
	lbl(v,"Depo kapasitesi, otomatik sulama, 4 aktif yaratık ve mevsim koruması.",14)
	v=new_tab("Görevler")
	quest_info=lbl(v,"",16)
	quest_choice=menu(v,func(_i): pass)
	for g in GOAL_NAMES: quest_choice.add_item(g)
	btn(v,"Ödülü al",func(): claim_goal(quest_choice.selected))
	v=new_tab("Ansiklopedi")
	dex_info=lbl(v,"",14)
	evolution_info=lbl(v,"",15,true)
	btn(v,"Seçili yaratığı evrimleştir",func(): evolve_pet(selected_creature))
	lbl(v,"Sağ panelden yaratık seç; evrim kalıcı görünüm ve aura kazandırır.",13)
	v=new_tab("Üretim")
	production_info=lbl(v,"",16)
	production_choice=menu(v,func(_i): pass)
	production_choice.add_item("Orman reçeli")
	production_choice.add_item("Kristal iksiri")
	btn(v,"Üret",func(): process_goods(production_choice.selected))
	btn(v,"1 adet sat",func(): sell_processed(production_choice.selected))
	v=new_tab("Ayarlar")
	var q=CheckButton.new()
	q.text="Yüksek grafik kalitesi (gölge ve MSAA)"
	q.button_pressed=quality
	v.add_child(q)
	q.toggled.connect(func(on): quality=on; apply_settings())
	var m=CheckButton.new()
	m.text="Yaratık ve çevre hareketleri"
	m.button_pressed=motion
	v.add_child(m)
	m.toggled.connect(func(on): motion=on; apply_settings())
	lbl(v,"Ana ses düzeyi",16)
	var s=HSlider.new()
	s.max_value=1
	s.step=0.05
	s.value=volume
	v.add_child(s)
	s.value_changed.connect(func(n): volume=n; apply_settings())
	btn(v,"Pencere / tam ekran",func():
		var mode=DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
	btn(v,"Ayarları kaydet",func(): save_game(); notify("Ayarlar kaydedildi."))
	btn(outer,"Kapat",func(): manager.hide())

func new_tab(tab_name: String) -> VBoxContainer:
	var scroll=ScrollContainer.new()
	scroll.name=tab_name
	manager_tabs.add_child(scroll)
	var v=VBoxContainer.new()
	v.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation",9)
	scroll.add_child(v)
	return v

func show_manager(tab: int):
	refresh_ui()
	manager_tabs.current_tab=tab
	manager.popup_centered()

func apply_settings():
	if is_instance_valid(sun):
		sun.shadow_enabled=quality
	get_viewport().msaa_3d=Viewport.MSAA_2X if quality else Viewport.MSAA_DISABLED
	var idx=AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(idx,volume<=0.001)
	AudioServer.set_bus_volume_db(idx,linear_to_db(maxf(volume,0.001)))

func refresh_ui():
	super.refresh_ui()
	if is_instance_valid(status_line):
		status_line.text="V0.3 / "+ZONES[zone]+" • "+SEASONS[season]
	if not is_instance_valid(region_info): return
	var lines=[]
	for i in range(6):
		lines.append(("▶ " if zone==i else "")+ZONES[i]+(" — Açık" if zone_open[i] else " — L%d / %d G" % [ZLEVEL[i],ZCOST[i]]))
	region_info.text="Bölgeler: %d/6 • Toplam tarla: %d/72\n" % [zone_open.count(true),total_land()]+"\n".join(lines)
	lines=[]
	for i in range(4):
		lines.append(BUILDINGS[i]+(" — Kuruldu" if buildings[i] else " — L%d / %d G" % [BUILD_LEVEL[i],BUILD_COST[i]]))
	building_info.text="Depo: %d/%d • Barınak: %d yuva\n" % [storage_used(),storage_capacity(),active_capacity()]+"\n".join(lines)
	lines=[]
	for i in range(6):
		lines.append(GOAL_NAMES[i]+" — "+("Alındı" if claimed[i] else ("Hazır" if goal_ready(i) else "Devam ediyor")))
	quest_info.text="Başarılar: %d/6\n" % claimed.count(true)+"\n".join(lines)
	lines=[]
	for i in range(12):
		lines.append("%s | %s | %s" % [SPECIES[i] if seen_species.has(i) else "???",RARITIES[int(i/2.0)],ELEMENTS[i] if seen_species.has(i) else "Keşfedilmedi"])
	dex_info.text="Keşif: %d/12\n" % seen_species.size()+"\n".join(lines)
	evolution_info.text="Evrim: L8 • yetişkin • 150 G • 3 kristal tozu"
	production_info.text="Orman reçeli: 2 meyve + 1 havuç + 3 G → 58 G\nKristal iksiri: 1 kristal meyve + 1 toz + 5 G → 82 G\nStok: reçel %d | iksir %d" % processed
	if is_instance_valid(inventory_text):
		inventory_text.text+="\nDepo kapasitesi: %d/%d" % [storage_used(),storage_capacity()]

func total_land() -> int:
	var n=0
	for i in range(6):
		if zone_open[i]: n+=unlocked if i==zone else int(zone_land[i])
	return n

func decorative_motion_enabled() -> bool:
	return motion

func _process(delta):
	# Base timers and crop economy always run, even when decorative motion is disabled.
	super._process(delta)
	if testing: return
	total_play+=delta
	season_time+=delta
	advance_season()
	if not motion:
		for n in pet_nodes:
			n.rotation.x=0
			n.rotation.z=0
			n.position.y=0


func advance_season():
	if season_time>=300.0:
		season_time-=300.0
		season=(season+1)%4
		rebuild_region()
		notify("Yeni mevsim: "+SEASONS[season])

func save_game(path: String=SAVE_V03,allow_testing: bool=false):
	sync_zone()
	super.save_game(path,allow_testing)
	if testing and not allow_testing: return
	var f=FileAccess.open(path,FileAccess.READ)
	if not f: return
	var data=JSON.parse_string(f.get_as_text())
	f.close()
	if not data is Dictionary: return
	var pos=[]
	for p in decor_positions: pos.append([p.x,p.y,p.z])
	data["zone"]=zone
	data["zone_open"]=zone_open
	data["zone_plots"]=zone_plots
	data["zone_land"]=zone_land
	data["buildings"]=buildings
	data["decor_positions"]=pos
	data["claimed"]=claimed
	data["processed"]=processed
	data["season"]=season
	data["season_time"]=season_time
	data["motion"]=motion
	data["quality"]=quality
	data["volume"]=volume
	data["seen_species"]=seen_species
	data["total_play"]=total_play
	f=FileAccess.open(path,FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(data))

func load_game(path: String=SAVE_V03):
	super.load_game(path)
	var f=FileAccess.open(path,FileAccess.READ)
	if not f: return
	var data=JSON.parse_string(f.get_as_text())
	if not data is Dictionary: return
	zone=int(data.get("zone",0))
	zone_open=data.get("zone_open",[true,false,false,false,false,false])
	zone_plots=data.get("zone_plots",zone_plots)
	zone_land=data.get("zone_land",[4,4,4,4,4,4])
	buildings=data.get("buildings",[false,false,false,false])
	var pos=data.get("decor_positions",[])
	if pos.size()==4:
		for i in range(4): decor_positions[i]=Vector3(float(pos[i][0]),float(pos[i][1]),float(pos[i][2]))
	claimed=data.get("claimed",[false,false,false,false,false,false])
	processed=data.get("processed",[0,0])
	season=int(data.get("season",0))
	season_time=float(data.get("season_time",0))
	motion=bool(data.get("motion",true))
	quality=bool(data.get("quality",true))
	volume=float(data.get("volume",0.8))
	seen_species=data.get("seen_species",[])
	total_play=float(data.get("total_play",0))
	for p in creatures:
		if not seen_species.has(int(p.species)): seen_species.append(int(p.species))
	sync_zone()
	if is_instance_valid(region_root):
		rebuild_region()
		rebuild_decor()
		apply_settings()

func refresh_plot(i: int):
	super.refresh_plot(i)
	if i>=unlocked: return
	var p=plots[i]
	if p.crop<0 or p.remaining>0: return
	var root: Node3D=crop_nodes[i]
	var id=int(p.crop)
	for x in [-0.42,0.42]:
		for z in [-0.42,0.42]:
			match id:
				0:
					for j in range(3):
						sphere_at(root,Vector3(x,0.43+j*0.09,z),Vector3(0.10,0.16,0.10),Color("#ffe39c"))
				1:
					cone_at(root,Vector3(x,0.36,z),0.12,0.29,Color("#ef813a"))
				2:
					sphere_at(root,Vector3(x+0.09,0.52,z),Vector3(0.14,0.32,0.15),Color("#f1d460"))
				3:
					for j in range(3):
						sphere_at(root,Vector3(x+(j-1)*0.09,0.49,z),Vector3(0.13,0.12,0.13),Color("#b76adc"))
				4:
					var pepper=sphere_at(root,Vector3(x+0.09,0.44,z),Vector3(0.13,0.34,0.14),Color("#f65340"))
					pepper.rotation.z=0.32
				5:
					gem(root,Vector3(x,0.53,z),0.15,0.35,Color("#a0e8fa"))
				6:
					for j in range(5):
						var a=j*TAU/5
						sphere_at(root,Vector3(x+cos(a)*0.10,0.58,z+sin(a)*0.10),Vector3(0.12,0.07,0.12),Color("#fff0ab"))
					sphere_at(root,Vector3(x,0.61,z),Vector3(0.09,0.08,0.09),Color("#f4b84f"))

func visual_test():
	reset_data()
	level=40
	gold=10000
	decorations=[true,true,true,true]
	rebuild_decor()
	for i in range(4): build(i)
	for s in [4,8]:
		creatures.append({"species":s,"shiny":false,"growth":300.0,"hunger":1800.0,"active":true,"production":0.0})
	rebuild_pets()
	crystal_dust=3
	evolve_pet(0)
	for z in range(6):
		travel(z)
		if zone!=z or zone_open[z]==false:
			push_error("V0.3 VISUAL FAIL: biome")
			get_tree().quit(1)
			return
		await get_tree().process_frame
		await get_tree().create_timer(0.12).timeout
	travel(0)
	drag_mode=true
	var start=decor_positions[0]
	var dest=Vector3(5.3,0,1.5)
	var press=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=true
	press.position=cam.unproject_position(start+Vector3(0,0.1,0))
	_unhandled_input(press)
	var motion_event=InputEventMouseMotion.new()
	motion_event.position=cam.unproject_position(dest+Vector3(0,0.1,0))
	_unhandled_input(motion_event)
	press.pressed=false
	press.position=motion_event.position
	_unhandled_input(press)
	if decor_positions[0].distance_to(start)<0.5:
		push_error("V0.3 VISUAL FAIL: mouse drag")
		get_tree().quit(1)
		return
	drag_mode=false
	show_manager(0)
	for t in range(6):
		manager_tabs.current_tab=t
		await get_tree().create_timer(0.12).timeout
	manager.hide()
	show_inventory()
	await get_tree().create_timer(0.2).timeout
	inventory_window.hide()
	show_decor()
	await get_tree().create_timer(0.2).timeout
	decor_window.hide()
	show_reveal(creatures.back())
	await get_tree().create_timer(1.8).timeout
	if not preview_pet.visible or not reveal_label.text.contains("Solvaris"):
		push_error("V0.3 VISUAL FAIL: reveal")
		get_tree().quit(1)
		return
	close_reveal()
	print("V0.3 VISUAL PASS: six biomes, buildings, evolved model, simulated mouse drag, six manager tabs, inventory, chest reveal")
	get_tree().quit(0)

func run_tests():
	var errors=[]
	level=16
	gold=3000
	plot_action(0)
	travel(1)
	if zone!=1 or not zone_open[1] or plots[0].crop!=-1: errors.append("zone unlock")
	travel(0)
	if plots[0].crop!=0: errors.append("zone persistence")
	season=2
	season_time=300.0
	advance_season()
	if season!=3 or not is_equal_approx(crop_speed_modifier(0),0.78): errors.append("season transition")
	for i in range(4): build(i)
	if storage_capacity()!=120 or active_capacity()!=4 or not buildings[3]: errors.append("buildings")
	plot_action(1)
	if not plots[1].watered: errors.append("auto water")
	season=3
	if not is_equal_approx(crop_speed_modifier(0),1.0): errors.append("greenhouse")
	purchase_decor(0)
	var pos=Vector3(5.1,0,2.25)
	if not valid_decor_position(0,pos): errors.append("decor validation")
	decor_positions[0]=pos
	rebuild_decor()
	if decor_groups[0].position!=pos: errors.append("decor movement")
	stock[3]=2
	stock[1]=1
	process_goods(0)
	if processed[0]!=1 or stock[3]!=0: errors.append("production")
	creatures.append({"species":4,"shiny":false,"growth":300.0,"hunger":1800.0,"active":true,"production":0.0})
	crystal_dust=3
	evolve_pet(0)
	if not creatures[0].get("evolved",false) or crystal_dust!=0: errors.append("evolution")
	harvests=10
	var old_gold=gold
	claim_goal(0)
	claim_goal(0)
	if not claimed[0] or gold!=old_gold+35: errors.append("claim once")
	seen_species=[4]
	quality=false
	motion=false
	volume=0.4
	apply_settings()
	if sun.shadow_enabled: errors.append("settings")
	var path="user://sproutlings_v03_test_"+str(Time.get_ticks_usec())+".json"
	save_game(path,true)
	reset_data()
	load_game(path)
	if not buildings[1] or not zone_open[1] or not claimed[0] or processed[0]!=1 or decor_positions[0]!=pos or not creatures[0].get("evolved",false) or season!=3 or quality or motion or not is_equal_approx(volume,0.4): errors.append("extended save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not errors.is_empty():
		push_error("V0.3 FAIL "+str(errors))
		get_tree().quit(1)
		return
	print("V0.3 PASS: biome unlock/persistence, buildings, auto-water, greenhouse, decor movement, production, evolution, quest claim, settings, season/save")
	reset_data()
	rebuild_region()
	rebuild_decor()
	apply_settings()
	refresh_all()
	super.run_tests()
