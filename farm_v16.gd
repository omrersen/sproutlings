extends "res://farm_v15.gd"

const STORY_NAMES=["Yeni başlangıç","İlk dost","Bereketli toprak","Köy yaşamı","Kâşifin yolu","Ustalık","Ay bahçesi","Vadi koruyucusu"]
const STORY_HINTS=["Dört ürün hasat et. Boş tarlaya tıkla, ek ve sula; hazır olunca hasat et.","Bir yaratık edin, besle ve görevlendir. İlk hasatla gelen kasayı kullan.","Çiftliğini sekiz tarlaya genişlet ve toplam 12 hasada ulaş.","L3 seviyesine ulaş ve ilk binanı kur. M ile yönetim panelini aç.","İlk mağarana gir, üç cevher çıkar ve bir hazine bul.","En az bir ustalığı L3 yap ve bir ekipman üret. P ile atölyeyi aç.","Altı biyomu keşfet ve koleksiyonunda altı farklı yaratık türü biriktir.","75 hasat, üç mağara ve 10 farklı yaratık türü. Vadinin koruyucusu ol."]
const STORY_GOLD=[30,40,65,85,100,150,220,400]
const STORY_CRATE=[0,0,0,1,1,2,2,3]
const STORY_TARGET=[4,1,12,1,1,1,1,1]
var story_stage=0
var story_complete=false
var chapter_text: Label
var chapter_progress: ProgressBar
var chapter_claim: Button
var chapter_hint: Label
var pause_window: Window
var pause_info: Label
var story_badge: Label
var quest_clock=0.0
var camera_follow=false
var camera_target=Vector3(0,0,-0.6)
var camera_origin=Vector3.ZERO
var focus_toggle: CheckButton
var runtime_test_mode=false
var runtime_save="user://sproutlings_runtime_test.json"
var runtime_seconds=0.0

func reset_data():
	super.reset_data()
	story_stage=0
	story_complete=false
	camera_follow=false

func _ready():
	runtime_test_mode="--runtime-test" in OS.get_cmdline_user_args()
	super._ready()
	if testing: return
	DisplayServer.window_set_title("Sproutlings V1.6")
	camera_origin=cam.position
	if runtime_test_mode:
		call_deferred("run_runtime_test")
		return
	if "--visual-test" not in OS.get_cmdline_user_args():
		call_deferred("open_title")

func save_game(path: String=SAVE_V1,allow_testing: bool=false):
	if runtime_test_mode and path==SAVE_V1: path=runtime_save
	super.save_game(path,allow_testing)

func load_game(path: String=SAVE_V1):
	if runtime_test_mode and path==SAVE_V1: path=runtime_save
	super.load_game(path)

func story_value(i: int) -> int:
	match i:
		0: return harvests
		1:
			for p in creatures:
				if p.active and p.hunger>0: return 1
		2: return harvests if zone_land[0]>=8 or (zone==0 and unlocked>=8) else 0
		3: return 1 if level>=3 and buildings.has(true) else 0
		4: return 1 if cave_seen.size()>0 and mined_count>=3 and treasure_claimed.has(true) else 0
		5: return 1 if skill_xp.max()>=200 and (crafted[1]>0 or crafted[2]>0 or crafted[3]>0 or crafted[0]>0) else 0
		6: return 1 if zone_open.count(true)>=6 and seen_species.size()>=6 else 0
		7: return 1 if harvests>=75 and cave_seen.size()>=3 and seen_species.size()>=10 else 0
	return 0

func story_ready() -> bool:
	return not story_complete and story_stage<8 and story_value(story_stage)>=STORY_TARGET[story_stage]

func claim_chapter():
	if not story_ready():
		notify("Önce bölümün hedefini tamamla.")
		return
	var i=story_stage
	gold+=STORY_GOLD[i]
	crates[STORY_CRATE[i]]+=1
	story_stage+=1
	story_complete=story_stage>=8
	notify("Bölüm tamamlandı: "+STORY_NAMES[i]+" • Ödül alındı!")
	effect_sound(4)
	refresh_ui()
	save_game()

func chapter_action():
	if story_ready():
		claim_chapter()
		return
	if story_complete: return
	match story_stage:
		0,1,2: manager.hide()
		3: show_manager(1)
		4: show_manager(11)
		5: show_manager(12)
		6: show_manager(0)
		7: show_manager(3)

func open_title():
	if not is_instance_valid(pause_window): return
	if is_instance_valid(welcome_window): welcome_window.hide()
	pause_info.text="Çiftliğine hoş geldin.\nSeviye %d • %d altın • %d hasat\nBölüm %d/8 • %d keşfedilen yaratık" % [level,gold,harvests,mini(story_stage+1,8),seen_species.size()]
	pause_window.popup_centered()

func resume_game():
	pause_window.hide()
	welcome_seen=true
	notify("Çiftliğine hoş geldin! C: hikâye, Esc: menü.")

func open_settings_menu():
	pause_window.hide()
	show_manager(5)

func save_and_exit():
	save_game()
	get_tree().quit()

func modal_open() -> bool:
	return super.modal_open() or (is_instance_valid(pause_window) and pause_window.visible)

func show_manager(tab: int):
	if is_instance_valid(pause_window): pause_window.hide()
	super.show_manager(tab)

func make_ui():
	super.make_ui()
	var v=new_tab("Hikâye")
	lbl(v,"VADİNİN HİKÂYESİ",26,true)
	chapter_text=lbl(v,"",19,true)
	chapter_hint=lbl(v,"",16)
	chapter_progress=ProgressBar.new()
	chapter_progress.custom_minimum_size.y=25
	v.add_child(chapter_progress)
	chapter_claim=btn(v,"Devam et",chapter_action)
	lbl(v,"Sekiz bölümün ödüllerini al ve Vadi Koruyucusu unvanını kazan. Hikâyeden sonra serbest oyun devam eder.",14)
	focus_toggle=CheckButton.new()
	focus_toggle.text="Kamera karakteri takip etsin"
	focus_toggle.button_pressed=camera_follow
	v.add_child(focus_toggle)
	focus_toggle.toggled.connect(func(on): camera_follow=on; save_game())
	var layer=get_node("HUD")
	pause_window=Window.new()
	pause_window.title="Sproutlings • Ana menü"
	pause_window.size=Vector2i(520,420)
	pause_window.exclusive=true
	layer.add_child(pause_window)
	pause_window.hide()
	pause_window.close_requested.connect(resume_game)
	v=window_content(pause_window)
	lbl(v,"SPROUTLINGS",32,true)
	lbl(v,"V2.0  /  VADİNİN HİKÂYESİ",17,true)
	pause_info=lbl(v,"",17)
	separator(v)
	btn(v,"Oyuna devam et",resume_game)
	btn(v,"Hikâye ve görevler [C]",func(): show_manager(13))
	btn(v,"Ayarlar",open_settings_menu)
	btn(v,"Kaydet ve çık",save_and_exit)
	lbl(v,"Tamamen çevrim dışı • Yerel kayıt • Esc: menü",13)
	story_badge=Label.new()
	layer.add_child(story_badge)
	story_badge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	story_badge.offset_left=-255
	story_badge.offset_right=255
	story_badge.offset_top=-145
	story_badge.offset_bottom=-111
	story_badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	story_badge.add_theme_font_size_override("font_size",17)
	story_badge.add_theme_color_override("font_color",Color("#fff0bd"))
	story_badge.add_theme_color_override("font_outline_color",Color("#1a3026"))
	story_badge.add_theme_constant_override("outline_size",6)
	story_badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
	refresh_ui()

func refresh_ui():
	super.refresh_ui()
	if is_instance_valid(status_line): status_line.text="V1.6 / "+(CAVE_NAMES[cave_index] if cave_active else ZONES[zone])+" • "+WEATHER_NAMES[weather]
	if not is_instance_valid(chapter_text): return
	if story_complete:
		chapter_text.text="VADİ KORUYUCUSU"
		chapter_hint.text="Tüm bölümler tamamlandı. Çiftliğini geliştirmeye devam edebilirsin."
		chapter_progress.max_value=8
		chapter_progress.value=8
		chapter_claim.disabled=true
		story_badge.text="Vadi Koruyucusu • C: hikâye"
	else:
		var i=story_stage
		chapter_text.text="Bölüm %d/8 • %s" % [i+1,STORY_NAMES[i]]
		chapter_hint.text=STORY_HINTS[i]+"\nÖdül: %d altın + %s kasa" % [STORY_GOLD[i],TIERS[STORY_CRATE[i]]]
		chapter_progress.max_value=STORY_TARGET[i]
		chapter_progress.value=mini(story_value(i),STORY_TARGET[i])
		chapter_claim.disabled=false
		chapter_claim.text="Bölüm ödülünü al" if story_ready() else "Hedefe git"
		story_badge.text=STORY_NAMES[i]+" • "+("Ödül hazır!" if story_ready() else str(int(chapter_progress.value))+"/"+str(STORY_TARGET[i]))+" • C"
		if is_instance_valid(goal): goal.text="Bölüm %d: %s" % [i+1,STORY_NAMES[i]]

func update_camera(delta: float):
	if not is_instance_valid(cam) or not is_instance_valid(hero): return
	var target=Vector3.ZERO
	if camera_follow: target=Vector3(hero.position.x*0.35,0,hero.position.z*0.35)
	var change=(target-camera_target)*minf(1.0,delta*3.0)
	camera_target+=change
	cam.position+=change
	cam.look_at(camera_target+Vector3(0,0,-0.6))

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			if pause_window.visible: resume_game()
			else: open_title()
			return
		if event.keycode==KEY_C:
			show_manager(13)
			return
		if event.keycode in [KEY_Q,KEY_E]:
			cam.position-=camera_target
			super._unhandled_input(event)
			cam.position+=camera_target
			cam.look_at(camera_target+Vector3(0,0,-0.6))
			return
	super._unhandled_input(event)

func _process(delta):
	if is_instance_valid(pause_window) and pause_window.visible and not testing: return
	super._process(delta)
	if testing: return
	update_camera(delta)
	if runtime_test_mode: runtime_seconds+=delta

func _write_extension(data: Dictionary):
	super._write_extension(data)
	data["v16"]={"chapter":story_stage,"complete":story_complete,"camera_follow":camera_follow}

func _read_extension(data: Dictionary):
	super._read_extension(data)
	var e=data.get("v16",{})
	if not e is Dictionary: return
	story_stage=clampi(int(e.get("chapter",0)),0,8)
	story_complete=story_stage==8
	camera_follow=bool(e.get("camera_follow",false))
	if is_instance_valid(focus_toggle): focus_toggle.set_pressed_no_signal(camera_follow)

func run_tests():
	var errors=[]
	harvests=4
	var before=gold
	claim_chapter()
	claim_chapter()
	if story_stage!=1 or gold!=before+30: errors.append("chapter reward")
	creatures.append({"species":0,"shiny":false,"growth":300.0,"hunger":100.0,"active":true,"production":0.0})
	claim_chapter()
	unlocked=8
	harvests=12
	claim_chapter()
	level=3
	buildings[0]=true
	claim_chapter()
	cave_seen=[0]
	mined_count=3
	treasure_claimed[0]=true
	claim_chapter()
	skill_xp[0]=200
	crafted[1]=1
	claim_chapter()
	zone_open=[true,true,true,true,true,true]
	seen_species=[0,1,2,3,4,5,6,7,8,9]
	claim_chapter()
	harvests=75
	cave_seen=[0,3,4]
	claim_chapter()
	if story_stage!=8 or not story_complete: errors.append("campaign end")
	var path="user://sproutlings_v16_test_"+str(Time.get_ticks_usec())+".json"
	camera_follow=true
	save_game(path,true)
	reset_data()
	load_game(path)
	if not story_complete or story_stage!=8 or not camera_follow: errors.append("campaign save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not errors.is_empty():
		push_error("V1.6 FAIL "+str(errors))
		get_tree().quit(1)
		return
	print("V1.6 PASS: eight chapter campaign, duplicate reward prevention, ending, save")
	reset_data()
	rebuild_region()
	rebuild_decor()
	refresh_all()
	super.run_tests()

func visual_test():
	open_title()
	await get_tree().process_frame
	if not pause_window.visible:
		push_error("V1.6 VISUAL FAIL menu")
		get_tree().quit(1)
		return
	resume_game()
	show_manager(13)
	await get_tree().process_frame
	if manager_tabs.current_tab!=13 or not is_instance_valid(chapter_progress):
		push_error("V1.6 VISUAL FAIL campaign")
		get_tree().quit(1)
		return
	manager.hide()
	print("V1.6 VISUAL PASS: title menu, campaign screen")
	await super.visual_test()

func run_runtime_test():
	# This path uses an isolated save; the real save is never opened.
	reset_data()
	rebuild_region()
	refresh_all()
	if is_instance_valid(welcome_window): welcome_window.hide()
	for i in range(4):
		plot_action(i)
		plot_action(i)
	# Let actual frame processing grow the crops without altering their timers.
	await get_tree().create_timer(14.0).timeout
	for i in range(4): plot_action(i)
	if harvests!=4 or not story_ready():
		push_error("RUNTIME FAIL harvest "+str(harvests))
		get_tree().quit(1)
		return
	claim_chapter()
	open_crate(0)
	if is_instance_valid(reveal_window): close_reveal()
	if creatures.is_empty():
		push_error("RUNTIME FAIL crate")
		get_tree().quit(1)
		return
	feed_pet(0)
	if not creatures[0].active: toggle_pet(0)
	if not story_ready():
		push_error("RUNTIME FAIL companion")
		get_tree().quit(1)
		return
	claim_chapter()
	save_game()
	load_game()
	if story_stage!=2 or harvests!=4:
		push_error("RUNTIME FAIL save")
		get_tree().quit(1)
		return
	print("V1.6 RUNTIME PASS: real-time crop growth, four harvests, crate, companion, story, reload")
	# Avoid writing after cleanup via normal close request.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(runtime_save))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(runtime_save+".bak"))
	get_tree().quit()
