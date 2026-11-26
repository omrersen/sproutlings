extends "res://farm_v12.gd"

const TOOL_NAMES=["Olta","Kazma","Sulama kabı"]
const WEATHER_NAMES=["Güneşli","Bulutlu","Yağmurlu","Sisli"]
const NEW_DECOR=["Bahçe kemeri","Kuş evi","Taş fener"]
const NEW_COST=[85,120,160]
const NPC_POS=[Vector3(-2.5,0,-3.65),Vector3(-0.9,0,-3.65),Vector3(0.7,0,-3.65)]
const CAVE_GATE=Vector3(5.65,0,3.8)
const ROCK_POS=[Vector3(-3.8,0,-2.1),Vector3(0,0,-3.0),Vector3(3.8,0,-2.0),Vector3(3.8,0,1.7)]
var hero: Node3D
var hero_legs=[]
var hero_position=Vector3(0,0,4.5)
var walk_phase=0.0
var cave: Node3D
var cave_active=false
var cave_hidden=[]
var cave_rocks=[]
var rock_hp=[3,3,3,3]
var rock_respawn=[0.0,0.0,0.0,0.0]
var hit_delay=0.0
var tool_levels=[0,0,0]
var equipped=0
var extra_decor=[false,false,false]
var extra_root: Node3D
var weather=0
var weather_left=70.0
var weather_root: Node3D
var drops=[]
var music: AudioStreamPlayer
var music_enabled=true
var fishing=false
var fish_phase=0.0
var fish_left=0.0
var fish_target=0.5
var fish_window: Window
var fish_bar: ProgressBar
var fish_label: Label
var dialogue: Window
var dialogue_text: Label
var dialogue_name: Label
var dialogue_action: Button
var selected_npc=0
var gear_text: Label
var tool_choice: OptionButton
var extra_choice: OptionButton
var hint: Label
var bag_labels=[]
var bag_item: OptionButton
var bag_summary: Label
var bag_recipe: OptionButton
var bag_selected: Label
var plot_cache={}
var shared_sphere: SphereMesh
var shared_boxes={}
var shared_cones={}
var fast_mode=false
var weather_toggle: CheckButton

func reset_data():
	super.reset_data()
	hero_position=Vector3(0,0,4.5)
	tool_levels=[0,0,0]
	equipped=0
	extra_decor=[false,false,false]
	weather=0
	weather_left=70.0
	music_enabled=true
	fast_mode=false
	rock_hp=[3,3,3,3]
	rock_respawn=[0.0,0.0,0.0,0.0]
	fishing=false
	plot_cache.clear()

func _ready():
	super._ready()
	if not testing and not "--visual-test" in OS.get_cmdline_user_args():
		DisplayServer.window_set_title("Sproutlings V1.3")
		start_music()

func sphere_at(parent: Node3D,pos: Vector3,scale_v: Vector3,col: Color) -> MeshInstance3D:
	if not is_instance_valid(shared_sphere):
		shared_sphere=SphereMesh.new()
		shared_sphere.radial_segments=10
		shared_sphere.rings=5
	var n=mesh_at(parent,shared_sphere,pos,col)
	n.scale=scale_v
	return n

func box_at(parent: Node3D,pos: Vector3,size: Vector3,col: Color) -> MeshInstance3D:
	if not shared_boxes.has(size):
		var m=BoxMesh.new()
		m.size=size
		if shared_boxes.size()<512: shared_boxes[size]=m
		else: return mesh_at(parent,m,pos,col)
	return mesh_at(parent,shared_boxes[size],pos,col)

func cone_at(parent: Node3D,pos: Vector3,radius: float,height: float,col: Color) -> MeshInstance3D:
	var key=Vector2(radius,height)
	if not shared_cones.has(key):
		var m=CylinderMesh.new()
		m.top_radius=0
		m.bottom_radius=radius
		m.height=height
		m.radial_segments=7
		shared_cones[key]=m
	return mesh_at(parent,shared_cones[key],pos,col)

func refresh_plot(i: int):
	if i<0 or i>=plots.size() or i>=crop_nodes.size(): return
	var p=plots[i]
	var step=-1 if p.crop<0 else (5 if p.remaining<=0 else clampi(int(5.0*(1.0-float(p.remaining)/float(CROPS[int(p.crop)].time))),0,4))
	var key=[zone,i<unlocked,int(p.crop),bool(p.watered),step]
	if plot_cache.get(i,[])==key: return
	plot_cache[i]=key
	super.refresh_plot(i)

func make_world():
	super.make_world()
	hero=Node3D.new()
	hero.name="Player"
	add_child(hero)
	hero.position=hero_position
	box_at(hero,Vector3(0,0.62,0),Vector3(0.43,0.55,0.31),Color("#3d7969"))
	box_at(hero,Vector3(0,0.63,-0.21),Vector3(0.38,0.43,0.18),Color("#b18c59"))
	sphere_at(hero,Vector3(0,1.06,0.02),Vector3(0.38,0.39,0.37),Color("#edc79b"))
	var hat=CylinderMesh.new()
	hat.top_radius=0.26
	hat.bottom_radius=0.33
	hat.height=0.10
	mesh_at(hero,hat,Vector3(0,1.25,0),Color("#d8b46f"))
	box_at(hero,Vector3(0,1.35,0),Vector3(0.36,0.15,0.32),Color("#d8b46f"))
	for x in [-0.27,0.27]:
		box_at(hero,Vector3(x,0.59,0.02),Vector3(0.14,0.4,0.14),Color("#d9a875"))
	for x in [-0.115,0.115]:
		var leg=Node3D.new()
		hero.add_child(leg)
		leg.position=Vector3(x,0.34,0)
		box_at(leg,Vector3(0,-0.12,0),Vector3(0.16,0.29,0.20),Color("#414e57"))
		box_at(leg,Vector3(0,-0.27,0.055),Vector3(0.18,0.12,0.28),Color("#694d3c"))
		hero_legs.append(leg)
	weather_root=Node3D.new()
	add_child(weather_root)
	for i in range(48):
		var n=box_at(weather_root,Vector3.ZERO,Vector3(0.026,0.33,0.026),Color("#8bd3ed"))
		n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.position=Vector3(-7.0+fmod(i*2.73,14.0),0.5+fmod(i*1.93,5.0),-5.7+fmod(i*3.13,11.4))
		drops.append(n)
	apply_weather()

func rebuild_region():
	super.rebuild_region()
	if not is_instance_valid(region_root): return
	if zone in [0,3,4]:
		var p=CAVE_GATE
		box_at(region_root,p+Vector3(0,0.65,-0.25),Vector3(1.8,1.3,0.4),Color("#655b56"))
		box_at(region_root,p+Vector3(0,0.45,0),Vector3(0.95,0.90,0.45),Color("#292e36"))
		for x in [-0.77,0.77]:
			gem(region_root,p+Vector3(x,0.75,0),0.35,1.5,Color("#817c72"))
		var sign=Label3D.new()
		sign.text="Maden • F"
		sign.position=p+Vector3(0,1.75,0)
		sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		sign.font_size=32
		sign.pixel_size=0.009
		region_root.add_child(sign)
	rebuild_extra_decor()

func rebuild_extra_decor():
	if not is_instance_valid(region_root): return
	if is_instance_valid(extra_root):
		extra_root.queue_free()
	extra_root=Node3D.new()
	region_root.add_child(extra_root)
	if zone!=0: return
	if extra_decor[0]:
		for x in [-0.52,0.52]:
			box_at(extra_root,Vector3(x+3.8,0.7,4.5),Vector3(0.13,1.4,0.13),Color("#9a7450"))
			flower_cluster(extra_root,Vector3(x+3.8,0,4.65),Color("#efb3d1"))
		box_at(extra_root,Vector3(3.8,1.42,4.5),Vector3(1.3,0.15,0.28),Color("#c39a70"))
	if extra_decor[1]:
		box_at(extra_root,Vector3(-3.7,0.72,4.8),Vector3(0.12,1.45,0.12),Color("#96724e"))
		box_at(extra_root,Vector3(-3.7,1.46,4.8),Vector3(0.52,0.5,0.45),Color("#f2c77d"))
		cone_at(extra_root,Vector3(-3.7,1.85,4.8),0.37,0.35,Color("#a96859"))
		sphere_at(extra_root,Vector3(-3.7,1.46,5.04),Vector3(0.16,0.16,0.05),Color("#42362f"))
	if extra_decor[2]:
		box_at(extra_root,Vector3(5.8,0.36,-0.1),Vector3(0.5,0.72,0.5),Color("#969a8d"))
		var n=box_at(extra_root,Vector3(5.8,0.85,-0.1),Vector3(0.35,0.35,0.35),Color("#ffdfa1"))
		var m=n.material_override as StandardMaterial3D
		m.emission_enabled=true
		m.emission=Color("#ffc974")
		cone_at(extra_root,Vector3(5.8,1.14,-0.1),0.38,0.29,Color("#7a817b"))

func buy_extra(i: int):
	if i<0 or i>=3 or extra_decor[i] or gold<NEW_COST[i]: return
	gold-=NEW_COST[i]
	extra_decor[i]=true
	rebuild_extra_decor()
	refresh_ui()
	save_game()

func modal_open() -> bool:
	for w in [manager,inventory_window,decor_window,reveal_window,welcome_window,fish_window,dialogue]:
		if is_instance_valid(w) and w.visible: return true
	return false

func move_hero(input: Vector2,delta: float):
	if not is_instance_valid(hero) or input.length_squared()<0.001: return
	var forward=-cam.global_transform.basis.z
	forward.y=0
	forward=forward.normalized()
	var right=cam.global_transform.basis.x
	right.y=0
	right=right.normalized()
	var dir=(right*input.x+forward*input.y).normalized()
	var dest=hero.position+dir*3.25*delta
	dest.x=clampf(dest.x,-6.5,6.5)
	dest.z=clampf(dest.z,-5.2,5.2)
	if cave_active:
		dest.x=clampf(dest.x,-5.7,5.7)
		dest.z=clampf(dest.z,-4.6,4.6)
	hero.position=dest
	hero.rotation.y=atan2(dir.x,dir.z)
	walk_phase+=delta*11.0
	for i in range(hero_legs.size()):
		hero_legs[i].rotation.x=sin(walk_phase+i*PI)*0.40 if motion else 0.0
	if not cave_active: hero_position=hero.position

func nearest_npc() -> int:
	if not is_instance_valid(hero) or cave_active: return -1
	var idx=-1
	var best=1.8
	for i in range(3):
		var dist=hero.position.distance_to(NPC_POS[i])
		if dist<best: best=dist;idx=i
	return idx

func show_dialogue(i: int):
	if i<0 or i>=3: return
	selected_npc=i
	dialogue_name.text=["Mira — Tüccar","Deniz — Balıkçı","Bora — Madenci"][i]
	dialogue_text.text=["Hoş geldin! Fiyatlar her gün değişir. Çantandaki ürünleri alıp satabiliriz.","Balıklar suyun ritmini izler. İşaret yeşil bölgedeyken yakala! Daha iyi bir olta işini kolaylaştırır.","Mağarada dört cevher damarı var. Yaklaş, F ile kaz. Kazmanı geliştirirsen daha hızlı kırarsın."][i]
	dialogue_action.text=["Pazarı aç","Balık tut","Mağaraya gir"][i]
	dialogue.popup_centered()

func do_dialogue():
	dialogue.hide()
	match selected_npc:
		0: show_manager(8)
		1: start_fishing()
		2: enter_cave()

func interact():
	if cave_active:
		if hero.position.distance_to(Vector3(0,0,4.3))<1.6: exit_cave()
		else: mine_nearest()
		return
	var n=nearest_npc()
	if n>=0: show_dialogue(n);return
	if zone in [0,3,4] and hero.position.distance_to(CAVE_GATE)<1.8: enter_cave();return
	var best=1.8
	var idx=-1
	for i in range(unlocked):
		var p=plot_pos(i)
		p.y=0
		var dist=hero.position.distance_to(p)
		if dist<best: best=dist;idx=i
	if idx>=0:
		selected_plot=idx
		plot_action(idx)
	else: notify("Etkileşmek için bir tarla, NPC veya mağaraya yaklaş.")

func enter_cave():
	if cave_active or level<3 or zone not in [0,3,4]:
		notify("Mağara L3: Yeşil Vadi, Köz Toprakları veya Kristal Vadisi.")
		return
	manager.hide()
	cave_active=true
	cave_hidden=[]
	for n in get_children():
		if n is Node3D and n!=cam and n!=sun and n!=hero and n!=weather_root and n.visible:
			cave_hidden.append(n)
			n.hide()
	weather_root.hide()
	cave=Node3D.new()
	add_child(cave)
	box_at(cave,Vector3(0,-0.35,0),Vector3(13,0.5,11),Color("#46515b"))
	for x in [-6.1,6.1]:
		box_at(cave,Vector3(x,0.9,0),Vector3(0.7,1.8,11),Color("#56606b"))
	box_at(cave,Vector3(0,0.9,-5.2),Vector3(12.4,1.8,0.6),Color("#56606b"))
	for i in range(6):
		var p=Vector3(-5.5+i*2.2,0,-4.2)
		gem(cave,p+Vector3(0,0.8,0),0.36,1.6,Color("#7796a7"))
	cave_rocks=[]
	for i in range(4):
		var n=Node3D.new()
		cave.add_child(n)
		n.position=ROCK_POS[i]
		sphere_at(n,Vector3(0,0.32,0),Vector3(1.1,0.72,0.9),Color("#777c81"))
		for j in range(3): gem(n,Vector3((j-1)*0.23,0.6,0.12),0.17,0.45,Color("#d7a06a") if i<2 else Color("#a6ddea"))
		n.visible=rock_hp[i]>0
		cave_rocks.append(n)
	var sign=Label3D.new()
	sign.text="Çıkış • F"
	sign.position=Vector3(0,1.2,4.3)
	sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size=36
	sign.pixel_size=0.01
	cave.add_child(sign)
	hero.position=Vector3(0,0,3.8)
	notify("Mağara: kayaya yaklaş ve F ile kaz.")
	refresh_ui()

func exit_cave():
	if not cave_active: return
	cave_active=false
	if is_instance_valid(cave): cave.queue_free()
	cave=null
	for n in cave_hidden:
		if is_instance_valid(n): n.show()
	cave_hidden=[]
	hero.position=hero_position
	rebuild_region()
	apply_weather()
	refresh_all()

func mine_rock(i: int):
	if not cave_active or i<0 or i>=4 or rock_hp[i]<=0 or hit_delay>0: return
	if gathered.reduce(func(a,b): return a+int(b),0)>=100:
		notify("Kaynak çantası dolu.")
		return
	hit_delay=0.38
	rock_hp[i]=maxi(0,int(rock_hp[i])-1-(int(tool_levels[1]) if equipped==1 else 0))
	effect_sound(0)
	if rock_hp[i]==0:
		var idx=3 if i<2 else 4
		if rng.randf()<0.06+0.025*float(tool_levels[1]): idx=5
		gathered[idx]+=1
		activity_total+=1
		rock_respawn[i]=45.0
		cave_rocks[i].hide()
		notify(RESOURCE_NAMES[idx]+" kazıldı!")
		save_game()
	else: notify("Cevher dayanıklılığı: %d" % rock_hp[i])
	refresh_ui()

func mine_nearest():
	var best=1.65
	var idx=-1
	for i in range(4):
		if rock_hp[i]<=0: continue
		var dist=hero.position.distance_to(ROCK_POS[i])
		if dist<best: best=dist;idx=i
	if idx>=0: mine_rock(idx)
	else: notify("Bir cevher damarına yaklaş.")

func travel(z: int):
	if cave_active: exit_cave()
	super.travel(z)
	if is_instance_valid(hero):
		hero_position=Vector3(0,0,4.5)
		hero.position=hero_position

func start_activity(kind: String):
	if testing:
		super.start_activity(kind)
		return
	if kind=="fish": start_fishing()
	elif kind=="mine": enter_cave()

func start_fishing():
	if fishing or activity!="" or cave_active or zone not in [0,2,5] or gold<3:
		notify("Balıkçılık için uygun biyom, boş olta ve 3 altın gerekli.")
		return
	if gathered.reduce(func(a,b): return a+int(b),0)>=100: return
	gold-=3
	fishing=true
	fish_phase=0.0
	fish_left=9.0
	fish_target=rng.randf_range(0.25,0.75)
	if is_instance_valid(manager): manager.hide()
	update_fish_ui()
	if not testing: fish_window.popup_centered()
	save_game()

func fish_position() -> float:
	return 0.5+0.5*sin(fish_phase*3.4)

func fish_width() -> float:
	return 0.095+(0.035*float(tool_levels[0]) if equipped==0 else 0.0)

func fish_attempt():
	if not fishing: return
	var success=absf(fish_position()-fish_target)<=fish_width()
	fishing=false
	fish_window.hide()
	if success:
		var idx=0
		var roll=rng.randf()
		if roll<0.03+0.025*float(tool_levels[0]): idx=2
		elif roll<0.30: idx=1
		gathered[idx]+=1
		activity_total+=1
		notify(RESOURCE_NAMES[idx]+" yakalandı!")
		effect_sound(3)
	else: notify("Balık kaçtı. Tekrar dene!")
	refresh_ui()
	save_game()

func cancel_fishing():
	fishing=false
	if is_instance_valid(fish_window): fish_window.hide()
	notify("Olta toplandı.")

func update_fish_ui():
	if not is_instance_valid(fish_bar): return
	fish_bar.value=100.0*fish_position()
	fish_label.text="Hedef: %d–%d%%  •  İşaret: %d%%  •  %d sn" % [roundi((fish_target-fish_width())*100),roundi((fish_target+fish_width())*100),roundi(fish_position()*100),ceili(fish_left)]
	fish_bar.modulate=Color("#91e8a0") if absf(fish_position()-fish_target)<=fish_width() else Color("#e7c77e")

func upgrade_tool(i: int):
	if i<0 or i>=3 or tool_levels[i]>=3: return
	var cost=60*(int(tool_levels[i])+1)
	var ore=int(tool_levels[i])+1
	if level<3 or gold<cost or gathered[3]<ore:
		notify("Alet geliştirme: L3, %d G ve %d bakır." % [cost,ore])
		return
	gold-=cost
	gathered[3]-=ore
	tool_levels[i]+=1
	equipped=i
	refresh_ui()
	save_game()

func crop_speed_modifier(i: int) -> float:
	return super.crop_speed_modifier(i)*(1.0+0.04*float(tool_levels[2]) if equipped==2 else 1.0)

func apply_weather():
	if not is_instance_valid(weather_root): return
	weather_root.visible=weather==2 and not cave_active and motion and not fast_mode
	sun.light_color=[Color("#fff1d4"),Color("#d1dbe7"),Color("#bacfdf"),Color("#d2dbd8")][weather]
	for n in get_children():
		if n is WorldEnvironment:
			n.environment.background_color=[Color("#b7d9d8"),Color("#aebecb"),Color("#8da9be"),Color("#c3d1ce")][weather]
			n.environment.ambient_light_energy=[0.7,0.65,0.58,0.65][weather]

func weather_tick(delta: float):
	weather_left-=delta
	if weather_left<=0:
		weather=rng.randi_range(0,3)
		weather_left=75.0
		apply_weather()
		if weather==2 and not cave_active:
			for i in range(unlocked):
				if plots[i].crop>=0 and not plots[i].watered:
					plots[i].watered=true
					refresh_plot(i)
		notify("Hava: "+WEATHER_NAMES[weather])
	if is_instance_valid(weather_root) and weather_root.visible:
		for n in drops:
			n.position.y-=delta*5.5
			if n.position.y<0: n.position.y+=5.5

func start_music():
	if is_instance_valid(music): return
	music=AudioStreamPlayer.new()
	add_child(music)
	var rate=16000
	var length=8.0
	var count=int(rate*length)
	var data=PackedByteArray()
	data.resize(count*2)
	var melody=[261.63,329.63,392.0,440.0,392.0,329.63,293.66,329.63,293.66,349.23,440.0,523.25,440.0,392.0,329.63,293.66]
	for i in range(count):
		var t=float(i)/rate
		var k=mini(15,int(t/0.5))
		var x=fmod(t,0.5)
		var env=minf(x/0.025,1.0)*minf((0.5-x)/0.06,1.0)*exp(-x*4.0)
		var f=float(melody[k])
		var sample=(sin(TAU*f*x)+0.20*sin(TAU*f*2.0*x))*env*0.16
		data.encode_s16(i*2,int(sample*32767.0))
	var stream=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=rate
	stream.data=data
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_end=count
	music.stream=stream
	music.volume_db=-22
	if music_enabled: music.play()

func make_ui():
	super.make_ui()
	var layer=get_node("HUD")
	for c in layer.get_children():
		if c is HBoxContainer:
			for b in c.get_children():
				if b is Button and b.text=="Taşı [D]": b.text="Taşı [T]"
	var v=new_tab("Ekipman")
	lbl(v,"Aletler ve dekorasyon",23,true)
	gear_text=lbl(v,"",15)
	tool_choice=menu(v,func(_i): refresh_ui())
	for n in TOOL_NAMES: tool_choice.add_item(n)
	btn(v,"Aleti kuşan",func(): equipped=tool_choice.selected;refresh_ui();save_game())
	btn(v,"Aleti geliştir",func(): upgrade_tool(tool_choice.selected))
	extra_choice=menu(v,func(_i): pass)
	for i in range(3): extra_choice.add_item(NEW_DECOR[i]+" • "+str(NEW_COST[i])+" G")
	btn(v,"Yeni dekoru satın al",func(): buy_extra(extra_choice.selected))
	var mus=CheckButton.new()
	mus.text="Arka plan müziği"
	mus.button_pressed=music_enabled
	v.add_child(mus)
	mus.toggled.connect(func(on): music_enabled=on; if is_instance_valid(music): music.play() if on else music.stop(); save_game())
	weather_toggle=CheckButton.new()
	weather_toggle.text="Hafif grafik modu (yağmur efektlerini kapat)"
	weather_toggle.button_pressed=fast_mode
	v.add_child(weather_toggle)
	weather_toggle.toggled.connect(func(on): fast_mode=on;apply_weather();save_game())
	var old=inventory_window.get_child(0)
	old.hide()
	inventory_window.size=Vector2i(760,650)
	inventory_window.title="Çanta • Depo ve ekipman"
	v=window_content(inventory_window)
	lbl(v,"ÇANTA   /   ENVANTER",25,true)
	bag_summary=lbl(v,"",15)
	var tabs=TabContainer.new()
	tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size=Vector2(700,330)
	v.add_child(tabs)
	for cat in range(3):
		var pane=VBoxContainer.new()
		pane.name=["Ürünler","Kaynaklar","Yemler"][cat]
		tabs.add_child(pane)
		var grid=GridContainer.new()
		grid.columns=3
		grid.add_theme_constant_override("h_separation",12)
		grid.add_theme_constant_override("v_separation",12)
		pane.add_child(grid)
		var names=ITEMS if cat==0 else (RESOURCE_NAMES if cat==1 else FEED_NAMES)
		for i in range(names.size()):
			var tile=PanelContainer.new()
			tile.custom_minimum_size=Vector2(215,75)
			var style=StyleBoxFlat.new()
			style.bg_color=Color("#294b42")
			style.border_color=Color("#547e68")
			style.set_border_width_all(1)
			style.set_corner_radius_all(10)
			style.content_margin_left=10
			style.content_margin_top=8
			tile.add_theme_stylebox_override("panel",style)
			grid.add_child(tile)
			var l=lbl(tile,"",16,true)
			bag_labels.append([cat,i,l])
	bag_item=menu(v,func(_i): refresh_ui())
	for n in ITEMS: bag_item.add_item(n)
	for n in RESOURCE_NAMES: bag_item.add_item(n)
	var row=HBoxContainer.new()
	v.add_child(row)
	btn(row,"1 sat",func(): bag_trade(false))
	btn(row,"1 al",func(): bag_trade(true))
	bag_recipe=menu(v,func(_i): pass)
	for n in FEED_NAMES: bag_recipe.add_item(n)
	btn(v,"Yem üret",func(): craft_recipe(bag_recipe.selected))
	btn(v,"Kapat",func(): inventory_window.hide())
	dialogue=Window.new()
	dialogue.title="Köy sohbeti"
	dialogue.size=Vector2i(490,265)
	dialogue.exclusive=true
	layer.add_child(dialogue)
	dialogue.hide()
	dialogue.close_requested.connect(func(): dialogue.hide())
	v=window_content(dialogue)
	dialogue_name=lbl(v,"",23,true)
	dialogue_text=lbl(v,"",17)
	dialogue_action=btn(v,"Devam",do_dialogue)
	btn(v,"Görüşürüz",func(): dialogue.hide())
	fish_window=Window.new()
	fish_window.title="Balıkçılık"
	fish_window.size=Vector2i(500,250)
	fish_window.exclusive=true
	layer.add_child(fish_window)
	fish_window.hide()
	fish_window.close_requested.connect(cancel_fishing)
	v=window_content(fish_window)
	lbl(v,"BALIKÇILIK • ZAMANLAMA",22,true)
	fish_label=lbl(v,"",16)
	fish_bar=ProgressBar.new()
	fish_bar.max_value=100
	fish_bar.custom_minimum_size.y=32
	v.add_child(fish_bar)
	btn(v,"Yakala! (yeşil olduğunda)",fish_attempt)
	btn(v,"Vazgeç",cancel_fishing)
	hint=Label.new()
	layer.add_child(hint)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_left=305
	hint.offset_right=-305
	hint.offset_top=-105
	hint.offset_bottom=-68
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",16)
	hint.add_theme_color_override("font_color",Color("#fff2bf"))
	hint.add_theme_constant_override("outline_size",6)
	hint.add_theme_color_override("font_outline_color",Color("#1e322b"))
	hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	apply_polish()
	refresh_ui()

func bag_trade(buy: bool):
	var i=bag_item.selected
	if i<0: return
	trade_resource(i+6 if i<ITEMS.size() else i-ITEMS.size(),buy)

func refresh_ui():
	super.refresh_ui()
	if is_instance_valid(status_line): status_line.text="V1.3 / "+ZONES[zone]+" • "+WEATHER_NAMES[weather]
	if is_instance_valid(gear_text):
		var a=[]
		for i in range(3): a.append(TOOL_NAMES[i]+" • "+str(tool_levels[i])+"/3"+(" • Kuşanıldı" if i==equipped else ""))
		for i in range(3): a.append(NEW_DECOR[i]+(" • Kuruldu" if extra_decor[i] else " • "+str(NEW_COST[i])+" G"))
		gear_text.text="\n".join(a)
	if is_instance_valid(bag_summary):
		bag_summary.text="Altın %d G  •  Depo %d/%d  •  Kuşanılan %s" % [gold,storage_used(),storage_capacity(),TOOL_NAMES[equipped]]
		for b in bag_labels:
			var cat=int(b[0])
			var i=int(b[1])
			var names=ITEMS if cat==0 else (RESOURCE_NAMES if cat==1 else FEED_NAMES)
			var qty=quantity(i) if cat==0 else (int(gathered[i]) if cat==1 else int(food_stock[i]))
			b[2].text=names[i]+"\n× "+str(qty)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_D: return
		if event.keycode==KEY_T:
			toggle_drag()
			return
		if event.keycode==KEY_F:
			interact()
			return
		if event.keycode==KEY_L:
			show_manager(10)
			return
		if cave_active and event.keycode in [KEY_SPACE,KEY_H]:
			mine_nearest()
			return
	if cave_active and event is InputEventMouseButton: return
	super._unhandled_input(event)

func _process(delta):
	super._process(delta)
	if testing: return
	if not modal_open():
		var input=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_W))-float(Input.is_physical_key_pressed(KEY_S)))
		if input.length_squared()>0: move_hero(input,delta)
		else:
			for leg in hero_legs: leg.rotation.x=0
	if fishing:
		fish_phase+=delta
		fish_left-=delta
		update_fish_ui()
		if fish_left<=0: cancel_fishing()
	hit_delay=maxf(0.0,hit_delay-delta)
	for i in range(4):
		if rock_hp[i]<=0:
			rock_respawn[i]-=delta
			if rock_respawn[i]<=0:
				rock_hp[i]=3
				if cave_active and i<cave_rocks.size(): cave_rocks[i].show()
	weather_tick(delta)
	if is_instance_valid(hint):
		var n=nearest_npc()
		hint.text="WASD • F etkileşim • L ekipman • T dekor" if not cave_active else "Mağara • F kaz / çıkış"
		if n>=0: hint.text="F • "+["Mira","Deniz","Bora"][n]+" ile konuş"

func _write_extension(data: Dictionary):
	super._write_extension(data)
	data["v13"]={"hero":[hero_position.x,hero_position.z],"tools":tool_levels,"equipped":equipped,"extra_decor":extra_decor,"weather":weather,"weather_left":weather_left,"music":music_enabled,"fast_mode":fast_mode,"rock_hp":rock_hp,"rock_respawn":rock_respawn}

func _read_extension(data: Dictionary):
	super._read_extension(data)
	var e=data.get("v13",{})
	if not e is Dictionary: return
	var pos=e.get("hero",[0,4.5])
	if pos is Array and pos.size()==2: hero_position=Vector3(clampf(float(pos[0]),-6.5,6.5),0,clampf(float(pos[1]),-5.2,5.2))
	var t=e.get("tools",[])
	if t is Array and t.size()==3:
		for i in range(3): tool_levels[i]=clampi(int(t[i]),0,3)
	equipped=clampi(int(e.get("equipped",0)),0,2)
	var decor=e.get("extra_decor",[])
	if decor is Array and decor.size()==3: extra_decor=decor
	weather=clampi(int(e.get("weather",0)),0,3)
	weather_left=clampf(float(e.get("weather_left",70)),0,75)
	music_enabled=bool(e.get("music",true))
	fast_mode=bool(e.get("fast_mode",false))
	var hp=e.get("rock_hp",[])
	var resp=e.get("rock_respawn",[])
	if hp is Array and hp.size()==4: rock_hp=hp
	if resp is Array and resp.size()==4: rock_respawn=resp
	if is_instance_valid(hero): hero.position=hero_position
	apply_weather()

func run_tests():
	var errors=[]
	level=5
	gold=1000
	var start=hero.position
	move_hero(Vector2(1,0),0.2)
	if hero.position.distance_to(start)<0.3: errors.append("movement")
	hero.position=NPC_POS[0]
	if nearest_npc()!=0: errors.append("NPC proximity")
	start_fishing()
	fish_target=0.5
	fish_phase=0
	fish_attempt()
	if activity_total!=1 or fishing: errors.append("fishing success")
	start_fishing()
	fish_target=0.8
	fish_phase=0
	fish_attempt()
	if activity_total!=1: errors.append("fishing failure")
	enter_cave()
	if not cave_active or cave_rocks.size()!=4: errors.append("cave")
	for i in range(3):
		hit_delay=0
		mine_rock(0)
	if rock_hp[0]!=0 or activity_total!=2: errors.append("mining")
	exit_cave()
	if cave_active: errors.append("exit")
	gathered[3]=3
	upgrade_tool(1)
	if tool_levels[1]!=1 or equipped!=1 or gathered[3]!=2: errors.append("tool upgrade")
	buy_extra(0)
	if not extra_decor[0]: errors.append("decor")
	weather=2
	apply_weather()
	if not weather_root.visible: errors.append("weather")
	var path="user://sproutlings_v13_test_"+str(Time.get_ticks_usec())+".json"
	save_game(path,true)
	reset_data()
	load_game(path)
	if tool_levels[1]!=1 or not extra_decor[0] or weather!=2 or rock_hp[0]!=0: errors.append("save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not errors.is_empty():
		push_error("V1.3 FAIL "+str(errors))
		get_tree().quit(1)
		return
	print("V1.3 PASS: movement, NPC proximity, fishing timing, cave mining, equipment, decorations, weather, save")
	reset_data()
	rebuild_region()
	rebuild_decor()
	refresh_all()
	super.run_tests()

func visual_test():
	start_music()
	if not is_instance_valid(music) or music.stream==null:
		push_error("V1.3 VISUAL FAIL music")
		get_tree().quit(1)
		return
	music.stop()
	level=8
	show_dialogue(0)
	await get_tree().process_frame
	if not dialogue.visible:
		push_error("V1.3 VISUAL FAIL dialogue")
		get_tree().quit(1)
		return
	dialogue.hide()
	show_inventory()
	await get_tree().process_frame
	if not inventory_window.visible or bag_labels.size()!=21:
		push_error("V1.3 VISUAL FAIL inventory")
		get_tree().quit(1)
		return
	inventory_window.hide()
	enter_cave()
	await get_tree().process_frame
	exit_cave()
	show_manager(10)
	await get_tree().process_frame
	manager.hide()
	print("V1.3 VISUAL PASS: character, dialogue, inventory, cave, gear tab")
	await super.visual_test()
