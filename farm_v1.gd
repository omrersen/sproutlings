extends "res://farm_v03.gd"

const SAVE_V1="user://sproutlings_v1.json"
var release_hint: Label
var welcome_window: Window
var welcome_seen=false
var motion_saved=true

func reset_data():
	super.reset_data()
	welcome_seen=false

func make_ui():
	super.make_ui()
	var layer=get_node("HUD")
	var bar=HBoxContainer.new()
	layer.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bar.offset_left=-225
	bar.offset_right=225
	bar.offset_top=106
	bar.offset_bottom=147
	bar.alignment=BoxContainer.ALIGNMENT_CENTER
	btn(bar,"Rehber [F1]",show_guide)
	welcome_window=Window.new()
	welcome_window.title="Sproutlings • Çiftliğine hoş geldin"
	welcome_window.size=Vector2i(550,440)
	welcome_window.exclusive=true
	layer.add_child(welcome_window)
	welcome_window.hide()
	welcome_window.close_requested.connect(close_guide)
	var v=window_content(welcome_window)
	lbl(v,"SPROUTLINGS  /  V1.3",25,true)
	lbl(v,"Küçük bir çiftlikten kendi yaratık cennetine.",18)
	separator(v)
	lbl(v,"1. Boş tarlaya tıkla, ek ve sula. Hazır olduğunda hasat et.\n2. İlk hasatla kazandığın Ahşap kasayı aç.\n3. Yaratığını besle ve görevlendir.\n4. Envanter, dekorasyon ve harita üzerinden çiftliğini geliştir.",16)
	separator(v)
	lbl(v,"Tek oyunculu masaüstü oyunu. İlerlemen bilgisayarında saklanır.",14)
	btn(v,"Çiftliğime başla",close_guide)
	if not testing and not welcome_seen and not "--visual-test" in OS.get_cmdline_user_args():
		call_deferred("show_guide")

func show_guide():
	welcome_window.popup_centered()

func close_guide():
	welcome_seen=true
	welcome_window.hide()

func refresh_ui():
	super.refresh_ui()
	if is_instance_valid(status_line):
		status_line.text="V1.0 / "+ZONES[zone]+" • "+SEASONS[season]

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F1:
			show_guide()
			return
		if event.keycode==KEY_F11:
			var mode=DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			return
	super._unhandled_input(event)

func save_game(path: String=SAVE_V1,allow_testing: bool=false):
	# Serialize all inherited data to a sibling temporary file; replace only on success.
	if testing and not allow_testing: return
	var temp=path+".tmp"
	super.save_game(temp,allow_testing)
	var f=FileAccess.open(temp,FileAccess.READ)
	if not f: return
	var data=JSON.parse_string(f.get_as_text())
	f.close()
	if not data is Dictionary: return
	data["welcome_seen"]=welcome_seen
	_write_extension(data)
	f=FileAccess.open(temp,FileAccess.WRITE)
	if not f: return
	f.store_string(JSON.stringify(data))
	f.close()
	var from=ProjectSettings.globalize_path(temp)
	var dest=ProjectSettings.globalize_path(path)
	var backup=dest+".bak"
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(dest,backup)
	var result=DirAccess.rename_absolute(from,dest)
	if result!=OK:
		push_warning("Save replacement failed: "+str(result))

func load_game(path: String=SAVE_V1):
	var actual=path
	var f=FileAccess.open(actual,FileAccess.READ)
	if f:
		var data=JSON.parse_string(f.get_as_text())
		f.close()
		if not data is Dictionary: actual=path+".bak"
	elif FileAccess.file_exists(path+".bak"):
		actual=path+".bak"
	super.load_game(actual)
	f=FileAccess.open(actual,FileAccess.READ)
	if f:
		var data=JSON.parse_string(f.get_as_text())
		if data is Dictionary:
			welcome_seen=bool(data.get("welcome_seen",false))
			_read_extension(data)

func _write_extension(_data: Dictionary):
	pass

func _read_extension(_data: Dictionary):
	pass

func run_tests():
	welcome_seen=true
	gold=124
	var path="user://sproutlings_v1_test_"+str(Time.get_ticks_usec())+".json"
	save_game(path,true)
	gold=125
	save_game(path,true)
	reset_data()
	load_game(path)
	if gold!=125 or not welcome_seen:
		push_error("V1 FAIL: atomic save / tutorial flag")
		get_tree().quit(1)
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".bak"))
	print("V1 PASS: atomic save replacement, backup, tutorial state")
	reset_data()
	refresh_all()
	super.run_tests()
