extends Node2D
## Original procedural stage art and generated HD pixel-art animation presentation.
## Combat state is read-only here; visuals never change simulation or collision data.

const FIGHTER = preload("res://scripts/fighter.gd")
const NAMES = ["arthur", "vitorbem", "maria", "diogo", "mirkos", "felipe", "murilo", "gabriel", "fabiano", "vitormal", "lorenzo", "leonardo", "cristian", "fernando", "andre", "kelvin"]
const COLORS = [Color("ffc365"),Color("8ec6ff"),Color("75b8ff"),Color("8be38e"),Color("62e8f1"),Color("ff645d"),Color("ff9ad0"),Color("ffde72"),Color("c5a4ff"),Color("e394ff"),Color("70dcff"),Color("f2bf6d"),Color("f6ad75"),Color("cf9a6d"),Color("bee17c"),Color("d5a1ff")]
const STAGE_COLORS = [Color("50e1df"),Color("de69c7"),Color("a899f5"),Color("9b6fec"),Color("b0e3f2"),Color("e5ba65"),Color("79b2ef"),Color("ec885b"),Color("76d6c1"),Color("d294ed")]
const BEAR_REGIONS = [Rect2(76,18,265,401),Rect2(521,25,301,396),Rect2(968,29,313,388),Rect2(1340,66,433,355),Rect2(48,426,322,436),Rect2(490,546,427,285),Rect2(929,470,395,386),Rect2(1382,501,352,343)]
const BEAR_FOOT_X = [210.0,666.0,1093.0,1488.0,224.0,674.0,1116.0,1574.0]
var bear_texture: Texture2D
var particle_intensity: float = .7
var combat = null
var stage_id: int = 0
var time: float = 0.0
var alternate: Array = [false, false]
var debug: bool = false
var shake_strength: float = 0.6
var flash_strength: float = 0.5
var textures: Array = []
var sprite_data: Dictionary = {}
var sprite_atlas: Dictionary = {}
var portrait_art: Dictionary = {}
var backgrounds: Array = []
const STAGE_FILES = ["patio","container","rua","entrada","quadra","laboratorio","corredor","vilabelga"]
var effects: Array = []
var pulse: float = 0.0
var shake: float = 0.0
var camera_offset: float = 0.0
var paused: bool = false
var cinematic: float = 0.0
var cinematic_id: int = 0
var super_position: Vector2 = Vector2(640,400)
var _shake_offset: Vector2 = Vector2.ZERO
var _glow_texture: GradientTexture2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	load_art()

func load_art() -> void:
	bear_texture=load("res://assets/sprites/urso.png")
	textures.clear()
	for n in NAMES + ["diogo_alt"]:
		var base = "res://assets/sprites/"+n+"/"
		if FileAccess.file_exists(base+"frames.json"):
			sprite_data[n] = JSON.parse_string(FileAccess.get_file_as_string(base+"frames.json"))
			sprite_atlas[n] = load(base+"atlas.png")
			portrait_art[n] = load(base+"portrait.png")
	for n in NAMES: textures.append(sprite_atlas.get(n))
	backgrounds.clear()
	for n in STAGE_FILES:
		var path = "res://assets/arenas/"+n+".png"
		backgrounds.append(load(path) if ResourceLoader.exists(path) else null)

func _process(delta: float) -> void:
	if not paused:
		time += delta
		pulse = maxf(0.0, pulse - delta * 2.3)
		shake = maxf(0.0, shake - delta * 36.0)
		cinematic = maxf(0.0, cinematic - delta)
		for e in effects:
			e.age += delta
		effects = effects.filter(func(e): return e.age < 0.75)
	queue_redraw()

func ingest_events(events: Array) -> void:
	for event in events:
		var e: Dictionary = event.duplicate()
		if combat != null:
			var player = clampi(int(e.get("player",0)),0,combat.fighters.size()-1)
			e.id = combat.fighters[player].id
		e.age = 0.0
		var kind: String = str(e.get("type", e.get("kind", "hit"))).to_lower()
		if kind in ["hit", "counter", "guard_break", "super_hit", "ko", "block", "perfect_block", "parry", "clash", "projectile_clash", "throw", "super"]:
			if effects.size() >= 64:
				effects.pop_front()
			effects.append(e)
		if kind in ["hit", "counter", "guard_break", "super_hit", "ko", "super"]:
			pulse = minf(1.0, pulse + 0.45)
			shake = maxf(shake, 8.0 if kind in ["guard_break", "ko", "super"] else 3.0)
		if kind == "super":
			cinematic = 1.15
			cinematic_id = int(e.get("id", e.get("character",0)))
			super_position = Vector2(float(e.get("x",640)),float(e.get("y",450)))

func _draw() -> void:
	_shake_offset = Vector2(sin(time * 101.0), cos(time * 123.0)) * shake * shake_strength
	draw_set_transform(_shake_offset)
	draw_stage(stage_id, time, pulse)
	if combat != null:
		var sequence = combat.get("cinematic")
		if sequence is Dictionary and bool(sequence.get("active",false)):
			_draw_super_sequence(sequence,time)
			draw_set_transform(Vector2.ZERO)
			return
	if combat != null:
		for p in combat.projectiles:
			if str(p.get("kind", "projectile")) in ["trap", "barrier"]:
				draw_projectile(p,time)
		for i in range(combat.fighters.size()):
			draw_fighter(combat.fighters[i], time, alternate[i] if i < alternate.size() else false)
		for p in combat.projectiles:
			if str(p.get("kind", "projectile")) not in ["trap", "barrier"]:
				draw_projectile(p,time)
		if debug:
			for f in combat.fighters:
				draw_rect(FIGHTER.hurtbox(f),Color(0.2,1,0.7,0.25))
				draw_rect(FIGHTER.hurtbox(f),Color(0.2,1,0.7,0.9),false,2)
				draw_rect(FIGHTER.pushbox(f),Color(0.1,0.5,1,0.7),false,2)
				if combat.has_method("hitbox") and not f.get("move",{}).is_empty():
					draw_rect(combat.hitbox(f),Color(1,0.2,0.3,0.35))
	for e in effects:
		draw_effect(e, float(e.age))
	draw_set_transform(Vector2.ZERO)
	if cinematic > 0.0:
		var c = COLORS[clampi(cinematic_id,0,NAMES.size()-1)]
		var a = minf(1.0, cinematic * 3.0)
		draw_rect(Rect2(0,0,1280,38*a),Color(0.01,0.02,0.04,0.95))
		draw_rect(Rect2(0,720-38*a,1280,38*a),Color(0.01,0.02,0.04,0.95))
		for i in range(10):
			var y = 90.0 + i * 58.0
			draw_line(Vector2(fmod(time*1700+i*138.0,1500)-200,y),Vector2(fmod(time*1700+i*138.0,1500)+160,y),Color(c,0.13*a),2)

func _gradient(rect: Rect2, top: Color, bottom: Color, steps: int = 40) -> void:
	for i in range(steps):
		var y = rect.position.y + rect.size.y * float(i) / steps
		draw_rect(Rect2(rect.position.x,y,rect.size.x,rect.size.y/steps+1),top.lerp(bottom,float(i)/steps))

func _glow(center: Vector2, radius: float, color: Color, strength: float = 1.0) -> void:
	if _glow_texture == null:
		var gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0,0.2,0.5,1.0])
		gradient.colors = PackedColorArray([Color(1,1,1,1),Color(1,1,1,.62),Color(1,1,1,.17),Color(1,1,1,0)])
		_glow_texture = GradientTexture2D.new()
		_glow_texture.gradient = gradient
		_glow_texture.width = 256
		_glow_texture.height = 256
		_glow_texture.fill = GradientTexture2D.FILL_RADIAL
		_glow_texture.fill_from = Vector2(.5,.5)
		_glow_texture.fill_to = Vector2(1,.5)
	draw_texture_rect(_glow_texture,Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2),false,Color(color,.55*strength))

func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points),color)

func _ellipse(center: Vector2, radius: Vector2, color: Color, filled: bool = true, width: float = 1.0) -> void:
	var points = PackedVector2Array()
	for i in range(49):
		var a = TAU * i / 48.0
		points.append(center+Vector2(cos(a)*radius.x,sin(a)*radius.y))
	if filled:
		draw_colored_polygon(points,color)
	else:
		draw_polyline(points,color,width,true)

func _ring(center: Vector2, radius: float, color: Color, rotation: float, sections: int = 12) -> void:
	for i in range(sections):
		var a = TAU*i/sections+rotation
		draw_arc(center,radius,a,a+TAU/sections*0.74,12,color,2.0,true)

func draw_stage(id: int, t: float, impact: float = 0.0) -> void:
	var idx = posmod(id,STAGE_FILES.size())
	if backgrounds.size() != STAGE_FILES.size(): load_art()
	if backgrounds[idx] != null:
		var tex: Texture2D = backgrounds[idx]
		# Keep the reference architecture visible, with the full fight plane below it.
		draw_texture_rect(tex,Rect2(0,0,1280,720),false)
		_gradient(Rect2(0,0,1280,200),Color(0.006,0.025,0.075,.57),Color(0.005,0.015,0.04,0),16)
		_gradient(Rect2(0,634,1280,86),Color(0,0,0,0),Color(0.002,.009,.024,.44),12)
	else:
		_gradient(Rect2(0,0,1280,720),Color("003d7c"),Color("071526"))
		_draw_campus(Color("99c8f5"),t,0)
		_draw_floor(Color("507ca3"),8,t)
	for i in range(int(20*particle_intensity)):
		var pt = Vector2(fmod(i*137.4+t*(5+i%4),1330)-25,170+fmod(i*79.6+t*9,385))
		draw_rect(Rect2(pt,Vector2(2,2)),Color(.73,.89,1,.09))
	if idx in [0,1,3]:
		for i in range(5):
			var pt=Vector2(fmod(i*285+t*19,1380)-40,250+fmod(i*97+t*22,260))
			draw_line(pt,pt+Vector2(4,2),Color(.62,.78,.38,.25),2)
	if impact>0: draw_rect(Rect2(0,0,1280,720),Color(.7,.89,1,impact*.025*flash_strength))

func _draw_architectural_detail(c: Color,id: int,t: float,p: float) -> void:
	# Shallow relief, perspective rails and reflected light ground every arena.
	if id in [0,3,7]:
		for i in range(20):
			var x=i*72.0-40+p*.3
			_poly([Vector2(x,500),Vector2(x+38,500),Vector2(x+26,478),Vector2(x+8,478)],Color("1a2934"))
			draw_line(Vector2(x+8,478),Vector2(x+26,478),Color(c,.28),1)
			draw_rect(Rect2(x+6,486,23,3),Color("080e17"))
		for x in [110,1138]:
			draw_rect(Rect2(x,373,38,85),Color("0c1520"))
			draw_rect(Rect2(x+5,380,28,29),Color(c,.09))
			for j in range(4):
				draw_rect(Rect2(x+8,415+j*8,17+(j%2)*7,2),Color(c,.24))
	elif id in [2,5]:
		for side in [-1,1]:
			for i in range(4):
				var x=640+side*(162+i*107)+p
				for j in range(3):
					var center=Vector2(x,306+j*48)
					draw_arc(center,9,0,TAU,4,Color(c,.10),1)
					draw_line(center-Vector2(0,12),center+Vector2(0,12),Color(c,.12),1)
		for i in range(28):
			var a=i*TAU/28.0
			var center=Vector2(640+p,248)
			draw_arc(center,177,a,a+.105,6,Color(c,.15),1,true)
	elif id in [1,4,6]:
		for i in range(5):
			var x=100+i*270+p
			draw_rect(Rect2(x,415,68,90),Color("0b121e"))
			draw_rect(Rect2(x+7,423,54,31),Color("17222e"))
			for j in range(6):
				draw_line(Vector2(x+11,428+j*4),Vector2(x+55,428+j*4),Color(c,.12),1)
			draw_circle(Vector2(x+54,472),2,Color(c,.45))
		for i in range(12):
			var x=i*118+p*.4
			draw_line(Vector2(x,504),Vector2(x,458),Color("263440"),3)
			draw_line(Vector2(x,466),Vector2(x+118,466),Color("263440"),2)
	elif id == 8:
		for x in [186,454,834,1102]:
			draw_rect(Rect2(x,460,78,8),Color("314047"))
			for side in [4,68]:
				draw_rect(Rect2(x+side,468,5,30),Color("222f37"))
		for i in range(34):
			var x=i*41.0+p
			draw_line(Vector2(x,502),Vector2(x,481),Color("2c383e"),1)
			draw_line(Vector2(x,489),Vector2(x+41,489),Color("24343c"),1)
	for i in range(3):
		var x=180+i*457+sin(t*.13+i)*20
		var pts=PackedVector2Array([Vector2(x-15,140),Vector2(x+15,140),Vector2(x+160,512),Vector2(x-140,512)])
		draw_polygon(pts,PackedColorArray([Color(c,.025),Color(c,.025),Color(c,0),Color(c,0)]))

func _draw_energy_core(c: Color,t: float,p: float,impact: float) -> void:
	var center = Vector2(640+p,280)
	_glow(center,310,c,1.1+impact)
	for i in range(4):
		_ring(center,100+i*40,Color(c,.11+i*.035),t*(.035 if i%2 else -.045),16)
	for side in [-1,1]:
		for i in range(3):
			var x = 640+side*(300+i*168)+p
			_poly([Vector2(x-26,132+i*34),Vector2(x+24,142+i*34),Vector2(x+36,487),Vector2(x-46,487)],Color("0d1b28"))
			draw_line(Vector2(x-22,148+i*34),Vector2(x-38,473),Color(c,.35),3)
	_poly([center+Vector2(0,-99),center+Vector2(75,0),center+Vector2(0,99),center+Vector2(-75,0)],Color("15293b"))
	_poly([center+Vector2(0,-78),center+Vector2(41,0),center+Vector2(0,78),center+Vector2(-41,0)],Color(c,.18+.04*sin(t)))
	draw_line(center+Vector2(0,-62),center+Vector2(0,62),Color(c,.6),2)

func _draw_city(c: Color,t: float,p: float,frozen: bool) -> void:
	var moon = Vector2(950+p*.3,137)
	_glow(moon,130,Color("a0caff"),.45)
	draw_circle(moon,47,Color("364955"))
	draw_circle(moon+Vector2(-15,-9),44,Color("101c2b"))
	for layer in range(2):
		for i in range(15):
			var x = i*98-43+p*(.3+layer*.6)
			var h = 105+fmod(i*89+layer*61,190)
			var y = 449-h+layer*30
			draw_rect(Rect2(x,y,74+layer*24,460-y),Color("0b1423") if layer==0 else Color("101f2d"))
			for row in range(int(h/23)):
				for col in range(4):
					if (row*3+col+i)%4!=0:
						draw_rect(Rect2(x+11+col*16,y+15+row*22,4,8),Color(c,.04+layer*.08))
			if layer==1:
				draw_rect(Rect2(x+5,y+2,68,3),Color(c,.4))
				if frozen:
					_poly([Vector2(x,y),Vector2(x+75,y),Vector2(x+50,y+16),Vector2(x+32,y+3),Vector2(x+18,y+21)],Color("628698"))
	if not frozen:
		for i in range(3):
			var x = 168+i*433+p
			draw_rect(Rect2(x,278+i%2*58,64,131),Color(c,.1))
			draw_rect(Rect2(x+6,284+i%2*58,3,92),Color(c,.6))
			for j in range(4):
				draw_line(Vector2(x+16,299+j*19+i%2*58),Vector2(x+46,299+j*19+i%2*58),Color(c,.25),3)
		var car_x = fmod(t*55,1500)-100
		draw_line(Vector2(car_x,236),Vector2(car_x+45,236),Color(c,.4),2)
	else:
		for i in range(9):
			var x = i*164-10+p
			_poly([Vector2(x,516),Vector2(x+25,370-fmod(i*45,95)),Vector2(x+46,410),Vector2(x+74,517)],Color("1a3548"))
			draw_line(Vector2(x+25,370-fmod(i*45,95)),Vector2(x+30,495),Color(c,.32),2)

func _draw_temple(c: Color,t: float,p: float,solar: bool) -> void:
	var center = Vector2(640+p,248)
	_glow(center,280,c,.9)
	if solar:
		draw_circle(center,92,Color(c,.09))
		for i in range(20):
			var a=TAU*i/20.0+t*.015
			draw_line(center+Vector2.from_angle(a)*110,center+Vector2.from_angle(a)*156,Color(c,.18),3)
	else:
		_ring(center,112,Color(c,.27),t*.09,12)
		_ring(center,145,Color(c,.13),-t*.06,12)
		for i in range(12):
			var a=TAU*i/12.0-PI*.5
			draw_line(center+Vector2.from_angle(a)*88,center+Vector2.from_angle(a)*99,Color(c,.5),2)
		draw_line(center,center+Vector2.from_angle(t*.11)*77,Color(c,.46),2)
		draw_line(center,center+Vector2.from_angle(t*.027)*54,Color(c,.46),3)
	for side in [-1,1]:
		for i in range(3):
			var x=640+side*(260+i*190)+p
			var h=278+i*42
			draw_rect(Rect2(x-26,480-h,52,h),Color("1c222c"))
			draw_rect(Rect2(x-33,470-h,66,20),Color("2b3037"))
			draw_rect(Rect2(x-38,470,76,25),Color("27313a"))
			draw_line(Vector2(x-15,494-h),Vector2(x-15,469),Color(c,.15),3)
			if solar:
				draw_rect(Rect2(x-3,484-h,6,60),Color(c,.25))
	for i in range(4):
		draw_rect(Rect2(355-i*36,453+i*14,570+i*72,16),Color(.045+i*.009,.055+i*.008,.073+i*.007))

func _draw_station(c: Color,t: float,p: float) -> void:
	var center=Vector2(700+p*.5,225)
	_glow(center,230,c,.8)
	for i in range(7):
		_ellipse(center,Vector2(65+i*15,84+i*18),Color(c,.08),false,2)
	draw_circle(center,75,Color("070913"))
	_ring(center,81,Color(c,.52),t*.13,21)
	for i in range(5):
		var x=i*320-10+p
		_poly([Vector2(x,0),Vector2(x+65,0),Vector2(x+130,485),Vector2(x+84,490)],Color("111824"))
		draw_line(Vector2(x+50,20),Vector2(x+114,476),Color("344756"),4)
	draw_rect(Rect2(0,440,1280,60),Color("18232d"))
	for i in range(12):
		draw_rect(Rect2(i*114+22,455,62,3),Color(c,.33))
	draw_rect(Rect2(0,82,1280,16),Color("1b2734"))

func _draw_tower(c: Color,t: float,p: float) -> void:
	_draw_city(Color("699bbb"),t,p,false)
	for i in range(7):
		var x=i*230-170+sin(t*.05+i)*60
		_ellipse(Vector2(x,80+i%3*37),Vector2(210,47),Color("111b2b"))
	if fmod(t,7.0)<.15:
		var x=400+sin(floor(t/7))*370
		var points=PackedVector2Array([Vector2(x,100),Vector2(x+35,175),Vector2(x+10,170),Vector2(x+60,268)])
		draw_polyline(points,Color(c,.7*flash_strength),3,true)
		_glow(Vector2(x+20,158),280,c,flash_strength)
	for x in [70,1210]:
		draw_rect(Rect2(x-11,105,22,392),Color("182434"))
		draw_line(Vector2(x,105),Vector2(x,492),Color(c,.38),3)
		_ring(Vector2(x,128),20,Color(c,.6),t*.2,5)

func _draw_reactor(c: Color,t: float,p: float,impact: float) -> void:
	_glow(Vector2(640+p,320),320,c,.8+impact)
	for x in [280,640,1000]:
		var center=Vector2(x+p,277)
		draw_rect(Rect2(center.x-111,128,222,357),Color("111c23"))
		draw_rect(Rect2(center.x-73,145,146,324),Color("261f22"))
		for i in range(7):
			var y=159+i*44
			draw_rect(Rect2(center.x-61,y,122,18),Color(c,.05+.04*sin(t*1.4+i)))
			draw_rect(Rect2(center.x-105,y,15,21),Color(c,.45))
			draw_rect(Rect2(center.x+90,y,15,21),Color(c,.45))
		_ring(center,69,Color(c,.35),t*.3,8)
		draw_circle(center,35,Color(c,.13))
	for i in range(4):
		draw_rect(Rect2(0,77+i*16,1280,6),Color("1a252c"))

func _draw_campus(c: Color,t: float,p: float) -> void:
	_glow(Vector2(630,252),260,c,.45)
	for i in range(3):
		var x=172+i*373+p
		draw_rect(Rect2(x,209-i%2*38,264,239+i%2*38),Color("1c2733"))
		draw_rect(Rect2(x-13,199-i%2*38,289,14),Color("384552"))
		for row in range(4):
			for col in range(5):
				draw_rect(Rect2(x+17+col*47,230-i%2*38+row*43,25,26),Color(c,.07+float((row+col)%3)*.035))
	for x in [108,1140]:
		draw_line(Vector2(x,270),Vector2(x,488),Color("303d45"),6)
		draw_line(Vector2(x-25,270),Vector2(x+25,270),Color(c,.6),3)
		_glow(Vector2(x,275),65,c,.5)
	for i in range(6):
		var x=57+i*243+p
		draw_line(Vector2(x,377),Vector2(x+9,493),Color("162c31"),9)
		for k in range(3):
			draw_circle(Vector2(x+k*19-18,369+k%2*19),37,Color("173534"))
	var center=Vector2(656+p,374)
	_ring(center,68,Color(c,.18),t*.08,9)
	_poly([center+Vector2(0,-54),center+Vector2(38,0),center+Vector2(0,54),center+Vector2(-38,0)],Color(c,.16))

func _draw_dimension(c: Color,t: float,p: float,impact: float) -> void:
	var center=Vector2(640+p,240)
	_glow(center,320,c,.95+impact)
	for i in range(8):
		_ring(center,55+i*28,Color(c,.05+i*.014),t*(.05 if i%2 else -.025),7)
	draw_circle(center,45,Color("030613"))
	for i in range(15):
		var x=fmod(i*257.0+121,1350)-35+p
		var y=175+fmod(i*91,290)+sin(t*.6+i)*10
		var s=22+fmod(i*17,55)
		_poly([Vector2(x-s,y),Vector2(x+s*.7,y-12),Vector2(x+s,y+8),Vector2(x,y+s*.5)],Color("1b2037"))
		draw_line(Vector2(x-s,y),Vector2(x+s*.7,y-12),Color(c,.24),2)

func _draw_floor(c: Color,id: int,t: float) -> void:
	_gradient(Rect2(0,512,1280,208),Color("18252e"),Color("080e17"),28)
	for i in range(-6,15):
		var x = i*124.0
		draw_line(Vector2(640+(x-640)*.53,512),Vector2(x,720),Color(c,.075),1.5)
	for y in [523,546,579,626,695]:
		draw_line(Vector2(0,y),Vector2(1280,y),Color(c,.075),1)
	# Fixed deterministic fine detail avoids texture noise moving underfoot.
	for i in range(150):
		var x=fmod(i*241.91+51,1280)
		var y=518+fmod(i*91.731,200)
		var width=2+fmod(i*13.7,25)
		draw_line(Vector2(x,y),Vector2(x+width,y-.4),Color(c,.018+float(i%3)*.007),1)
	if id in [1,4,6]:
		for i in range(7):
			var x=90+i*203.0
			for j in range(5):
				draw_line(Vector2(x+j*8,538),Vector2(x+j*13-16,558),Color(c,.035),2)
	if id in [2,5,8]:
		for i in range(6):
			draw_line(Vector2(0,631+i*4),Vector2(1280,631+i*4),Color(c,.022),1)
	draw_line(Vector2(0,513),Vector2(1280,513),Color(c,.30),2)
	_ellipse(Vector2(640,591),Vector2(342,62),Color(c,.04),false,2)
	_ellipse(Vector2(640,591),Vector2(275,48),Color(c,.04),false,1)
	for side in [-1,1]:
		var x=640+side*573
		_poly([Vector2(x,616),Vector2(x+side*41,624),Vector2(x+side*89,624),Vector2(x+side*34,613)],Color(c,.36))
		if id in [0,3,7,9]:
			draw_line(Vector2(x,533),Vector2(x+side*65,571),Color(c,.24+.05*sin(t)),2)

func _frame_for(f: Dictionary) -> int:
	var state: String = str(f.get("state","idle"))
	var anim: String = str(f.get("anim",state))
	var m: Dictionary = f.get("move",{})
	if state in ["ko","knockdown","hitstun","hit","guard_break","guardbreak","throw_victim","thrown","super_victim"]:
		return 6
	if state in ["block","blockstun","crouch_block","crouch","parry","counter"]:
		return 4
	if state in ["jump","fall"] or (float(f.get("y",590))<588 and m.is_empty()):
		return 5
	if not m.is_empty() and state in ["attack","special","super","throw","charge"]:
		var k: String = str(m.get("kind","strike"))
		if k in ["projectile","trap","barrier","super","buff","counter","freeze","echo","pull","burst","wave"]:
			return 7
		if k in ["uppercut"]:
			return 5
		if k in ["slide","blink_strike"] or str(m.get("level","mid"))=="low" or "KICK" in str(m.get("name","")):
			return 3
		return 2
	if state in ["walk","dash","evade"] or anim in ["walk","walk_forward","walk_back"]:
		return 1
	if state in ["victory","intro"]:
		return 7 if (int(f.get("round_wins",0))+int(f.get("id",0)))%2 else 0
	return 0

func _source_rect(id: int, frame: int) -> Rect2:
	var tex: Texture2D = textures[id]
	var cell = tex.get_size()/Vector2(4,2)
	return Rect2(Vector2(frame%4,frame/4)*cell,cell)

func _draw_atlas_frame(id: int,target: Rect2,frame: int,color: Color) -> void:
	var source=_source_rect(id,frame)
	var pixels_to_world=target.size.x/source.size.x
	# Generated sheets have a few casting toes beyond the nominal cell edge.
	# Region adjustment keeps those toes in cast, out of hurt, with no rescaling.
	if frame==6:
		var right_edges=[396.0,428.0,417.0,400.0,411.0,421.0,400.0,417.0]
		source.size.x=right_edges[id]
		target.size.x=source.size.x*pixels_to_world
	elif frame==7:
		var left_extension=[34.0,14.0,10.0,19.0,11.0,0.0,33.0,21.0]
		var extension=float(left_extension[id])
		source.position.x-=extension
		source.size.x+=extension
		target.position.x-=extension*pixels_to_world
		target.size.x+=extension*pixels_to_world
	draw_texture_rect_region(textures[id],target,source,color)

func draw_fighter(f: Dictionary,t: float,alt: bool = false) -> void:
	var id=clampi(int(f.get("id",0)),0,NAMES.size()-1)
	var pos=Vector2(float(f.get("x",640)),float(f.get("y",590)))
	var face=float(f.get("face",1))
	var state=str(f.get("state","idle"))
	var c: Color=COLORS[id]
	var m: Dictionary=f.get("move",{})
	var frame=float(f.get("frame",0))
	var duration=maxf(1,float(m.get("startup",6))+float(m.get("active",3))+float(m.get("recovery",16)))
	var progress=clampf(frame/duration,0,.999)
	var pose="idle"
	var phase=fmod(t*(.68+id*.022),1)
	if state in ["walk","dash","evade"]: pose="walk" if state=="walk" else "dash";phase=fmod(t*2.4,1)
	elif state in ["crouch","crouch_block"]:pose="crouch" if state=="crouch" else "lowguard"
	elif state in ["block","blockstun","counter","parry"]:pose="guard"
	elif state in ["hitstun","hit","frozen"]:pose="hurt";phase=clampf(frame/15,0,.999)
	elif state in ["ko","knockdown"]:pose="down";phase=.7
	elif state in ["victory","intro","entry"]:pose="victory" if state=="victory" else "intro"
	elif state in ["jump","fall"] or (pos.y<589 and m.is_empty()):pose="jump" if f.get("vel",Vector2.ZERO).y<0 else "fall"
	if not m.is_empty() and state in ["attack","super","throw"]:
		phase=progress
		pose=str(m.get("body_pose","light"))
		var family=str(m.get("family","normal"))
		if family=="super":pose="ultimate"
		elif family=="special":pose=str(m.get("animation",m.get("pose",pose)))
		var aliases={"punch":"light","projectile":"specialA","uppercut":"heavy","spin":"specialB","grab":"grab","throw":"grab","crouch":"lowkick","slide":"lowkick","aim":"specialA","cast":"specialA","sweep":"lowkick","run":"dash","charge":"intro","block":"guard"}
		pose=aliases.get(pose,pose)
		if pos.y<580 and family=="normal":pose="airkick" if pose=="kick" else "airlight"
		elif str(m.get("level",""))=="low" and family=="normal":pose="lowkick" if pose=="kick" else "lowlight"
	# Fernando signals from behind the bear rather than performing its attack.
	if id==13 and not m.is_empty():pose="guard" if progress<.2 else "victory"
	if id in [11,12] and pose in ["specialA","specialB","ultimate"]:pose="light" if id==11 else "heavy"
	if f.has("_pose_name"):pose=str(f._pose_name)
	var skin="diogo_alt" if id==3 and int(f.get("skin",0))==1 else NAMES[id]
	if not sprite_data.has(skin):return
	var data: Dictionary=sprite_data[skin]
	var sequence: Array=data.animations.get(pose,data.animations.idle)
	var fn=str(sequence[mini(sequence.size()-1,int(phase*sequence.size()))])
	if id==13 and not m.is_empty() and state in ["attack","super","throw"]:
		fn="guard" if progress<.2 else "win"
		if f.has("_command_frame"):fn=str(f._command_frame)
	var r: Array=data.frames.get(fn,data.frames.idle0)
	var source=Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3]))
	var zoom=float(f.get("_visual_scale",1))
	var shadow_scale=clampf(1-(590-pos.y)/480,.4,1)
	_ellipse(Vector2(pos.x,590),Vector2(76,8)*shadow_scale,Color(0.004,.018,.03,.42))
	draw_set_transform(pos+_shake_offset,0,Vector2(face*zoom,zoom))
	var tint=Color.WHITE
	if alt:tint=Color(.87,.94,1)
	if int(f.get("invuln",0))>0:tint.a=.65+.25*sin(t*40)
	_draw_clipped_frame(self,skin,fn,Rect2(-192,-304,384,320),tint)
	if not m.is_empty() and state in ["attack","super","counter"]:_ufn_prop(f,pose,progress,t)
	if int(f.get("transform",0))>0:_ufn_mech(Vector2(0,-110),t)
	if int(f.get("prepared",0))>0 and state!="attack":_ufn_ball(Vector2(48,-32-absf(sin(t*6))*44),18,false,t)
	draw_set_transform(_shake_offset)
	if id==13:_draw_bear(f,t)
	if float(f.get("meter",0))>=99:_ellipse(Vector2(pos.x,588),Vector2(48,7),Color(c,.65),false,2)
	if state not in ["ko","knockdown"]:
		draw_rect(Rect2(pos.x-14,pos.y-270,28,15),Color("003d7c") if int(f.get("player",0))==0 else Color("526e8d"))
		draw_string(ThemeDB.fallback_font,Vector2(pos.x-9,pos.y-258),"J"+str(int(f.get("player",0))+1),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE)

func _super_clone(source: Dictionary,pos: Vector2,pose: int,scale_factor: float,rotation: float = 0.0,face: int = 1) -> Dictionary:
	var f: Dictionary=source.duplicate()
	f.x=pos.x
	f.y=pos.y
	f.face=face
	f.frame=90
	f.invuln=0
	f.state="hitstun" if pose==6 else "attack"
	f.stun=0
	f.move={"kind":"super","startup":1,"family":"cinematic"}
	f._pose=pose
	f._visual_scale=scale_factor
	f._visual_rotation=rotation
	return f

func _beam(a: Vector2,b: Vector2,c: Color,width: float,strength: float) -> void:
	var normal=(b-a).normalized().orthogonal()
	for i in range(4,0,-1):
		var w=width*(.5+i*.24)
		draw_polygon(PackedVector2Array([a+normal*w,a-normal*w,b-normal*w*.7,b+normal*w*.7]),PackedColorArray([Color(c,.05*strength),Color(c,.05*strength),Color(c,.11*strength),Color(c,.11*strength)]))
	draw_line(a,b,Color(c,.7*strength),maxf(1,width*.4),true)
	draw_line(a,b,Color(1,1,1,.68*strength),maxf(1,width*.075),true)

func _bolt(a: Vector2,b: Vector2,c: Color,t: float,power: float=1.0) -> void:
	var direction=(b-a).normalized().orthogonal()
	var pts=PackedVector2Array()
	for i in range(13):
		var q=float(i)/12.0
		pts.append(a.lerp(b,q)+direction*sin(i*19.3+floor(t*22)*6.17)*23*sin(q*PI))
	draw_polyline(pts,Color(c,.22*power),10,true)
	draw_polyline(pts,Color(c,.85*power),3,true)
	draw_polyline(pts,Color(1,1,1,.78*power),1,true)

func _ice_shard(pos: Vector2,height: float,width: float,c: Color,alpha: float=1.0) -> void:
	_poly([pos+Vector2(-width,0),pos+Vector2(-width*.4,-height*.78),pos+Vector2(0,-height),pos+Vector2(width*.72,-height*.72),pos+Vector2(width,0)],Color(c,.18*alpha))
	_poly([pos,pos+Vector2(0,-height),pos+Vector2(width*.72,-height*.72),pos+Vector2(width,0)],Color(c,.3*alpha))
	draw_line(pos+Vector2(0,-height),pos+Vector2(-width*.4,-height*.78),Color(c,.8*alpha),2,true)
	draw_line(pos+Vector2(0,-height),pos,Color(c,.55*alpha),1,true)

func _draw_super_sequence(sequence: Dictionary,t: float) -> void:
	var frame=int(sequence.get("frame",0))
	var duration=maxi(1,int(sequence.get("duration",210)))
	var q=clampf(float(frame)/duration,0,1)
	var id=clampi(int(sequence.get("character",0)),0,NAMES.size()-1)
	var attacker=int(sequence.get("attacker",0))
	var defender=int(sequence.get("defender",1))
	var c: Color=COLORS[id]
	var beat=int(frame/30)%6
	var pulse_hit=maxf(0,1-float(frame%30)/12)
	draw_rect(Rect2(0,0,1280,720),Color(.002,.007,.024,.6))
	_glow(Vector2(740,380),430,c,.3)
	var a: Dictionary=combat.fighters[attacker].duplicate()
	var b: Dictionary=combat.fighters[defender].duplicate()
	a.x=410.0;a.y=590.0;a.face=1;a._visual_scale=1.12;a._pose_name=["light","heavy","kick","specialA","specialB","ultimate"][beat]
	b.x=840.0;b.y=555.0-sin(q*PI)*75;b.face=-1;b._visual_scale=1.12;b._pose_name="hurt"
	match id:
		0:
			a.x=660.0-pulse_hit*55;a._pose_name="heavy" if beat<4 else "lowheavy";b.x=735.0;b.y=390.0 if beat<4 else 585.0
			if beat>=4:
				for i in range(12):draw_line(Vector2(735,590),Vector2(735+cos(i*1.7)*210,595+sin(i*2)*42),Color(c,.55),2)
		1:
			a.x=630.0-pulse_hit*90;a._pose_name="heavy" if beat%2 else "light"
			draw_string(ThemeDB.fallback_font,Vector2(660,255),"AGORA CHEGA!",HORIZONTAL_ALIGNMENT_LEFT,-1,38,Color(c,.8))
		2:
			for i in range(6):_ufn_capy(Vector2(fmod(t*390+i*223,1480)-100,590+i%2*12),1.2,t+i)
			a._pose_name="specialA";_beam(Vector2(500,458),Vector2(840,b.y-130),c,9,pulse_hit)
		3:
			for i in range(5):_ufn_vine(Vector2(580+i*65,602),Vector2(840,b.y-60-i*32),t+i,4)
			if beat>=4:
				for i in range(8):_ufn_vine(Vector2(842,605),Vector2(842+cos(i*.8)*140,290+sin(i*2)*90),t,9)
				for i in range(35):draw_circle(Vector2(840+sin(i*3.7)*155,310+cos(i*7.3)*110),10+i%4*3,Color(c,.5))
		4:_ufn_mech(Vector2(440,450),t)
		5:
			a.x=630.0;a._pose_name="airkick" if beat>=4 else "kick";a.y=535.0 if beat>=4 else 590.0
			_ufn_ball(Vector2(750+sin(t*14)*150,410+cos(t*14)*70),27,false,t)
			for i in range(9):draw_line(Vector2(920+i*26,285),Vector2(920+i*26,590),Color(.8,1,1,.45),1)
			for i in range(10):draw_line(Vector2(918,295+i*32),Vector2(1150,295+i*32),Color(.8,1,1,.45),1)
		6:
			a._pose_name="specialA";_ufn_ball(Vector2(680+sin(t*12)*190,420+cos(t*12)*100),26,true,t)
			draw_arc(Vector2(640,590),195,PI,TAU,40,Color(c,.7),3)
		7:
			_ufn_vehicle(Vector2(550+sin(q*PI)*360,567),2.0,true,t);a._pose_name="dash";a.x=550+sin(q*PI)*230
		8:
			for i in range(5):_ring(Vector2(840,b.y-110),80+i*20,Color(c,.45),t*(1 if i%2 else -1),3+i)
			draw_string(ThemeDB.fallback_font,Vector2(560,262),"f(x) = COMBO²",HORIZONTAL_ALIGNMENT_LEFT,-1,39,c)
		9:
			for i in range(4):_ufn_ally(Vector2(590+i*80,590-i%2*45),t+i,i)
	if id>=10:
		var visuals=["network","foam","house","bear","gas","skate"]
		if id==13:
			a.bear_x=740.0;a._pose_name="victory";b.x=875.0
			a._command_frame="guard" if frame%30<6 else "win"
			a._bear_pose=[6,3,4,5,6,4][beat]
		else:
			for i in range(5):_draw_new_effect(visuals[id-10],Vector2(675+i*65,415+sin(t*3+i)*60),t+i,c,"cinematic",false)
	draw_fighter(a,t)
	draw_fighter(b,t)
	if pulse_hit>0:
		for i in range(9):
			var d=Vector2.from_angle(i*TAU/9)
			draw_line(Vector2(b.x,b.y-115)+d*22,Vector2(b.x,b.y-115)+d*(60+pulse_hit*45),Color(c,pulse_hit),3)
	draw_rect(Rect2(0,0,1280,42),Color("030c19"));draw_rect(Rect2(0,657,1280,63),Color("030c19"))

func _draw_prime(pos: Vector2,face: float,state: String,t: float,c: Color) -> void:
	var bob=sin(t*2)*5
	var center=pos+Vector2(0,-128+bob)
	_glow(center,90,c,.8)
	for side in [-1,1]:
		_poly([center+Vector2(side*17,13),center+Vector2(side*37,48),pos+Vector2(side*46,-8),pos+Vector2(side*10,-8)],Color("263447"))
		_poly([center+Vector2(side*22,-30),center+Vector2(side*61,-8),center+Vector2(side*70,37),center+Vector2(side*45,20)],Color("344354"))
		_poly([center+Vector2(side*29,-29),center+Vector2(side*59,-47),center+Vector2(side*79,-17),center+Vector2(side*48,-8)],Color("576173"))
		draw_line(center+Vector2(side*46,-29),center+Vector2(side*65,-19),c,2)
	_poly([center+Vector2(-26,-38),center+Vector2(26,-38),center+Vector2(38,9),center+Vector2(0,38),center+Vector2(-38,9)],Color("202b42"))
	_poly([center+Vector2(0,-31),center+Vector2(19,-5),center+Vector2(0,21),center+Vector2(-19,-5)],Color(c,.8))
	var head=center+Vector2(0,-63)
	_poly([head+Vector2(-20,-20),head+Vector2(14,-25),head+Vector2(24,2),head+Vector2(6,27),head+Vector2(-17,12)],Color("4c526d"))
	draw_line(head+Vector2(-7,-2),head+Vector2(18,-2),Color("faf0ff"),3)
	_ring(center,101,Color(c,.16),t*.22,7)
	if state in ["attack","special","super"]:
		_element_marks(7,center+Vector2(face*75,0),c,t,1)

func _element_marks(id: int,pos: Vector2,c: Color,t: float,strength: float) -> void:
	if id==0:
		var pts=PackedVector2Array()
		for i in range(7):
			pts.append(pos+Vector2(i*10-30,sin(i*2.9+t*25)*14))
		draw_polyline(pts,Color(c,.8*strength),2,true)
	elif id in [2,4,7]:
		_ring(pos,24,Color(c,.7*strength),t*1.2,8 if id==2 else 6)
		if id==4:
			draw_circle(pos,12,Color("121328"))
	elif id in [3,5]:
		for i in range(5):
			var a=t+i*TAU/5
			var p=pos+Vector2.from_angle(a)*25
			if id==3:
				draw_rect(Rect2(p,Vector2(5,5)),Color(c,.6*strength),false,1)
			else:
				_poly([p+Vector2(0,-10),p+Vector2(4,0),p+Vector2(0,7),p+Vector2(-4,0)],Color(c,.6*strength))
	else:
		for i in range(5):
			var a=t*2+i*1.26
			var p=pos+Vector2.from_angle(a)*14
			draw_circle(p,5+i%3,Color(c,.2*strength))

func draw_projectile(p: Dictionary,t: float) -> void:
	var owner=int(p.get("owner",0))
	var id=int(p.get("id",0))
	if combat!=null and owner<combat.fighters.size():id=int(combat.fighters[owner].id)
	var c: Color=COLORS[clampi(id,0,NAMES.size()-1)]
	var pos=Vector2(float(p.get("x",640)),float(p.get("y",480)))
	var visual=str(p.get("visual",p.get("move",{}).get("visual",p.get("kind","projectile"))))
	var age=float(p.get("age",0))/60
	var kind=str(p.get("kind",""))
	var active=bool(p.get("active",true))
	if int(p.get("delay",0))>0:
		_ellipse(Vector2(pos.x,588),Vector2(68,10),Color(c,.6),false,2)
		draw_string(ThemeDB.fallback_font,Vector2(pos.x-8,569),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,26,c)
		return
	if visual in ["packet","network","firewall","foam","mug","brick","wall","pillar","house","gas","burp","skate","rail"]:
		_draw_new_effect(visual,pos,t,c,kind,p.age<float(p.move.get("setup_time",0)))
		return
	match visual:
		"ball","football","soccer","goal":_ufn_ball(pos,20,false,t)
		"handball","bounce","rebounds":_ufn_ball(pos,18,true,t)
		"capybara","stampede","herd":_ufn_capy(pos+Vector2(0,24),.9,t)
		"ally","allies","entourage","charm":_ufn_ally(Vector2(pos.x,590),t,int(p.get("variant",owner)))
		"drone","sentry","sentinel","robot":_ufn_drone(pos,visual!="drone",t)
		"roots","root","nature":
			_ellipse(Vector2(pos.x,587),Vector2(70,10),Color(c,.5),false,2)
			for i in range(5):_ufn_vine(Vector2(pos.x-48+i*24,590),Vector2(pos.x-35+i*19,480-absf(sin(t*4+i))*55),t+i,6)
		"smoke","cloud":
			for i in range(12):_glow(pos+Vector2(sin(i*13+t)*80,cos(i*7+t)*35),55,Color("80be77"),.09)
		"vector","parabola","loop","equation":
			_ring(pos,64 if kind=="trap" else 27,c,t,3)
			draw_line(pos-Vector2(24,0),pos+Vector2(32,0),c,3)
			draw_line(pos+Vector2(17,-11),pos+Vector2(32,0),c,3)
			draw_string(ThemeDB.fallback_font,pos+Vector2(-16,-39),"×3" if visual=="loop" else "f(x)",HORIZONTAL_ALIGNMENT_LEFT,-1,18,c)
		"weights","barbell","shockwave","dumbbell":
			_ellipse(Vector2(pos.x,586),Vector2(55+sin(t*20)*8,12),Color(c,.5),false,3)
			for i in range(7):draw_line(Vector2(pos.x-70+i*22,589),Vector2(pos.x-70+i*22,568-sin(i*2+t*6)*15),c,3)
		"bullet":_beam(pos-Vector2(36,0),pos+Vector2(25,0),Color("ffd7a5"),4,1)
		"rage","shout":
			draw_string(ThemeDB.fallback_font,pos+Vector2(-58,12),"#@!%",HORIZONTAL_ALIGNMENT_LEFT,-1,40,Color("ffba71"))
		"shield","barrier":
			_ellipse(pos,Vector2(26,82),Color(c,.25));_ellipse(pos,Vector2(26,82),Color(c,.9),false,3)
		"biz","car","tire":_ufn_vehicle(Vector2(pos.x,575),1.1,visual=="car",t)
		"vine":
			var a=combat.fighters[owner] if combat!=null else {"x":pos.x-150,"y":590}
			_ufn_vine(Vector2(a.x+48,a.y-143),pos,t,5)
		_:
			_glow(pos,38,c,.4);_ring(pos,17,c,t*4,6);draw_circle(pos,6,Color.WHITE)

func draw_effect(event: Dictionary,age: float) -> void:
	var kind=str(event.get("type",event.get("kind","hit"))).to_lower()
	var id=clampi(int(event.get("id",event.get("character",0))),0,NAMES.size()-1)
	var pos=Vector2(float(event.get("x",640)),float(event.get("y",460)))
	if event.get("pos",null) is Vector2:
		pos=event.pos
	var c: Color=COLORS[id]
	if kind in ["block","perfect_block","parry"]:
		c=Color("94f6fa")
	elif kind in ["hit","counter","throw","guard_break"]:
		c=Color("ffe2a2")
	var alpha=clampf(1-age*2.3,0,1)
	var size=26+age*170
	if kind=="guard_break":
		size*=1.5
	if age < .17:
		_glow(pos,75,c,alpha)
		draw_circle(pos,maxf(1,17-age*90),Color(1,1,1,alpha*flash_strength))
	if kind in ["block","perfect_block","parry","clash","projectile_clash"]:
		draw_arc(pos,size,0,TAU,40,Color(c,alpha),2,true)
	else:
		for i in range(11):
			var a=i*TAU/11+.17
			var direction=Vector2.from_angle(a)
			draw_line(pos+direction*size*.55,pos+direction*size*(.85+float(i%3)*.2),Color(c,alpha),3.0 if i%2 else 2.0,true)
		for i in range(5):
			var a=i*1.29+.42
			var point=pos+Vector2.from_angle(a)*(size+15)+Vector2(0,age*age*110)
			draw_rect(Rect2(point,Vector2(3,3)),Color(c,alpha))

func _draw_clipped_frame(canvas: CanvasItem, key: String, frame: String, dest: Rect2, tint: Color = Color.WHITE) -> void:
	# Clip neighboring figures in the presentation only. UVs preserve the original
	# 384x320 cell and foot anchor; animation masks never affect combat hitboxes.
	var data: Dictionary = sprite_data[key]
	var r: Array = data.frames.get(frame,data.frames.idle0)
	var source = Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3]))
	var clip: Array = data.get("frame_clips",{}).get(frame,[])
	if clip.size() < 3:
		canvas.draw_texture_rect_region(sprite_atlas[key],dest,source,tint)
		return
	var points = PackedVector2Array()
	var uvs = PackedVector2Array()
	var tex: Texture2D = sprite_atlas[key]
	for vertex in clip:
		var local = Vector2(float(vertex[0]),float(vertex[1]))
		points.append(dest.position + local / Vector2(384,320) * dest.size)
		uvs.append((source.position + local / Vector2(384,320) * source.size) / tex.get_size())
	canvas.draw_polygon(points,PackedColorArray([tint]),uvs,tex)

func draw_portrait(canvas: CanvasItem,id: int,rect: Rect2,variant: int=0,flip: bool=false,skin: int=0) -> void:
	id=clampi(id,0,NAMES.size()-1)
	if sprite_data.is_empty():load_art()
	var key="diogo_alt" if id==3 and skin==1 else NAMES[id]
	if not portrait_art.has(key):return
	if variant==0:
		canvas.draw_texture_rect(portrait_art[key],rect,false,Color.WHITE)
		return
	var data: Dictionary=sprite_data[key]
	var animation="victory" if variant==3 else "idle"
	var seq: Array=data.animations.get(animation,data.animations.idle)
	var fn=str(seq[int(fmod(time*.55,1)*seq.size())])
	var r: Array=data.frames.get(fn,data.frames.idle0)
	var scale_factor=minf(rect.size.x/205,rect.size.y/255)
	var dest=Rect2(Vector2(-192,-304)*scale_factor,Vector2(384,320)*scale_factor)
	canvas.draw_set_transform(Vector2(rect.get_center().x,rect.end.y),0,Vector2(-1 if flip else 1,1))
	_draw_clipped_frame(canvas,key,fn,dest,Color.WHITE)
	canvas.draw_set_transform(Vector2.ZERO)

func _ufn_ball(p: Vector2, r: float, handball: bool, t: float) -> void:
	draw_circle(p+Vector2(3,4),r+2,Color(0,0,0,.23))
	draw_circle(p,r,Color("ee9a54") if handball else Color("eef3f3"))
	draw_arc(p,r,0,TAU,32,Color("142c47"),2,true)
	for i in range(5):
		var a=t*8+i*TAU/5
		var c=p+Vector2.from_angle(a)*r*.61
		if handball:draw_arc(p+Vector2.from_angle(a)*r*.7,r*.82,a+1,a+2.6,12,Color("343967"),2,true)
		else:
			var points=PackedVector2Array()
			for j in range(6):points.append(c+Vector2.from_angle(j*TAU/5+a)*r*.24)
			draw_colored_polygon(points,Color("18354f"))
	draw_circle(p+Vector2(-r*.3,-r*.36),r*.17,Color(1,1,1,.7))

func _ufn_vine(a: Vector2,b: Vector2,t: float,w: float) -> void:
	var points=PackedVector2Array()
	for i in range(21):
		var q=i/20.0
		points.append(a.lerp(b,q)+Vector2(sin(q*12+t*9)*15,cos(q*8+t*8)*9)*sin(q*PI))
	draw_polyline(points,Color("194c37"),w+3,true)
	draw_polyline(points,Color("77cb81"),w,true)
	for i in range(3,19,3):
		var p=points[i]
		var side=1 if i%2 else -1
		_poly([p,p+Vector2(side*15,-15),p+Vector2(side*23,-13),p+Vector2(side*15,-3)],Color("9be493"))

func _ufn_capy(p: Vector2,s: float,t: float) -> void:
	var col=Color("a87b50")
	for i in range(4):
		var x=p.x+(-30+i*18)*s
		draw_line(Vector2(x,p.y-17*s),Vector2(x+sin(t*17+i*2)*10*s,p.y),Color("614833"),9*s)
	_ellipse(p+Vector2(-7,-33)*s,Vector2(45,27)*s,col)
	_ellipse(p+Vector2(31,-53)*s,Vector2(27,24)*s,col)
	_ellipse(p+Vector2(48,-43)*s,Vector2(22,14)*s,Color("be9667"))
	draw_circle(p+Vector2(19,-75)*s,8*s,Color("795c40"))
	draw_circle(p+Vector2(43,-60)*s,3*s,Color("131f28"))
	draw_rect(Rect2(p+Vector2(59,-47)*s,Vector2(7,5)*s),Color("403327"))
	draw_line(p+Vector2(-36,-41)*s,p+Vector2(13,-49)*s,Color("caa071"),2*s)

func _ufn_vehicle(p: Vector2,s: float,car: bool,t: float) -> void:
	var r=21*s
	for side in [-1,1]:
		var wheel=p+Vector2(side*59,-4)*s
		draw_circle(wheel,r,Color("101c2b"));draw_circle(wheel,r*.56,Color("a6b7c5"))
		for i in range(5):draw_line(wheel,wheel+Vector2.from_angle(t*19+i*TAU/5)*r*.45,Color("354d62"),2*s)
	if car:
		_poly([p+Vector2(-91,-15)*s,p+Vector2(-95,-46)*s,p+Vector2(-55,-54)*s,p+Vector2(-30,-84)*s,p+Vector2(36,-84)*s,p+Vector2(59,-55)*s,p+Vector2(91,-43)*s,p+Vector2(98,-17)*s],Color("0965ab"))
		_poly([p+Vector2(-43,-56)*s,p+Vector2(-24,-77)*s,p+Vector2(5,-77)*s,p+Vector2(5,-55)*s],Color("c5e5ec"))
		_poly([p+Vector2(12,-77)*s,p+Vector2(32,-77)*s,p+Vector2(49,-55)*s,p+Vector2(12,-55)*s],Color("90c0d3"))
		draw_line(p+Vector2(-90,-42)*s,p+Vector2(80,-42)*s,Color("48a4d6"),3*s)
		draw_rect(Rect2(p+Vector2(80,-40)*s,Vector2(13,10)*s),Color("fff7bf"))
	else:
		draw_line(p+Vector2(-55,-11)*s,p+Vector2(16,-47)*s,Color("cad4dc"),9*s)
		draw_line(p+Vector2(55,-11)*s,p+Vector2(35,-72)*s,Color("9fb2c0"),7*s)
		_poly([p+Vector2(-40,-24)*s,p+Vector2(-31,-55)*s,p+Vector2(4,-53)*s,p+Vector2(20,-27)*s],Color("247eae"))
		draw_line(p+Vector2(-42,-54)*s,p+Vector2(0,-54)*s,Color("142136"),9*s)
		draw_line(p+Vector2(31,-72)*s,p+Vector2(14,-77)*s,Color("132a3d"),5*s)
		draw_circle(p+Vector2(37,-61)*s,7*s,Color("fff5bd"))

func _ufn_drone(p: Vector2,sentry: bool,t: float) -> void:
	if sentry:
		for side in [-1,1]:draw_line(p+Vector2(0,12),p+Vector2(side*31,48),Color("94aabd"),6)
		draw_rect(Rect2(p-Vector2(23,15),Vector2(46,33)),Color("234463"))
		draw_line(p+Vector2(12,-4),p+Vector2(48,-4),Color("b4cdda"),8)
	else:
		for side in [-1,1]:
			draw_line(p,p+Vector2(side*33,-8),Color("719cb6"),4)
			_ellipse(p+Vector2(side*35,-11),Vector2(22,4+sin(t*40)*2),Color("d5f1ff"),false,2)
		_poly([p+Vector2(-20,-12),p+Vector2(23,-12),p+Vector2(29,8),p+Vector2(0,18),p+Vector2(-26,6)],Color("235175"))
	draw_circle(p+Vector2(6,1),6,Color("75edff"));_glow(p,35,Color("6be8ff"),.22)

func _ufn_mech(p: Vector2,t: float) -> void:
	var cyan=Color("83f1ff")
	for side in [-1,1]:
		var hip=p+Vector2(side*30,38)
		var foot=p+Vector2(side*48,103)
		draw_line(hip,foot,Color("183c57"),17)
		draw_line(hip,foot,Color("97bbcc"),6)
		draw_circle(hip,9,cyan);draw_circle(foot,7,Color("82c9df"))
		_poly([p+Vector2(side*27,-63),p+Vector2(side*62,-59),p+Vector2(side*69,-30),p+Vector2(side*39,-23)],Color("2c6280"))
		draw_line(p+Vector2(side*45,-54),p+Vector2(side*56,-33),cyan,3)
	_ring(p+Vector2(0,-21),22,cyan,t,8)
	_glow(p+Vector2(0,-21),75,cyan,.25)

func _ufn_ally(p: Vector2,t: float,variant: int) -> void:
	# Adult allies use an existing full body sprite in a distinct tint.
	if not sprite_data.has("maria"):return
	var data: Dictionary=sprite_data.maria
	var name=str(data.animations.light[int(fmod(t*2+variant*.2,1)*24)%24])
	var r: Array=data.frames[name]
	var tint=Color("e8bcff") if variant%2 else Color("9bdfea")
	draw_texture_rect_region(sprite_atlas.maria,Rect2(p-Vector2(154,243),Vector2(307,256)),Rect2(r[0],r[1],r[2],r[3]),Color(tint,.85))
	_ring(p+Vector2(0,-90),48,Color(tint,.35),t,5)

func _ufn_prop(f: Dictionary,pose: String,q: float,t: float) -> void:
	var m: Dictionary=f.get("move",{})
	if str(m.get("family","normal"))=="normal":return
	var v=str(m.get("visual",""))
	var hand=Vector2(67,-137)
	if pose in ["heavy","lowheavy"]:hand=Vector2(17,-237)
	if pose in ["lowkick","lowlight","crouch"]:hand=Vector2(32,-89)
	var strength=sin(q*PI)
	if v in ["packet","network","firewall","foam","mug","brick","wall","pillar","house","gas","burp","skate","rail"]:
		_draw_new_effect(v,hand if v not in ["skate","rail"] else Vector2(0,-5),t,COLORS[int(f.id)],"prop",false)
		return
	match v:
		"dumbbell","barbell":
			var center=hand if v=="dumbbell" else Vector2(10,-30-absf(cos(q*PI))*95)
			var w=22 if v=="dumbbell" else 62
			draw_line(center-Vector2(w,0),center+Vector2(w,0),Color("bfccd6"),6)
			for side in [-1,1]:
				draw_rect(Rect2(center+Vector2(side*w-7,-23),Vector2(14,46)),Color("273b54"))
				draw_rect(Rect2(center+Vector2(side*w-3,-19),Vector2(3,38)),Color("a7bac8"))
		"bullet","reload":
			draw_rect(Rect2(hand+Vector2(-6,-10),Vector2(38,9)),Color("a7b8bf"))
			draw_rect(Rect2(hand+Vector2(-5,-4),Vector2(12,19)),Color("483b35"))
			draw_circle(hand+Vector2(8,-4),8,Color("506978"))
			if v=="bullet" and q>.31 and q<.48:
				_poly([hand+Vector2(32,-8),hand+Vector2(67,-21),hand+Vector2(50,-5),hand+Vector2(70,7),hand+Vector2(34,1)],Color("ffdf99"))
		"football":_ufn_ball(Vector2(74,-45-absf(sin(q*PI))*67),18,false,t)
		"handball":_ufn_ball(hand,17,true,t)
		"vine":_ufn_vine(hand,hand+Vector2(180*strength,-15),t,5)
		"drone":_ufn_drone(hand+Vector2(21,-35),false,t)
		"shield":_ellipse(Vector2(60,-123),Vector2(28,89),Color(.4,.88,1,.45),false,4)
		"biz":_ufn_vehicle(Vector2(12,-10),1,false,t)
		"tire":
			draw_arc(Vector2(14,-102),102,TAU*q,TAU*q+3.8,28,Color("b9d3ea"),4,true)
		"vector","parabola","loop","equation":
			_ring(hand,27,Color("c4a6ff"),t*3,3)
			draw_string(ThemeDB.fallback_font,hand+Vector2(-15,-37),"f(x)",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("d9c7ff"))
		"rage":
			for i in range(6):
				var p=Vector2(sin(i*4)*47,-20-i*34)
				draw_line(p,p+Vector2(-12,-27)*strength,Color(1,.46,.2,.7*strength),3)
		"hearts":
			for i in range(4):
				var p=Vector2(10+i*18,-170-i*12)
				draw_circle(p,6,Color("ec99c7"));draw_circle(p+Vector2(8,0),6,Color("ec99c7"));_poly([p-Vector2(6,0),p+Vector2(14,0),p+Vector2(4,13)],Color("ec99c7"))

func _draw_bear(f: Dictionary,t: float) -> void:
	if bear_texture==null:return
	var x=float(f.get("bear_x",f.x+f.face*85))
	var pose=0
	var moving=absf(x-(float(f.x)+float(f.face)*85))>8 or f.state=="walk"
	if moving:pose=1+int(t*7)%2
	var m:Dictionary=f.get("move",{})
	if int(f.get("bear_stun",0))>0:pose=7
	elif not m.is_empty() and f.state in ["attack","throw","super"]:
		var active=int(f.frame)>=int(m.get("startup",0))
		pose=6 if m.kind=="throw" else (5 if m.get("level","")=="low" else (4 if float(m.get("damage",0))>80 else 3))
		if not active:pose=0
	if f.has("_bear_pose"):pose=clampi(int(f._bear_pose),0,BEAR_REGIONS.size()-1)
	# The eight drawings do not follow an exact grid. Explicit bounds exclude
	# neighbouring claws and keep all poses at the same pixel scale and floor.
	var source:Rect2=BEAR_REGIONS[pose]
	var scale_factor=250.0/444.0
	var target=Rect2(Vector2(source.position.x-BEAR_FOOT_X[pose],-source.size.y)*scale_factor,source.size*scale_factor)
	_ellipse(Vector2(x,590),Vector2(66,9),Color(0,0,0,.25))
	draw_set_transform(Vector2(x,590)+_shake_offset,0,Vector2(f.face,1))
	draw_texture_rect_region(bear_texture,target,source,Color(.7,.8,.9) if pose==7 else Color.WHITE)
	draw_set_transform(_shake_offset)
	for i in 3:
		draw_line(Vector2(f.x+f.face*35,f.y-180-i*6),Vector2(x-f.face*(15+i*12),397+i*20),Color(.64,.87,1,.27),1)
	if pose==7:_ring(Vector2(x,329),27,Color("ffc365"),t*3,5)

func _draw_new_effect(v: String,p: Vector2,t: float,c: Color,kind: String,telegraph: bool) -> void:
	if telegraph:
		_ellipse(Vector2(p.x,587),Vector2(65,12),Color(c,.65),false,2)
		return
	match v:
		"packet","network":
			for i in 4:
				var a=t+i*TAU/4
				var q=p+Vector2.from_angle(a)*37
				draw_line(p,q,Color(c,.7),2);draw_rect(Rect2(q-Vector2(5,5),Vector2(10,10)),c)
			draw_rect(Rect2(p-Vector2(15,12),Vector2(30,24)),Color("12385d"));draw_rect(Rect2(p-Vector2(15,12),Vector2(30,24)),c,false,2)
			draw_line(p-Vector2(10,6),p+Vector2(8,6),c,2)
		"firewall":
			var rect=Rect2(p-Vector2(17,90),Vector2(34,180))
			draw_rect(rect,Color(c,.18));draw_rect(rect,c,false,2)
			for i in 10:draw_line(p+Vector2(-15,-85+i*18),p+Vector2(15,-85+i*18),Color(c,.5),1)
		"mug","foam":
			draw_rect(Rect2(p-Vector2(15,15),Vector2(28,34)),Color("dca83e"));draw_rect(Rect2(p-Vector2(15,15),Vector2(28,34)),Color("fff3ca"),false,2)
			draw_arc(p+Vector2(15,0),11,-PI/2,PI/2,14,Color("dca83e"),5)
			for i in 4:draw_circle(p+Vector2(i*7-12,-16+sin(i*3+t)*2),6,Color("fff9dc"))
			if v=="foam":
				for i in 10:draw_circle(p+Vector2(i*7,10+sin(i+t*5)*12),4,Color(1,.92,.65,.65))
		"brick","wall","pillar","house":
			var columns=1 if v=="brick" or kind=="prop" else (5 if v=="house" else 2)
			var rows=1 if v=="brick" or kind=="prop" else 5
			for y in rows:
				for x in columns:
					var rect=Rect2(p+Vector2((x-columns/2.0)*32+(y%2)*6,-y*21),Vector2(30,19))
					draw_rect(rect,Color("bf785a"));draw_line(rect.position,rect.position+Vector2(30,0),Color("ffcf96"),2)
			if v=="house":_poly([p+Vector2(-95,-102),p+Vector2(5,-158),p+Vector2(106,-102)],Color("759ac5"))
		"gas","burp":
			for i in 8:
				var q=p+Vector2(sin(i*7+t)*52,cos(i*4+t)*23)
				_glow(q,30,Color("c8db70"),.17)
			if v=="burp":
				for i in 3:draw_arc(p-Vector2(30,0),35+i*19,-.8,.8,14,Color(c,.7),3)
		"skate","rail":
			var a=sin(t*12)*.25 if kind!="prop" else 0.0
			var dir=Vector2(cos(a),sin(a))
			draw_line(p-dir*55,p+dir*55,Color("f3c5ef"),10)
			draw_line(p-dir*48-Vector2(0,3),p+dir*48-Vector2(0,3),Color("39213e"),5)
			for side in [-1,1]:draw_circle(p+dir*side*37+Vector2(0,8),7,Color("b2ccdb"))
			if v=="rail":draw_line(p-Vector2(120,-21),p+Vector2(155,33),Color("a0dfff"),5)

