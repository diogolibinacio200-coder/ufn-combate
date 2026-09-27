extends Node
## UFN Kart: deterministic arcade driving over a shared 3D world.
## Two independent chase cameras, eight competitors, ordered checkpoint gates.

signal exit_requested
signal race_finished(results: Array)

const HUD = preload("res://scripts/kart_hud.gd")
const IDS: Array[String] = ["arthur", "vitorbem", "maria", "diogo", "mirkos", "felipe", "murilo", "gabriel", "fabiano", "vitormal", "lorenzo", "leonardo", "cristian", "fernando"]
const NAMES: Array[String] = ["ARTHUR", "VITOR DO BEM", "MARIA", "DIOGO", "MIRKOS", "FELIPE", "MURILO", "GABRIEL", "FABIANO", "VITOR DO MAL", "LORENZO", "LEONARDO", "CRISTIAN", "FERNANDO"]
const COLORS: Array[Color] = [Color("55b8ff"), Color("79deb5"), Color("d6adff"), Color("2187ff"), Color("ffcd66"), Color("f498ca"), Color("58a8e9"), Color("fd9268"), Color("bc879c"), Color("a2ade9"),Color("42ddff"),Color("59b878"),Color("e79769"),Color("bba17d")]
const ITEM_NAMES: Array[String] = ["", "PULSO UFN", "TURBO", "ESCUDO", "CHOQUE", "ÓLEO", "CAPIVARA", "PODER EXCLUSIVO"]
const ROAD_HALF: float = 7.7
const GATES: int = 20
const LAPS: int = 3

const SIGNATURES = ["HALTER", "GRITO", "CAPIVARA", "RAÍZES", "DRONE", "BOLA COM CURVA", "HANDEBOL", "TURBO DE MOTOR", "PARÁBOLA", "ALIADA", "PACOTE DE DADOS", "ESPUMA", "TIJOLOS", "PATADA LATERAL"]
const TRACK_NAMES = ["CIRCUITO DO CAMPUS","VOLTA DA VILA BELGA","CENTRO DE SANTA MARIA","DESAFIO UNIVERSITÁRIO"]
var tutorial_mode=false
var tutorial_step=0
var race_mode = "quick"
var horizontal_split = false
var auto_accelerate = false
var difficulty = 1
var championship_points: Dictionary = {}
var race_points_before: Dictionary = {}
var app: Node
var active: bool = false
var paused: bool = false
var phase: String = "countdown"
var countdown: float = 4.0
var elapsed: float = 0.0
var clock_time: float = 0.0
var player_count: int = 2
var track_id: int = 0
var track_name: String = "CIRCUITO DO CAMPUS"
var choices_saved: Array = []
var skins_saved: Array = []
var racers: Array[Dictionary] = []
var road: PackedVector2Array = []
var cumulative: PackedFloat32Array = []
var total_length: float = 0.0
var checkpoints: Array[Dictionary] = []
var boxes: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var ordered_results: Array = []
var cameras: Array[Camera3D] = []
var views: Array[SubViewport] = []
var display: Control
var world: Node3D
var hud: Control
var layer: CanvasLayer
var finish_delay: float = 0.0
var mat_cache: Dictionary = {}
var previous_keys: Array[Dictionary] = [{}, {}]
var texture_cache: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var engine_voices: Array[AudioStreamPlayer] = []
var engine_phases: Array[float] = [0.0,0.0]
var countdown_tick: int = 4

func setup(parent_app: Node) -> void:
	app = parent_app
	rng.randomize()
	set_physics_process(false)
	set_process(false)

func start(choices: Array, skins: Array = [], track: int = 0, humans: int = 2) -> void:
	stop()
	choices_saved = choices.duplicate()
	skins_saved = skins.duplicate()
	player_count = clampi(humans, 1, 2)
	track_id = posmod(track, 4)
	track_name = TRACK_NAMES[track_id]
	race_points_before=championship_points.duplicate()
	if race_mode=="time_trial":player_count=1
	active = true
	paused = false
	tutorial_step=0
	phase = "countdown"
	countdown = 4.0
	countdown_tick = 4
	elapsed = 0.0
	clock_time = 0.0
	finish_delay = 0.0
	ordered_results.clear()
	previous_keys = [{}, {}]
	_build_track()
	_build_views()
	_build_world()
	_spawn_racers(choices, skins)
	_spawn_boxes()
	_start_engines()
	hud = HUD.new()
	hud.game = self
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_update_cameras(1.0, true)
	set_physics_process(true)
	set_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func stop() -> void:
	active = false
	set_physics_process(false)
	set_process(false)
	if is_instance_valid(layer):
		layer.queue_free()
	layer = null
	world = null
	hud = null
	racers.clear()
	views.clear()
	cameras.clear()
	boxes.clear()
	projectiles.clear()
	hazards.clear()
	effects.clear()
	mat_cache.clear()
	for voice: AudioStreamPlayer in engine_voices:
		voice.stop()
		voice.queue_free()
	engine_voices.clear()

func leave() -> void:
	stop()
	exit_requested.emit()

func restart() -> void:
	championship_points=race_points_before.duplicate()
	start(choices_saved, skins_saved, track_id, player_count)

func toggle_pause() -> void:
	if not active or phase == "results":
		return
	paused = not paused
	if is_instance_valid(hud):
		hud.refresh_menu()

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F2 and not paused and phase == "race":
			respawn_racer(racers[0])
		elif event.keycode == KEY_BACKSPACE and player_count == 2 and not paused and phase == "race":
			respawn_racer(racers[1])
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		toggle_pause()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and active and phase == "race" and not paused:
		paused = true
		if is_instance_valid(hud):
			hud.refresh_menu()

func _build_track() -> void:
	road.clear()
	cumulative.clear()
	checkpoints.clear()
	var anchors: PackedVector2Array
	if track_id == 0:
		anchors = PackedVector2Array([Vector2(-54,-46), Vector2(0,-52), Vector2(57,-46), Vector2(76,-16), Vector2(50,10), Vector2(72,44), Vector2(28,64), Vector2(-16,53), Vector2(-57,65), Vector2(-79,30), Vector2(-59,2), Vector2(-78,-26)])
	elif track_id==1:
		anchors = PackedVector2Array([Vector2(-50,-60), Vector2(10,-62), Vector2(65,-49), Vector2(83,-4), Vector2(58,29), Vector2(18,20), Vector2(0,66), Vector2(-55,64), Vector2(-84,30), Vector2(-68,0)])
	elif track_id==2:
		anchors=PackedVector2Array([Vector2(-65,-63),Vector2(28,-67),Vector2(76,-50),Vector2(78,-7),Vector2(28,-2),Vector2(26,48),Vector2(65,65),Vector2(-18,72),Vector2(-73,51),Vector2(-77,0)])
	else:
		anchors=PackedVector2Array([Vector2(-60,-68),Vector2(0,-77),Vector2(70,-65),Vector2(83,-20),Vector2(45,7),Vector2(75,60),Vector2(13,77),Vector2(-26,40),Vector2(-74,62),Vector2(-86,13),Vector2(-44,-5)])
	for i: int in range(anchors.size()):
		for sub: int in range(12):
			var t: float = float(sub) / 12.0
			var a: Vector2 = anchors[posmod(i-1, anchors.size())]
			var b: Vector2 = anchors[i]
			var c: Vector2 = anchors[(i+1)%anchors.size()]
			var d: Vector2 = anchors[(i+2)%anchors.size()]
			road.append(0.5 * ((2.0*b) + (-a+c)*t + (2.0*a-5.0*b+4.0*c-d)*t*t + (-a+3.0*b-3.0*c+d)*t*t*t))
	cumulative.append(0.0)
	total_length = 0.0
	for i: int in range(road.size()):
		total_length += road[i].distance_to(road[(i+1)%road.size()])
		cumulative.append(total_length)
	for i: int in range(GATES):
		var s: Dictionary = sample_road(float(i)*total_length/float(GATES))
		checkpoints.append(s)

func sample_road(distance: float) -> Dictionary:
	var d: float = fposmod(distance, total_length)
	var idx: int = 0
	for i: int in range(road.size()):
		if cumulative[i+1] >= d:
			idx = i
			break
	var tangent: Vector2 = (road[(idx+1)%road.size()]-road[idx]).normalized()
	var amount: float = (d-cumulative[idx])/maxf(0.001,cumulative[idx+1]-cumulative[idx])
	return {"pos": road[idx].lerp(road[(idx+1)%road.size()], amount), "dir": tangent, "distance":d, "index":idx}

func nearest_road(pos: Vector2) -> Dictionary:
	var best: float = INF
	var nearest: Vector2 = Vector2.ZERO
	var distance: float = 0.0
	var tangent: Vector2 = Vector2.RIGHT
	for i: int in range(road.size()):
		var a: Vector2 = road[i]
		var delta: Vector2 = road[(i+1)%road.size()]-a
		var amount: float = clampf((pos-a).dot(delta)/maxf(delta.length_squared(),0.001),0.0,1.0)
		var projected: Vector2 = a+delta*amount
		var error: float = pos.distance_squared_to(projected)
		if error < best:
			best = error
			nearest = projected
			distance = cumulative[i]+delta.length()*amount
			tangent = delta.normalized()
	return {"pos":nearest,"dir":tangent,"distance":distance,"offset":sqrt(best)}

func _build_views() -> void:
	layer = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	display = Control.new()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(display)
	var row: BoxContainer = VBoxContainer.new() if horizontal_split else HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 3)
	display.add_child(row)
	for i: int in range(player_count):
		var container: SubViewportContainer = SubViewportContainer.new()
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.stretch = true
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(container)
		var viewport: SubViewport = SubViewport.new()
		viewport.size = Vector2i(640,720)
		viewport.handle_input_locally = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.msaa_3d = Viewport.MSAA_DISABLED if is_instance_valid(app) and int(app.profile.data.settings.quality)==1 else Viewport.MSAA_2X
		container.add_child(viewport)
		views.append(viewport)
		if i == 0:
			world = Node3D.new()
			viewport.add_child(world)
		else:
			viewport.world_3d = views[0].world_3d
		var camera: Camera3D = Camera3D.new()
		camera.fov = 73.0 if player_count == 2 else 67.0
		camera.near = 0.3
		camera.far = 500.0
		camera.current = true
		viewport.add_child(camera)
		cameras.append(camera)

func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key: String = color.to_html()+str(glow)
	if mat_cache.has(key):
		return mat_cache[key]
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	if color.a < 0.999:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.4
	mat_cache[key] = mat
	return mat

func cube(parent: Node3D, position: Vector3, size: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color,glow)
	node.position = position
	parent.add_child(node)
	return node

func ball(parent: Node3D, position: Vector3, radius: float, color: Color, flattened: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = position
	node.scale = flattened
	parent.add_child(node)
	return node

func cylinder(parent: Node3D, position: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = position
	parent.add_child(node)
	return node

func sign3d(parent: Node3D, text_value: String, pos: Vector3, font_size: int, color: Color, angle: float = 0.0) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text_value
	label.position = pos
	label.font_size = font_size
	label.pixel_size = 0.018
	label.modulate = color
	label.outline_modulate = Color("05255a")
	label.outline_size = 8
	label.rotation.y = angle
	label.no_depth_test = false
	parent.add_child(label)
	return label

func _strip(offset_inner: float, offset_outer: float, elevation: float, color: Color, dashed: bool = false) -> void:
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.surface_set_normal(Vector3.UP)
	for i: int in range(road.size()):
		if dashed and i%4 > 1:
			continue
		var j: int = (i+1)%road.size()
		var d1: Vector2 = (road[j]-road[posmod(i-1,road.size())]).normalized()
		var d2: Vector2 = (road[(j+1)%road.size()]-road[i]).normalized()
		var n1: Vector2 = Vector2(-d1.y,d1.x)
		var n2: Vector2 = Vector2(-d2.y,d2.x)
		var a: Vector2 = road[i]+n1*offset_inner
		var b: Vector2 = road[i]+n1*offset_outer
		var c: Vector2 = road[j]+n2*offset_inner
		var d: Vector2 = road[j]+n2*offset_outer
		for p: Vector2 in [a,c,b,b,c,d]:
			mesh.surface_add_vertex(Vector3(p.x,elevation,p.y))
	mesh.surface_end()
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	var mat: StandardMaterial3D = material(color).duplicate()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	world.add_child(node)

func _build_world() -> void:
	var env_node: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("6fa1c4") if track_id == 0 else Color("3a4778")
	sky_mat.sky_horizon_color = Color("d7e9f1") if track_id == 0 else Color("f8b091")
	sky_mat.ground_bottom_color = Color("1d3745")
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b3d0e8")
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("abcad9") if track_id == 0 else Color("c7a4bb")
	env.fog_density = 0.0009
	env_node.environment = env
	world.add_child(env_node)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-25,0)
	sun.light_color = Color("ffefdb")
	sun.light_energy = 0.85
	sun.shadow_enabled = not (is_instance_valid(app) and int(app.profile.data.settings.quality)==1)
	sun.directional_shadow_max_distance = 80.0
	world.add_child(sun)
	cube(world,Vector3(0,-0.25,0),Vector3(650,0.4,650), Color("427c67") if track_id==0 else Color("355b61"))
	_strip(-ROAD_HALF-1.4,ROAD_HALF+1.4,0.003,Color("e9e5d8"))
	_strip(-ROAD_HALF,ROAD_HALF,0.025,Color("283c50"))
	_strip(-0.07,0.07,0.041,Color("cfdaaa"),true)
	_strip(-ROAD_HALF,-ROAD_HALF+0.18,0.042,Color("d4ecf8"))
	_strip(ROAD_HALF-0.18,ROAD_HALF,0.042,Color("d4ecf8"))
	# Short kerb segments alternate the university blue and white.
	for i: int in range(0,road.size(),2):
		var s: Dictionary = sample_road(cumulative[i])
		var dir: Vector2 = s.dir
		var normal: Vector2 = Vector2(-dir.y,dir.x)
		for side: float in [-1.0,1.0]:
			var p: Vector2 = s.pos + normal*(ROAD_HALF+0.35)*side
			var kerb: MeshInstance3D = cube(world,Vector3(p.x,0.11,p.y),Vector3(0.55,0.2,3.0),Color("006bbc") if i%4==0 else Color("edfaff"))
			kerb.rotation.y = -dir.angle()+PI/2.0
		if i%8 == 0:
			var outside: Vector2 = s.pos + normal*13.0
			var board: Node3D = Node3D.new()
			world.add_child(board)
			board.position = Vector3(outside.x,0,outside.y)
			board.rotation.y = -dir.angle()
			cube(board,Vector3(0,1.2,0),Vector3(5.5,2.1,0.28),Color("03509c"))
			sign3d(board,"UFN  ››",Vector3(0,1.25,0.17),62,Color.WHITE)
	var line: Dictionary = sample_road(0)
	var start_root: Node3D = Node3D.new()
	world.add_child(start_root)
	start_root.position = Vector3(line.pos.x,0,line.pos.y)
	start_root.rotation.y = -Vector2(line.dir).angle()-PI/2.0
	for xx: int in range(16):
		for zz: int in range(3):
			cube(start_root,Vector3(-7.5+xx,0.048,-1.0+zz),Vector3(1,0.015,1),Color.WHITE if (xx+zz)%2==0 else Color("133355"))
	for side: float in [-1.0,1.0]:
		cube(start_root,Vector3(side*9,3.7,0),Vector3(0.7,7.4,0.7),Color("e4eff3"))
	cube(start_root,Vector3(0,7.0,0),Vector3(19,1.8,0.6),Color("003d7c"))
	sign3d(start_root,"UFN  •  KART",Vector3(0,7.0,0.34),98,Color.WHITE)
	sign3d(start_root,"UFN  •  KART",Vector3(0,7.0,-0.34),98,Color.WHITE,PI)
	_build_scenery()
	_batch_static_geometry()

func _building(pos: Vector3, size: Vector3, color: Color, title: String = "") -> void:
	var parent: Node3D = Node3D.new()
	world.add_child(parent)
	parent.position = pos
	cube(parent,Vector3(0,size.y/2,0),size,color)
	cube(parent,Vector3(0,size.y+0.18,0),Vector3(size.x+0.6,0.36,size.z+0.6),Color("e0e6e7"))
	for floor_i: int in range(maxi(1,int(size.y/3.5))):
		for window_i: int in range(maxi(1,int(size.x/3.8))):
			var wx: float = -size.x/2+2.0+window_i*3.8
			cube(parent,Vector3(wx,1.8+floor_i*3.5,size.z/2+0.04),Vector3(2.4,1.55,0.07),Color("387b9b"))
			cube(parent,Vector3(wx,1.8+floor_i*3.5,-size.z/2-0.04),Vector3(2.4,1.55,0.07),Color("397190"))
	if not title.is_empty():
		cube(parent,Vector3(0,size.y*0.65,size.z/2+0.1),Vector3(size.x*0.9,1.5,0.12),Color("004e9c"))
		sign3d(parent,title,Vector3(0,size.y*0.65,size.z/2+0.2),60,Color.WHITE)

func _tree(pos: Vector2, scale_value: float = 1.0) -> void:
	var p: Node3D = Node3D.new()
	world.add_child(p)
	p.position = Vector3(pos.x,0,pos.y)
	p.scale = Vector3.ONE*scale_value
	cylinder(p,Vector3(0,2.0,0),0.36,4.0,Color("705747"))
	ball(p,Vector3(0,5.1,0),2.7,Color("276953"),Vector3(1.0,1.25,1.0))
	ball(p,Vector3(1.3,5.7,0.2),1.8,Color("367e5a"))

func _build_scenery() -> void:
	if track_id == 0:
		_building(Vector3(0,0,-20),Vector3(30,17,14),Color("d9e2e2"),"UNIVERSIDADE FRANCISCANA")
		_building(Vector3(-24,0,12),Vector3(20,10,16),Color("ecdfc9"),"UFN  •  INOVAÇÃO")
		_building(Vector3(30,0,35),Vector3(17,8,10),Color("e7e3d7"),"BIBLIOTECA")
		# Container café: corrugated panels, terrace and illuminated identity.
		for i: int in range(3):
			var p: Node3D = Node3D.new()
			world.add_child(p)
			p.position = Vector3(-16+i*13,0,-80)
			cube(p,Vector3(0,2,0),Vector3(12,4,5),[Color("0c65ad"),Color("e3e6d8"),Color("245f69")][i])
			for rib: int in range(15):
				cube(p,Vector3(-5.7+rib*0.8,2,2.56),Vector3(0.10,3.7,0.08),Color("075392"))
			cube(p,Vector3(0,1.9,2.65),Vector3(6.5,2,0.13),Color("182b35"))
			cube(p,Vector3(0,1.05,3.05),Vector3(7.3,0.25,1.2),Color("c3aa83"))
			sign3d(p,["CAFÉ DO PÁTIO","CONVIVÊNCIA","UFN • CONTAINER"][i],Vector3(0,3.45,2.66),45,Color.WHITE)
			for chair: int in range(3):
				cylinder(p,Vector3(-4+chair*4,0.7,7),0.8,0.13,Color("d4c29e"))
				cylinder(p,Vector3(-4+chair*4,0.35,7),0.13,0.7,Color("263a42"))
	elif track_id==1:
		for i in 12:
			var x=-101+i*18
			var color=[Color("f3a7b2"),Color("96c8af"),Color("7bb7d7"),Color("e5c48b")][i%4]
			_building(Vector3(x,0,-99),Vector3(16,7,12),color,"VILA BELGA" if i==6 else "")
			_building(Vector3(x,0,102),Vector3(16,7,12),color)
			for w in 3:cube(world,Vector3(x-5+w*5,3.5,-92.8),Vector3(2,4.7,.3),Color("e9f2df"))
	elif track_id==3:
		_building(Vector3(0,0,-15),Vector3(29,16,18),Color("e4edf3"),"DESAFIO UNIVERSITÁRIO")
		for i in 3:
			var ramp=sample_road(float(i)*total_length/3+2)
			var mesh=cube(world,Vector3(ramp.pos.x,.35,ramp.pos.y),Vector3(13,.5,4),Color("20a2cd"))
			mesh.rotation.y=-Vector2(ramp.dir).angle()-PI/2
			mesh.rotation.x=-.16
			for j in 3:sign3d(world,"↑",Vector3(ramp.pos.x,.7,ramp.pos.y),75,Color.WHITE)
	else:
		for i: int in range(9):
			_building(Vector3(-70+i*18,0,-96),Vector3(15,10+(i%4)*4,12),[Color("ceb99c"),Color("bdd2d5"),Color("c69080")][i%3],"SANTA MARIA" if i==4 else "")
		_building(Vector3(115,0,0),Vector3(21,24,28),Color("d2ccb1"),"CIDADE CULTURA")
		_building(Vector3(0,0,-20),Vector3(24,14,12),Color("eee3d1"),"UFN  •  CENTRO")
		# A stylized old railway station and distant hills evoke Santa Maria.
		_building(Vector3(-18,0,100),Vector3(43,7,12),Color("bf8261"),"ESTAÇÃO SANTA MARIA")
		for i: int in range(7):
			ball(world,Vector3(-170+i*57,0,-200),40,Color("466469"),Vector3(1.6,1.1,1))
	for i: int in range(42):
		var theta: float = float(i)*TAU/42.0
		var pos: Vector2 = Vector2(cos(theta)*109.0,sin(theta)*91.0)
		if nearest_road(pos).offset > 13.0:
			_tree(pos,0.85+float(i%4)*0.15)
	for p: Vector2 in [Vector2(6,17),Vector2(20,4),Vector2(-31,-20),Vector2(-5,36),Vector2(37,-6)]:
		if nearest_road(p).offset > 13:
			_tree(p,1.1)
	# Corner direction arrows and campus lamps are visible from both cameras.
	for i: int in range(16):
		var s: Dictionary = sample_road(float(i)*total_length/16.0)
		var n: Vector2 = Vector2(-s.dir.y,s.dir.x)
		var p: Vector2 = s.pos+n*10.8
		cylinder(world,Vector3(p.x,3.5,p.y),0.12,7.0,Color("526879"))
		cube(world,Vector3(p.x,7,p.y),Vector3(1.4,0.2,0.75),Color("e4f5fa"),true)

func _choice_index(value: Variant) -> int:
	if value is String:
		return maxi(0,IDS.find(value))
	return posmod(int(value),IDS.size())

func _spawn_racers(choices: Array, skins: Array) -> void:
	var selected_ids: Array = []
	for i in mini(player_count,choices.size()):selected_ids.append(_choice_index(choices[i]))
	for i: int in range(1 if race_mode=="time_trial" else 8):
		var selected: int = _choice_index(choices[i]) if i<choices.size() else (i+3)%IDS.size()
		if i>=player_count:
			while selected in selected_ids:selected=(selected+1)%IDS.size()
			selected_ids.append(selected)
		var skin: int = int(skins[i]) if i<skins.size() else 0
		# Humans start on the last grid row: all rivals remain ahead of the chase camera.
		var grid_slot: int = 8-player_count+i if i<player_count else i-player_count
		var s: Dictionary = sample_road(-10.0-float(grid_slot/2)*5.0)
		var n: Vector2 = Vector2(-s.dir.y,s.dir.x)
		var pos: Vector2 = s.pos+n*(-2.2 if grid_slot%2==0 else 2.2)
		var root: Node3D = _make_kart(selected,skin)
		var r: Dictionary = {"id":i,"character":selected,"skin":skin,"name":NAMES[selected],"human":i<player_count,"pos":pos,"previous_pos":pos,"heading":Vector2(s.dir).angle(),"velocity":Vector2.ZERO,"speed":0.0,"steer":0.0,"lap":1,"next_gate":1,"gates":0,"rank":i+1,"item":0,"item_edge":false,"drift":0.0,"drifting":false,"boost":0.0,"shield":0.0,"stun":0.0,"hit_flash":0.0,"offroad":false,"wrongway":false,"last_progress":0.0,"progress":0.0,"finish_time":-1.0,"node":root,"bot_timer":2.0+float(i),"notice":"","notice_time":0.0,"recovery":0.0,"trail_timer":0.0,"invincible":0.0,"jump":0.0,"launch_back":false,"signature":0.0,"max_speed":31.0+(selected%3)*0.4}
		racers.append(r)
		r.rank = grid_slot+1
		_sync_kart(r,0.0)

func _make_kart(selected: int, skin: int) -> Node3D:
	var root: Node3D = Node3D.new()
	world.add_child(root)
	var color: Color = COLORS[selected]
	# Local forward is -Z. Body, bumper, side pods, rear engine, four wheels.
	cube(root,Vector3(0,0.55,0),Vector3(1.48,0.40,2.30),color)
	cube(root,Vector3(0,0.67,-0.93),Vector3(1.32,0.25,0.68),Color("eff8ff"))
	cube(root,Vector3(0,0.30,-1.38),Vector3(1.80,0.18,0.20),Color("193244"))
	cube(root,Vector3(0,0.42,1.17),Vector3(1.8,0.24,0.22),Color("193244"))
	cube(root,Vector3(0,0.90,0.76),Vector3(0.95,0.63,0.55),Color("263c49"))
	cube(root,Vector3(0,1.08,0.25),Vector3(0.76,0.87,0.30),Color("18303e"))
	for side: float in [-1.0,1.0]:
		cube(root,Vector3(side*0.77,0.53,0.2),Vector3(0.3,0.36,1.4),color.darkened(0.15))
		cube(root,Vector3(side*0.45,0.65,-1.3),Vector3(0.25,0.15,0.04),Color("82ebff"),true)
		for zz: float in [-0.86,0.80]:
			var wheel: MeshInstance3D = cylinder(root,Vector3(side*0.90,0.38,zz),0.40,0.32,Color("13232d"))
			wheel.rotation.z = PI/2.0
			var rim: MeshInstance3D = cylinder(root,Vector3(side*1.08,0.38,zz),0.23,0.025,Color("a6c8d8"))
			rim.rotation.z = PI/2.0
	var shirt: Color = [Color("20232c"),Color("233449"),Color("17243d"),Color("f1f1e9") if skin==0 else Color("181e25"),Color("182d4e"),Color("737f88"),Color("eda6bf"),Color("191e23"),Color("79344a"),Color("282730"),Color("1c2731"),Color("268055"),Color("252a35"),Color("969c9d")][selected]
	ball(root,Vector3(0,1.29,-0.08),0.39,shirt,Vector3(0.83,1.1,0.68))
	ball(root,Vector3(0,1.85,-0.04),0.32,Color("d9aa87"))
	if selected not in [10,11]:ball(root,Vector3(0,2.01,0.0),0.32,Color("382a28"),Vector3(1,0.60,1))
	if selected==2:ball(root,Vector3(0,1.76,.2),.33,Color("231f27"),Vector3(1,1.8,.7))
	if selected in [4,6,10,11,12]:cube(root,Vector3(0,1.9,-.31),Vector3(.54,.07,.035),Color("151d29"))
	if selected in [10,11,12,13]:ball(root,Vector3(0,1.7,-.14),.24,Color("aaabad") if selected==11 else Color("2a2424"),Vector3(.8,.5,.8))
	for side: float in [-1.0,1.0]:
		ball(root,Vector3(side*0.28,1.31,-0.47),0.13,Color("d9aa87"))
	var steering: MeshInstance3D = cylinder(root,Vector3(0,1.22,-0.51),0.31,0.08,Color("14222a"))
	steering.rotation_degrees.x = 57
	var badge: Label3D = sign3d(root,"UFN",Vector3(0,0.83,-1.17),30,Color("074b88"))
	badge.rotation_degrees.x = -60
	var avatar_path: String = "res://assets/sprites/"+("diogo_alt" if selected==3 and skin>0 else IDS[selected])+"/portrait.png"
	if ResourceLoader.exists(avatar_path):
		var avatar: Sprite3D = Sprite3D.new()
		avatar.texture = load(avatar_path)
		avatar.pixel_size = 0.003
		avatar.position = Vector3(0,1.25,0.43)
		avatar.rotation.y = PI
		root.add_child(avatar)
	match selected:
		0:
			for side in [-1,1]:cylinder(root,Vector3(side*.8,1.1,.9),.3,.6,Color("657587"))
		1:sign3d(root,"!",Vector3(0,2.5,.5),44,Color("9efcad"))
		2:ball(root,Vector3(.9,1.1,.4),.35,Color("ad885f"),Vector3(.7,.7,1.3))
		3:
			for side in [-1,1]:ball(root,Vector3(side*.72,.8,1),.4,Color("448d59"),Vector3(.6,1.4,.6))
		4:
			cube(root,Vector3(0,2.7,.7),Vector3(1.1,.22,.8),Color("abb9c6"))
			for side in [-1,1]:cylinder(root,Vector3(side*.68,2.7,.7),.38,.05,Color("223344"))
		5:ball(root,Vector3(.75,.95,.8),.35,Color.WHITE)
		6:ball(root,Vector3(.75,.95,.8),.29,Color("e69842"))
		7:
			for side in [-1,1]:cylinder(root,Vector3(side*.7,.9,1.3),.18,.65,Color("9da6ad"))
		8:sign3d(root,"π",Vector3(0,1.5,1.1),38,Color("f0cef7"))
		9:ball(root,Vector3(.72,1.3,.2),.29,Color("6c5090"))
		10:
			cylinder(root,Vector3(0,2.6,.8),.05,1.1,Color("3cccea"))
			ball(root,Vector3(0,3.2,.8),.19,Color("55e7ff"))
		11:
			cylinder(root,Vector3(.8,1.0,.65),.25,.6,Color("dbab41"))
			ball(root,Vector3(.8,1.3,.65),.26,Color.WHITE,Vector3(1,.3,1))
		12:
			for j in 3:cube(root,Vector3(-.55+j*.5,.95,1),Vector3(.45,.32,.4),Color("b66e49"))
		13:
			var bear=Node3D.new();root.add_child(bear);bear.name="Bear"
			ball(bear,Vector3(.9,1.25,.65),.62,Color("7d5638"),Vector3(.8,1,.8))
			ball(bear,Vector3(.9,1.85,.45),.41,Color("9b724f"))
			for side in [-1,1]:ball(bear,Vector3(.9+side*.29,2.1,.45),.16,Color("7d5638"))
	var shield_node: MeshInstance3D = ball(root,Vector3(0,0.95,0),1.6,Color(0.15,0.7,1.0,0.22),Vector3(1,0.85,1))
	shield_node.name = "Shield"
	shield_node.visible = false
	return root

func _spawn_boxes() -> void:
	if race_mode=="time_trial" or tutorial_mode:return
	for i: int in range(7):
		var s: Dictionary = sample_road(38.0+float(i)*total_length/7.0)
		var n: Vector2 = Vector2(-s.dir.y,s.dir.x)
		for lane: float in [-4.0,0.0,4.0]:
			var pos: Vector2 = s.pos+n*lane
			var root: Node3D = Node3D.new()
			world.add_child(root)
			root.position = Vector3(pos.x,1.1,pos.y)
			cube(root,Vector3.ZERO,Vector3(1.35,1.35,1.35),Color(0.10,0.66,1.0,0.75),true)
			for side: int in range(4):
				var label: Label3D = sign3d(root,"?",Vector3.ZERO,64,Color.WHITE,float(side)*PI/2.0)
				label.position = Vector3(sin(float(side)*PI/2.0)*0.69,0,cos(float(side)*PI/2.0)*0.69)
			boxes.append({"pos":pos,"node":root,"cooldown":0.0})

func _process(dt: float) -> void:
	if not active:
		return
	_update_engine_audio()
	if not paused:
		clock_time += dt
		_update_cameras(dt)
		for b: Dictionary in boxes:
			if float(b.cooldown) <= 0:
				b.node.rotation.y += dt*0.85
				b.node.position.y = 1.25+sin(clock_time*2.5+b.pos.x)*0.19
	if is_instance_valid(hud):
		hud.queue_redraw()

func _physics_process(dt: float) -> void:
	if not active or paused:
		return
	if phase == "countdown":
		countdown -= dt
		var tick: int = int(ceil(countdown))
		if tick != countdown_tick:
			countdown_tick = tick
			_play_sound("select" if tick>0 else "confirm")
		if countdown <= 0:
			phase = "race"
			for r: Dictionary in racers:
				r.notice = "VAI!"
				r.notice_time = 1.2
		return
	if phase != "race":
		return
	if tutorial_mode:
		var player=racers[0]
		if tutorial_step==0:
			notice(player,"A1 ACELERA · A2 FREIA · ESQUERDA/DIREITA",.2)
			if player.speed>22:tutorial_step=1
		elif tutorial_step==1:
			notice(player,"SEGURE A3 E VIRE. SOLTE PARA MINITURBO",.2)
			if player.boost>0:tutorial_step=2;player.item=7
		elif tutorial_step==2:
			notice(player,"D USA ITEM · BAIXO + D LANÇA PARA TRÁS",.2)
			if player.item==0:tutorial_step=3
		elif tutorial_step==3:
			notice(player,"TUTORIAL CONCLUÍDO · ESC PARA VOLTAR",.2)
			if is_instance_valid(app):app.unlock("PRIMEIROS PASSOS")
	elapsed += dt
	for r: Dictionary in racers:
		var controls: Dictionary = _human_input(int(r.id)) if bool(r.human) and float(r.finish_time)<0 else _bot_input(r,dt)
		step_racer(r,controls,dt)
	_check_collisions()
	_update_items(dt)
	_update_effects(dt)
	_update_ranking()
	var humans_finished: bool = true
	for i: int in range(player_count):
		if float(racers[i].finish_time) < 0:
			humans_finished = false
	if humans_finished:
		finish_delay += dt
		if finish_delay > 2.0:
			finish_race()

func _key(player: int, action: String, fallback: int) -> int:
	if is_instance_valid(app):
		var manager: Variant = app.get("input")
		if manager != null and manager.has_method("get_binding"):
			var candidate: int = int(manager.get_binding(player,action))
			if candidate > 0:
				return candidate
	return fallback

func control_hint(player: int) -> String:
	if is_instance_valid(app):return app.input.display_label(player,"attack",true)+" ACELERA  ·  "+app.input.display_label(player,"heavy",true)+" FREIA/RÉ  ·  "+app.input.display_label(player,"kick",true)+" DRIFT  ·  "+app.input.display_label(player,"block",true)+" ITEM"
	return "A1 ACELERA · A2 FREIA · A3 DRIFT · D ITEM"

func _human_input(player: int) -> Dictionary:
	var commands:Dictionary=app.input.sample_kart(player) if is_instance_valid(app) else {}
	var steer=float(commands.get("right",false))-float(commands.get("left",false))
	var throttle=float(bool(commands.get("attack",false)) or auto_accelerate)-float(commands.get("heavy",false))
	if commands.get("heavy",false):throttle=-1.0
	var item=bool(commands.get("block",false))
	var edge=item and not bool(previous_keys[player].get("item",false))
	previous_keys[player]["item"]=item
	return {"throttle":throttle,"steer":steer,"drift":commands.get("kick",false),"item":edge,"back":commands.get("down",false)}

func _bot_input(r: Dictionary,dt: float) -> Dictionary:
	var nearest: Dictionary = nearest_road(r.pos)
	var target: Dictionary = sample_road(float(nearest.distance)+9.0+absf(float(r.speed))*0.25)
	var normal: Vector2 = Vector2(-target.dir.y,target.dir.x)
	var lane: float = sin(float(r.id)*2.1)*1.8
	var toward: Vector2 = Vector2(target.pos)+normal*lane-Vector2(r.pos)
	var angle: float = wrapf(toward.angle()-float(r.heading),-PI,PI)
	var steer: float = clampf(angle*2.6,-1,1)
	var safe_speed: float = 22.0+difficulty*1.8-absf(angle)*8.0+float(int(r.id)%3)
	var throttle: float = 1.0 if float(r.speed)<safe_speed else 0.1
	r.bot_timer = float(r.bot_timer)-dt
	var use_item: bool = int(r.item)>0 and float(r.bot_timer)<=0
	if use_item:
		r.bot_timer = rng.randf_range(2.0,5.0)
	return {"throttle":throttle,"steer":steer,"drift":false,"item":use_item}

func step_racer(r: Dictionary, controls: Dictionary, dt: float) -> void:
	for timer: String in ["boost","shield","stun","hit_flash","notice_time","recovery","invincible","jump","signature"]:
		r[timer] = maxf(0,float(r[timer])-dt)
	var throttle: float = float(controls.get("throttle",0.0))
	var steer: float = float(controls.get("steer",0.0))
	var drift: bool = bool(controls.get("drift",false)) and absf(float(r.speed))>10.0 and absf(steer)>0.15
	var nearest: Dictionary = nearest_road(r.pos)
	r.offroad = float(nearest.offset)>ROAD_HALF+0.7
	r.wrongway = Vector2(cos(float(r.heading)),sin(float(r.heading))).dot(nearest.dir)<-0.3 and float(r.speed)>3
	var max_speed: float = float(r.max_speed)
	if bool(r.offroad):
		max_speed *= 0.42
	if float(r.boost)>0:
		max_speed *= 1.42
	if float(r.stun)>0:
		throttle = 0.0
		steer = 0.0
		max_speed = 3.0
	var acceleration: float = 14.0 if throttle>=0 else 24.0
	if throttle<0 and float(r.speed)<=0:
		acceleration = 7.0
	var speed: float = float(r.speed)+throttle*acceleration*dt
	if absf(throttle)<0.05:
		speed = move_toward(speed,0.0,3.8*dt)
	if speed>max_speed:
		speed = move_toward(speed,max_speed,22.0*dt)
	speed = clampf(speed,-9.0,45.0)
	if float(r.boost)>0 and throttle>=0:
		speed = move_toward(speed,max_speed,22.0*dt)
	var steering_power: float = 1.8*(0.35+0.65*clampf(absf(speed)/12.0,0,1))
	if drift:
		steering_power *= 1.25
		r.drift = minf(2.5,float(r.drift)+dt)
	elif bool(r.drifting):
		if float(r.drift)>0.70:
			r.boost = maxf(float(r.boost),0.65+float(r.drift)*0.48)
			notice(r,"MINITURBO!",1.1)
		r.drift = 0.0
	r.drifting = drift
	r.heading = float(r.heading)+steer*steering_power*dt*signf(speed)
	r.steer = lerpf(float(r.steer),steer,dt*8.0)
	var direction: Vector2 = Vector2(cos(float(r.heading)),sin(float(r.heading)))
	var desired_velocity: Vector2 = direction*speed
	var grip: float = 3.0 if drift else 10.0
	r.velocity = Vector2(r.velocity).lerp(desired_velocity,1.0-exp(-grip*dt))
	r.previous_pos = r.pos
	r.pos = Vector2(r.pos)+Vector2(r.velocity)*dt
	r.speed = speed
	if float(nearest.offset)>ROAD_HALF+8:
		var push: Vector2 = (Vector2(nearest.pos)-Vector2(r.pos)).normalized()
		r.pos = Vector2(r.pos)+push*minf(4.0,float(nearest.offset)-ROAD_HALF-8)
		r.speed = float(r.speed)*0.80
	if float(nearest.offset)>ROAD_HALF+20 and float(r.recovery)<=0:
		respawn_racer(r)
	if track_id==3 and r.jump<=0 and absf(float(r.speed))>15 and fposmod(float(nearest.distance),total_length/3)<2.5:r.jump=1.0
	check_gate(r)
	if bool(controls.get("item",false)) and int(r.item)>0 and float(r.finish_time)<0:
		r.launch_back=bool(controls.get("back",false))
		use_item(r)
	if is_instance_valid(world):
		_sync_kart(r,dt)
		r.trail_timer = float(r.trail_timer)-dt
		if (drift or float(r.boost)>0 or bool(r.offroad)) and float(r.trail_timer)<=0 and absf(speed)>8:
			r.trail_timer = 0.09
			var trail_color: Color = Color("4dddff") if float(r.boost)>0 else (Color("ffc465") if drift else Color("b3ac82"))
			burst(Vector2(r.pos)-direction*1.4,trail_color,2,0.38)

func check_gate(r: Dictionary) -> void:
	if float(r.finish_time)>=0:
		return
	var gate_index: int = int(r.next_gate)
	var gate: Dictionary = checkpoints[gate_index]
	var center: Vector2 = gate.pos
	var direction: Vector2 = gate.dir
	var old_side: float = (Vector2(r.previous_pos)-center).dot(direction)
	var new_side: float = (Vector2(r.pos)-center).dot(direction)
	var delta: Vector2 = Vector2(r.pos)-Vector2(r.previous_pos)
	# Only a forward crossing of the next finite gate counts. Every gate is required.
	if old_side<=0 and new_side>0 and delta.dot(direction)>0:
		var fraction: float = clampf(-old_side/maxf(0.0001,new_side-old_side),0,1)
		var intersection: Vector2 = Vector2(r.previous_pos)+delta*fraction
		if intersection.distance_to(center)<=ROAD_HALF+2.0:
			r.gates = int(r.gates)+1
			r.next_gate = (gate_index+1)%GATES
			if gate_index==0:
				r.lap = int(r.lap)+1
				if int(r.lap)>LAPS:
					r.finish_time = elapsed
					notice(r,"CHEGADA!",5.0)
				else:
					notice(r,"ÚLTIMA VOLTA!" if int(r.lap)==LAPS else "VOLTA %d / %d" % [r.lap,LAPS],1.6)
	var previous_gate: Dictionary = checkpoints[posmod(int(r.next_gate)-1,GATES)]
	var fraction_progress: float = clampf((Vector2(r.pos)-Vector2(previous_gate.pos)).dot(previous_gate.dir)/(total_length/GATES),-0.99 if int(r.gates)==0 else 0.0,0.99)
	r.progress = float(r.gates)+fraction_progress

func respawn_racer(r: Dictionary) -> void:
	var gate: Dictionary = checkpoints[posmod(int(r.next_gate)-1,GATES)]
	r.pos = Vector2(gate.pos)+Vector2(gate.dir)*2.0
	r.previous_pos = r.pos
	r.heading = Vector2(gate.dir).angle()
	r.velocity = Vector2.ZERO
	r.speed = 0.0
	r.stun = 1.0
	r.recovery = 3.0
	notice(r,"DE VOLTA À PISTA",1.6)

func _sync_kart(r: Dictionary,dt: float) -> void:
	var root: Node3D = r.node
	root.position = Vector3(r.pos.x,sin(clampf(float(r.get("jump",0)),0,1)*PI)*3+0.07+sin(clock_time*15+float(r.id))*minf(absf(float(r.speed))*0.001,0.04),r.pos.y)
	root.rotation.y = -float(r.heading)-PI/2.0
	root.rotation.z = -float(r.steer)*minf(absf(float(r.speed))/30.0,1.0)*0.08
	if float(r.stun)>0:
		root.rotation.y += sin(float(r.stun)*15)*0.45
	root.get_node("Shield").visible = float(r.shield)>0
	if root.has_node("Bear"):root.get_node("Bear").rotation.z=sin(r.signature*15)*.45 if r.signature>0 else 0.0

func _check_collisions() -> void:
	for a: int in range(racers.size()):
		for b: int in range(a+1,racers.size()):
			var one: Dictionary = racers[a]
			var two: Dictionary = racers[b]
			var delta: Vector2 = Vector2(two.pos)-Vector2(one.pos)
			var distance: float = delta.length()
			if distance<1.90 and distance>0.001:
				var normal: Vector2 = delta/distance
				var overlap: float = (1.90-distance)*0.5
				one.pos = Vector2(one.pos)-normal*overlap
				two.pos = Vector2(two.pos)+normal*overlap
				var impact: float = (Vector2(one.velocity)-Vector2(two.velocity)).dot(normal)
				if impact>1.0:
					one.velocity = Vector2(one.velocity)-normal*impact*0.45
					two.velocity = Vector2(two.velocity)+normal*impact*0.45
					one.speed = float(one.speed)*0.94
					two.speed = float(two.speed)*0.97

func _update_ranking() -> void:
	var order: Array[Dictionary] = racers.duplicate()
	order.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if float(a.finish_time)>=0 and float(b.finish_time)>=0:
			return float(a.finish_time)<float(b.finish_time)
		if float(a.finish_time)>=0:
			return true
		if float(b.finish_time)>=0:
			return false
		return float(a.progress)>float(b.progress))
	for i: int in range(order.size()):
		order[i].rank = i+1

func roll_item(rank_value: int) -> int:
	var pool: Array = [1,3,5,7,7] if rank_value<=2 else [1,2,2,3,4,7,7]
	return pool[rng.randi_range(0,pool.size()-1)]

func notice(r: Dictionary, message: String, seconds: float = 1.5) -> void:
	r.notice = message
	r.notice_time = seconds

func use_item(r: Dictionary) -> void:
	var item: int = int(r.item)
	r.item = 0
	var dir: Vector2 = Vector2(cos(float(r.heading)),sin(float(r.heading)))
	if r.get("launch_back",false):dir=-dir
	match item:
		7:
			signature_item(r,dir)
		1:
			var node: Node3D = Node3D.new()
			world.add_child(node)
			ball(node,Vector3.ZERO,0.55,Color("58dfff"))
			var tail: MeshInstance3D = ball(node,Vector3(0,0,0.6),0.5,Color(0.16,0.5,1,0.45),Vector3(0.8,0.8,2.4))
			tail.material_override = material(Color(0.16,0.7,1,0.7),true)
			projectiles.append({"owner":int(r.id),"pos":Vector2(r.pos)+dir*2,"dir":dir,"speed":49.0,"life":5.0,"node":node})
			notice(r,"PULSO LANÇADO!",1.0)
		2:
			r.boost = 3.0
			notice(r,"TURBO UFN!",1.5)
		3:
			r.shield = 7.0
			notice(r,"ESCUDO ATIVO",1.3)
		4:
			for other: Dictionary in racers:
				if other.id!=r.id and Vector2(r.pos).distance_to(other.pos)<22:
					hit_racer(other,1.55)
			burst(r.pos,Color("c2adff"),28,0.9,14)
			notice(r,"CHOQUE EM ÁREA!",1.3)
		5,6:
			var pos: Vector2 = Vector2(r.pos)+dir*(-2.6 if item==5 else 5.0)
			var node: Node3D = Node3D.new()
			world.add_child(node)
			node.position = Vector3(pos.x,0.05,pos.y)
			if item==5:
				ball(node,Vector3.ZERO,1.4,Color("172a37"),Vector3(1,0.025,1))
				ball(node,Vector3(0,0.04,0),0.8,Color("636d88"),Vector3(1,0.025,1))
			else:
				ball(node,Vector3(0,0.6,0),0.9,Color("a98458"),Vector3(0.80,0.68,1.15))
				ball(node,Vector3(0,0.86,-0.72),0.45,Color("b59065"),Vector3(0.75,0.80,1.1))
				for side: float in [-1.0,1.0]:
					ball(node,Vector3(side*0.23,1.18,-0.67),0.11,Color("816241"))
					ball(node,Vector3(side*0.30,0.99,-0.91),0.055,Color("162129"))
				for xx: float in [-0.5,0.5]:
					for zz: float in [-0.5,0.5]:
						cube(node,Vector3(xx,0.22,zz),Vector3(0.23,0.44,0.24),Color("856847"))
				node.rotation.y = -float(r.heading)-PI/2.0
			hazards.append({"owner":int(r.id),"pos":pos,"life":16.0,"node":node,"kind":item,"grace":1.2})
			notice(r,"ÓLEO NA PISTA" if item==5 else "CAPIVARA SOLTA!",1.4)
	_play_sound("confirm")

func hit_racer(r: Dictionary, duration: float) -> void:
	if float(r.get("invincible",0))>0 or float(r.finish_time)>=0:return
	r.invincible=2.0
	if float(r.shield)>0:
		r.shield = 0.0
		notice(r,"ESCUDO ABSORVEU!",1.5)
		if is_instance_valid(world):
			burst(r.pos,Color("75eaff"),12,0.7)
		return
	r.stun = maxf(float(r.stun),duration)
	r.speed = float(r.speed)*0.30
	r.velocity = Vector2(r.velocity)*0.35
	r.hit_flash = 0.4
	if is_instance_valid(world):
		burst(r.pos,Color("fff2a3"),15,0.8)
	notice(r,"ATINGIDO!",0.85)
	_play_sound("hit")

func _update_items(dt: float) -> void:
	for b: Dictionary in boxes:
		b.cooldown = maxf(0,float(b.cooldown)-dt)
		b.node.visible = true
		b.node.scale=Vector3.ONE*(1.0 if b.cooldown<=0 else .2+.2*(1.0-b.cooldown/6.0))
		if float(b.cooldown)>0:
			continue
		for r: Dictionary in racers:
			if int(r.item)==0 and float(r.finish_time)<0 and Vector2(r.pos).distance_to(b.pos)<2.1:
				r.item = roll_item(int(r.rank))
				b.cooldown = 6.0
				b.node.visible = false
				burst(b.pos,Color("65ddff"),8,0.6)
				notice(r,item_name(r),1.1)
				if r.human:
					_play_sound("select")
				break
	for i: int in range(projectiles.size()-1,-1,-1):
		var p: Dictionary = projectiles[i]
		p.life = float(p.life)-dt
		var target: Dictionary = {}
		var best: float = 45.0
		for r: Dictionary in racers:
			if int(r.id)==int(p.owner):
				continue
			var delta: Vector2 = Vector2(r.pos)-Vector2(p.pos)
			if delta.length()<best and delta.normalized().dot(p.dir)>0.25:
				target = r
				best = delta.length()
		if not target.is_empty() and bool(p.get("homing",false)):
			if target.human and best<18:notice(target,"PROJECTIL SE APROXIMANDO!",.3)
			p.dir = Vector2(p.dir).lerp((Vector2(target.pos)-Vector2(p.pos)).normalized(),dt*2.6).normalized()
		p["age"]=float(p.get("age",0))+dt
		if p.get("curve",false):p.dir=Vector2(p.dir).rotated(dt*.23)
		p.pos = Vector2(p.pos)+Vector2(p.dir)*float(p.speed)*dt
		p.node.position = Vector3(p.pos.x,0.95+absf(sin(float(p.age)*4))*float(p.get("bounce",0)),p.pos.y)
		p.node.rotation.y = -Vector2(p.dir).angle()-PI/2.0
		for r: Dictionary in racers:
			if int(r.id)!=int(p.owner) and Vector2(r.pos).distance_to(p.pos)<1.65:
				hit_racer(r,float(p.get("stun",1.2)))
				p.life = 0.0
				break
		if float(p.life)<=0:
			p.node.queue_free()
			projectiles.remove_at(i)
	for i: int in range(hazards.size()-1,-1,-1):
		var h: Dictionary = hazards[i]
		h.life = float(h.life)-dt
		h.grace = maxf(0,float(h.grace)-dt)
		for r: Dictionary in racers:
			if int(r.id)==int(h.owner) and float(h.grace)>0:
				continue
			if Vector2(r.pos).distance_to(h.pos)<1.75:
				hit_racer(r,1.25 if int(h.kind)==5 else 1.6)
				h.life = 0.0
				break
		if float(h.life)<=0:
			h.node.queue_free()
			hazards.remove_at(i)

func burst(pos: Vector2,color: Color,count: int,life: float,spread: float = 3.5) -> void:
	if not is_instance_valid(world):
		return
	for i: int in range(count):
		if effects.size()>130:
			break
		var node: MeshInstance3D = cube(world,Vector3(pos.x,0.45,pos.y),Vector3.ONE*rng.randf_range(0.10,0.24),color,true)
		var theta: float = rng.randf()*TAU
		var velocity: Vector3 = Vector3(cos(theta)*spread,rng.randf_range(0.5,3),sin(theta)*spread)
		effects.append({"node":node,"velocity":velocity,"life":life,"total":life})

func _update_effects(dt: float) -> void:
	for i: int in range(effects.size()-1,-1,-1):
		var e: Dictionary = effects[i]
		e.life = float(e.life)-dt
		e.node.position += Vector3(e.velocity)*dt
		e.velocity = Vector3(e.velocity)+Vector3.DOWN*3.0*dt
		e.node.scale = Vector3.ONE*maxf(0.01,float(e.life)/float(e.total))
		if float(e.life)<=0:
			e.node.queue_free()
			effects.remove_at(i)

func _update_cameras(dt: float, snap: bool = false) -> void:
	for i: int in range(mini(cameras.size(),racers.size())):
		var r: Dictionary = racers[i]
		var dir: Vector2 = Vector2(cos(float(r.heading)),sin(float(r.heading)))
		var center: Vector3 = Vector3(r.pos.x,0,r.pos.y)
		var follow: float = 7.4+clampf(absf(float(r.speed))/32.0,0,1)*1.1
		var desired: Vector3 = center-Vector3(dir.x,0,dir.y)*follow+Vector3.UP*4.4
		cameras[i].position = desired if snap else cameras[i].position.lerp(desired,1.0-exp(-7.0*dt))
		var target: Vector3 = center+Vector3(dir.x,0,dir.y)*5.5+Vector3.UP*0.6
		cameras[i].look_at(target,Vector3.UP)
		cameras[i].fov = lerpf(cameras[i].fov,(76.0 if player_count==2 else 69.0)+(6.0 if float(r.boost)>0 else 0.0),minf(1,dt*3))

func _play_sound(sound: String) -> void:
	if not is_instance_valid(app):
		return
	var audio: Variant = app.get("sound")
	if audio != null and audio.has_method("play"):
		audio.play(sound)

func _start_engines() -> void:
	if DisplayServer.get_name()=="headless":
		return
	engine_phases = [0.0,0.0]
	for i: int in range(player_count):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		var generator: AudioStreamGenerator = AudioStreamGenerator.new()
		generator.mix_rate = 22050.0
		generator.buffer_length = 0.12
		voice.stream = generator
		voice.volume_db = -23.0
		voice.bus = "UFNSFX" if AudioServer.get_bus_index("UFNSFX")>=0 else "Master"
		add_child(voice)
		voice.play()
		engine_voices.append(voice)

func _update_engine_audio() -> void:
	for i: int in range(engine_voices.size()):
		var voice: AudioStreamPlayer = engine_voices[i]
		var playback: AudioStreamGeneratorPlayback = voice.get_stream_playback()
		if playback==null:
			continue
		var r: Dictionary = racers[i]
		var frequency: float = 58.0+absf(float(r.speed))*7.0+(25.0 if float(r.boost)>0 else 0.0)
		var frames: int = mini(playback.get_frames_available(),4096)
		for sample_index: int in range(frames):
			engine_phases[i] = fposmod(engine_phases[i]+frequency/22050.0,1.0)
			var angle: float = engine_phases[i]*TAU
			var wave: float = (sin(angle)*0.55+sin(angle*2.0)*0.22+sin(angle*3.0)*0.12)*0.7
			if paused or phase=="results":
				wave = 0.0
			playback.push_frame(Vector2(wave*(1.0 if i==0 else 0.7),wave*(0.7 if i==0 else 1.0)))

func finish_race() -> void:
	if phase=="results":
		return
	phase = "results"
	_play_sound("confirm")
	_update_ranking()
	ordered_results.clear()
	var sorted: Array[Dictionary] = racers.duplicate()
	sorted.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return int(a.rank)<int(b.rank))
	for r: Dictionary in sorted:
		if race_mode=="championship":championship_points[str(r.id)]=int(championship_points.get(str(r.id),0))+[15,12,10,8,6,4,2,1][int(r.rank)-1]
		ordered_results.append({"rank":r.rank,"name":r.name,"player":int(r.id)+1 if r.human else 0,"time":r.finish_time,"character":r.character,"points":int(championship_points.get(str(r.id),0))})
	hud.refresh_menu()
	race_finished.emit(ordered_results)

func portrait(index: int, skin: int = 0) -> Texture2D:
	var id: String = "diogo_alt" if index==3 and skin>0 else IDS[posmod(index,IDS.size())]
	if texture_cache.has(id):
		return texture_cache[id]
	var path: String = "res://assets/sprites/"+id+"/portrait.png"
	if ResourceLoader.exists(path):
		var texture: Texture2D = load(path)
		texture_cache[id] = texture
		return texture
	return null

func item_name(r: Dictionary) -> String:
	return SIGNATURES[int(r.character)] if int(r.item)==7 else ITEM_NAMES[int(r.item)]

func next_race() -> void:
	if race_mode=="championship" and track_id<3:start(choices_saved,skins_saved,track_id+1,player_count)

func signature_item(r: Dictionary, direction: Vector2) -> void:
	var id=int(r.character)
	r.signature=1.0
	notice(r,SIGNATURES[id]+"!",1.5)
	if id in [1,13]:
		var radius=9.0 if id==1 else 5.0
		for other in racers:
			if other.id!=r.id and Vector2(other.pos).distance_to(r.pos)<radius:hit_racer(other,.65 if id==1 else 1.1)
		burst(r.pos,COLORS[id],18,.65,radius)
	elif id==7:r.boost=3.3
	elif id==9:r.shield=7.0
	elif id in [3,11,12]:
		var pos=Vector2(r.pos)-direction*3
		var node=Node3D.new();world.add_child(node);node.position=Vector3(pos.x,.1,pos.y)
		if id==12:
			for n in 3:
				for row in 2:cube(node,Vector3((n-1)*.7,row*.45,0),Vector3(.67,.43,.5),Color("bc704a"))
		elif id==3:
			for n in 5:
				var root=cylinder(node,Vector3((n-2)*.5,.4,0),.15,.8,Color("43865a"));root.rotation.z=(n-2)*.35
		else:
			for n in 6:ball(node,Vector3(sin(n*1.2),.12,cos(n*1.2)),.65,Color("e8e8cb"),Vector3(1,.25,1))
		hazards.append({"owner":r.id,"pos":pos,"life":9.0,"node":node,"kind":5,"grace":1.2})
	else:
		var node=Node3D.new();world.add_child(node)
		if id==0:
			cube(node,Vector3.ZERO,Vector3(1.5,.16,.16),Color("bacbda"))
			for side in [-1,1]:ball(node,Vector3(side*.68,0,0),.4,Color("496075"))
		elif id==2:
			ball(node,Vector3.ZERO,.55,Color("a98558"),Vector3(.8,.7,1.4));ball(node,Vector3(0,.3,-.6),.35,Color("bf9a70"))
		elif id==10:cube(node,Vector3.ZERO,Vector3(.85,.65,.65),Color("3ce6ed"),true)
		elif id==8:
			var poly=cube(node,Vector3.ZERO,Vector3(.7,.7,.7),Color("c79add"));poly.rotation=Vector3(.6,.4,.7)
		else:ball(node,Vector3.ZERO,.45,Color.WHITE if id==5 else COLORS[id])
		projectiles.append({"owner":r.id,"pos":Vector2(r.pos)+direction*2.5,"dir":direction,"speed":43.0 if id==2 else 49.0,"life":4.0,"node":node,"homing":id in [2,4,10],"curve":id==5,"bounce":2.0 if id in [0,6,8] else 0.0,"stun":1.15})

# Static campus meshes share material batches; racing vehicles remain independent.
func _batch_static_geometry() -> void:
	var groups:Dictionary={}
	var pending:Array=[world]
	var meshes:Array=[]
	while not pending.is_empty():
		var node=pending.pop_back()
		pending.append_array(node.get_children())
		if node is MeshInstance3D and node.mesh!=null and node.material_override!=null:meshes.append(node)
	for node in meshes:
		var key=node.material_override.get_instance_id()
		if not groups.has(key):
			var builder=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			builder.set_material(node.material_override);groups[key]=builder
		groups[key].append_from(node.mesh,0,world.global_transform.affine_inverse()*node.global_transform)
		node.visible=false;node.queue_free()
	for key in groups:
		var merged=MeshInstance3D.new();merged.mesh=groups[key].commit();world.add_child(merged)
