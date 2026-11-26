extends "res://farm_v16.gd"

const DAILY_NAMES=["Çiftlik siparişi","Madenci görevi","Balıkçı siparişi"]
const DAILY_TARGETS=[8,4,3]
const DAILY_GOLD=[45,55,40]
var daily_day=-1
var daily_start=[0,0,0]
var daily_claimed=[false,false,false]
var daily_label: Label
var daily_choice: OptionButton
var daily_button: Button
var dashboard: Label
var dashboard_bar: ProgressBar
var background_clock=0.0
var daily_clock=0.0
var sample_clock=0.0
var sampled_fps=0
var stats_toggle=false
var stats_check: CheckButton

func reset_data():
	super.reset_data()
	daily_day=-1
	daily_start=[0,0,0]
	daily_claimed=[false,false,false]
	background_clock=0.0
	stats_toggle=false

func _ready():
	super._ready()
	if not testing: DisplayServer.window_set_title("Sproutlings V1.7")
	if not testing: ensure_daily()

func daily_counts() -> Array:
	return [harvests,mined_count,fished_count]

func ensure_daily():
	var day=int(floor(Time.get_unix_time_from_system()/86400.0))
	if daily_day>=day: return
	daily_day=day
	daily_start=daily_counts()
	daily_claimed=[false,false,false]

func daily_progress(i: int) -> int:
	return maxi(0,int(daily_counts()[i])-int(daily_start[i]))

func claim_daily(i: int):
	ensure_daily()
	if i<0 or i>=3 or daily_claimed[i] or daily_progress(i)<DAILY_TARGETS[i]:
		notify("Günlük sipariş henüz hazır değil.")
		return
	daily_claimed[i]=true
	gold+=DAILY_GOLD[i]
	crates[0]+=1
	notify("Günlük sipariş tamamlandı!")
	effect_sound(2)
	refresh_ui()
	save_game()

func advance_background_farms(delta: float):
	if zone_plots.size()!=6: return
	var factor=(1.0+bonus("speed"))*crop_speed_modifier(0)
	for z in range(6):
		if z==zone or not zone_open[z]: continue
		for i in range(mini(int(zone_land[z]),zone_plots[z].size())):
			var p=zone_plots[z][i]
			if p.crop<0: continue
			if buildings[1]: p.watered=true
			if p.watered and p.remaining>0:
				p.remaining=maxf(0.0,float(p.remaining)-delta*factor)

func rebuild_region():
	super.rebuild_region()
	if cave_active:
		for n in home_meshes:
			if is_instance_valid(n): n.hide()
		if is_instance_valid(decor_root): decor_root.hide()
		if is_instance_valid(region_root): region_root.hide()
		if is_instance_valid(construction_root): construction_root.hide()

func exit_cave():
	super.exit_cave()
	if not cave_active and is_instance_valid(region_root): region_root.show()

func update_followers(delta: float):
	if cave_active or not companions or not is_instance_valid(hero): return
	for i in range(pet_nodes.size()):
		var n=pet_nodes[i]
		if not is_instance_valid(n): continue
		var a=hero.rotation.y
		var back=Vector3(-sin(a),0,-cos(a))
		var side=Vector3(cos(a),0,-sin(a))
		var target=hero.position+back*(0.95+0.65*int(i/2.0))+side*(0.65 if i%2==0 else -0.65)
		target.x=clampf(target.x,-6.4,6.4)
		target.z=clampf(target.z,-5.1,5.1)
		if obstacle_at(target): target=hero.position
		var prev: Vector3=follower_positions.get(i,n.position)
		var next=prev.move_toward(target,delta*4.4)
		next.y=0
		if obstacle_at(next):
			var x=Vector3(next.x,0,prev.z)
			var z=Vector3(prev.x,0,next.z)
			if not obstacle_at(x): next=x
			elif not obstacle_at(z): next=z
			elif prev.distance_to(target)>4.5 and not obstacle_at(target): next=target
			else: next=Vector3(prev.x,0,prev.z)
		next.y=n.position.y
		var direction=next-prev
		n.position=next
		if Vector2(direction.x,direction.z).length()>0.01: n.rotation.y=atan2(direction.x,direction.z)
		follower_positions[i]=next

func make_ui():
	super.make_ui()
	var v=new_tab("Günlük")
	lbl(v,"KÖY SİPARİŞLERİ",24,true)
	daily_label=lbl(v,"",16)
	daily_choice=menu(v,func(_i): refresh_ui())
	for n in DAILY_NAMES: daily_choice.add_item(n)
	daily_button=btn(v,"Sipariş ödülünü al",func(): claim_daily(daily_choice.selected))
	lbl(v,"Siparişler UTC gününe göre yenilenir. Saat geri alınırsa önceki ödüller yeniden açılmaz.",13)
	stats_check=CheckButton.new()
	stats_check.text="FPS göstergesini aç"
	stats_check.button_pressed=stats_toggle
	v.add_child(stats_check)
	stats_check.toggled.connect(func(on): stats_toggle=on;refresh_ui();save_game())
	var layer=get_node("HUD")
	var panel=PanelContainer.new()
	layer.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left=-210
	panel.offset_right=210
	panel.offset_top=-207
	panel.offset_bottom=-151
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style=StyleBoxFlat.new()
	style.bg_color=Color("#172d2bd9")
	style.border_color=Color("#638b74")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left=12
	style.content_margin_right=12
	style.content_margin_top=5
	style.content_margin_bottom=5
	panel.add_theme_stylebox_override("panel",style)
	var box=VBoxContainer.new()
	box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	dashboard=lbl(box,"",13,true)
	dashboard.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	dashboard.mouse_filter=Control.MOUSE_FILTER_IGNORE
	dashboard_bar=ProgressBar.new()
	dashboard_bar.max_value=100
	dashboard_bar.show_percentage=false
	dashboard_bar.custom_minimum_size.y=8
	dashboard_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	box.add_child(dashboard_bar)
	refresh_ui()

func refresh_ui():
	super.refresh_ui()
	if is_instance_valid(status_line): status_line.text="V1.7 / "+(CAVE_NAMES[cave_index] if cave_active else ZONES[zone])+" • "+WEATHER_NAMES[weather]
	if is_instance_valid(daily_label):
		var lines=[]
		for i in range(3):
			lines.append("%s • %d/%d • %s" % [DAILY_NAMES[i],mini(daily_progress(i),DAILY_TARGETS[i]),DAILY_TARGETS[i],"Alındı" if daily_claimed[i] else str(DAILY_GOLD[i])+" G + kasa"])
		daily_label.text="\n".join(lines)
		var i=maxi(0,daily_choice.selected)
		daily_button.disabled=daily_claimed[i] or daily_progress(i)<DAILY_TARGETS[i]
	if is_instance_valid(dashboard):
		var ready=0
		for i in range(unlocked):
			if plots[i].crop>=0 and plots[i].watered and plots[i].remaining<=0: ready+=1
		dashboard.text="%d hazır tarla • %d dayanıklılık • V: günlük" % [ready,int(stamina)]
		if stats_toggle: dashboard.text+=" • %d FPS" % sampled_fps
		dashboard_bar.value=stamina

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_V:
		show_manager(14)
		return
	super._unhandled_input(event)

func _process(delta):
	if is_instance_valid(pause_window) and pause_window.visible and not testing: return
	super._process(delta)
	if testing: return
	background_clock+=delta
	if background_clock>=0.5:
		advance_background_farms(background_clock)
		background_clock=0.0
	daily_clock+=delta
	if daily_clock>=2.0:
		daily_clock=0
		ensure_daily()
	sample_clock+=delta
	if sample_clock>=1.0:
		sample_clock=0.0
		sampled_fps=Engine.get_frames_per_second()

func _write_extension(data: Dictionary):
	super._write_extension(data)
	data["v17"]={"day":daily_day,"start":daily_start,"claimed":daily_claimed,"fps":stats_toggle}

func _read_extension(data: Dictionary):
	super._read_extension(data)
	var e=data.get("v17",{})
	if not e is Dictionary: return
	daily_day=int(e.get("day",-1))
	var a=e.get("start",[])
	if a is Array and a.size()==3: daily_start=a
	var c=e.get("claimed",[])
	if c is Array and c.size()==3: daily_claimed=c
	stats_toggle=bool(e.get("fps",false))
	if is_instance_valid(stats_check): stats_check.set_pressed_no_signal(stats_toggle)

func run_tests():
	var errors=[]
	ensure_daily()
	harvests=8
	var before=gold
	claim_daily(0)
	claim_daily(0)
	if gold!=before+45 or not daily_claimed[0]: errors.append("daily repeat")
	zone_open[1]=true
	zone_plots[1][0]={"crop":0,"watered":true,"remaining":1.0}
	advance_background_farms(2.0)
	if zone_plots[1][0].remaining!=0: errors.append("background farm")
	var path="user://sproutlings_v17_test_"+str(Time.get_ticks_usec())+".json"
	stats_toggle=true
	save_game(path,true)
	reset_data()
	load_game(path)
	if not daily_claimed[0] or not stats_toggle: errors.append("save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not errors.is_empty():
		push_error("V1.7 FAIL "+str(errors))
		get_tree().quit(1)
		return
	print("V1.7 PASS: daily order, repeat prevention, background farm, save")
	reset_data()
	rebuild_region()
	rebuild_decor()
	refresh_all()
	super.run_tests()

func visual_test():
	show_manager(14)
	await get_tree().process_frame
	if manager_tabs.current_tab!=14 or not is_instance_valid(dashboard):
		push_error("V1.7 VISUAL FAIL dashboard")
		get_tree().quit(1)
		return
	manager.hide()
	print("V1.7 VISUAL PASS: daily orders and live HUD")
	await super.visual_test()
