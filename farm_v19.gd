extends "res://farm_v18.gd"

const VILLAGE_NAMES=["Mira","Deniz","Bora"]
const VILLAGE_COLORS=["#d19e66","#74a9c8","#a28ac6"]
const SCENERY_COLORS=["#a5c482","#5fa36e","#9dcdd2","#c28b58","#a1c9e3","#b1a6da"]
var scenery: Node3D
var field_markers=[]
var world_feedback: Label3D
var feedback_clock=0.0
var scenery_instances=0
var compact_ui=false
var compact_toggle: CheckButton
var side_panels=[]
var close_view_button: Button

func reset_data():
	super.reset_data()
	compact_ui=false

func _ready():
	super._ready()
	if not testing: DisplayServer.window_set_title("Sproutlings V1.9")

func sign3d(parent: Node3D,at: Vector3,caption: String,scale_px: float=0.009) -> Label3D:
	var label=Label3D.new()
	label.text=caption
	label.font_size=36
	label.outline_size=8
	label.pixel_size=scale_px
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate=Color("#fff1c7")
	label.outline_modulate=Color("#253b33")
	label.position=at
	parent.add_child(label)
	return label

func make_world():
	super.make_world()
	world_feedback=sign3d(self,Vector3.ZERO,"",0.011)
	world_feedback.hide()
	for i in range(12):
		var p=plot_pos(i)+Vector3(0,0.96,0)
		var l=sign3d(self,p,"HAZIR",0.0075)
		l.modulate=Color("#ffe69c")
		l.hide()
		field_markers.append(l)
	if is_instance_valid(hero):
		for x in [-0.075,0.075]:
			sphere_at(hero,Vector3(x,1.08,0.187),Vector3(0.045,0.048,0.025),Color("#343b38"))
		box_at(hero,Vector3(0,0.51,0.17),Vector3(0.26,0.08,0.045),Color("#c5a66c"))

func create_ground_cover(parent: Node3D):
	var rng_scene=RandomNumberGenerator.new()
	rng_scene.seed=1829+zone*197
	var positions=[]
	for i in range(320):
		var x=rng_scene.randf_range(-7.0,7.0)
		var z=rng_scene.randf_range(-5.8,5.65)
		if absf(x)<4.15 and z>-3.1 and z<3.9: continue
		if z<-2.85 and z>-4.4 and x>-3.45 and x<1.8: continue
		if zone==0 and ((x<-3.5 and z<-2.3) or (x>3.5 and z<-1.2)): continue
		if Vector3(x,0,z).distance_to(TREASURE_POS[zone])<0.85: continue
		positions.append(Vector3(x,0.035,z))
	var mm=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.use_colors=true
	var mesh=BoxMesh.new()
	mesh.size=Vector3(0.038,0.17,0.045)
	mm.mesh=mesh
	mm.instance_count=positions.size()
	for i in range(positions.size()):
		var p=positions[i]
		var basis=Basis(Vector3.UP,rng_scene.randf_range(0,TAU)).scaled(Vector3(1,rng_scene.randf_range(0.65,1.45),1))
		mm.set_instance_transform(i,Transform3D(basis,p+Vector3(0,0.07,0)))
		mm.set_instance_color(i,Color(SCENERY_COLORS[zone]).lerp(Color("#ede0a0"),rng_scene.randf_range(0,0.35)))
	var n=MultiMeshInstance3D.new()
	n.multimesh=mm
	var material=mat(Color.WHITE)
	material.vertex_color_use_as_albedo=true
	n.material_override=material
	n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	scenery_instances=positions.size()

func rebuild_region():
	super.rebuild_region()
	if not is_instance_valid(region_root): return
	scenery=Node3D.new()
	scenery.name="WorldDetail"
	region_root.add_child(scenery)
	create_ground_cover(scenery)
	var ground=Color(SCENERY_COLORS[zone]).lerp(Color("#d2b78f"),0.65)
	box_at(scenery,Vector3(-0.9,-0.065,-3.34),Vector3(6.0,0.06,0.76),ground)
	for i in range(3):
		var p=NPC_POS[i]
		var c=Color(VILLAGE_COLORS[i])
		var back=p+Vector3(0,0,-0.95)
		box_at(scenery,back+Vector3(0,0.25,0),Vector3(1.15,0.45,0.58),c.darkened(0.18))
		for x in [-0.49,0.49]:
			box_at(scenery,back+Vector3(x,0.76,0),Vector3(0.065,1.45,0.065),Color("#9d7854"))
		box_at(scenery,back+Vector3(0,1.48,0),Vector3(1.22,0.13,0.76),c)
		for j in range(3):
			box_at(scenery,back+Vector3(-0.39+j*0.39,1.51,0.38),Vector3(0.20,0.12,0.055),Color("#f2dfb3"))
		for x in [-0.25,0.25]:
			box_at(scenery,p+Vector3(x,0.45,0),Vector3(0.12,0.32,0.14),c.darkened(0.08))
		for x in [-0.062,0.062]:
			sphere_at(scenery,p+Vector3(x,0.9,0.177),Vector3(0.04,0.045,0.02),Color("#29362e"))
		for x in [-0.1,0.1]:
			box_at(scenery,p+Vector3(x,0.10,0.04),Vector3(0.14,0.19,0.24),Color("#635747"))
	for p in [Vector3(-3.65,0,-3.1),Vector3(1.65,0,-3.1),Vector3(5.1,0,2.5)]:
		box_at(scenery,p+Vector3(0,0.44,0),Vector3(0.10,0.88,0.10),Color("#755d43"))
		var lamp=box_at(scenery,p+Vector3(0,0.93,0),Vector3(0.24,0.27,0.24),Color("#ffe5a0"))
		var m=lamp.material_override as StandardMaterial3D
		m.emission_enabled=true
		m.emission=Color("#f3bc60")
		cone_at(scenery,p+Vector3(0,1.11,0),0.20,0.18,Color("#786950"))
	if zone in [0,2,5]:
		if zone!=0:
			var lake=CylinderMesh.new()
			lake.top_radius=0.93
			lake.bottom_radius=0.93
			lake.height=0.055
			lake.radial_segments=20
			mesh_at(scenery,lake,Vector3(5.1,-0.04,-2.9),Color("#74c3cf"))
		sign3d(scenery,Vector3(5.1,0.8,-2.9),"Balıkçılık",0.008)

func obstacle_at(p: Vector3) -> bool:
	if super.obstacle_at(p): return true
	if cave_active: return false
	for center in NPC_POS:
		if inside_obstacle(p,center+Vector3(0,0,-0.95),Vector2(0.58,0.33)): return true
	if zone in [2,5] and inside_obstacle(p,Vector3(5.1,0,-2.9),Vector2(0.83,0.83)): return true
	return false

func fishing_nearby() -> bool:
	return not cave_active and zone in [0,2,5] and is_instance_valid(hero) and hero.position.distance_to(Vector3(5.1,0,-2.9))<1.95

func interact():
	if fishing_nearby():
		start_fishing()
		return
	super.interact()

func context_target() -> Array:
	if not is_instance_valid(hero): return []
	if cave_active:
		if hero.position.distance_to(Vector3(0,0,4.3))<1.6: return [Vector3(0,0,4.3),"F • Mağaradan çık"]
		for i in range(4):
			if rock_hp[i]>0 and hero.position.distance_to(cave_positions()[i])<1.65:
				return [cave_positions()[i],"F • Kaz (%d)" % rock_hp[i]]
		return []
	if fishing_nearby(): return [Vector3(5.1,0,-2.9),"F • Balık tut"]
	if not treasure_claimed[zone] and hero.position.distance_to(TREASURE_POS[zone])<1.6:
		return [TREASURE_POS[zone],"F • Hazineyi aç"]
	var n=nearest_npc()
	if n>=0: return [NPC_POS[n],"F • "+VILLAGE_NAMES[n]+" ile konuş"]
	if zone in CAVE_ZONES and hero.position.distance_to(CAVE_GATE)<1.8: return [CAVE_GATE,"F • Mağaraya gir"]
	var best=1.8
	var idx=-1
	for i in range(unlocked):
		var p=plot_pos(i)
		p.y=0
		var dist=hero.position.distance_to(p)
		if dist<best: best=dist;idx=i
	if idx<0: return []
	var p=plots[idx]
	var caption="F • Ekim" if p.crop<0 else ("F • Sula" if not p.watered else ("F • Hasat" if p.remaining<=0 else "Büyüyor • %d sn" % ceili(p.remaining)))
	return [plot_pos(idx),caption]

func update_world_feedback():
	for i in range(field_markers.size()):
		var p=plots[i]
		field_markers[i].visible=not cave_active and i<unlocked and p.crop>=0 and p.watered and p.remaining<=0
	if not is_instance_valid(world_feedback): return
	var a=context_target()
	world_feedback.visible=not modal_open() and a.size()==2
	if a.size()==2:
		world_feedback.position=a[0]+Vector3(0,1.65,0)
		world_feedback.text=a[1]

func set_compact(on: bool):
	compact_ui=on
	for panel in side_panels:
		if is_instance_valid(panel): panel.visible=not on
	if is_instance_valid(close_view_button): close_view_button.text="Panelleri göster [G]" if on else "Panelleri gizle [G]"

func make_ui():
	super.make_ui()
	var layer=get_node("HUD")
	for n in layer.get_children():
		if n is PanelContainer and n.get_child_count()>0:
			var box=n.get_child(0)
			if box is VBoxContainer:
				for c in box.get_children():
					if c is Label and (c.text=="SPROUTLINGS" or c.text=="YARATIKLAR"):
						side_panels.append(n)
						break
	var button=Button.new()
	button.text="Panelleri gizle [G]"
	button.custom_minimum_size.y=33
	layer.add_child(button)
	button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	button.offset_left=-105
	button.offset_right=105
	button.offset_top=115
	button.offset_bottom=151
	button.pressed.connect(func(): set_compact(not compact_ui);save_game())
	close_view_button=button
	set_compact(compact_ui)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_G:
		set_compact(not compact_ui)
		save_game()
		return
	super._unhandled_input(event)

func refresh_ui():
	super.refresh_ui()
	if is_instance_valid(status_line): status_line.text="V1.9 / "+(CAVE_NAMES[cave_index] if cave_active else ZONES[zone])+" • "+WEATHER_NAMES[weather]

func _process(delta):
	super._process(delta)
	if testing: return
	feedback_clock+=delta
	if feedback_clock>=0.12:
		feedback_clock=0
		update_world_feedback()

func _write_extension(data: Dictionary):
	super._write_extension(data)
	data["v19"]={"compact":compact_ui}

func _read_extension(data: Dictionary):
	super._read_extension(data)
	var e=data.get("v19",{})
	if e is Dictionary: set_compact(bool(e.get("compact",false)))

func run_tests():
	var errors=[]
	if scenery_instances<40: errors.append("ground detail")
	hero.position=Vector3(5.1,0,-1.6)
	if not fishing_nearby() or context_target().size()!=2: errors.append("pond interaction")
	hero.position=NPC_POS[0]+Vector3(0,0,0.75)
	if nearest_npc()!=0 or not context_target()[1].contains("Mira"): errors.append("NPC accessibility")
	if not obstacle_at(NPC_POS[0]+Vector3(0,0,-0.95)): errors.append("stall collision")
	if field_markers.size()!=12: errors.append("plot labels")
	plots[0].crop=0
	plots[0].watered=true
	plots[0].remaining=0
	update_world_feedback()
	if not field_markers[0].visible: errors.append("ready marker")
	set_compact(true)
	if not compact_ui or side_panels.size()!=2: errors.append("compact HUD")
	set_compact(false)
	if not errors.is_empty():
		push_error("V1.9 FAIL "+str(errors))
		get_tree().quit(1)
		return
	print("V1.9 PASS: world details, pond and NPC interactions, collision, harvest markers, compact HUD")
	reset_data()
	rebuild_region()
	rebuild_decor()
	refresh_all()
	super.run_tests()

func visual_test():
	hero.position=NPC_POS[0]+Vector3(0,0,0.8)
	update_world_feedback()
	await get_tree().process_frame
	if not is_instance_valid(scenery) or not world_feedback.visible or not world_feedback.text.contains("Mira"):
		push_error("V1.9 VISUAL FAIL world prompts")
		get_tree().quit(1)
		return
	set_compact(true)
	await get_tree().process_frame
	set_compact(false)
	print("V1.9 VISUAL PASS: world details, contextual labels, compact HUD")
	await super.visual_test()
