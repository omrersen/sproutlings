extends "res://farm_v14.gd"

const SKILL_NAMES=["Çiftçilik","Madencilik","Balıkçılık","Keşif"]
const CRAFT_NAMES=["Enerji iksiri","Madenci tılsımı","Hasat rozeti","Gezgin çantası"]
const CRAFT_GOLD=[15,80,100,140]
const CRAFT_REQ=[{0:2,3:1},{3:5,4:2},{1:3,4:2},{2:1,5:1}]
const TREASURE_POS=[Vector3(4.8,0,4.65),Vector3(5.1,0,4.35),Vector3(-4.6,0,4.4),Vector3(-4.7,0,4.5),Vector3(4.6,0,4.4),Vector3(-4.6,0,4.4)]
var skill_xp=[0,0,0,0]
var crafted=[0,0,0,0]
var charm=-1
var treasure_claimed=[false,false,false,false,false,false]
var treasure_root: Node3D
var companions=true
var follower_positions={}
var skill_text: Label
var work_text: Label
var work_choice: OptionButton
var charm_choice: OptionButton
var treasure_text: Label
var follower_check: CheckButton

func reset_data():
	super.reset_data()
	skill_xp=[0,0,0,0]
	crafted=[0,0,0,0]
	charm=-1
	treasure_claimed=[false,false,false,false,false,false]
	companions=true
	follower_positions={}

func _ready():
	super._ready()
	if not testing: DisplayServer.window_set_title("Sproutlings V1.5")

func skill_level(i: int) -> int:
	return mini(10,1+int(skill_xp[i]/100.0))

func gain_skill(i: int,amount: int):
	if i<0 or i>=4: return
	var old=skill_level(i)
	skill_xp[i]=mini(900,int(skill_xp[i])+amount)
	if skill_level(i)>old: notify(SKILL_NAMES[i]+" ustalığı "+str(skill_level(i))+" oldu!")

func plot_action(i: int):
	var before=harvests
	super.plot_action(i)
	if harvests>before:
		gain_skill(0,10)
		refresh_ui()

func mine_rock(i: int):
	var before=mined_count
	super.mine_rock(i)
	if mined_count>before:
		gain_skill(1,25)
		if not testing and charm==1 and gathered.reduce(func(a,b): return a+int(b),0)<100 and rng.randf()<0.20:
			gathered[3]+=1
			notify("Madenci tılsımı: ek bakır!")
		refresh_ui()
		save_game()

func fish_attempt():
	var before=fished_count
	super.fish_attempt()
	if fished_count>before:
		gain_skill(2,25)
		refresh_ui()
		save_game()

func enter_cave():
	var old=cave_seen.size()
	super.enter_cave()
	if cave_seen.size()>old:
		gain_skill(3,50)
		refresh_ui()
		save_game()

func crop_speed_modifier(i: int) -> float:
	return super.crop_speed_modifier(i)*(1.0+0.015*float(skill_level(0)-1))

func fish_width() -> float:
	return super.fish_width()+0.006*float(skill_level(2)-1)

func craft_equipment(i: int):
	if i<0 or i>=4 or level<3 or gold<CRAFT_GOLD[i]:
		notify("Üretim için L3 ve yeterli altın gerekli.")
		return
	if i>0 and crafted[i]>0:
		notify("Bu ekipman zaten üretildi.")
		return
	for r in CRAFT_REQ[i]:
		if gathered[int(r)]<CRAFT_REQ[i][r]:
			notify("Malzeme eksik: "+RESOURCE_NAMES[int(r)])
			return
	gold-=CRAFT_GOLD[i]
	for r in CRAFT_REQ[i]: gathered[int(r)]-=CRAFT_REQ[i][r]
	crafted[i]+=1
	notify(CRAFT_NAMES[i]+" üretildi!")
	effect_sound(2)
	refresh_ui()
	save_game()

func use_equipment(i: int):
	if i<0 or i>=4 or crafted[i]<=0:
		notify("Önce bu eşyayı üret.")
		return
	if i==0:
		if stamina>=100:
			notify("Dayanıklılık zaten dolu.")
			return
		crafted[0]-=1
		stamina=minf(100.0,stamina+50.0)
	else:
		charm=i if charm!=i else -1
	notify("Eşya kullanıldı.")
	refresh_ui()
	save_game()

func bonus(kind: String) -> float:
	var b=super.bonus(kind)
	if kind=="yield" and charm==2: b+=0.035
	return minf(0.4,b)

func tick_journal(delta: float):
	var old=stamina
	super.tick_journal(delta)
	if charm==3 and stamina>old: stamina=minf(100.0,stamina+delta*4.0)

func rebuild_region():
	super.rebuild_region()
	rebuild_treasure()

func rebuild_treasure():
	if not is_instance_valid(region_root): return
	if is_instance_valid(treasure_root): treasure_root.queue_free()
	treasure_root=Node3D.new()
	region_root.add_child(treasure_root)
	if treasure_claimed[zone]: return
	var p=TREASURE_POS[zone]
	box_at(treasure_root,p+Vector3(0,0.22,0),Vector3(0.67,0.44,0.48),Color("#8b6443"))
	box_at(treasure_root,p+Vector3(0,0.46,0),Vector3(0.72,0.12,0.52),Color("#c99a5a"))
	box_at(treasure_root,p+Vector3(0,0.28,0.25),Vector3(0.14,0.18,0.05),Color("#ffe19b"))
	var label=Label3D.new()
	label.text="Hazine • F"
	label.position=p+Vector3(0,0.9,0)
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size=30
	label.pixel_size=0.009
	treasure_root.add_child(label)

func claim_treasure():
	if cave_active or treasure_claimed[zone] or not is_instance_valid(hero) or hero.position.distance_to(TREASURE_POS[zone])>1.6:
		return
	treasure_claimed[zone]=true
	gold+=35+zone*20
	crates[mini(3,int(zone/2.0))]+=1
	gain_skill(3,40)
	rebuild_treasure()
	effect_sound(4)
	notify("Gizli hazine bulundu! Altın ve kasa.")
	refresh_ui()
	save_game()

func interact():
	if not cave_active and not treasure_claimed[zone] and hero.position.distance_to(TREASURE_POS[zone])<1.6:
		claim_treasure()
		return
	super.interact()

func rebuild_pets():
	super.rebuild_pets()
	follower_positions={}

func update_followers(delta: float):
	if cave_active or not companions or not is_instance_valid(hero): return
	for i in range(pet_nodes.size()):
		var n=pet_nodes[i]
		if not is_instance_valid(n): continue
		var angle=hero.rotation.y
		var back=Vector3(-sin(angle),0,-cos(angle))
		var side=Vector3(cos(angle),0,-sin(angle))
		var target=hero.position+back*(0.9+0.6*int(i/2.0))+side*(0.62 if i%2==0 else -0.62)
		target.x=clampf(target.x,-6.4,6.4)
		target.z=clampf(target.z,-5.1,5.1)
		var previous: Vector3=follower_positions.get(i,n.position)
		var next=previous.lerp(target,minf(1.0,delta*5.0))
		var flat=Vector3(next.x,0,next.z)
		if obstacle_at(flat): next=previous
		next.y=n.position.y
		n.position=next
		var dir=target-next
		if Vector2(dir.x,dir.z).length()>0.08: n.rotation.y=atan2(dir.x,dir.z)
		follower_positions[i]=next

func make_ui():
	super.make_ui()
	var v=new_tab("Ustalık")
	lbl(v,"USTALIK & ATÖLYE",24,true)
	skill_text=lbl(v,"",16)
	lbl(v,"Hasat 10 XP; maden/balık 25 XP; yeni mağara 50 XP; hazine 40 XP. 100 XP bir ustalık seviyesi.",13)
	work_choice=menu(v,func(_i): refresh_ui())
	for n in CRAFT_NAMES: work_choice.add_item(n)
	work_text=lbl(v,"",15)
	btn(v,"Seçili eşyayı üret",func(): craft_equipment(work_choice.selected))
	btn(v,"Kullan / kuşan / çıkar",func(): use_equipment(work_choice.selected))
	follower_check=CheckButton.new()
	follower_check.text="Aktif yaratıklar beni takip etsin"
	follower_check.button_pressed=companions
	v.add_child(follower_check)
	follower_check.toggled.connect(func(on): companions=on;follower_positions={};save_game())
	treasure_text=lbl(v,"",15)
	lbl(v,"P: ustalık paneli. Her biyomda bir hazine var. Yaklaş ve F ile aç.",13)
	refresh_ui()

func refresh_ui():
	super.refresh_ui()
	if is_instance_valid(status_line): status_line.text="V1.5 / "+(CAVE_NAMES[cave_index] if cave_active else ZONES[zone])+" • "+WEATHER_NAMES[weather]
	if not is_instance_valid(skill_text): return
	var lines=[]
	for i in range(4): lines.append("%s  L%d/10  •  %d XP" % [SKILL_NAMES[i],skill_level(i),skill_xp[i]])
	skill_text.text="\n".join(lines)
	var index=maxi(0,work_choice.selected)
	var req=[]
	for r in CRAFT_REQ[index]: req.append("%s %d/%d" % [RESOURCE_NAMES[int(r)],gathered[int(r)],CRAFT_REQ[index][r]])
	var descriptions=["+50 dayanıklılık, tek kullanımlık.","%20 ek bakır şansı (maden).","+%3,5 hasat bonusu.","Dinlenmede +4 dayanıklılık/sn."]
	work_text.text="%s • %d G\n%s\n%s\nÇantada: %d%s" % [CRAFT_NAMES[index],CRAFT_GOLD[index],", ".join(req),descriptions[index],crafted[index]," • Kuşanıldı" if charm==index else ""]
	var count=treasure_claimed.count(true)
	treasure_text.text="Hazineler: %d/6 • Bu biyom: %s" % [count,"Alındı" if treasure_claimed[zone] else "Keşfedilmeyi bekliyor"]

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_P:
		show_manager(12)
		return
	super._unhandled_input(event)

func _process(delta):
	super._process(delta)
	if testing: return
	update_followers(delta)

func _write_extension(data: Dictionary):
	super._write_extension(data)
	data["v15"]={"skill_xp":skill_xp,"crafted":crafted,"charm":charm,"treasures":treasure_claimed,"companions":companions}

func _read_extension(data: Dictionary):
	super._read_extension(data)
	var e=data.get("v15",{})
	if not e is Dictionary: return
	var x=e.get("skill_xp",[])
	if x is Array and x.size()==4:
		for i in range(4): skill_xp[i]=clampi(int(x[i]),0,900)
	var c=e.get("crafted",[])
	if c is Array and c.size()==4:
		for i in range(4): crafted[i]=maxi(0,int(c[i]))
	charm=clampi(int(e.get("charm",-1)),-1,3)
	if charm>=1 and crafted[charm]==0: charm=-1
	var t=e.get("treasures",[])
	if t is Array and t.size()==6: treasure_claimed=t
	companions=bool(e.get("companions",true))
	if is_instance_valid(follower_check): follower_check.set_pressed_no_signal(companions)
	if is_instance_valid(region_root): rebuild_treasure()

func run_tests():
	var errors=[]
	level=10
	gold=1000
	gain_skill(0,110)
	if skill_level(0)!=2 or skill_xp[0]!=110: errors.append("skill")
	gathered[0]=2
	gathered[3]=6
	gathered[4]=2
	craft_equipment(0)
	stamina=30
	use_equipment(0)
	if stamina!=80 or crafted[0]!=0 or gathered[0]!=0: errors.append("potion")
	craft_equipment(1)
	var before=gold
	craft_equipment(1)
	use_equipment(1)
	if charm!=1 or crafted[1]!=1 or gold!=before: errors.append("equipment")
	hero.position=TREASURE_POS[0]
	before=gold
	claim_treasure()
	claim_treasure()
	if not treasure_claimed[0] or gold!=before+35 or skill_xp[3]!=40: errors.append("treasure")
	var path="user://sproutlings_v15_test_"+str(Time.get_ticks_usec())+".json"
	save_game(path,true)
	reset_data()
	load_game(path)
	if skill_level(0)!=2 or charm!=1 or not treasure_claimed[0]: errors.append("save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not errors.is_empty():
		push_error("V1.5 FAIL "+str(errors))
		get_tree().quit(1)
		return
	print("V1.5 PASS: skills, crafting, consumable, accessory, treasure, save")
	reset_data()
	rebuild_region()
	rebuild_decor()
	refresh_all()
	super.run_tests()

func visual_test():
	level=8
	gold=1000
	show_manager(12)
	await get_tree().process_frame
	if manager_tabs.current_tab!=12 or not is_instance_valid(work_text):
		push_error("V1.5 VISUAL FAIL workshop")
		get_tree().quit(1)
		return
	manager.hide()
	creatures.append({"species":0,"shiny":false,"growth":300.0,"hunger":100.0,"active":true,"production":0.0})
	refresh_all()
	hero.position=Vector3(0,0,4.2)
	update_followers(0.2)
	await get_tree().process_frame
	if follower_positions.is_empty() or not is_instance_valid(treasure_root):
		push_error("V1.5 VISUAL FAIL companions/treasure")
		get_tree().quit(1)
		return
	print("V1.5 VISUAL PASS: workshop, treasure, companion follow")
	await super.visual_test()
