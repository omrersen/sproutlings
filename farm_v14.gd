extends "res://farm_v13.gd"

const CAVE_ZONES=[0,3,4]
const CAVE_NAMES=["Yosun Mağarası","Köz Ocağı","Kristal Labirenti"]
const CAVE_LAYOUTS=[
	[Vector3(-3.8,0,-2.1),Vector3(0,0,-3),Vector3(3.8,0,-2),Vector3(3.8,0,1.7)],
	[Vector3(-4.2,0,0),Vector3(-2,0,-3.1),Vector3(2.2,0,-3),Vector3(4.2,0,0.8)],
	[Vector3(-4,0,-3),Vector3(-3.7,0,2),Vector3(3.9,0,-3),Vector3(4,0,2)]
]
const JOURNAL_NAMES=["İlk keşif","Üç mağara","Usta madenci","Balıkçı çırağı","Çiftlik ustası"]
const JOURNAL_REWARDS=[60,180,120,100,180]
var cave_states={}
var cave_index=0
var cave_seen=[]
var cave_obstacles=[]
var mined_count=0
var fished_count=0
var journal_claimed=[false,false,false,false,false]
var stamina=100.0
var sprinting=false
var journal_text: Label
var journal_choice: OptionButton
var stamina_bar: ProgressBar
var map_view: Control
var map_caption: Label
var map_clock=0.0
var physics_steps=0

func reset_data():
	super.reset_data()
	cave_states={}
	cave_seen=[]
	cave_index=0
	cave_obstacles=[]
	mined_count=0
	fished_count=0
	journal_claimed=[false,false,false,false,false]
	stamina=100.0
	sprinting=false

func _ready():
	super._ready()
	if not testing:
		DisplayServer.window_set_title("Sproutlings V1.4")

func cave_positions() -> Array:
	return CAVE_LAYOUTS[cave_index]

func store_cave():
	if cave_active:
		cave_states[str(CAVE_ZONES[cave_index])]={"hp":rock_hp.duplicate(),"respawn":rock_respawn.duplicate()}

func enter_cave():
	if cave_active or level<3 or zone not in CAVE_ZONES:
		super.enter_cave()
		return
	cave_index=CAVE_ZONES.find(zone)
	var key=str(zone)
	var state=cave_states.get(key,{"hp":[3,3,3,3],"respawn":[0.0,0.0,0.0,0.0]})
	rock_hp=state.hp.duplicate()
	rock_respawn=state.respawn.duplicate()
	super.enter_cave()
	if not cave_active: return
	if not cave_seen.has(zone): cave_seen.append(zone)
	cave_obstacles=[]
	var floor_col=[Color("#52685a"),Color("#68473c"),Color("#405873")][cave_index]
	var wall_col=[Color("#71836b"),Color("#825448"),Color("#637f9e")][cave_index]
	var crystal_col=[Color("#95d39b"),Color("#f39c55"),Color("#9adef8")][cave_index]
	# Recolor the inherited floor and boundary walls without changing the exit.
	for i in range(mini(4,cave.get_child_count())):
		var n=cave.get_child(i)
		if n is MeshInstance3D:
			n.material_override=mat(floor_col if i==0 else wall_col)
	for i in range(4):
		cave_rocks[i].position=cave_positions()[i]
		for child in cave_rocks[i].get_children():
			if child is MeshInstance3D:
				child.material_override=mat(wall_col if child.get_index()==0 else crystal_col)
	var pillars=[]
	if cave_index==0: pillars=[Vector3(-1.9,0,0.2),Vector3(2.1,0,-0.1)]
	elif cave_index==1: pillars=[Vector3(-1.6,0,-0.3),Vector3(1.5,0,-0.3),Vector3(0,0,-1.9)]
	else: pillars=[Vector3(-2.0,0,0.0),Vector3(2.0,0,0.0),Vector3(0,0,-2.7)]
	for p in pillars:
		cave_obstacles.append([p,Vector2(0.65,0.65)])
		var pillar=box_at(cave,p+Vector3(0,0.8,0),Vector3(1.3,1.6,1.3),wall_col)
		gem(cave,p+Vector3(0,1.35,0),0.35,0.95,crystal_col)
		pillar.rotation.y=0.08
	if cave_index==1:
		for x in [-4.6,4.6]:
			box_at(cave,Vector3(x,-0.03,-4.1),Vector3(2,0.10,1.0),Color("#ee7c40"))
			cave_obstacles.append([Vector3(x,0,-4.1),Vector2(1.0,0.5)])
	elif cave_index==2:
		for x in [-2.7,2.7]:
			gem(cave,Vector3(x,0.8,-4.0),0.52,1.6,crystal_col)
			cave_obstacles.append([Vector3(x,0,-4),Vector2(0.55,0.55)])
	else:
		for x in [-5.0,5.0]:
			flower_cluster(cave,Vector3(x,0,-1),crystal_col)
	var sign=Label3D.new()
	sign.text=CAVE_NAMES[cave_index]
	sign.position=Vector3(0,1.8,-4.8)
	sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size=46
	sign.pixel_size=0.012
	cave.add_child(sign)
	notify(CAVE_NAMES[cave_index]+" • Yeni damarları keşfet.")
	refresh_ui()
	save_game()

func exit_cave():
	store_cave()
	super.exit_cave()
	cave_obstacles=[]

func mine_nearest():
	var best=1.65
	var idx=-1
	for i in range(4):
		if rock_hp[i]<=0: continue
		var dist=hero.position.distance_to(cave_positions()[i])
		if dist<best: best=dist;idx=i
	if idx>=0: mine_rock(idx)
	else: notify("Bir cevher damarına yaklaş.")

func mine_rock(i: int):
	var before=activity_total
	super.mine_rock(i)
	if activity_total>before:
		mined_count+=1
		store_cave()
		refresh_ui()
		save_game()

func fish_attempt():
	var before=activity_total
	super.fish_attempt()
	if activity_total>before:
		fished_count+=1
		refresh_ui()
		save_game()

func inside_obstacle(p: Vector3,center: Vector3,half: Vector2) -> bool:
	return absf(p.x-center.x)<half.x+0.21 and absf(p.z-center.z)<half.y+0.21

func obstacle_at(p: Vector3) -> bool:
	if cave_active:
		for o in cave_obstacles:
			if inside_obstacle(p,o[0],o[1]): return true
		for i in range(4):
			if rock_hp[i]>0 and inside_obstacle(p,cave_positions()[i],Vector2(0.48,0.40)): return true
		return false
	if zone==0:
		if inside_obstacle(p,Vector3(-4.9,0,-3.6),Vector2(1.1,0.95)): return true
		if inside_obstacle(p,Vector3(5.1,0,-2.9),Vector2(1.18,0.85)): return true
		for i in range(4):
			if buildings[i] and inside_obstacle(p,Vector3(-6.0,0,-1.0+i*1.85),Vector2(0.65,0.64)): return true
			if decorations[i] and inside_obstacle(p,decor_positions[i],Vector2(0.65,0.56)): return true
		if extra_decor[1] and inside_obstacle(p,Vector3(-3.7,0,4.8),Vector2(0.15,0.15)): return true
		if extra_decor[2] and inside_obstacle(p,Vector3(5.8,0,-0.1),Vector2(0.27,0.27)): return true
	for p0 in NPC_POS:
		if inside_obstacle(p,p0,Vector2(0.22,0.20)): return true
	if zone in CAVE_ZONES and inside_obstacle(p,CAVE_GATE,Vector2(0.82,0.31)): return true
	return false

func resolve_motion(from: Vector3,dest: Vector3) -> Vector3:
	if not obstacle_at(dest): return dest
	# Let older saves that started inside a new obstacle escape rather than trap them.
	if obstacle_at(from): return dest
	var x=Vector3(dest.x,from.y,from.z)
	var z=Vector3(from.x,from.y,dest.z)
	if not obstacle_at(x): return x
	if not obstacle_at(z): return z
	return from

func move_hero(input: Vector2,delta: float):
	if not is_instance_valid(hero) or input.length_squared()<0.001: return
	sprinting=Input.is_physical_key_pressed(KEY_SHIFT) and stamina>1.0
	var speed=1.55 if sprinting else 1.0
	var steps=clampi(ceili(delta*speed/0.045),1,20)
	for i in range(steps):
		var from=hero.position
		super.move_hero(input,delta*speed/steps)
		hero.position=resolve_motion(from,hero.position)
		physics_steps+=1
	if not cave_active: hero_position=hero.position
	if sprinting: stamina=maxf(0.0,stamina-delta*20.0)

func tick_journal(delta: float):
	for key in cave_states.keys():
		if cave_active and key==str(CAVE_ZONES[cave_index]): continue
		var state=cave_states[key]
		for i in range(4):
			if state.hp[i]<=0:
				state.respawn[i]=maxf(0,float(state.respawn[i])-delta)
				if state.respawn[i]<=0: state.hp[i]=3
	if not sprinting: stamina=minf(100.0,stamina+delta*13.0)
	sprinting=false

func journal_value(i: int) -> int:
	match i:
		0: return cave_seen.size()
		1: return cave_seen.size()
		2: return mined_count
		3: return fished_count
		4: return harvests
	return 0

func journal_target(i: int) -> int:
	return [1,3,12,8,75][i]

func claim_journal(i: int):
	if i<0 or i>=5 or journal_claimed[i] or journal_value(i)<journal_target(i):
		notify("Keşif hedefi henüz tamamlanmadı.")
		return
	journal_claimed[i]=true
	gold+=JOURNAL_REWARDS[i]
	crates[1 if i>0 else 0]+=1
	notify("Başarım: "+JOURNAL_NAMES[i]+" • Ödül alındı!")
	refresh_ui()
	save_game()

func make_ui():
	super.make_ui()
	var v=new_tab("Keşif")
	lbl(v,"KAŞİF GÜNLÜĞÜ",25,true)
	journal_text=lbl(v,"",16)
	journal_choice=menu(v,func(_i): pass)
	for n in JOURNAL_NAMES: journal_choice.add_item(n)
	btn(v,"Başarım ödülünü al",func(): claim_journal(journal_choice.selected))
	lbl(v,"Shift: koş • F: etkileşim • U: keşif günlüğü. Koşu dayanıklılık tüketir; durunca yenilenir.",14)
	stamina_bar=ProgressBar.new()
	stamina_bar.max_value=100
	stamina_bar.custom_minimum_size.y=20
	v.add_child(stamina_bar)
	map_caption=lbl(v,"",14,true)
	map_view=Control.new()
	map_view.custom_minimum_size=Vector2(400,220)
	map_view.mouse_filter=Control.MOUSE_FILTER_IGNORE
	map_view.draw.connect(draw_map)
	v.add_child(map_view)
	refresh_ui()

func draw_map():
	if not is_instance_valid(map_view) or not is_instance_valid(hero): return
	var size=map_view.size
	var r=Rect2(Vector2(5,5),size-Vector2(10,10))
	map_view.draw_rect(r,Color("#183c35") if not cave_active else Color("#283a4d"))
	var conv=func(p: Vector3): return r.position+Vector2((p.x+7.0)/14.0*r.size.x,(p.z+5.7)/11.4*r.size.y)
	if cave_active:
		for i in range(4):
			map_view.draw_circle(conv.call(cave_positions()[i]),7,Color("#e9b46d") if rock_hp[i]>0 else Color("#64717a"))
		map_view.draw_circle(conv.call(Vector3(0,0,4.3)),6,Color("#82d5b4"))
	else:
		for i in range(unlocked):
			map_view.draw_rect(Rect2(conv.call(plot_pos(i))-Vector2(10,8),Vector2(20,16)),Color("#b79661"))
		for pos in NPC_POS: map_view.draw_circle(conv.call(pos),5,Color("#e0b6ed"))
		if zone in CAVE_ZONES: map_view.draw_circle(conv.call(CAVE_GATE),7,Color("#80d5e7"))
	map_view.draw_circle(conv.call(hero.position),6,Color("#fff3ac"))
	map_view.draw_rect(r,Color("#6e9d8c"),false,2)

func refresh_ui():
	super.refresh_ui()
	if is_instance_valid(status_line): status_line.text="V1.4 / "+(CAVE_NAMES[cave_index] if cave_active else ZONES[zone])+" • "+WEATHER_NAMES[weather]
	if not is_instance_valid(journal_text): return
	var lines=[]
	for i in range(5):
		lines.append("%s • %d/%d • %s" % [JOURNAL_NAMES[i],mini(journal_value(i),journal_target(i)),journal_target(i),"Alındı" if journal_claimed[i] else str(JOURNAL_REWARDS[i])+" G + kasa"])
	journal_text.text="\n".join(lines)
	stamina_bar.value=stamina
	map_caption.text=(CAVE_NAMES[cave_index] if cave_active else ZONES[zone])+" • Sarı: sen | Turkuaz: giriş/çıkış"
	map_view.queue_redraw()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_U:
		show_manager(11)
		return
	super._unhandled_input(event)

func _process(delta):
	super._process(delta)
	if testing: return
	tick_journal(delta)
	map_clock+=delta
	if map_clock>=0.25:
		map_clock=0
		if is_instance_valid(stamina_bar): stamina_bar.value=stamina
		if is_instance_valid(map_view) and manager.visible: map_view.queue_redraw()

func _write_extension(data: Dictionary):
	store_cave()
	super._write_extension(data)
	data["v14"]={"caves":cave_states,"seen":cave_seen,"mined":mined_count,"fished":fished_count,"claimed":journal_claimed,"stamina":stamina}

func _read_extension(data: Dictionary):
	super._read_extension(data)
	var e=data.get("v14",{})
	if not e is Dictionary: return
	cave_states=e.get("caves",{})
	if not cave_states.has("0"):
		cave_states["0"]={"hp":rock_hp.duplicate(),"respawn":rock_respawn.duplicate()}
	cave_seen=e.get("seen",[])
	mined_count=maxi(0,int(e.get("mined",0)))
	fished_count=maxi(0,int(e.get("fished",0)))
	var c=e.get("claimed",[])
	if c is Array and c.size()==5: journal_claimed=c
	stamina=clampf(float(e.get("stamina",100)),0,100)
	if is_instance_valid(region_root): rebuild_extra_decor()

func run_tests():
	var errors=[]
	level=40
	gold=10000
	if not obstacle_at(Vector3(-4.9,0,-3.6)): errors.append("barn collision")
	if resolve_motion(Vector3(-4.9,0,-2.2),Vector3(-4.9,0,-3.0))!=Vector3(-4.9,0,-2.2): errors.append("collision resolution")
	enter_cave()
	for i in range(3):
		hit_delay=0
		mine_rock(0)
	if mined_count!=1 or rock_hp[0]!=0: errors.append("mine counter")
	exit_cave()
	travel(3)
	enter_cave()
	if rock_hp[0]!=3 or cave_index!=1 or cave_rocks[0].position!=CAVE_LAYOUTS[1][0]: errors.append("independent ember cave")
	exit_cave()
	travel(4)
	enter_cave()
	if cave_index!=2 or cave_rocks[0].position!=CAVE_LAYOUTS[2][0]: errors.append("crystal layout")
	exit_cave()
	travel(0)
	enter_cave()
	if rock_hp[0]!=0 or cave_seen.size()!=3: errors.append("cave persistence")
	exit_cave()
	var before=gold
	claim_journal(1)
	claim_journal(1)
	if gold!=before+180 or not journal_claimed[1]: errors.append("journal claim")
	stamina=50
	tick_journal(1)
	if stamina<62: errors.append("stamina recovery")
	var path="user://sproutlings_v14_test_"+str(Time.get_ticks_usec())+".json"
	save_game(path,true)
	reset_data()
	load_game(path)
	if cave_seen.size()!=3 or mined_count!=1 or not journal_claimed[1]: errors.append("save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not errors.is_empty():
		push_error("V1.4 FAIL "+str(errors))
		get_tree().quit(1)
		return
	print("V1.4 PASS: collision, three cave layouts, independent ore, journal, stamina, save")
	reset_data()
	rebuild_region()
	rebuild_decor()
	refresh_all()
	super.run_tests()

func visual_test():
	level=40
	gold=10000
	for z in CAVE_ZONES:
		travel(z)
		enter_cave()
		await get_tree().process_frame
		if not cave_active or cave_rocks.size()!=4:
			push_error("V1.4 VISUAL FAIL cave")
			get_tree().quit(1)
			return
		exit_cave()
	travel(0)
	show_manager(11)
	await get_tree().process_frame
	if not is_instance_valid(map_view) or manager_tabs.current_tab!=11:
		push_error("V1.4 VISUAL FAIL journal")
		get_tree().quit(1)
		return
	manager.hide()
	print("V1.4 VISUAL PASS: three cave environments, exploration journal, map")
	await super.visual_test()
