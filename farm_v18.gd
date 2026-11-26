extends "res://farm_v17.gd"

var navigation: OptionButton
var field_crop: OptionButton
var field_summary: Label
var field_tiles=[]
var fps_samples=[]
var fps_clock18=0.0

func make_ui():
	super.make_ui()
	var v=new_tab("Tarla")
	lbl(v,"TARLA YÖNETİMİ",24,true)
	field_summary=lbl(v,"",16)
	field_crop=menu(v,func(i): selected_crop=i;crop_menu.select(i);refresh_ui())
	for c in CROPS: field_crop.add_item(c.name+" • "+str(c.cost)+" G")
	var actions=HBoxContainer.new()
	v.add_child(actions)
	btn(actions,"Boşları ek",func(): farm_batch("plant"))
	btn(actions,"Sulamayı tamamla",func(): farm_batch("water"))
	btn(actions,"Hazırları hasat et",func(): farm_batch("harvest"))
	var grid=GridContainer.new()
	grid.columns=4
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	v.add_child(grid)
	for i in range(12):
		var b=btn(grid,"",func(): field_action(i))
		b.custom_minimum_size=Vector2(175,82)
		field_tiles.append(b)
	lbl(v,"Her düğme yalnızca seçtiğin işlemi gerçekleştirir. Tarla kartına tıklayarak tek tek ekebilir, sulayabilir veya hasat edebilirsin.",14)
	var outer=manager_tabs.get_parent()
	navigation=OptionButton.new()
	navigation.custom_minimum_size.y=42
	outer.add_child(navigation)
	outer.move_child(navigation,manager_tabs.get_index())
	for i in range(manager_tabs.get_tab_count()):
		navigation.add_item(manager_tabs.get_tab_title(i),i)
	navigation.item_selected.connect(func(i): manager_tabs.current_tab=i)
	manager_tabs.tab_changed.connect(func(i): navigation.select(i))
	manager_tabs.tabs_visible=false
	for c in outer.get_children():
		if c is Label and c.text.begins_with("ÇİFTLİK YÖNETİMİ"): c.text="ÇİFTLİK YÖNETİMİ"
	var layer=get_node("HUD")
	for n in layer.get_children():
		if n is HBoxContainer: n.hide()
	var panel=PanelContainer.new()
	layer.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left=-382
	panel.offset_right=382
	panel.offset_top=63
	panel.offset_bottom=110
	var style=StyleBoxFlat.new()
	style.bg_color=Color("#172d2be8")
	style.border_color=Color("#638b74")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left=8
	style.content_margin_right=8
	style.content_margin_top=4
	style.content_margin_bottom=4
	panel.add_theme_stylebox_override("panel",style)
	var row=HBoxContainer.new()
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",5)
	panel.add_child(row)
	btn(row,"Hikâye [C]",func(): show_manager(13))
	btn(row,"Tarla [Y]",func(): show_manager(15))
	btn(row,"Yönetim [M]",func(): show_manager(0))
	btn(row,"Çanta [I]",show_inventory)
	btn(row,"Dekor [B]",func(): decor_window.popup_centered())
	btn(row,"Menü [Esc]",open_title)
	apply_polish()
	refresh_ui()

func field_action(i: int):
	if cave_active or i<0 or i>=unlocked: return
	selected_plot=i
	plot_action(i)
	save_game()

func farm_batch(kind: String):
	if cave_active:
		notify("Önce mağaradan çık.")
		return
	var count=0
	for i in range(unlocked):
		var p=plots[i]
		var valid=(kind=="plant" and p.crop<0) or (kind=="water" and p.crop>=0 and not p.watered) or (kind=="harvest" and p.crop>=0 and p.watered and p.remaining<=0)
		if not valid: continue
		var old=[p.crop,p.watered,harvests]
		plot_action(i)
		if old!=[p.crop,p.watered,harvests]: count+=1
	notify("%d tarla işlendi." % count)
	refresh_ui()
	if count>0: save_game()

func refresh_ui():
	super.refresh_ui()
	if is_instance_valid(status_line): status_line.text="V1.8 / "+(CAVE_NAMES[cave_index] if cave_active else ZONES[zone])+" • "+WEATHER_NAMES[weather]
	if not is_instance_valid(field_summary) or field_tiles.size()!=12: return
	var counts=[0,0,0,0]
	for i in range(12):
		var b=field_tiles[i]
		var state="Kilitli"
		var col=Color("#82948b")
		b.disabled=i>=unlocked or cave_active
		if i<unlocked:
			var p=plots[i]
			if p.crop<0:
				state="Boş"
				counts[0]+=1
				col=Color("#d5b994")
			elif not p.watered:
				state=CROPS[int(p.crop)].name+"\nSu bekliyor"
				counts[1]+=1
				col=Color("#a8d2ed")
			elif p.remaining>0:
				state=CROPS[int(p.crop)].name+"\n"+str(ceili(p.remaining))+" sn"
				counts[2]+=1
				col=Color("#a1cda7")
				b.disabled=true
			else:
				state=CROPS[int(p.crop)].name+"\nHASADA HAZIR"
				counts[3]+=1
				col=Color("#ffe098")
		b.text="%02d • %s" % [i+1,state]
		b.add_theme_color_override("font_color",col)
	field_summary.text="%s • %d G\nBoş %d  |  Susuz %d  |  Büyüyor %d  |  Hazır %d" % [ZONES[zone],gold,counts[0],counts[1],counts[2],counts[3]]
	for i in range(CROPS.size()): field_crop.set_item_disabled(i,level<CROPS[i].level)
	if field_crop.selected!=selected_crop: field_crop.select(selected_crop)

func mine_rock(i: int):
	var before=mined_count
	super.mine_rock(i)
	if mined_count>before and not testing and skill_level(1)>1 and rng.randf()<0.02*(skill_level(1)-1) and gathered.reduce(func(a,b): return a+int(b),0)<100:
		gathered[3]+=1
		notify("Madencilik ustalığı: ek bakır!")
		refresh_ui()
		save_game()

func tick_journal(delta: float):
	var old=stamina
	super.tick_journal(delta)
	if stamina>old: stamina=minf(100.0,stamina+delta*0.5*(skill_level(3)-1))

func _ready():
	super._ready()
	if not testing: DisplayServer.window_set_title("Sproutlings V1.8")

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_Y:
		show_manager(15)
		return
	super._unhandled_input(event)

func _process(delta):
	super._process(delta)
	if runtime_test_mode and not testing:
		fps_clock18+=delta
		if fps_clock18>=1.0:
			fps_clock18=0
			fps_samples.append(Engine.get_frames_per_second())

func run_tests():
	var errors=[]
	farm_batch("plant")
	if gold!=92: errors.append("batch cost")
	farm_batch("plant")
	if gold!=92: errors.append("duplicate plant")
	farm_batch("water")
	for i in range(4):
		if not plots[i].watered: errors.append("water")
		plots[i].remaining=0
	farm_batch("harvest")
	farm_batch("harvest")
	if harvests!=4 or not story_ready(): errors.append("harvest/story")
	if not errors.is_empty():
		push_error("V1.8 FAIL "+str(errors))
		get_tree().quit(1)
		return
	print("V1.8 PASS: isolated farm batches, costs, duplicate prevention, campaign progression")
	reset_data()
	rebuild_region()
	rebuild_decor()
	refresh_all()
	super.run_tests()

func visual_test():
	show_manager(15)
	await get_tree().process_frame
	if field_tiles.size()!=12 or navigation.selected!=15 or manager_tabs.tabs_visible:
		push_error("V1.8 VISUAL FAIL")
		get_tree().quit(1)
		return
	manager.hide()
	print("V1.8 VISUAL PASS: unified navigation, field grid, management picker")
	await super.visual_test()

func run_runtime_test():
	reset_data()
	rebuild_region()
	refresh_all()
	if is_instance_valid(welcome_window): welcome_window.hide()
	farm_batch("plant")
	farm_batch("water")
	await get_tree().create_timer(14.0).timeout
	farm_batch("harvest")
	if harvests!=4 or not story_ready():
		push_error("V1.8 RUNTIME FAIL farm")
		get_tree().quit(1)
		return
	claim_chapter()
	open_crate(0)
	if is_instance_valid(reveal_window): close_reveal()
	if creatures.is_empty():
		get_tree().quit(1)
		return
	feed_pet(0)
	if not creatures[0].active: toggle_pet(0)
	if not story_ready():
		get_tree().quit(1)
		return
	claim_chapter()
	save_game()
	load_game()
	if story_stage!=2 or harvests!=4:
		get_tree().quit(1)
		return
	var total=0.0
	for n in fps_samples: total+=float(n)
	print("V1.8 RUNTIME PASS: batch planting, watering, real growth, harvest, pet, campaign, reload")
	if fps_samples.size()>0: print("FPS samples=",fps_samples.size()," mean=",snappedf(total/fps_samples.size(),0.1)," min=",fps_samples.min())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(runtime_save))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(runtime_save+".bak"))
	get_tree().quit()
