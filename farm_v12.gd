extends "res://farm_v11.gd"

const RESOURCE_NAMES=["Gümüş balık","Kristal sazan","Ay balığı","Bakır cevheri","Gümüş cevheri","Yıldız taşı"]
const RESOURCE_VALUE=[14,32,75,18,38,85]
const EVENT_NAMES=["Filiz yağmuru","Peri ışıkları","Gümüş dalga","Köz fırtınası","Kristal yağmuru","Ay tutulması"]
var gathered=[0,0,0,0,0,0]
var eggs=[]
var activity=""
var activity_left=0.0
var activity_zone=0
var activity_total=0
var event_left=0.0
var event_clock=0.0
var event_zone=-1
var event_claimed=false
var breed_a: OptionButton
var breed_b: OptionButton
var breed_text: Label
var resource_text: Label
var resource_menu: OptionButton
var event_text: Label
var village_text: Label
var npc_root: Node3D
var event_marker: Node3D
var action_meter: ProgressBar
var hatch_btn: Button
var market_day_override=-1
var price_day=-1
var prices=[]
var refresh12=0.0
var pet_menu_signature=""
var sound_effects=true

func reset_data():
	super.reset_data()
	gathered=[0,0,0,0,0,0]
	eggs=[]
	activity=""
	activity_left=0.0
	activity_zone=0
	activity_total=0
	event_left=0.0
	event_clock=0.0
	event_zone=-1
	event_claimed=false
	price_day=-1
	prices=[]
	market_day_override=-1
	pet_menu_signature=""
	sound_effects=true

func _ready():
	super._ready()
	if not testing and not "--visual-test" in OS.get_cmdline_user_args():
		DisplayServer.window_set_title("Sproutlings V1.2")

func genes(p: Dictionary) -> Array:
	return p.get("genes",[0,0,0])

func ensure_genes(p: Dictionary):
	if not p.has("genes"):
		p["genes"]=[rng.randi_range(0,4),rng.randi_range(0,4),rng.randi_range(0,4)]
	if not p.has("generation"): p["generation"]=0
	if not p.has("breed_cd"): p["breed_cd"]=0.0

func cross_genes(a: Dictionary,b: Dictionary) -> Array:
	var g=[]
	for i in range(3):
		var v=int(genes(a)[i] if rng.randf()<0.5 else genes(b)[i])
		if rng.randf()<0.08: v+=1 if rng.randf()<0.5 else -1
		g.append(clampi(v,0,5))
	return g

func child_species(a: int,b: int) -> int:
	var pair=[mini(a,b),maxi(a,b)]
	if pair==[0,1] and rng.randf()<0.35: return 12
	if pair==[2,3] and rng.randf()<0.35: return 13
	if pair==[4,5] and rng.randf()<0.35: return 14
	if pair==[6,7] and rng.randf()<0.35: return 15
	return a if rng.randf()<0.5 else b

func breed(i: int,j: int):
	if i<0 or j<0 or i>=creatures.size() or j>=creatures.size() or i==j:
		notify("İki farklı yaratık seç.")
		return
	var a=creatures[i]
	var b=creatures[j]
	if level<5 or gold<80 or eggs.size()>=3 or a.growth<300 or b.growth<300 or a.hunger<=0 or b.hunger<=0 or species_rarity(int(a.species))==5 or species_rarity(int(b.species))==5 or float(a.get("breed_cd",0))>0 or float(b.get("breed_cd",0))>0:
		notify("Üretim: L5, 80 G, iki tok yetişkin (Mythic hariç), hazır ebeveynler ve boş yumurta yuvası.")
		return
	ensure_genes(a)
	ensure_genes(b)
	gold-=80
	a.breed_cd=180.0
	b.breed_cd=180.0
	a.hunger=maxf(0.0,float(a.hunger)-300)
	b.hunger=maxf(0.0,float(b.hunger)-300)
	var chance=0.01+0.02*(int(a.shiny)+int(b.shiny))
	eggs.append({"species":child_species(int(a.species),int(b.species)),"shiny":rng.randf()<chance,"genes":cross_genes(a,b),"generation":maxi(int(a.generation),int(b.generation))+1,"left":90.0})
	notify("Yumurta kuluçkaya alındı. 90 saniye.")
	effect_sound(2)
	refresh_ui()
	save_game()

func hatch_egg():
	for i in range(eggs.size()):
		var egg=eggs[i]
		if egg.left>0: continue
		var p={"species":int(egg.species),"shiny":bool(egg.shiny),"growth":0.0,"hunger":0.0,"active":false,"production":0.0,"genes":egg.genes.duplicate(),"generation":int(egg.generation),"breed_cd":0.0}
		eggs.remove_at(i)
		creatures.append(p)
		selected_creature=creatures.size()-1
		if not seen_species.has(int(p.species)): seen_species.append(int(p.species))
		refresh_all()
		notify("Yumurtadan "+SPECIES[int(p.species)]+" çıktı!")
		save_game()
		if not testing:
			manager.hide()
			show_reveal(p)
		return
	notify("Henüz hazır yumurta yok.")

func bonus(kind: String) -> float:
	var base=super.bonus(kind)
	var extra=0.0
	for p in creatures:
		if not p.active or p.hunger<=0: continue
		var g=genes(p)
		var id=int(p.species)
		var stage=0.5 if p.growth<100 else (0.75 if p.growth<300 else 1.0)
		if kind=="speed": extra+=(float(g[0])*0.004+(0.04 if id in [12,14] else 0.0))*stage
		if kind=="yield": extra+=(float(g[1])*0.004+(0.04 if id in [13,15] else 0.0))*stage
	return minf(0.4,base+extra)

func open_crate(t: int):
	var old=creatures.size()
	super.open_crate(t)
	if creatures.size()>old:
		ensure_genes(creatures.back())
		refresh_ui()

func train_creature():
	var old=0.0
	if selected_creature>=0 and selected_creature<creatures.size(): old=float(creatures[selected_creature].growth)
	super.train_creature()
	if selected_creature>=0 and selected_creature<creatures.size():
		var p=creatures[selected_creature]
		if p.growth>old:
			p.growth=minf(300.0,float(p.growth)+float(genes(p)[2])*2.0)
			refresh_all()

func start_activity(kind: String):
	if activity!="":
		notify("Önce devam eden işi bitir.")
		return
	if kind=="fish" and zone not in [0,2,5]:
		notify("Balıkçılık: Yeşil Vadi, Safir Gölü veya Ay Bahçesi.")
		return
	if kind=="mine" and (level<3 or zone not in [0,3,4]):
		notify("Madencilik L3: Yeşil Vadi, Köz Toprakları veya Kristal Vadisi.")
		return
	if kind not in ["fish","mine"]: return
	var cost=3 if kind=="fish" else 5
	if gold<cost:
		notify("Ekipman için yeterli altın yok.")
		return
	if gathered.reduce(func(a,b): return a+int(b),0)>=100:
		notify("Kaynak çantası dolu.")
		return
	gold-=cost
	activity=kind
	activity_zone=zone
	activity_left=8.0 if kind=="fish" else 12.0
	notify("Olta atıldı..." if kind=="fish" else "Kazma çalışıyor...")
	effect_sound(0)
	refresh_ui()
	save_game()

func finish_activity():
	if activity=="": return
	var roll=rng.randf()
	var rare_chance=0.06 if activity_zone in [4,5] else 0.02
	if event_left>0 and event_zone==activity_zone: rare_chance+=0.12
	var idx=0 if activity=="fish" else 3
	if roll<rare_chance: idx+=2
	elif roll<0.30: idx+=1
	gathered[idx]+=1
	activity_total+=1
	activity=""
	activity_left=0.0
	notify(RESOURCE_NAMES[idx]+" elde edildi!")
	effect_sound(3 if idx%3==2 else 1)
	refresh_ui()
	save_game()

func market_day() -> int:
	return market_day_override if market_day_override>=0 else int(floor(Time.get_unix_time_from_system()/86400.0))

func update_prices():
	var day=market_day()
	if price_day==day: return
	price_day=day
	var r=RandomNumberGenerator.new()
	r.seed=day*7919+17011
	prices=[]
	for v in RESOURCE_VALUE: prices.append(maxi(1,roundi(v*r.randf_range(0.75,1.35))))
	# The town trader buys harvested goods from storage too.
	for v in ITEM_PRICES: prices.append(maxi(1,roundi(v*r.randf_range(0.8,1.25))))

func trade_resource(i: int,buy: bool):
	update_prices()
	if i<0 or i>=prices.size(): return
	var price=int(prices[i])
	if i<6:
		if buy:
			var cost=ceili(price*1.35)
			if gold<cost or gathered.reduce(func(a,b): return a+int(b),0)>=100: return
			gold-=cost
			gathered[i]+=1
		else:
			if gathered[i]<=0: return
			gathered[i]-=1
			gold+=price
	else:
		var item=i-6
		if buy:
			var cost=ceili(price*1.35)
			if gold<cost or storage_used()>=storage_capacity(): return
			gold-=cost
			change_item(item,1)
		else:
			if quantity(item)<=0: return
			change_item(item,-1)
			gold+=price
	notify("Tüccar işlemi tamamlandı.")
	effect_sound(1)
	refresh_ui()
	save_game()

func begin_event(z: int):
	if z<0 or z>=6 or not zone_open[z] or level<5: return
	event_zone=z
	event_left=90.0
	event_claimed=false
	update_event_marker()
	notify(ZONES[z]+": "+EVENT_NAMES[z]+" başladı!")

func collect_event():
	if event_left<=0 or event_zone!=zone or event_claimed:
		notify("Bu bölgede toplanabilir etkinlik yok.")
		return
	event_claimed=true
	gold+=25+zone*10
	crates[5]+=1
	if zone>=3: crystal_dust+=1
	notify("Nadir etkinlik ödülü: etkinlik kasası ve altın!")
	effect_sound(5)
	update_event_marker()
	refresh_ui()
	save_game()

func effect_sound(r: int):
	if sound_effects and not testing and is_instance_valid(chime): play_chime(r)

func pet_model(parent: Node3D,species: int,shiny: bool) -> Node3D:
	if species<12: return super.pet_model(parent,species,shiny)
	var base=[0,2,5,6][species-12]
	var n=super.pet_model(parent,base,shiny)
	var c=[Color("#f4b9cf"),Color("#77e5e4"),Color("#ffbb76"),Color("#adabef")][species-12]
	match species:
		12:
			for j in range(5):
				var a=j*TAU/5
				sphere_at(n,Vector3(cos(a)*0.22,1.15,sin(a)*0.22),Vector3(0.27,0.12,0.20),c)
		13:
			for j in range(3): gem(n,Vector3((j-1)*0.23,0.75,-0.48),0.13,0.35,c)
			sphere_at(n,Vector3(0,0.50,-0.65),Vector3(0.60,0.12,0.25),c)
		14:
			for j in range(4): cone_at(n,Vector3((j%2-0.5)*0.55,0.88,-0.3+int(j/2)*0.42),0.14,0.42,c)
		15:
			for x in [-0.45,0.45]: sphere_at(n,Vector3(x,0.65,-0.18),Vector3(0.76,0.13,0.36),c)
			gem(n,Vector3(0,1.12,0.05),0.14,0.40,c)
	return n

func rebuild_region():
	super.rebuild_region()
	if not is_instance_valid(region_root): return
	npc_root=Node3D.new()
	npc_root.name="VillageVisitors"
	region_root.add_child(npc_root)
	for i in range(3):
		var p=Vector3(-5.7+i*1.05,0,-3.35)
		var colors=[Color("#d19e66"),Color("#74a9c8"),Color("#a28ac6")]
		box_at(npc_root,p+Vector3(0,0.38,0),Vector3(0.40,0.62,0.33),colors[i])
		sphere_at(npc_root,p+Vector3(0,0.89,0),Vector3(0.36,0.36,0.36),Color("#f0cc9f"))
		cone_at(npc_root,p+Vector3(0,1.18,0),0.28,0.28,colors[i].darkened(0.18))
		var label=Label3D.new()
		label.text=["Mira • Tüccar","Deniz • Balıkçı","Bora • Madenci"][i]
		label.position=p+Vector3(0,1.48,0)
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size=32
		label.pixel_size=0.008
		npc_root.add_child(label)
	update_event_marker()

func update_event_marker():
	if not is_instance_valid(region_root): return
	if is_instance_valid(event_marker):
		event_marker.queue_free()
	event_marker=null
	if event_left<=0 or event_zone!=zone or event_claimed: return
	event_marker=Node3D.new()
	region_root.add_child(event_marker)
	event_marker.position=Vector3(5.8,0.6,2.5)
	for i in range(6):
		var a=i*TAU/6
		gem(event_marker,Vector3(cos(a)*0.55,0.25,sin(a)*0.55),0.15,0.5,Color("#f2dc99"))
	var ring=TorusMesh.new()
	ring.inner_radius=0.55
	ring.outer_radius=0.65
	var m=mesh_at(event_marker,ring,Vector3.ZERO,Color("#f5da8a"))
	var material=m.material_override as StandardMaterial3D
	material.emission_enabled=true
	material.emission=Color("#eec46a")

func tick12(delta: float):
	for p in creatures:
		if p.has("breed_cd"): p.breed_cd=maxf(0.0,float(p.breed_cd)-delta)
	for egg in eggs: egg.left=maxf(0.0,float(egg.left)-delta)
	if activity!="":
		activity_left=maxf(0.0,activity_left-delta)
		if activity_left<=0: finish_activity()
	if event_left>0:
		event_left=maxf(0.0,event_left-delta)
		if event_left<=0: update_event_marker()
	event_clock+=delta
	if event_clock>=180:
		event_clock=0.0
		if level>=5 and event_left<=0 and rng.randf()<0.30:
			var zones=[]
			for z in range(6):
				if zone_open[z]: zones.append(z)
			begin_event(int(zones[rng.randi_range(0,zones.size()-1)]))

func _process(delta):
	super._process(delta)
	if testing: return
	tick12(delta)
	if is_instance_valid(event_marker) and motion: event_marker.rotation.y+=delta*0.6
	refresh12+=delta
	if refresh12>=1.0:
		refresh12=0.0
		update_prices()
		refresh_ui()

func make_ui():
	super.make_ui()
	var v=new_tab("Kuluçka")
	lbl(v,"Yumurta ve kalıtım",23,true)
	breed_text=lbl(v,"",15)
	breed_a=menu(v,func(_i): pass)
	breed_b=menu(v,func(_i): pass)
	btn(v,"Çiftleştir (80 G)",func(): breed(breed_a.selected,breed_b.selected))
	hatch_btn=btn(v,"Hazır yumurtayı aç",hatch_egg)
	lbl(v,"İki tok yetişkin; L5. Her gen ebeveynlerden birinden gelir; %8 mutasyon olasılığı (gen başına). Mythic üretilemez. 3 yuva, 90 sn kuluçka.",13)
	v=new_tab("Köy ve kaynak")
	lbl(v,"Mira, Deniz ve Bora",23,true)
	village_text=lbl(v,"",15)
	btn(v,"Deniz • Balık tut (3 G)",func(): start_activity("fish"))
	btn(v,"Bora • Maden kaz (5 G)",func(): start_activity("mine"))
	action_meter=ProgressBar.new()
	action_meter.custom_minimum_size.y=22
	action_meter.max_value=100
	v.add_child(action_meter)
	resource_menu=menu(v,func(_i): refresh_ui())
	for name in RESOURCE_NAMES: resource_menu.add_item(name)
	for name in ITEMS: resource_menu.add_item(name)
	resource_text=lbl(v,"",14)
	var row=HBoxContainer.new()
	v.add_child(row)
	btn(row,"Mira • 1 adet sat",func(): trade_resource(resource_menu.selected,false))
	btn(row,"Mira • 1 adet al",func(): trade_resource(resource_menu.selected,true))
	v=new_tab("Etkinlikler")
	lbl(v,"Biyom olayları",23,true)
	event_text=lbl(v,"",16)
	btn(v,"Etkinlik ödülünü topla",collect_event)
	lbl(v,"L5 sonrasında her 3 dakikada %30 olasılıkla açık bir biyomda 90 saniyelik etkinlik. Ödül bir kez alınır.",13)
	var audio=CheckButton.new()
	audio.text="Yeni işlem sesleri"
	audio.button_pressed=sound_effects
	v.add_child(audio)
	audio.toggled.connect(func(on): sound_effects=on; save_game())
	manager.size=Vector2i(860,710)
	manager_tabs.custom_minimum_size=Vector2(790,535)
	for c in get_node("HUD").get_children():
		if c is HBoxContainer:
			for b in c.get_children():
				if b is Button and b.text=="Gelişim [J]":
					btn(c,"Köy [K]",func(): show_manager(8))
					btn(c,"Kuluçka [N]",func(): show_manager(7))
					break
	apply_polish()
	refresh_ui()

func apply_polish():
	var theme=Theme.new()
	for state_name in ["normal","hover","pressed","disabled","focus"]:
		var style=StyleBoxFlat.new()
		style.bg_color=Color("#294b42") if state_name=="normal" else (Color("#416c58") if state_name in ["hover","focus"] else Color("#203831"))
		style.border_color=Color("#7cab8b") if state_name=="focus" else Color("#527865")
		style.set_border_width_all(1)
		style.set_corner_radius_all(9)
		style.content_margin_left=10
		style.content_margin_right=10
		style.content_margin_top=5
		style.content_margin_bottom=5
		theme.set_stylebox(state_name,"Button",style)
		theme.set_stylebox(state_name,"OptionButton",style)
	theme.set_color("font_color","Button",Color("#f0f6e9"))
	theme.set_color("font_color","OptionButton",Color("#eaf3e5"))
	theme.set_color("font_disabled_color","Button",Color("#879d91"))
	for c in get_node("HUD").get_children():
		if c is Control: c.theme=theme
	for w in [manager,inventory_window,decor_window,welcome_window,reveal_window]:
		if is_instance_valid(w): w.theme=theme

func refresh_ui():
	super.refresh_ui()
	if is_instance_valid(status_line): status_line.text="V1.2 / "+ZONES[zone]+" • "+SEASONS[season]
	if not is_instance_valid(breed_text): return
	var sig=str(creatures.size())+":"+str(creatures.map(func(p): return int(p.species)))
	if pet_menu_signature!=sig or breed_a.item_count!=creatures.size():
		pet_menu_signature=sig
		var ia=breed_a.selected
		var ib=breed_b.selected
		breed_a.clear()
		breed_b.clear()
		for i in range(creatures.size()):
			var name="%d • %s" % [i+1,SPECIES[int(creatures[i].species)]]
			breed_a.add_item(name)
			breed_b.add_item(name)
		if creatures.size()>0:
			breed_a.select(clampi(ia,0,creatures.size()-1))
			breed_b.select(clampi(ib if ib>=0 else 1,0,creatures.size()-1))
	var lines=["Kuluçka: %d/3" % eggs.size()]
	var ready=false
	for e in eggs:
		lines.append("Yumurta • "+("Hazır" if e.left<=0 else "%d sn" % ceili(e.left)))
		if e.left<=0: ready=true
	if selected_creature>=0 and selected_creature<creatures.size():
		var p=creatures[selected_creature]
		lines.append("%s | Nesil %d | Hız %d / Verim %d / Eğitim %d" % [SPECIES[int(p.species)],int(p.get("generation",0)),genes(p)[0],genes(p)[1],genes(p)[2]])
		lines.append("Çiftleşme bekleme: %d sn" % ceili(float(p.get("breed_cd",0))))
	breed_text.text="\n".join(lines)
	hatch_btn.disabled=not ready
	update_prices()
	village_text.text="Bölge: "+ZONES[zone]+"\nToplanan kaynak: %d • Günlük fiyatlar UTC gününde değişir." % activity_total
	action_meter.value=0.0 if activity=="" else 100.0*(1.0-activity_left/(8.0 if activity=="fish" else 12.0))
	var idx=resource_menu.selected
	if idx>=0 and idx<prices.size():
		var name=RESOURCE_NAMES[idx] if idx<6 else ITEMS[idx-6]
		var qty=int(gathered[idx]) if idx<6 else quantity(idx-6)
		resource_text.text="%s • Stok %d\nSatış %d G • Alış %d G" % [name,qty,prices[idx],ceili(prices[idx]*1.35)]
	event_text.text="Etkinlik bekleniyor." if event_left<=0 else "%s • %s\n%d sn • %s" % [EVENT_NAMES[event_zone],ZONES[event_zone],ceili(event_left),"Ödül alındı" if event_claimed else "Ödül hazır"]
	if is_instance_valid(dex_info):
		var dex=[]
		for i in range(SPECIES.size()):
			dex.append("%s | %s | %s" % [SPECIES[i] if seen_species.has(i) else "???",RARITIES[species_rarity(i)],ELEMENTS[i] if seen_species.has(i) else "Keşfedilmedi"])
		dex_info.text="Keşif: %d/%d\n" % [seen_species.size(),SPECIES.size()]+"\n".join(dex)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_K:
			show_manager(8)
			return
		if event.keycode==KEY_N:
			show_manager(7)
			return
	super._unhandled_input(event)

func _write_extension(data: Dictionary):
	super._write_extension(data)
	data["v12"]={"gathered":gathered,"eggs":eggs,"activity":activity,"activity_left":activity_left,"activity_zone":activity_zone,"activity_total":activity_total,"event_left":event_left,"event_clock":event_clock,"event_zone":event_zone,"event_claimed":event_claimed,"sound_effects":sound_effects}

func _read_extension(data: Dictionary):
	super._read_extension(data)
	var e=data.get("v12",{})
	if not e is Dictionary: return
	var g=e.get("gathered",[])
	if g is Array and g.size()==6: gathered=g
	eggs=e.get("eggs",[])
	activity=str(e.get("activity",""))
	activity_left=float(e.get("activity_left",0))
	activity_zone=int(e.get("activity_zone",0))
	activity_total=int(e.get("activity_total",0))
	event_left=float(e.get("event_left",0))
	event_clock=float(e.get("event_clock",0))
	event_zone=int(e.get("event_zone",-1))
	event_claimed=bool(e.get("event_claimed",false))
	sound_effects=bool(e.get("sound_effects",true))
	for p in creatures: ensure_genes(p)

func run_tests():
	var errors=[]
	level=8
	gold=1000
	for i in range(2): creatures.append({"species":i,"shiny":false,"growth":300.0,"hunger":1800.0,"active":true,"production":0.0,"genes":[i+1,i+2,i+3],"generation":0,"breed_cd":0.0})
	refresh_all()
	breed(0,0)
	if eggs.size()!=0: errors.append("same parent")
	breed(0,1)
	breed(0,1)
	if eggs.size()!=1 or gold!=920: errors.append("breed cooldown")
	tick12(91.0)
	hatch_egg()
	if creatures.size()!=3 or eggs.size()!=0 or creatures.back().generation!=1 or genes(creatures.back()).size()!=3: errors.append("hatch/genetics")
	start_activity("fish")
	tick12(8.1)
	start_activity("mine")
	tick12(12.1)
	if activity_total!=2 or gathered.reduce(func(a,b): return a+int(b),0)!=2: errors.append("resource activities")
	market_day_override=30000
	update_prices()
	var old=prices.duplicate()
	market_day_override=30001
	update_prices()
	if old==prices: errors.append("market day")
	var idx=0
	for i in range(6):
		if gathered[i]>0: idx=i; break
	var count=int(gathered[idx])
	var before=gold
	var value=prices[idx]
	trade_resource(idx,false)
	if gathered[idx]!=count-1 or gold!=before+value: errors.append("market sale")
	begin_event(0)
	var c=crates[5]
	collect_event()
	collect_event()
	if crates[5]!=c+1 or not event_claimed: errors.append("event once")
	for i in range(12,16):
		var n=pet_model(pets_root,i,false)
		if n.get_child_count()<10 or species_rarity(i)!=i-12: errors.append("new species model")
		n.queue_free()
	var path="user://sproutlings_v12_test_"+str(Time.get_ticks_usec())+".json"
	save_game(path,true)
	reset_data()
	load_game(path)
	if activity_total!=2 or not event_claimed or creatures.size()!=3 or creatures.back().generation!=1: errors.append("save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not errors.is_empty():
		push_error("V1.2 FAIL "+str(errors))
		get_tree().quit(1)
		return
	print("V1.2 PASS: breeding, genes, eggs, fishing, mining, trader, daily prices, event, four species, save")
	reset_data()
	rebuild_region()
	rebuild_decor()
	refresh_all()
	super.run_tests()

func visual_test():
	level=8
	for i in range(7,10):
		show_manager(i)
		await get_tree().process_frame
		if manager_tabs.current_tab!=i:
			push_error("V1.2 VISUAL FAIL")
			get_tree().quit(1)
			return
	manager.hide()
	begin_event(0)
	await get_tree().process_frame
	if not is_instance_valid(npc_root) or not is_instance_valid(event_marker):
		push_error("V1.2 VISUAL FAIL NPC/event")
		get_tree().quit(1)
		return
	show_reveal({"species":14,"shiny":false})
	await get_tree().create_timer(1.8).timeout
	if not reveal_label.text.contains(SPECIES[14]):
		push_error("V1.2 VISUAL FAIL new species")
		get_tree().quit(1)
		return
	close_reveal()
	print("V1.2 VISUAL PASS: three tabs, NPCs, event marker, new species reveal")
	await super.visual_test()
