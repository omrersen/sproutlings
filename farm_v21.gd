extends "res://farm_v20.gd"

const ART_NAMES=["Çiftçi","Gezgin","Bahçıvan","Kaşif"]
const ART_MODELS=["character-male-a","character-male-b","character-female-a","character-male-c"]
const GROUND_PALETTE=[Color("#9bb47b"),Color("#709c73"),Color("#8fb7b1"),Color("#b58b66"),Color("#91aabe"),Color("#9a94b9")]
var landscape21: Node3D
var water_material21: ShaderMaterial
var water_nodes21=[]
var breeze_trees=[]
var avatar21=0
var avatar_menu21: OptionButton
var visual_count21=0
var sky_clock21=0.0
var cloud_nodes21=[]
var art_theme21: Theme
var preview21=false

func reset_data():
	super.reset_data()
	avatar21=0

func _ready():
	super._ready()
	if not testing: DisplayServer.window_set_title("Sproutlings — Valley Edition V2.1")

func water_shader21() -> ShaderMaterial:
	if is_instance_valid(water_material21): return water_material21
	var shader=Shader.new()
	shader.code="""shader_type spatial;
render_mode cull_disabled;
varying vec3 local_pos;
void vertex(){
	local_pos=VERTEX;
}
void fragment(){
	vec2 p=local_pos.xz;
	float a=sin(p.x*13.0+p.y*8.0+TIME*1.5);
	float b=sin(p.x*7.0-p.y*15.0-TIME*1.1);
	float ripple=(a+b)*0.25+0.5;
	float line=smoothstep(0.90,0.99,ripple);
	vec3 deep=vec3(0.10,0.43,0.47);
	vec3 light=vec3(0.35,0.74,0.70);
	ALBEDO=mix(deep,light,ripple*0.6)+line*vec3(0.16,0.19,0.16);
	ROUGHNESS=0.23;
	SPECULAR=0.55;
	NORMAL_MAP=vec3(0.5+a*0.06,0.5+b*0.06,1.0);
}
"""
	water_material21=ShaderMaterial.new()
	water_material21.shader=shader
	return water_material21

func style_water21():
	water_nodes21=[]
	if zone==0:
		for n in home_meshes:
			if n is MeshInstance3D and n.mesh is CylinderMesh and n.position.distance_to(Vector3(5.1,-0.04,-2.9))<0.04:
				n.material_override=water_shader21()
				water_nodes21.append(n)
	elif zone in [2,5]:
		if is_instance_valid(scenery):
			for n in scenery.get_children():
				if n is MeshInstance3D and n.mesh is CylinderMesh and n.position.distance_to(Vector3(5.1,-0.04,-2.9))<0.04:
					n.material_override=water_shader21()
					water_nodes21.append(n)
	if zone in [0,2,5]:
		for i in range(5):
			var pos=Vector3(5.1+cos(float(i)*1.22)*1.38,0,-2.9+sin(float(i)*1.22)*1.02)
			spawn_asset(landscape21,"rock-largea",pos,0.23+0.05*(i%3))
		for i in range(3):
			spawn_asset(landscape21,"grass-large",Vector3(4.35+0.65*i,0,-4.0),0.25)

func tree21(name: String,at: Vector3,height: float):
	var m=spawn_asset(landscape21,name,at,height)
	if not is_instance_valid(m):
		m=spawn_asset(landscape21,"tree-blocks-fall" if season==2 else "tree-blocks-dark",at,height)
	if is_instance_valid(m):
		m.rotation.y=at.x*0.34
		breeze_trees.append(m)
		visual_count21+=1

func rebuild_region():
	super.rebuild_region()
	if not is_instance_valid(region_root): return
	landscape21=Node3D.new()
	landscape21.name="ValleyArt"
	region_root.add_child(landscape21)
	breeze_trees=[]
	cloud_nodes21=[]
	visual_count21=0
	# Extend the landscape beyond the original playfield without changing saved plot coordinates.
	var ground=BoxMesh.new()
	ground.size=Vector3(46,0.18,42)
	mesh_at(landscape21,ground,Vector3(0,-0.25,0),GROUND_PALETTE[zone].darkened(0.09))
	var rng_art=RandomNumberGenerator.new()
	rng_art.seed=19731+zone*113
	var tree_name="tree-oak-fall" if season==2 else ("tree-detailed" if zone==1 else "tree-oak")
	for row in range(2):
		for i in range(9):
			var x=-13.0+i*3.15+rng_art.randf_range(-0.45,0.45)
			var z=-7.0-row*3.15+rng_art.randf_range(-0.3,0.3)
			if zone in [3,4]:
				var rock=spawn_asset(landscape21,"cliff-large-rock",Vector3(x,-0.12,z),rng_art.randf_range(1.7,3.1))
				if not is_instance_valid(rock): spawn_asset(landscape21,"rock-largea",Vector3(x,-0.12,z),1.4)
			else: tree21(tree_name,Vector3(x,-0.12,z),rng_art.randf_range(2.3,3.3))
	for side in [-1,1]:
		for i in range(4):
			var p=Vector3(side*(8.3+rng_art.randf_range(0.1,1.0)),-0.12,-3.0+i*2.8)
			if zone in [3,4]: spawn_asset(landscape21,"rock-largea",p,1.5)
			else: tree21(tree_name,p,2.4+rng_art.randf()*0.8)
	for i in range(9):
		var p=Vector3(-6.8+i*1.7,-0.10,6.55)
		spawn_asset(landscape21,"grass-large",p,0.20)
		if i%2==0: spawn_asset(landscape21,"flower-yellowa",p+Vector3(0.35,0,0.35),0.20)
	# Low distant cloud clusters; no expensive volumetric effects.
	for i in range(3):
		var cloud=Node3D.new()
		landscape21.add_child(cloud)
		cloud.position=Vector3(-12+i*12,6.5,-15.5-i)
		for j in range(3):
			var n=sphere_at(cloud,Vector3((j-1)*0.95,0.14*(j%2),0),Vector3(1.8,0.55,0.7),Color("#e9eee2"))
			n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud_nodes21.append(cloud)
	style_water21()
	style_lighting21()
	tint_trees21()

func style_lighting21():
	if not is_instance_valid(sun): return
	sun.shadow_enabled=not fast_mode
	sun.light_energy=0.78
	sun.shadow_blur=1.5
	sun.directional_shadow_max_distance=42
	for n in get_children():
		if n is WorldEnvironment and n.environment!=null:
			n.environment.ambient_light_color=Color("#d5e0df")
			n.environment.ambient_light_energy=0.42
			n.environment.background_color=Color("#d8e4d7")

func apply_weather():
	super.apply_weather()
	if is_instance_valid(sun):
		sun.shadow_enabled=not fast_mode
		sun.light_energy=[0.80,0.68,0.52,0.60][weather]

func set_avatar21(index: int):
	avatar21=clampi(index,0,3)
	if not is_instance_valid(hero): return
	var replacement=spawn_asset(hero,ART_MODELS[avatar21],Vector3.ZERO,1.43)
	if not is_instance_valid(replacement): return
	if is_instance_valid(hero_model): hero_model.queue_free()
	hero_model=replacement
	hero_anim=find_anim(replacement)
	play_model(hero_anim,["idle","stand"])
	if is_instance_valid(avatar_menu21): avatar_menu21.select(avatar21)

func make_world():
	super.make_world()
	if avatar21!=0: set_avatar21(avatar21)

func build_theme21() -> Theme:
	var t=Theme.new()
	t.default_font_size=16
	for kind in ["Button","OptionButton","CheckButton"]:
		for state_name in ["normal","hover","pressed","disabled","focus"]:
			var b=StyleBoxFlat.new()
			b.bg_color=Color("#253d36") if state_name=="normal" else Color("#42634f")
			if state_name=="pressed": b.bg_color=Color("#1a2e28")
			if state_name=="disabled": b.bg_color=Color("#2d3933")
			b.border_color=Color("#beaa77") if state_name=="focus" else Color("#56705d")
			b.set_border_width_all(1)
			b.set_corner_radius_all(9)
			b.content_margin_left=12
			b.content_margin_right=12
			b.content_margin_top=7
			b.content_margin_bottom=7
			t.set_stylebox(state_name,kind,b)
		t.set_color("font_color",kind,Color("#f0ebd7"))
		t.set_color("font_hover_color",kind,Color("#fff4cd"))
		t.set_color("font_disabled_color",kind,Color("#87988a"))
	var p=StyleBoxFlat.new()
	p.bg_color=Color("#162b26f5")
	p.border_color=Color("#829474")
	p.set_border_width_all(1)
	p.set_corner_radius_all(12)
	p.content_margin_left=14
	p.content_margin_right=14
	p.content_margin_top=10
	p.content_margin_bottom=10
	t.set_stylebox("panel","PanelContainer",p)
	t.set_color("font_color","Label",Color("#e9e5d4"))
	t.set_color("font_color","Window",Color("#f5e4ad"))
	t.set_stylebox("embedded_border","Window",p)
	var bar=StyleBoxFlat.new()
	bar.bg_color=Color("#b8c886")
	bar.set_corner_radius_all(5)
	t.set_stylebox("fill","ProgressBar",bar)
	return t

func skin_tree21(node: Node):
	if node is Control or node is Window: node.theme=art_theme21
	for c in node.get_children(): skin_tree21(c)

func make_ui():
	super.make_ui()
	var v=new_tab("Görünüm")
	lbl(v,"VADİDEKİ KİMLİĞİN",25,true)
	lbl(v,"Dört karakter görünümünden birini seç. Görünüm kayıt dosyanda saklanır.",15)
	avatar_menu21=menu(v,func(i): set_avatar21(i);save_game())
	for n in ART_NAMES: avatar_menu21.add_item(n)
	avatar_menu21.select(avatar21)
	btn(v,"Dünyaya dön",func(): manager.hide())
	if is_instance_valid(navigation):
		navigation.add_item("Görünüm",manager_tabs.get_tab_count()-1)
	art_theme21=build_theme21()
	skin_tree21(get_node("HUD"))
	for label in get_node("HUD").find_children("*","Label",true,false):
		if label.text.begins_with("Yerel prototip"): label.text="Yaratıklarını besle, keşfet ve koleksiyonunu geliştir."
		if label.text.contains("D dekor taşı"): label.text=label.text.replace("D dekor taşı","T dekor taşı")
	refresh_ui()

func refresh_ui():
	super.refresh_ui()
	if is_instance_valid(status_line): status_line.text="V2.1 / "+(CAVE_NAMES[cave_index] if cave_active else ZONES[zone])+" • "+WEATHER_NAMES[weather]

func _process(delta):
	super._process(delta)
	if testing or not motion or cave_active or fast_mode: return
	sky_clock21+=delta
	for i in range(breeze_trees.size()):
		var n=breeze_trees[i]
		if is_instance_valid(n): n.rotation.z=sin(sky_clock21*0.75+i*0.68)*0.018
	for i in range(cloud_nodes21.size()):
		var n=cloud_nodes21[i]
		if is_instance_valid(n): n.position.x=-12.0+i*12.0+sin(sky_clock21*0.07+i)*2.5

func _write_extension(data: Dictionary):
	super._write_extension(data)
	data["v21"]={"avatar":avatar21}

func _read_extension(data: Dictionary):
	super._read_extension(data)
	var e=data.get("v21",{})
	if e is Dictionary:
		avatar21=clampi(int(e.get("avatar",0)),0,3)
		if is_instance_valid(hero): set_avatar21(avatar21)

func run_tests():
	var errors=[]
	if visual_count21<10: errors.append("valley scenery")
	if water_nodes21.is_empty() or water_shader21().shader==null: errors.append("water")
	set_avatar21(2)
	if avatar21!=2 or not is_instance_valid(hero_anim): errors.append("avatar")
	var path="user://sproutlings_v21_test_"+str(Time.get_ticks_usec())+".json"
	save_game(path,true)
	reset_data()
	load_game(path)
	if avatar21!=2: errors.append("avatar save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not errors.is_empty():
		push_error("V2.1 FAIL "+str(errors))
		get_tree().quit(1)
		return
	print("V2.1 PASS: extended landscape, water material, avatar and save")
	reset_data()
	set_avatar21(0)
	rebuild_region()
	rebuild_decor()
	refresh_all()
	super.run_tests()

func visual_test():
	if is_instance_valid(welcome_window): welcome_window.hide()
	if is_instance_valid(pause_window): pause_window.hide()
	manager.hide()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var shot=get_viewport().get_texture().get_image()
	if not shot.is_empty():
		var path="user://quality_preview_v21.png"
		var result=shot.save_png(path)
		print("V2.1 SCREENSHOT ",ProjectSettings.globalize_path(path)," result=",result)
	if water_nodes21.is_empty() or not is_instance_valid(art_theme21):
		push_error("V2.1 VISUAL FAIL")
		get_tree().quit(1)
		return
	print("V2.1 VISUAL PASS: valley, animated water, unified theme")
	await super.visual_test()

func tint_trees21():
	for wrapper in region_root.find_children("Imported_tree*","Node3D",true,false):
		for mesh in wrapper.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh==null: continue
			for i in range(mesh.mesh.get_surface_count()):
				var source=mesh.get_active_material(i)
				if source is StandardMaterial3D:
					var m=source.duplicate() as StandardMaterial3D
					m.albedo_color=Color("#c39b62") if season==2 else Color("#6f9a57")
					mesh.set_surface_override_material(i,m)