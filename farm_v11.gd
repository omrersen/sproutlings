extends "res://farm_v1.gd"

const RESEARCH_NAMES=["Hızlı büyüme","Hasat uzmanlığı","Yaratık eğitimi"]
const RESEARCH_COST=[80,100,120]
const CONTRACT_CROPS=[0,1,2,3,4,5,6]
var research=[0,0,0]
var contract_index=0
var contract_count=0
var contracts_done=0
var offline_seconds=0
var offline_ready=0
var offline_enabled=true
var progress_text: Label
var research_choice: OptionButton
var offline_toggle: CheckButton

func reset_data():
	super.reset_data()
	research=[0,0,0]
	contract_index=0
	contract_count=0
	contracts_done=0
	offline_seconds=0
	offline_ready=0
	offline_enabled=true

func _ready():
	super._ready()
	if not testing and not "--visual-test" in OS.get_cmdline_user_args():
		DisplayServer.window_set_title("Sproutlings V1.1")
		if offline_ready>0:
			notify("Tekrar hoş geldin! %d ürün sen yokken olgunlaştı." % offline_ready)

func contract_crop() -> int:
	return CONTRACT_CROPS[contract_index%CONTRACT_CROPS.size()]

func contract_target() -> int:
	return 6+mini(6,int(contracts_done/3.0))

func next_contract():
	contracts_done+=1
	contract_index=(contract_index+1)%CONTRACT_CROPS.size()
	while int(CROPS[contract_crop()].level)>level:
		contract_index=(contract_index+1)%CONTRACT_CROPS.size()
	contract_count=0

func claim_contract():
	if contract_count<contract_target():
		notify("Sözleşme henüz tamamlanmadı.")
		return
	var reward=30+int(CROPS[contract_crop()].sale)*contract_target()/2
	gold+=int(reward)
	crates[0]+=1
	next_contract()
	notify("Sözleşme tamamlandı! +%d altın ve Ahşap kasa." % int(reward))
	refresh_ui()
	save_game()

func research_price(i: int) -> int:
	return RESEARCH_COST[i]*(int(research[i])+1)

func buy_research(i: int):
	if i<0 or i>=research.size(): return
	if level<3 or research[i]>=5 or gold<research_price(i):
		notify("Araştırma için L3, altın ve boş kademe gerekli.")
		return
	gold-=research_price(i)
	research[i]+=1
	notify(RESEARCH_NAMES[i]+" geliştirildi!")
	refresh_ui()
	save_game()

func crop_speed_modifier(i: int) -> float:
	return super.crop_speed_modifier(i)*(1.0+0.06*float(research[0]))

func bonus(kind: String) -> float:
	var b=super.bonus(kind)
	if kind=="yield": return minf(0.4,b+0.03*float(research[1]))
	return b

func feed_pet(i: int):
	if i<0 or i>=creatures.size(): return
	var p=creatures[i]
	var old=float(p.hunger)
	var old_growth=float(p.growth)
	super.feed_pet(i)
	if old<=0 and p.hunger>0:
		if old_growth==0 and p.growth==0: p.growth=50.0
		p.growth+=float(research[2])*5.0
		refresh_all()

func train_creature():
	if selected_creature<0 or selected_creature>=creatures.size():
		notify("Önce bir yaratık seç.")
		return
	var p=creatures[selected_creature]
	if level<3 or p.hunger<=0 or p.growth>=300 or gold<25:
		notify("Eğitim: L3, tok yaratık, yetişkin olmamalı ve 25 altın.")
		return
	gold-=25
	p.growth=minf(300.0,float(p.growth)+25.0+5.0*float(research[2]))
	rebuild_pets()
	refresh_ui()
	notify(SPECIES[int(p.species)]+" eğitimini tamamladı.")
	save_game()

func plot_action(i: int):
	if i<0 or i>=plots.size(): return
	var crop=int(plots[i].crop)
	var old=harvests
	super.plot_action(i)
	if harvests>old and crop==contract_crop():
		contract_count=mini(contract_target(),contract_count+1)
		refresh_ui()

func harvest_ready():
	var count=0
	for i in range(unlocked):
		var p=plots[i]
		if p.crop>=0 and p.watered and p.remaining<=0:
			var before=harvests
			plot_action(i)
			count+=harvests-before
	notify("%d hazır ürün hasat edildi." % count)
	if count>0: save_game()

func make_ui():
	super.make_ui()
	var v=new_tab("Gelişim")
	lbl(v,"Çiftlik sözleşmeleri ve araştırma",23,true)
	progress_text=lbl(v,"",15)
	btn(v,"Sözleşme ödülünü al",claim_contract)
	separator(v)
	research_choice=menu(v,func(_i): refresh_ui())
	for name in RESEARCH_NAMES: research_choice.add_item(name)
	btn(v,"Araştırmayı geliştir",func(): buy_research(research_choice.selected))
	btn(v,"Seçili yaratığı eğit (25 altın)",train_creature)
	btn(v,"Hazır ürünleri hasat et [H]",harvest_ready)
	offline_toggle=CheckButton.new()
	offline_toggle.text="Kapalıyken sulanmış ürünler büyüsün (en fazla 2 saat)"
	offline_toggle.button_pressed=offline_enabled
	v.add_child(offline_toggle)
	offline_toggle.toggled.connect(func(on): offline_enabled=on; save_game())
	lbl(v,"Sözleşmeler hasatla ilerler. Eğitim sadece tok ve yetişkin olmayan yaratıklarda çalışır. Çevrim dışı büyüme altın veya kasa vermez; hasadı sen yaparsın.",13)
	for c in get_node("HUD").get_children():
		if c is HBoxContainer:
			for b in c.get_children():
				if b is Button and b.text=="Rehber [F1]":
					btn(c,"Gelişim [J]",func(): show_manager(6))
					break
	refresh_ui()

func refresh_ui():
	super.refresh_ui()
	if is_instance_valid(status_line):
		status_line.text="V1.1 / "+ZONES[zone]+" • "+SEASONS[season]
	if is_instance_valid(progress_text):
		var lines=["Sözleşme: %s  %d/%d" % [CROPS[contract_crop()].name,contract_count,contract_target()],"Tamamlanan: %d  |  Ödül: %d altın + kasa" % [contracts_done,30+int(int(CROPS[contract_crop()].sale)*contract_target()/2.0)],""]
		for i in range(3):
			lines.append("%s: %d/5  •  %s" % [RESEARCH_NAMES[i],research[i],"Maksimum" if research[i]>=5 else str(research_price(i))+" altın"])
		lines.append("Büyüme +%d%%  |  Hasat bonusu +%d%%  |  Eğitim +%d XP" % [research[0]*6,research[1]*3,research[2]*5])
		progress_text.text="\n".join(lines)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_J:
			show_manager(6)
			return
		if event.keycode==KEY_H:
			harvest_ready()
			return
	super._unhandled_input(event)

func apply_offline(elapsed: float):
	offline_seconds=int(clampf(elapsed,0.0,7200.0))
	offline_ready=0
	if not offline_enabled: return
	for z in range(zone_plots.size()):
		if not zone_open[z]: continue
		for i in range(int(zone_land[z])):
			var p=zone_plots[z][i]
			if p.crop>=0 and p.watered and p.remaining>0:
				p.remaining=maxf(0.0,float(p.remaining)-float(offline_seconds))
				if p.remaining<=0: offline_ready+=1

func _write_extension(data: Dictionary):
	data["v11"]={"research":research,"contract_index":contract_index,"contract_count":contract_count,"contracts_done":contracts_done,"offline_enabled":offline_enabled,"saved_at":Time.get_unix_time_from_system()}

func _read_extension(data: Dictionary):
	var ext=data.get("v11",{})
	if not ext is Dictionary: return
	var r=ext.get("research",[0,0,0])
	if r is Array and r.size()==3:
		for i in range(3): research[i]=clampi(int(r[i]),0,5)
	contract_index=posmod(int(ext.get("contract_index",0)),CONTRACT_CROPS.size())
	contracts_done=maxi(0,int(ext.get("contracts_done",0)))
	contract_count=clampi(int(ext.get("contract_count",0)),0,contract_target())
	offline_enabled=bool(ext.get("offline_enabled",true))
	if not testing and not is_instance_valid(region_root):
		var saved=float(ext.get("saved_at",0))
		if saved>0: apply_offline(Time.get_unix_time_from_system()-saved)

func run_tests():
	var errors=[]
	level=5
	gold=1000
	buy_research(0)
	if research[0]!=1 or gold!=920: errors.append("research")
	if not is_equal_approx(crop_speed_modifier(0),super.crop_speed_modifier(0)*1.06): errors.append("speed override")
	plot_action(0)
	plots[0].watered=true
	plots[0].remaining=1.0
	apply_offline(9000)
	if offline_seconds!=7200 or offline_ready!=1 or plots[0].remaining!=0: errors.append("offline growth")
	harvest_ready()
	if contract_count!=1 or harvests!=1: errors.append("contract progress")
	contract_count=contract_target()
	var before=gold
	var c=crates[0]
	claim_contract()
	claim_contract()
	if contracts_done!=1 or gold!=before+45 or crates[0]!=c+1 or contract_count!=0: errors.append("contract reward")
	creatures.append({"species":0,"shiny":false,"growth":10.0,"hunger":1800.0,"active":true,"production":0.0})
	selected_creature=0
	before=gold
	train_creature()
	if creatures[0].growth!=35.0 or gold!=before-25: errors.append("training")
	var path="user://sproutlings_v11_test_"+str(Time.get_ticks_usec())+".json"
	offline_enabled=false
	save_game(path,true)
	reset_data()
	load_game(path)
	if research[0]!=1 or contracts_done!=1 or offline_enabled or creatures[0].growth!=35.0: errors.append("extended save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not errors.is_empty():
		push_error("V1.1 FAIL "+str(errors))
		get_tree().quit(1)
		return
	print("V1.1 PASS: research, capped offline growth, harvest, contracts, training, extended save")
	reset_data()
	rebuild_region()
	rebuild_decor()
	apply_settings()
	refresh_all()
	super.run_tests()

func visual_test():
	show_manager(6)
	await get_tree().process_frame
	if not is_instance_valid(progress_text) or not manager.visible or manager_tabs.current_tab!=6:
		push_error("V1.1 VISUAL FAIL")
		get_tree().quit(1)
		return
	manager.hide()
	print("V1.1 VISUAL PASS: progression panel")
	await super.visual_test()
