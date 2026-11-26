extends "res://farm_v19.gd"

const PET_ASSETS=["Tree","Mushroom","Crab","Deer","YellowDragon","Cactus","Bat","Bee","Chicken","Penguin","Alien","Yeti","Panda","Pig","Demon","Ghost"]
const CROP_ASSETS=["crops-wheatstageb","crop-carrot","crops-cornstaged","crops-leafsstageb","crop-pumpkin","crops-leafsstageb","crop-pumpkin"]
const TREE_POS=[Vector3(-6,0,-5.2),Vector3(-2.9,0,-5.2),Vector3(0.1,0,-5.35),Vector3(3.1,0,-5.3),Vector3(6.2,0,4.5),Vector3(-6.1,0,4.8)]
var asset_cache={}
var hero_model: Node3D
var hero_anim: AnimationPlayer
var hero_last=Vector3.ZERO
var imported_count=0
var use_imported_models=true

func _ready():
	super._ready()
	if not testing: DisplayServer.window_set_title("Sproutlings V2.0 Desktop")

func asset_path(name: String,pet: bool=false) -> String:
	return "res://assets/quaternius/"+name+".gltf" if pet else "res://assets/kenney/"+name+".glb"

func get_asset(name: String,pet: bool=false) -> PackedScene:
	var path=asset_path(name,pet)
	if not asset_cache.has(path):
		if not ResourceLoader.exists(path): return null
		var resource=load(path)
		if not resource is PackedScene: return null
		asset_cache[path]=resource
	return asset_cache[path]

func bounds_of(root: Node3D) -> AABB:
	var box=AABB()
	var first=true
	for n in root.find_children("*","MeshInstance3D",true,false):
		if n.mesh==null: continue
		var a=(root.global_transform.affine_inverse()*n.global_transform)*n.get_aabb()
		if first:
			box=a
			first=false
		else: box=box.merge(a)
	return box

func spawn_asset(parent: Node3D,name: String,at: Vector3,height: float,pet: bool=false) -> Node3D:
	var scene=get_asset(name,pet)
	if scene==null: return null
	var wrapper=Node3D.new()
	wrapper.name="Imported_"+name
	parent.add_child(wrapper)
	wrapper.position=at
	var model=scene.instantiate() as Node3D
	if model==null:
		wrapper.queue_free()
		return null
	wrapper.add_child(model)
	var bounds=bounds_of(wrapper)
	if bounds.size.y<=0.001:
		wrapper.queue_free()
		return null
	var factor=height/bounds.size.y
	model.scale*=factor
	model.position-=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
	imported_count+=1
	return wrapper

func find_anim(root: Node3D) -> AnimationPlayer:
	if not is_instance_valid(root): return null
	for n in root.find_children("*","AnimationPlayer",true,false):
		return n as AnimationPlayer
	return null

func play_model(anim: AnimationPlayer,keys: Array):
	if not is_instance_valid(anim): return
	var names=anim.get_animation_list()
	for key in keys:
		for clip in names:
			if String(clip).to_lower().contains(String(key).to_lower()):
				if anim.current_animation!=clip or not anim.is_playing():
					var a=anim.get_animation(clip)
					a.loop_mode=Animation.LOOP_LINEAR
					anim.play(clip,0.15)
				return

func make_world():
	super.make_world()
	if is_instance_valid(hero):
		var m=spawn_asset(hero,"character-male-a",Vector3.ZERO,1.43)
		if is_instance_valid(m):
			for child in hero.get_children():
				if child!=m and child is Node3D: child.hide()
			hero_model=m
			hero_anim=find_anim(m)
			play_model(hero_anim,["idle","stand"])
			hero_last=hero.position

func pet_model(parent: Node3D,species: int,shiny: bool) -> Node3D:
	# Keep the gameplay model root and compatibility with evolution/reveal systems.
	var root=super.pet_model(parent,species,shiny)
	if species<0 or species>=PET_ASSETS.size(): return root
	var m=spawn_asset(root,PET_ASSETS[species],Vector3.ZERO,0.87,true)
	if not is_instance_valid(m): return root
	for n in root.get_children():
		if n!=m and n is Node3D: n.hide()
	play_model(find_anim(m),["idle","stand","fly"])
	if shiny:
		var ring=TorusMesh.new()
		ring.inner_radius=0.39
		ring.outer_radius=0.45
		var halo=mesh_at(root,ring,Vector3(0,1.12,0),Color("#ffe6a3"))
		var mat_halo=halo.material_override as StandardMaterial3D
		mat_halo.emission_enabled=true
		mat_halo.emission=Color("#f9ce71")
	return root

func refresh_plot(i: int):
	super.refresh_plot(i)
	if i<0 or i>=unlocked or i>=crop_nodes.size(): return
	var p=plots[i]
	if p.crop<0: return
	var root: Node3D=crop_nodes[i]
	for child in root.get_children():
		if String(child.name).begins_with("Imported_"): return
	var c=int(p.crop)
	var growth=1.0 if p.remaining<=0 else clampf(0.25+0.75*(1.0-float(p.remaining)/float(CROPS[c].time)),0.25,1.0)
	var old=root.get_children()
	var models=[]
	for x in [-0.38,0.38]:
		for z in [-0.38,0.38]:
			var m=spawn_asset(root,CROP_ASSETS[c],Vector3(x,0,z),0.56*growth)
			if is_instance_valid(m): models.append(m)
	if models.size()==4:
		for j in range(3,old.size()):
			if old[j] is Node3D: old[j].hide()

func rebuild_region():
	super.rebuild_region()
	if not is_instance_valid(region_root): return
	var root=Node3D.new()
	root.name="ImportedLandscape"
	region_root.add_child(root)
	if zone==0:
		for i in range(TREE_POS.size()):
			var pos=TREE_POS[i]
			var m=spawn_asset(root,"tree-blocks-fall" if season==2 else "tree-blocks-dark",pos,2.3)
			if not is_instance_valid(m): continue
			for n in home_meshes:
				if n is MeshInstance3D and absf(n.position.x-pos.x)<0.03 and absf(n.position.z-pos.z)<0.03 and n.position.y>0.3: n.hide()
			m.rotation.y=i*0.9
	elif zone in [1,5]:
		for i in range(6):
			var pos=Vector3(-6.3+i*2.5,0,-5.1)
			var m=spawn_asset(root,"tree-blocks-dark",pos,2.0)
			if is_instance_valid(m):
				m.rotation.y=i*1.15
				for n in region_root.get_children():
					if n is MeshInstance3D and absf(n.position.x-pos.x)<0.5 and absf(n.position.z-pos.z)<0.5 and n.position.y>0.3: n.hide()
	for i in range(10):
		var p=Vector3(-6.5+float(i)*1.38,0,4.95)
		spawn_asset(root,"flower-purplea" if i%2==0 else "flower-yellowa",p,0.28)
	for i in range(3):
		var p=NPC_POS[i]
		var m=spawn_asset(root,["character-female-a","character-male-b","character-male-c"][i],p,1.34)
		if not is_instance_valid(m): continue
		if is_instance_valid(npc_root):
			for n in npc_root.get_children():
				if n is MeshInstance3D and absf(n.position.x-p.x)<0.43 and absf(n.position.z-p.z)<0.24: n.hide()
		if is_instance_valid(scenery):
			for n in scenery.get_children():
				if n is MeshInstance3D and absf(n.position.x-p.x)<0.35 and absf(n.position.z-p.z)<0.25 and n.position.y>0: n.hide()
		play_model(find_anim(m),["idle","stand"])

func refresh_ui():
	super.refresh_ui()
	if is_instance_valid(status_line): status_line.text="V2.0 Desktop / "+(CAVE_NAMES[cave_index] if cave_active else ZONES[zone])+" • "+WEATHER_NAMES[weather]

func _process(delta):
	super._process(delta)
	if testing or not is_instance_valid(hero_model): return
	var moving=hero.position.distance_to(hero_last)>0.002
	hero_last=hero.position
	play_model(hero_anim,["sprint","run","walk"] if moving and sprinting else (["walk","run"] if moving else ["idle","stand"]))
	if not motion and is_instance_valid(hero_anim): hero_anim.pause()

func run_tests():
	var errors=[]
	for name in PET_ASSETS:
		if get_asset(name,true)==null: errors.append(name)
	for name in CROP_ASSETS:
		if get_asset(name)==null: errors.append(name)
	if not is_instance_valid(hero_model) or not is_instance_valid(hero_anim): errors.append("hero")
	if imported_count<10: errors.append("world")
	for i in range(16):
		var n=pet_model(pets_root,i,false)
		var imported=false
		for child in n.get_children():
			if String(child.name).begins_with("Imported_"):
				imported=is_instance_valid(find_anim(child))
		if not imported: errors.append("pet "+str(i))
		n.queue_free()
	if not errors.is_empty():
		push_error("V2.0 FAIL "+str(errors))
		get_tree().quit(1)
		return
	print("V2.0 PASS: 16 animated creatures, imported farmer, crops, landscape and animation")
	reset_data()
	rebuild_region()
	rebuild_decor()
	refresh_all()
	super.run_tests()

func visual_test():
	if not is_instance_valid(hero_model) or not is_instance_valid(hero_anim):
		push_error("V2.0 VISUAL FAIL")
		get_tree().quit(1)
		return
	play_model(hero_anim,["walk"])
	await get_tree().process_frame
	if not hero_anim.is_playing():
		push_error("V2.0 VISUAL FAIL animation")
		get_tree().quit(1)
		return
	print("V2.0 VISUAL PASS: imported animated character and landscape")
	await super.visual_test()
