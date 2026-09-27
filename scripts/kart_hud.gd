extends Control
## Resolution-independent split-screen race overlay. Each player owns their HUD.
var game: Node
var menu: VBoxContainer
var font: Font = ThemeDB.fallback_font
const INK: Color = Color("071c35")
const BLUE: Color = Color("0678cb")
const CYAN: Color = Color("68e1ff")
const WHITE: Color = Color("f1faff")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bold_path: String = "res://assets/fonts/Rajdhani-Bold.ttf"
	if ResourceLoader.exists(bold_path):
		font = load(bold_path)
	refresh_menu()

func panel(rect: Rect2,color: Color = Color(0.02,0.07,0.14,0.84), border: Color = Color(0.22,0.57,0.76,0.6)) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	draw_style_box(style,rect)

func label(text_value: String,pos: Vector2,size_value: int,color: Color = WHITE) -> void:
	draw_string(font,pos+Vector2(0,2),text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,Color(0,0,0,0.5))
	draw_string(font,pos,text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,color)

func centered(text_value: String,center: Vector2,size_value: int,color: Color = WHITE) -> void:
	label(text_value,center-Vector2(font.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value).x/2,0),size_value,color)

func _draw() -> void:
	if not is_instance_valid(game) or not game.active:
		return
	var scale_value: float = minf(size.x/1280.0,size.y/720.0)
	var width: float = size.x/scale_value
	var height: float = size.y/scale_value
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*scale_value)
	panel(Rect2(0,0,width,43),Color(0.02,0.09,0.19,0.93))
	label("UFN KART",Vector2(20,29),23,WHITE)
	label(game.track_name,Vector2(176,28),14,CYAN)
	var time_text: String = "%02d:%05.2f" % [int(game.elapsed)/60,fmod(float(game.elapsed),60.0)]
	label(time_text,Vector2(width-180,28),17,WHITE)
	label("ESC  PAUSA",Vector2(width-92,27),11,Color("afd1df"))
	var lane_width: float = width/float(game.player_count) if not game.horizontal_split else width
	for p: int in range(game.player_count):
		var r: Dictionary = game.racers[p]
		var x: float = lane_width*p
		if game.horizontal_split and game.player_count==2:
			draw_set_transform(Vector2(0,p*height*.5*scale_value),0,Vector2.ONE*scale_value)
			_draw_player(r,p,0,lane_width,height*.5)
			draw_set_transform(Vector2.ZERO,0,Vector2.ONE*scale_value)
		else:_draw_player(r,p,x,lane_width,height)
	if game.player_count==2:
		draw_rect(Rect2(0,height*.5-1.5,width,3) if game.horizontal_split else Rect2(lane_width-1.5,43,3,height-43),Color("6bd5ed"))
	if game.phase=="countdown":
		for p: int in range(game.player_count):
			var x: float = lane_width*.5 if game.horizontal_split else lane_width*(p+0.5)
			var number: String = "PREPARE-SE" if game.countdown>3 else str(maxi(1,int(ceil(game.countdown))))
			centered(number,Vector2(x,(height*.5*p+height*.25) if game.horizontal_split else height*.42),34 if game.countdown>3 else 98,WHITE)
			centered("3 VOLTAS  •  8 PILOTOS  •  CAIXAS DE PODER",Vector2(x,(height*.5*p+height*.25+38) if game.horizontal_split else height*.42+38),12,CYAN)
			centered("A1 ACELERA · A2 FREIA · A3 DRIFT · D ITEM",Vector2(x,(height*.5*p+height*.25+61) if game.horizontal_split else height*.42+61),13,WHITE)
	if game.paused or game.phase=="results":
		draw_rect(Rect2(0,0,width,height),Color(0.008,0.024,0.07,0.85))
		if game.phase=="results":
			var final_cup=game.race_mode=="championship" and game.track_id==3
			var rows=game.ordered_results.duplicate(true)
			if final_cup:rows.sort_custom(func(a,b):return a.points>b.points if a.points!=b.points else a.rank<b.rank)
			centered("CAMPEÕES DO CAMPUS" if final_cup else "BANDEIRADA FINAL",Vector2(width/2,82),36,CYAN)
			centered("CAMPEONATO · CLASSIFICAÇÃO GERAL" if final_cup else game.track_name,Vector2(width/2,109),15,WHITE)
			var podium_x=[width/2,width/2-176,width/2+176]
			for i in mini(3,rows.size()):
				var row=rows[i];var yy=140 if i==0 else (165 if i==1 else 180)
				var tint=Color("f4cc6d") if i==0 else (Color("b8dcf0") if i==1 else Color("d4a278"))
				var texture=game.portrait(row.character)
				panel(Rect2(podium_x[i]-73,yy,146,272-yy),Color("0d3555"),tint)
				if texture:draw_texture_rect(texture,Rect2(podium_x[i]-40,yy+3,80,72),false)
				centered(str(i+1)+"º",Vector2(podium_x[i],yy+24),22,tint)
				centered(row.name.replace("VITOR DO ","V. "),Vector2(podium_x[i],265),15,WHITE)
			for i in rows.size():
				var result:Dictionary=rows[i];var y=285+i*25
				panel(Rect2(width/2-280,y,560,23),Color(0.03,0.16,0.28,0.95) if result.player>0 else Color(0.04,0.07,0.13,0.95))
				label(str(i+1)+"º",Vector2(width/2-262,y+17),16,CYAN if i==0 else WHITE)
				label(result.name+("  •  J"+str(result.player) if result.player>0 else "  •  CPU"),Vector2(width/2-200,y+17),14,WHITE)
				var time_value="%02d:%05.2f"%[int(result.time)/60,fmod(float(result.time),60.0)] if result.time>=0 else "EM PISTA"
				label(str(result.points)+" PTS" if game.race_mode=="championship" else time_value,Vector2(width/2+158,y+17),14,WHITE)
		else:
			centered("CORRIDA PAUSADA",Vector2(width/2,height*0.29),38,WHITE)
			centered("O cronômetro e todos os pilotos estão parados.",Vector2(width/2,height*0.29+35),16,CYAN)
			centered("A1 acelera · A2 freia/ré · A3 drift · D item · Baixo + D lança para trás",Vector2(width/2,height*0.78),13,WHITE)
			centered("Solte o drift após a barra carregar para ganhar miniturbo.",Vector2(width/2,height*0.78+26),14,CYAN)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func _draw_player(r: Dictionary,p: int,x: float,width: float,height: float) -> void:
	panel(Rect2(x+16,58,213,74))
	var texture: Texture2D = game.portrait(int(r.character),int(r.skin))
	if texture != null:
		draw_texture_rect(texture,Rect2(x+23,64,59,61),false)
	label("JOGADOR "+str(p+1),Vector2(x+92,80),10,CYAN)
	var small_name: String = str(r.name).replace("VITOR DO ","V. ")
	label(small_name,Vector2(x+92,103),17,WHITE)
	label("VOLTA %d / 3" % [mini(3,int(r.lap))],Vector2(x+92,122),13,WHITE)
	panel(Rect2(x+width-104,58,88,74))
	label(str(r.rank)+"º",Vector2(x+width-92,108),43,CYAN if int(r.rank)==1 else WHITE)
	label("/ "+str(game.racers.size()),Vector2(x+width-38,116),13,WHITE)
	# Personal inventory has a prominent pictogram and clear action key.
	panel(Rect2(x+width-164,height-139,148,93),Color(0.02,0.12,0.23,0.92),CYAN if int(r.item)>0 else Color("365970"))
	var item: int = int(r.item)
	var icon_center: Vector2 = Vector2(x+width-90,height-108)
	_draw_item(item,icon_center)
	centered(game.item_name(r) if item>0 else "PEGUE UMA CAIXA",Vector2(x+width-90,height-65),11,CYAN if item>0 else Color("9bb6c8"))
	var speed: int = int(absf(float(r.speed))*5.0)
	label(str(speed),Vector2(x+22,height-72),52,WHITE)
	label("KM/H",Vector2(x+25,height-51),12,CYAN)
	var bar_width: float = 118
	panel(Rect2(x+22,height-161,bar_width,6),Color(0.02,0.1,0.2,0.7))
	draw_rect(Rect2(x+22,height-161,bar_width*clampf(float(r.drift)/1.8,0,1),6),Color("ffc663") if float(r.drift)<0.7 else CYAN)
	label("DRIFT → TURBO",Vector2(x+22,height-171),10,CYAN)
	if float(r.boost)>0:
		label("TURBO",Vector2(x+25,height-133),17,CYAN)
	if float(r.shield)>0:
		label("ESCUDO %ds"%int(ceil(r.shield)),Vector2(x+25,height-191),12,CYAN)
	if r.offroad:
		centered("FORA DO ASFALTO",Vector2(x+width/2,height*0.69),13,Color("ffcc76"))
	if r.wrongway:
		centered("SENTIDO CONTRÁRIO",Vector2(x+width/2,178),21,Color("ffd26c"))
	if float(r.notice_time)>0 and game.phase=="race":
		centered(r.notice,Vector2(x+width/2,height*0.36),24,CYAN if float(r.stun)<=0 else Color("ffcd76"))
	if float(r.hit_flash)>0:
		draw_rect(Rect2(x,44,width,height-44),Color(0.60,0.2,0.1,float(r.hit_flash)*0.35))
	panel(Rect2(x,height-34,width,34),Color(0.015,0.06,0.12,0.95))
	centered(game.control_hint(p),Vector2(x+width/2,height-13),11 if width<700 else 13,Color("d0e4ed"))
	if height>500:_draw_minimap(Vector2(x+width-104,222),Vector2(144,126),p)
	else:_draw_minimap(Vector2(x+width-310,97),Vector2(104,69),p)
	if height>500 and game.phase=="race" and float(game.elapsed)<12:
		centered("COLETE ? • USE PODERES • DERRAPE NAS CURVAS",Vector2(x+width/2,height-213),11,WHITE)

func _draw_minimap(center: Vector2,map_size: Vector2,player: int) -> void:
	panel(Rect2(center-map_size/2-Vector2(7,7),map_size+Vector2(14,26)),Color(0.015,0.06,0.13,0.77))
	var points: PackedVector2Array = []
	for point: Vector2 in game.road:
		points.append(center+Vector2(point.x/190.0*map_size.x,point.y/160.0*map_size.y))
	points.append(points[0])
	draw_polyline(points,Color("54798d"),5,true)
	draw_polyline(points,Color("9ec6d7"),1,true)
	for r: Dictionary in game.racers:
		var point: Vector2 = center+Vector2(r.pos.x/190.0*map_size.x,r.pos.y/160.0*map_size.y)
		draw_circle(point,4.5 if int(r.id)==player else 3.0,CYAN if int(r.id)==player else (Color("ffc974") if r.human else Color("dbe6ea")))
	label("CIRCUITO / POSIÇÕES",center+Vector2(-map_size.x/2,map_size.y/2+13),9,CYAN)

func _draw_item(item: int,center: Vector2) -> void:
	match item:
		0:
			centered("?",center+Vector2(0,12),38,Color("758fa6"))
		1:
			draw_circle(center,13,CYAN)
			draw_circle(center-Vector2(3,2),7,WHITE)
			for i: int in range(3):
				draw_line(center+Vector2(-33,-7+i*7),center+Vector2(-18,-7+i*7),CYAN,3)
		2:
			for i: int in range(3):
				var xx: float = -21+i*18
				draw_polyline(PackedVector2Array([center+Vector2(xx-5,-15),center+Vector2(xx+8,0),center+Vector2(xx-5,15)]),CYAN,5,true)
		3:
			var points: PackedVector2Array = PackedVector2Array([center+Vector2(-15,-16),center+Vector2(15,-16),center+Vector2(13,6),center+Vector2(0,19),center+Vector2(-13,6),center+Vector2(-15,-16)])
			draw_polyline(points,CYAN,4,true)
		4:
			draw_colored_polygon(PackedVector2Array([center+Vector2(3,-21),center+Vector2(-15,4),center+Vector2(-2,3),center+Vector2(-6,21),center+Vector2(17,-6),center+Vector2(4,-4)]),Color("d6b7ff"))
		5:
			var points: PackedVector2Array = []
			for i: int in range(24):
				var angle: float = float(i)*TAU/24.0
				points.append(center+Vector2(cos(angle)*25.0,sin(angle)*10.0))
			draw_colored_polygon(points,Color("779ab2"))
		7:
			draw_circle(center,23,Color("3583b9"))
			centered("UFN",center+Vector2(0,7),17,WHITE)
		6:
			draw_rect(Rect2(center-Vector2(23,9),Vector2(41,23)),Color("b89166"))
			draw_circle(center+Vector2(20,-4),12,Color("cca177"))
			draw_circle(center+Vector2(20,-15),4,Color("cca177"))
			draw_circle(center+Vector2(26,-6),2,INK)

func refresh_menu() -> void:
	if is_instance_valid(menu):
		menu.queue_free()
		menu = null
	if not game.paused and game.phase!="results":
		return
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation",12)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.position = Vector2(-175,155 if game.phase=="results" else -25)
	menu.custom_minimum_size = Vector2(350,0)
	add_child(menu)
	if game.phase!="results":
		_button("CONTINUAR CORRIDA",func()->void:game.toggle_pause())
	if game.phase=="results" and game.race_mode=="championship" and game.track_id<3:
		_button("PRÓXIMA ETAPA",func()->void:game.next_race())
	else:
		_button("CORRER NOVAMENTE",func()->void:game.restart())
	_button("VOLTAR AO MENU",func()->void:game.leave())
	menu.get_child(0).grab_focus()

func _button(text_value: String,callback: Callable) -> void:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(350,48)
	button.add_theme_font_size_override("font_size",16)
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color("063962")
	normal.border_color = Color("3887af")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	var hovered: StyleBoxFlat = normal.duplicate()
	hovered.bg_color = Color("087abd")
	hovered.border_color = CYAN
	button.add_theme_stylebox_override("normal",normal)
	button.add_theme_stylebox_override("hover",hovered)
	button.add_theme_stylebox_override("focus",hovered)
	button.add_theme_color_override("font_color",WHITE)
	button.pressed.connect(callback)
	menu.add_child(button)
