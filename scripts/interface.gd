extends Node2D
## Deliberately drawn interface: the game has no editor-default controls.
const BOLD = preload("res://assets/fonts/Rajdhani-Bold.ttf")
const MEDIUM = preload("res://assets/fonts/Rajdhani-Medium.ttf")
const INK = Color("06172d")
const WHITE = Color("edf4f8")
const MUTED = Color("a0b7d0")
const GOLD = Color("99c8f5")
const CYAN = Color("9bd7ff")
const RED = Color("ffb58f")
var text_scale = 1.0
var logo: Texture2D
var app: Node
var _roster_cache: Dictionary = {}

func tx(s: String, x: float, y: float, size: int = 24, color: Color = WHITE, width: float = -1, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, bold: bool = true) -> void:
	draw_string(BOLD if bold else MEDIUM,Vector2(x,y),s,align,width,roundi(size*text_scale) if size<=24 else size,color)

func center(s: String, y: float, size: int = 24, color: Color = WHITE, x: float = 0, width: float = 1280) -> void:
	tx(s,x,y,size,color,width,HORIZONTAL_ALIGNMENT_CENTER)

func line(a: Vector2,b: Vector2,color: Color = Color("2a394b"),width: float = 1.0) -> void:
	draw_line(a,b,color,width,true)

func panel(rect: Rect2, fill: Color = Color(0.025,0.045,0.075,0.94), border: Color = Color("28394b")) -> void:
	draw_rect(rect,fill)
	draw_rect(rect,border,false,1)
	draw_line(rect.position,rect.position+Vector2(24,0),GOLD,2)

func tag(label: String, x: float, y: float, color: Color = GOLD, width: float = 80) -> void:
	draw_rect(Rect2(x,y,width,25),Color(color,0.12))
	tx(label,x+8,y+19,16,color)

func keycap(label: String,x: float,y: float,color: Color = WHITE,width: float = 30) -> void:
	draw_rect(Rect2(x,y,width,28),Color(color,0.08))
	draw_rect(Rect2(x,y,width,28),Color(color,0.4),false,1)
	center(label,y+21,17,color,x,width)

func wrap_text(s: String, x: float, y: float, width: float, size: int = 22, color: Color = MUTED, leading: float = 27) -> void:
	var words = s.split(" ")
	var buffer = ""
	var row = y
	for word in words:
		var candidate = buffer+" "+word if not buffer.is_empty() else word
		if MEDIUM.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > width and not buffer.is_empty():
			tx(buffer,x,row,size,color,-1,HORIZONTAL_ALIGNMENT_LEFT,false)
			buffer = word
			row += leading
		else: buffer = candidate
	if not buffer.is_empty(): tx(buffer,x,row,size,color,-1,HORIZONTAL_ALIGNMENT_LEFT,false)

func info(id: int) -> Dictionary:
	if not _roster_cache.has(id):
		_roster_cache[id] = app.fighter_info(id)
	return _roster_cache[id]

func fighter_color(id: int) -> Color:
	return Color(str(info(id).get("color","6de2f4")))

func topbar(section: String, number: String = "01") -> void:
	draw_rect(Rect2(0,0,1280,66),Color(.015,.05,.10,.94))
	if logo==null and ResourceLoader.exists("res://assets/ufn-logo.png"):logo=load("res://assets/ufn-logo.png")
	if logo!=null:draw_texture_rect(logo,Rect2(40,19,105,35),false)
	else:tx("UFN",42,47,37,WHITE)
	line(Vector2(166,22),Vector2(166,49),Color("477394"))
	tx("COMBATE",190,45,28,WHITE)
	tx(section,422,43,17,MUTED)
	tx("SANTA MARIA · RS",1002,43,17,MUTED,235,HORIZONTAL_ALIGNMENT_RIGHT)
	line(Vector2(40,65),Vector2(1240,65),Color("31577b"))

func footer(back: String = "VOLTAR", confirm_label: String = "CONFIRMAR") -> void:
	draw_rect(Rect2(0,664,1280,56),Color(.015,.05,.10,.97))
	line(Vector2(40,664),Vector2(1240,664))
	keycap("↑↓",44,679,MUTED,44)
	tx("NAVEGAR",100,700,17,MUTED)
	keycap(app.binding_label(0,"attack"),235,679,CYAN,38)
	keycap(app.binding_label(1,"attack"),281,679,RED,38)
	tx(confirm_label,331,700,17,MUTED)
	keycap("ESC",1053,679,MUTED,46)
	tx(back,1112,700,17,MUTED)

func shade(alpha: float = 0.76) -> void:
	draw_rect(Rect2(0,0,1280,720),Color(0.012,0.021,0.04,alpha))

func draw_background() -> void:
	draw_rect(Rect2(0,0,1280,720),INK)
	for i in range(40):
		var col=Color("003d7c").lerp(INK,i/39.0)
		draw_rect(Rect2(0,i*18,1280,19),col)
	for n in range(12):line(Vector2(680+n*90,0),Vector2(290+n*90,720),Color(.4,.69,.91,.055),1)
	for n in range(25):
		var x=fmod(n*173.5+app.clock_time*(2+n%4),1280)
		var y=fmod(n*79.4,720)
		draw_rect(Rect2(x,y,2,2),Color(.6,.8,1,.2))

func _draw() -> void:
	if app == null: return
	if not app.arena.visible: draw_background()
	match app.screen:
		"boot": draw_boot()
		"menu": draw_menu()
		"setup": draw_setup()
		"tower": draw_tower()
		"gallery": draw_gallery()
		"select": draw_select()
		"stage": draw_stages()
		"kart_stage": draw_kart_stage()
		"kart": return
		"vs": draw_vs()
		"fight": draw_hud()
		"pause":
			draw_hud()
			draw_pause()
		"training_menu":
			draw_hud()
			draw_training_menu()
		"result": draw_result()
		"settings": draw_settings()
		"controls": draw_controls()
		"help": draw_help()
		"stats": draw_stats()
		"credits": draw_credits()
		"ending": draw_ending()
		"tournament": draw_tournament()
		"tournament_result": draw_bracket()
	if app.toast_timer > 0:
		panel(Rect2(420,621,440,37),Color(0.025,0.07,0.1,0.98),CYAN)
		center(app.toast,647,20,CYAN,420,440)
	# A quick fade unifies every screen transition without delaying inputs.
	if app.screen_time < 0.18:
		draw_rect(Rect2(0,0,1280,720),Color(0.005,0.008,0.016,1.0-app.screen_time/0.18))

func emblem(pos: Vector2, radius: float, alpha: float = 1.0) -> void:
	draw_arc(pos,radius,0,TAU,64,Color(CYAN,alpha*.45),2,true)
	draw_arc(pos,radius-10,0,TAU,64,Color(CYAN,alpha*.12),1,true)
	tx("UFN",pos.x-radius,pos.y+radius*.21,int(radius*.64),Color(WHITE,alpha),radius*2,HORIZONTAL_ALIGNMENT_CENTER)

func draw_boot() -> void:
	emblem(Vector2(640,262),96)
	center("UFN COMBATE",453,70)
	center("O CAMPUS É A SUA ARENA.",502,23,GOLD)
	center("Criado e desenvolvido por Diogo Liberalesso Inácio",646,19,MUTED)

func draw_menu() -> void:
	if app.arena.backgrounds.size()>0 and app.arena.backgrounds[0]!=null:
		draw_texture_rect(app.arena.backgrounds[0],Rect2(0,65,811,599),false,Color(.55,.7,.88,.58))
	draw_rect(Rect2(0,65,812,599),Color(.015,.06,.12,.45))
	draw_rect(Rect2(810,65,470,599),Color("071c34"))
	app.arena.draw_portrait(self,3,Rect2(285,255,285,355),1,false)
	app.arena.draw_portrait(self,10,Rect2(520,314,228,290),1,true)
	topbar("LUTA & VELOCIDADE  /  1–2 JOGADORES")
	tag("UNIVERSIDADE FRANCISCANA",56,104,GOLD,256)
	tx("UFN",51,227,100)
	tx("COMBATE",52,303,82)
	line(Vector2(58,327),Vector2(138,327),GOLD,4)
	tx("O CAMPUS É",57,375,27,WHITE)
	tx("A SUA ARENA.",57,410,27,WHITE)
	var descriptions=["Dez confrontos e um final para cada campeão.","Suba a torre. Enfrente André CSTH e Kelvin.","Desafie um amigo ou a CPU em melhor de três.","Duas equipes. Vida, energia e troca estratégicas.","Quatro circuitos, oito pilotos e poderes exclusivos.","Pratique golpes e ajuste seu adversário.","Aprenda os comandos na arena e na pista.","Quatro ou oito participantes. Humanos e CPU.","Uma barra de vida. Até onde você consegue ir?","Conheça o elenco, as arenas e suas conquistas.","Seu histórico de confrontos e recordes.","Imagem, áudio, acessibilidade e dispositivos.","Quatro botões. Configure seu jeito de jogar.","Criação, produção e referências do jogo.","Até o próximo combate."]
	panel(Rect2(55,558,696,81),Color(.015,.065,.126,.96),Color("3e6b94"))
	tx("14 LUTADORES  ·  8 ARENAS  ·  4 CIRCUITOS",74,585,20,GOLD)
	wrap_text(descriptions[app.menu_index],74,615,651,20,WHITE,23)
	tx("ESCOLHA SEU MODO",845,90,16,MUTED)
	for i in range(app.MENU.size()):
		var y=103+i*35
		var selected=i==app.menu_index
		if selected:draw_rect(Rect2(824,y,400,32),GOLD)
		elif i<9:draw_rect(Rect2(824,y,400,32),Color(.13,.29,.46,.19))
		tx(str(i+1).pad_zeros(2),845,y+23,16,INK if selected else MUTED)
		tx(app.MENU[i],891,y+24,22,INK if selected else WHITE)
	footer("SAIR","JOGAR")
	center("Criado e desenvolvido por Diogo Liberalesso Inácio",702,14,MUTED,442,595)

func draw_select() -> void:
	shade(.67)
	topbar("SELEÇÃO DE PERSONAGENS", "02")
	var title="ESCOLHA SUA DUPLA" if app.mode=="teams" and app.selection_phase==1 else ("ESCOLHA SEU PILOTO" if app.mode=="kart" else "ESCOLHA SEU LUTADOR")
	center(title,127,42)
	var mode_names={"arcade":"ARCADE","tower":"TORRE UFN","versus":"VERSUS LOCAL","teams":"DUPLAS · TITULARES","kart":"KART UFN","training":"TREINAMENTO","survival":"SOBREVIVÊNCIA","tournament":"TORNEIO LOCAL"}
	center("DUPLAS · RESERVAS" if app.mode=="teams" and app.selection_phase==1 else mode_names.get(app.mode,"UFN COMBATE"),157,17,GOLD)
	var complexity=["SIMPLES","SIMPLES","SIMPLES","INTERMEDIÁRIO","INTERMEDIÁRIO","SIMPLES","INTERMEDIÁRIO","SIMPLES","AVANÇADO","INTERMEDIÁRIO","AVANÇADO","INTERMEDIÁRIO","INTERMEDIÁRIO","AVANÇADO"]
	for i in range(2):
		var id:int=app.cursors[i]
		var x=20 if i==0 else 920
		var col=CYAN if i==0 else RED
		var skin:int=app.reserve_skins[i] if app.selection_phase==1 else app.skins[i]
		app.arena.draw_portrait(self,id,Rect2(x,184,340,373),1,i==1,skin)
		tag("J"+str(i+1)+(" · PRONTO" if app.ready_players[i] else " · ESCOLHENDO"),x+53,176,col,230)
		center(info(id).name,566,35,col,x,340)
		center(info(id).title,593,15,MUTED,x-8,356)
		center("USO: "+complexity[clampi(id,0,complexity.size()-1)],618,15,GOLD,x,340)
		if id==3: center(app.binding_label(i,"heavy")+" · "+("CARECA" if skin==1 else "PRINCIPAL"),642,15,WHITE,x,340)
		elif app.mode=="teams" and app.selection_phase==1:center("LÍDER · "+info(app.chosen[i]).name,642,15,WHITE,x,340)
	for i in range(app.PLAYABLE):
		var rect=Rect2(358+(i%7)*82,222+int(i/7)*149,76,139)
		panel(rect,Color("123653"),Color("3b6382"))
		app.arena.draw_portrait(self,i,Rect2(rect.position+Vector2(1,2),Vector2(74,108)),0,false)
		draw_rect(Rect2(rect.position+Vector2(0,108),Vector2(76,31)),INK)
		center(info(i).name.replace("VITOR DO ","V. "),rect.position.y+129,13,WHITE,rect.position.x,76)
		for j in range(2):
			if app.cursors[j]==i:
				var col=CYAN if j==0 else RED
				draw_rect(rect.grow(-j*3),col,false,3)
				tag("J"+str(j+1),rect.position.x+j*36,rect.position.y+3,col,39)
	center("VS" if app.mode!="kart" else "CORRIDA",557,57 if app.mode!="kart" else 43,GOLD,399,482)
	panel(Rect2(356,581,568,72),Color(.012,.04,.083,.94),Color("31577b"))
	if app.mode=="kart":
		center("A1 ACELERAR · A2 FREAR · A3 DERRAPAR · D ITEM",607,15,WHITE,361,558)
		center("CAIXAS DÃO PODERES · BAIXO + D ATIRA PARA TRÁS",635,14,MUTED,361,558)
	else:
		center("A1 LEVE · A2 FORTE · A3 CHUTE · D DEFESA",607,15,WHITE,361,558)
		center("D+A1 AGARRAR · D+A2 ULTIMATE · D+A3 TROCAR",635,14,MUTED,361,558)
	footer()

func draw_stages() -> void:
	shade(.57)
	topbar("SELEÇÃO DE ARENA", "03")
	center("O PRÓXIMO CONFRONTO É AQUI",129,38)
	for i in range(app.STAGES.size()):
		var rect=Rect2(60+i%4*294,186+int(i/4)*206,277,182)
		var selected=app.stage_cursor==i
		panel(rect,INK,GOLD if selected else Color("446887"))
		if app.arena.backgrounds.size()>i and app.arena.backgrounds[i]!=null:draw_texture_rect(app.arena.backgrounds[i],Rect2(rect.position+Vector2(2,2),Vector2(273,137)),false)
		draw_rect(Rect2(rect.position+Vector2(0,134),Vector2(277,48)),Color(.02,.08,.16,.94))
		tx(str(i+1).pad_zeros(2),rect.position.x+13,rect.position.y+165,18,GOLD)
		tx(app.STAGES[i],rect.position.x+40,rect.position.y+165,17,WHITE)
		if selected:draw_rect(rect,GOLD,false,3)
	panel(Rect2(60,596,1164,43),Color("123858"),GOLD if app.stage_cursor==8 else Color("446887"))
	center("?  ARENA ALEATÓRIA",626,23,GOLD if app.stage_cursor==8 else WHITE)
	footer()

func draw_vs() -> void:
	shade(0.82)
	var shift = maxf(0,1.0-app.screen_time*2.7)*170
	for i in range(2):
		var xx = 62-shift if i == 0 else 819+shift
		var id: int = app.chosen[i]
		var col = fighter_color(id)
		draw_colored_polygon(PackedVector2Array([Vector2(xx+10,115),Vector2(xx+400,115),Vector2(xx+330,581),Vector2(xx-60,581)]),Color(col,0.08))
		app.arena.draw_portrait(self,id,Rect2(xx,90,400,491),2,i == 1,app.skins[i])
		center(info(id).name,581,49,WHITE,xx-20,440)
		center(info(id).title,611,19,col,xx-20,440)
	center("VS",380,139,GOLD)
	center("//",415,35,MUTED)
	center(app.STAGES[app.stage],468,23,WHITE)
	topbar("VERSUS  /  PREPARE-SE", "04")
	if app.mode in ["arcade","tower"]: center(("TORRE UFN" if app.mode=="tower" else "ARCADE")+"  •  CONFRONTO "+str(app.arcade_index+1)+" / 10",103,20,GOLD)
	if app.mode=="tournament":center("TORNEIO · "+("FINAL" if app.bracket_current.size()==2 else str(app.bracket_current.size())+" CLASSIFICADOS"),103,20,GOLD)
	line(Vector2(70,653),Vector2(1210,653))
	center("PRESSIONE ATAQUE PARA AVANÇAR",692,17,MUTED)

func meter_bar(value: float,rect: Rect2,color: Color,reverse: bool = false) -> void:
	draw_rect(rect,Color(0.015,0.022,0.038,0.95))
	var amount = clampf(value,0,1)*rect.size.x
	var fill_rect = Rect2(rect.position,Vector2(amount,rect.size.y))
	if reverse: fill_rect.position.x += rect.size.x-amount
	draw_rect(fill_rect,color)
	draw_rect(Rect2(fill_rect.position,Vector2(fill_rect.size.x,2)),Color(WHITE,0.55))
	draw_rect(rect,Color(WHITE,0.2),false,1)

func draw_hud() -> void:
	if app.combat.fighters.size()<2:return
	for j in range(10):draw_rect(Rect2(0,j*15,1280,16),Color(.003,.018,.045,.93-j*.081))
	for i in range(2):
		var f: Dictionary=app.combat.fighters[i]
		var x=44 if i==0 else 771
		var col=CYAN if i==0 else RED
		var align=HORIZONTAL_ALIGNMENT_LEFT if i==0 else HORIZONTAL_ALIGNMENT_RIGHT
		tx("J"+str(i+1)+"   "+info(f.id).name,x,35,26,WHITE,465,align)
		meter_bar(float(f.hp)/float(f.max_hp),Rect2(x,47,465,23),Color("d4eaff") if f.hp>250 else RED,i==1)
		meter_bar(float(f.guard)/100,Rect2(x,77,465,4),Color("d5deea"),i==1)
		meter_bar(float(f.meter)/100,Rect2(x,90,465,9),col,i==1)
		tx("ULTIMATE PRONTO  ·  "+app.binding_label(i,"block")+" + "+app.binding_label(i,"heavy") if f.meter>=100 else "ENERGIA  "+str(int(f.meter))+"%",x,120,15,col,465,align)
		for n in range(2):
			var rx=x+402+n*20 if i==0 else x+15+n*20
			draw_circle(Vector2(rx,29),5,WHITE if n<app.wins[i] else Color("456079"))
		if app.combat.team_mode:
			var reserve: Dictionary=app.combat.reserve(i)
			var cooldown:int=app.combat.tag_cooldowns[i]
			meter_bar(float(reserve.hp)/1000,Rect2(x,132,190,5),Color("80adce"),i==1)
			tx(info(reserve.id).name+"  ·  "+("FORA" if reserve.hp<=0 else (str(ceili(cooldown/60.0))+"s" if cooldown>0 else app.binding_label(i,"block")+" + "+app.binding_label(i,"kick"))),x,154,14,MUTED,465,align)
		elif f.id==2:tx("MUNIÇÃO  "+str(f.ammo)+" / 6",x,146,15,col,465,align)
		elif f.id==13:tx("URSO · POSTURA "+str(int(f.bear_posture))+"%"+(" · REAGRUPANDO" if f.bear_stun>0 else ""),x,146,15,col,465,align)
		elif f.id==11:tx("EMBALO "+str(f.embalo)+" / 3",x,146,15,col,465,align)
		elif f.id==1:tx("RAIVA  "+str(int(f.rage))+"%",x,146,15,col,465,align)
		elif int(f.get("transform",0))>0:tx("EXO ATIVO  "+str(ceili(f.transform/60.0))+"s",x,146,15,col,465,align)
		if f.combo>=2:
			var cx=80 if i==0 else 1003
			tx(str(f.combo),cx,256,62,col)
			tx("ACERTOS",cx+68,236,23,WHITE)
			tx(str(int(f.combo_damage))+" DANO",cx+70,261,17,MUTED)
	center("∞" if app.mode=="training" else str(ceili(app.combat.time_frames/60.0)).pad_zeros(2),83,66)
	center("ROUND "+str(app.round_number),112,15,GOLD)
	if app.intro_frames>0:
		if app.intro_frames>120:
			for i in range(2):center("“"+str(info(app.chosen[i]).quote)+"”",366+i*40,23,WHITE)
		else:center("LUTEM!" if app.intro_frames<=60 else ("ROUND FINAL" if app.is_final_round() and app.round_number>1 else "ROUND "+str(app.round_number)),362,88,WHITE)
	if app.round_end_timer>0:
		shade(.34)
		center("TEMPO!" if app.combat.time_frames<=0 else "K.O.",373,141,WHITE)
		center("EMPATE · NOVO ROUND" if app.combat.winner==2 else info(app.combat.fighters[app.combat.winner].id).name+" VENCE",429,30,GOLD)
	for n in app.notices:
		var x=53 if n.player==0 else 829
		tx(n.text,x,194-n.age*16,25,Color(GOLD,minf(1,(1.3-n.age)*2)),400,HORIZONTAL_ALIGNMENT_LEFT if n.player==0 else HORIZONTAL_ALIGNMENT_RIGHT)
	for f in app.combat.fighters:
		if f.state=="super":
			draw_rect(Rect2(0,598,1280,48),Color(.003,.016,.038,.94))
			center(str(info(f.id).super),631,29,fighter_color(f.id))
	draw_rect(Rect2(0,672,1280,48),Color(.012,.04,.083,.96))
	for i in range(2):
		var x=38 if i==0 else 879
		var col=CYAN if i==0 else RED
		tx(app.binding_label(i,"attack")+" / "+app.binding_label(i,"heavy")+" / "+app.binding_label(i,"kick")+"  GOLPES     "+app.binding_label(i,"block")+"  DEFESA",x,701,16,col)
	center("ESC  PAUSA" if app.mode!="training" else "TAB  TREINO  ·  F2  REINICIAR",701,16,MUTED,454,372)
	if app.mode=="attract":
		center("UFN COMBATE",565,53,WHITE)
		center("PRESSIONE QUALQUER BOTÃO",625,25,GOLD)
	if app.mode=="training":draw_training_hud()
	if app.debug_view:draw_debug()

func draw_training_hud() -> void:
	if app.tutorial:
		var a=app.binding_label(0,"attack");var b=app.binding_label(0,"heavy");var k=app.binding_label(0,"kick");var d=app.binding_label(0,"block")
		var messages=["MOVIMENTE-SE · ESQUERDA E DIREITA","ACERTE TRÊS GOLPES · "+a+" / "+b+" / "+k,"DEFENDA EM PÉ · SEGURE "+d,"DEFENDA AGACHADO · BAIXO + "+d,"AGARRE PERTO · "+d+" + "+a,"ESPECIAL · BAIXO, FRENTE + "+a,"CONECTE UM COMBO DE DOIS GOLPES","ULTIMATE · "+d+" + "+b,"TROQUE A DUPLA · "+d+" + "+k,"VAMOS À PISTA · CONFIRME PARA PRATICAR"]
		panel(Rect2(263,195,754,56),Color(.02,.04,.07,.95),GOLD)
		center(str(mini(10,app.tutorial_step+1))+" / 10    "+messages[mini(9,app.tutorial_step)],231,22,WHITE)
	else:
		tag("TREINO",565,190,GOLD,150)
	var f: Dictionary = app.combat.fighters[0]
	panel(Rect2(44,377,218,239),Color(0.016,0.028,0.05,0.85))
	tx("ÚLTIMOS COMANDOS",60,403,18,GOLD)
	for i in range(app.input_history[0].size()):
		var command=str(app.input_history[0][i]).to_upper()
		for action in {"ATTACK":"A1","HEAVY":"A2","KICK":"A3","BLOCK":"D","LEFT":"←","RIGHT":"→","UP":"↑","DOWN":"↓"}:
			command=command.replace(action,{"ATTACK":"A1","HEAVY":"A2","KICK":"A3","BLOCK":"D","LEFT":"←","RIGHT":"→","UP":"↑","DOWN":"↓"}[action])
		tx(command,60,432+i*22,15,MUTED)
	if not f.move.is_empty():
		panel(Rect2(940,390,298,164),Color(0.016,0.028,0.05,0.87))
		tx(str(f.move.name),959,420,23,GOLD)
		tx("PREPARAÇÃO / ATIVO / RECUPERAÇÃO",959,451,15,MUTED)
		tx("%s  /  %s  /  %s QUADROS"%[f.move.get("startup",0),f.move.get("active",0),f.move.get("recovery",0)],959,481,22)
		tx("DANO "+str(f.move.get("damage",0))+"    GUARDA "+str(f.move.get("guard_damage",0)),959,518,18,MUTED)

func draw_debug() -> void:
	panel(Rect2(390,505,505,127),Color(0.012,0.02,0.03,0.97),CYAN)
	tx("DEBUG  /  "+str(Engine.get_frames_per_second())+" FPS  /  60 HZ",404,532,18,CYAN)
	for i in range(2):
		var f: Dictionary = app.combat.fighters[i]
		tx("P%d %s  f:%d  x:%.1f y:%.1f v:(%.1f,%.1f)"%[i+1,f.state,f.frame,f.x,f.y,f.vel.x,f.vel.y],404,557+i*22,16,WHITE)
	tx("F3 FECHA  •  VERDE CORPO / VERMELHO ATAQUE / AZUL COLISÃO",404,611,13,MUTED)

func choice_list(options: Array,selected: int,x: float,y: float,width: float = 400,step: float = 48) -> void:
	for i in range(options.size()):
		if i == selected:
			draw_rect(Rect2(x,y+i*step-28,width,40),GOLD)
			tx("›",x+12,y+i*step+1,30,INK)
		tx(str(options[i]),x+38,y+i*step,24,INK if i == selected else WHITE)

func draw_pause() -> void:
	shade(0.86)
	panel(Rect2(370,115,540,511))
	tx("PAUSADO",407,178,43)
	tx("A ARENA ESPERA POR VOCÊ",409,207,17,MUTED)
	var options = ["CONTINUAR", "CONTROLES", "LISTA DE GOLPES", "REINICIAR PARTIDA", "SELEÇÃO", "MENU PRINCIPAL"]
	if app.mode == "training": options.insert(3,"OPÇÕES DE TREINO")
	choice_list(options,app.pause_index,402,259,476,47)

func draw_result() -> void:
	shade(0.88)
	var winner: int = maxi(0,app.match_winner)
	var id: int = app.chosen[winner]
	app.arena.draw_portrait(self,id,Rect2(64,99,490,543),3,false)
	topbar("RESULTADO DA PARTIDA", "05")
	tag("JOGADOR "+str(winner+1)+" VENCE",644,146,GOLD,182)
	tx(info(id).name,637,247,65)
	tx("VITÓRIA",641,301,42,fighter_color(id))
	tx(str(app.wins[0])+"  —  "+str(app.wins[1]),642,356,39,WHITE)
	tx("PONTUAÇÃO "+str(app.survival_score)+" · VITÓRIAS "+str(app.survival_wave+(1 if app.match_winner==0 else 0)) if app.mode=="survival" else "MAIOR COMBO "+str(app.event_counts.biggest_combo)+" HIT",642,395,21,MUTED)
	choice_list(app.result_options(),app.result_index,634,474,528,52)
	footer("MENU", "CONTINUAR")

func draw_settings() -> void:
	topbar("CONFIGURAÇÕES")
	tx("SEU JOGO. SEU ESTILO.",65,129,46)
	tx("Alterações salvas automaticamente. ← → ajusta · ↑ ↓ escolhe",68,163,21,MUTED)
	var s:Dictionary=app.profile.data.settings
	var values=[str(roundi(s.master*100))+"%",str(roundi(s.music*100))+"%",str(roundi(s.sfx*100))+"%",str(roundi(s.voice*100))+"%","SIM" if s.fullscreen else "NÃO","1280 × 720" if s.resolution==0 else "1920 × 1080","PADRÃO" if s.quality==0 else "LEVE",str(roundi(s.shake*100))+"%",str(roundi(s.flashes*100))+"%",str(roundi(s.particles*100))+"%","SIM" if s.subtitles else "NÃO","PADRÃO" if s.text_size==0 else "AMPLIADO",app.DIFFICULTIES[s.difficulty],"SIM" if s.auto_accelerate else "NÃO","SIM" if s.split_horizontal else "NÃO","→","→","→"]
	for i in app.settings_entries.size():
		var x=64+int(i/9)*588
		var y=222+(i%9)*47
		if i==app.settings_index:draw_rect(Rect2(x,y-28,561,39),Color(GOLD,.16))
		tx(app.settings_entries[i],x+13,y,21,GOLD if i==app.settings_index else WHITE)
		tx(values[i],x+360,y,21,GOLD if i==app.settings_index else MUTED,183,HORIZONTAL_ALIGNMENT_RIGHT)
	footer("MENU","ALTERAR")

func draw_controls() -> void:
	topbar("CONTROLES E REMAPEAMENTO", "07")
	tx("DOIS JOGADORES. SEU ESTILO.",65,126,43)
	tx("←  JOGADOR "+str(app.controls_player+1)+"  →",867,166,26,CYAN if app.controls_player==0 else RED)
	var labels=["PULAR / CIMA","AGACHAR / BAIXO","ESQUERDA","DIREITA","A1 · LEVE / ACELERAR","A2 · FORTE / FREAR","A3 · CHUTE / DRIFT","D · DEFESA / ITEM","RESTAURAR PADRÕES","PERFIL SEM NUMÉRICO","DISPOSITIVO: "+str(app.input.devices[app.controls_player]).to_upper(),"ATRIBUIR CONTROLE USB","REMAPEAR: "+("KART" if app.controls_kart else "LUTA"),"GUIA DE COMANDOS","VOLTAR"]
	tx("TECLA",510,168,15,MUTED);tx("PAD",626,168,15,MUTED)
	for i in range(labels.size()):
		var y=187+i*30
		if i==app.controls_index:draw_rect(Rect2(66,y-24,635,30),Color(GOLD,.16))
		tx(labels[i],83,y,19,GOLD if i==app.controls_index else WHITE)
		if i<8:
			keycap(app.control_binding(app.controls_player,app.controls_actions[i]),494,y-23,CYAN if app.controls_player==0 else RED,115)
			keycap(str(app.input.get_gamepad_binding(app.controls_player,app.controls_actions[i],app.controls_kart)),621,y-23,GOLD,54)
	panel(Rect2(743,203,472,235))
	tx("TECLADO + GAMEPADS",766,240,25,GOLD)
	wrap_text("Selecione a ação e confirme. Depois pressione a nova tecla ou botão do controle. O remapeamento é salvo neste computador.",766,279,422,23,WHITE,28)
	wrap_text("Direcional e analógico movem. Start pausa. PAD mostra o índice do botão conectado.",766,379,422,21,MUTED,26)
	tx("TESTE DE TECLAS SIMULTÂNEAS",756,483,21,GOLD)
	for j in range(2):
		var held: Array=[]
		for action in app.controls_actions:
			if Input.is_physical_key_pressed(app.input.get_binding(j,action)):held.append(app.binding_label(j,action))
		tx("J"+str(j+1)+"   [ "+"  ".join(held)+" ]",756,522+j*34,22,CYAN if j==0 else RED)
	wrap_text("ESPECIAIS · ↓ → + leve · ↓ ← + leve · ↓ ↓ + forte. Frente e trás seguem o rival.",756,600,450,20,MUTED,24)
	footer("VOLTAR","REMAPEAR")
	if app.capturing_binding:
		shade(.93)
		panel(Rect2(270,242,740,206),INK,GOLD)
		center("PRESSIONE A TECLA OU BOTÃO",311,36,GOLD)
		center(labels[app.controls_index]+"  /  JOGADOR "+str(app.controls_player+1),358,26)
		center("ESC / BACK cancela",406,20,MUTED)

func draw_help() -> void:
	topbar("COMO JOGAR  /  ← → TROCA A PÁGINA", "08")
	if app.help_page==0:
		tx("ENTRE NA ARENA.",64,137,53)
		tx("ENCONTRE SEU ESTILO.",64,187,49,GOLD)
		var titles=["01  MOVIMENTAÇÃO","02  GOLPES E GUARDA","03  ESPECIAIS","04  ULTIMATE E DUPLAS"]
		var bodies=["J1: W A S D. J2: setas. Cima pula, baixo agacha. Toque duas vezes uma direção para avançar rápido.","J1: J leve, K forte, L chute, U defesa. J2: Num1, Num2, Num3 e Num4. Agache ou salte para variar os golpes.","↓ → + leve: especial 1. ↓ ← + leve: especial 2. ↓ ↓ + forte: especial 3. Complete o movimento em 300 ms, seguindo a direção do rival.","D + A2: ultimate com 100% de energia. D + A3: troca de dupla a cada 5 segundos. D + A1: agarrão. Segure a defesa antes de tocar o ataque."]
		for i in range(4):
			var x=65+i%2*588
			var y=229+int(i/2)*186
			panel(Rect2(x,y,558,167))
			tx(titles[i],x+20,y+36,25,GOLD)
			wrap_text(bodies[i],x+20,y+72,513,22,WHITE,27)
	elif app.help_page==1:
		tx("TÉCNICA GANHA CONFRONTOS.",64,137,46)
		var rows=[["DEFESA PERFEITA","Defenda nos últimos 5 frames antes do impacto. Frente + defesa nos últimos 3 frames executa um desvio."],["QUEBRA DE GUARDA","Pressionar a guarda esgotada abre uma janela de punição. Afaste-se e solte a defesa para recuperá-la."],["AGARRÃO","Leve + defesa perto do rival. A vítima pode repetir a combinação na janela inicial para escapar."],["COMBOS","Confirme um normal e cancele em especial. Dano e tempo de atordoamento diminuem; o afastamento e limites encerram sequências."],["ENERGIA E DUPLAS","Acertar, defender e receber golpes gera energia. Nas duplas, cada lutador mantém vida e energia. O reserva entra automaticamente no K.O."],["UFN KART","A1 acelera, A2 freia e engata ré, A3 faz drift e D usa item. Baixo + D lança para trás. Oito pilotos, três voltas. ESC pausa."]]
		for i in range(6):
			var y=192+i*75
			tx(rows[i][0],66,y,22,GOLD)
			wrap_text(rows[i][1],367,y,830,21,WHITE,24)
			line(Vector2(65,y+47),Vector2(1210,y+47))
	else:
		var id:int=app.help_page-2
		var data=info(id)
		tx(data.name,64,138,49)
		tx(data.title,65,174,21,fighter_color(id))
		app.arena.draw_portrait(self,id,Rect2(45,208,365,401),1,false)
		var names=["↓ → + SOCO LEVE","↓ ← + SOCO LEVE","↓ ↓ + SOCO FORTE"]
		tx("COMANDO",442,230,17,MUTED);tx("ESPECIAL",723,230,17,MUTED);tx("ENERGIA",1120,230,16,MUTED)
		for i in range(3):
			var move:Dictionary=data.specials[i]
			var y=279+i*82
			tx(names[i],442,y,22,WHITE)
			tx(str(move.name),723,y,22,fighter_color(id))
			tx(str(int(move.cost))+"%",1120,y,22,MUTED)
			tx("DANO "+str(int(move.damage))+"   ·   PREPARAÇÃO "+str(move.startup)+" QUADROS",723,y+26,15,MUTED)
			line(Vector2(441,y+43),Vector2(1204,y+43))
		tag("ULTIMATE  ·  100%",442,517,GOLD,200)
		tx(str(data.super),442,582,37,GOLD)
		tx("D + A2 · DEFESA + ATAQUE FORTE · 100% DE ENERGIA",442,617,17,MUTED)
	footer("VOLTAR","TUTORIAL" if app.previous_screen=="menu" else "")
	center(str(app.help_page+1)+" / 18",701,18,GOLD)

func draw_training_menu() -> void:
	shade(0.9)
	panel(Rect2(300,105,680,535))
	tx("LABORATÓRIO DE TREINO",332,187,38)
	var opt: Dictionary = app.train_options
	var values = [["PARADO","DEFENDENDO","PULANDO","ATACANDO","IA"][int(opt.dummy)],"SIM" if opt.health else "NÃO","SIM" if opt.meter else "NÃO","SIM" if opt.guard else "NÃO","SIM" if opt.boxes else "NÃO",info(app.chosen[1]).name,"→","→"]
	for i in range(app.TRAIN_OPTIONS.size()):
		var yy = 247+i*47
		if i == app.train_index: draw_rect(Rect2(326,yy-29,628,40),Color(GOLD,0.14))
		var label=str(app.TRAIN_OPTIONS[i]).replace("HITBOXES","ÁREAS DE COLISÃO").replace("RESET DE POSIÇÃO","REPOSICIONAR")
		tx(label,345,yy,24,GOLD if i == app.train_index else WHITE)
		tx(values[i],720,yy,18,MUTED,215,HORIZONTAL_ALIGNMENT_RIGHT)

func draw_stats() -> void:
	topbar("ESTATÍSTICAS", "09")
	tx("SUA HISTÓRIA NA UFN",64,137,47)
	var s: Dictionary = app.profile.data.stats
	var most = "—"
	var maximum = 0
	for k in s.get("most_played",{}):
		if int(s.most_played[k]) > maximum:
			maximum = int(s.most_played[k])
			most = str(info(int(k)).name)
	var labels = ["PARTIDAS JOGADAS","VITÓRIAS P1","VITÓRIAS P2","MAIOR COMBO","DEFESAS PERFEITAS","QUEBRAS DE GUARDA","ULTIMATES UTILIZADOS","MAIS JOGADO"]
	var values = [str(s.get("matches",0)),str(s.get("p1_wins",0)),str(s.get("p2_wins",0)),str(s.get("biggest_combo",0))+" HIT",str(s.get("perfect_blocks",0)),str(s.get("guard_breaks",0)),str(s.get("supers",0)),most]
	for i in range(8):
		var xx = 65+(i%4)*294
		var yy = 204+int(i/4)*199
		panel(Rect2(xx,yy,272,175))
		tx(labels[i],xx+20,yy+39,18,MUTED)
		tx(values[i],xx+20,yy+113,46 if i != 7 else 28,GOLD)
	footer("MENU","VOLTAR")

func draw_credits() -> void:
	topbar("CRÉDITOS", "10")
	tx("UFN COMBATE",64,157,67)
	tx("UM JOGO COM A CARA DO NOSSO CAMPUS",67,199,24,GOLD)
	tx("Feito por Diogo Liberalesso Inácio",65,263,39,WHITE)
	tx("Criado e desenvolvido por Diogo Liberalesso Inácio",67,299,21,GOLD)
	panel(Rect2(65,328,774,124),Color("0a2948"),Color("31577b"))
	tx("PARA CONTATO OU FEEDBACK",84,359,19,GOLD)
	tx("Fale no Instagram @diogok_i",84,396,26,WHITE)
	tx("ou pelo e-mail diogolib.inacio200@gmail.com!",84,430,25,WHITE)
	wrap_text("Personagens e referências fornecidos pelo criador. Programação e produção assistidas por IA. Base de combate adaptada do projeto Nexus Kombat.",69,489,766,21,WHITE,27)
	wrap_text("Cenários: releituras em pixel art da UFN e de Santa Maria, além de espaços temáticos. Sprites: folhas fornecidas. Música e efeitos: síntese original.",69,571,766,20,MUTED,26)
	tx("GODOT 4 · MIT     /     RAJDHANI · SIL OPEN FONT LICENSE",69,640,17,MUTED)
	emblem(Vector2(1038,353),119)
	center("UNIVERSIDADE",532,20,WHITE,882,310)
	center("FRANCISCANA",559,20,WHITE,882,310)
	footer("MENU","VOLTAR")

func draw_ending() -> void:
	shade(0.87)
	var id: int = app.chosen[0]
	app.arena.draw_portrait(self,id,Rect2(67,94,452,545),3,false)
	topbar("ARCADE CONCLUÍDO", "11")
	tag("CAMPEÃO DO CAMPUS",606,159,GOLD,249)
	tx(info(id).name,600,245,62)
	wrap_text(str(info(id).ending),606,321,574,28,WHITE,37)
	wrap_text("O campeonato termina. A próxima história começa no campus.",606,502,550,23,MUTED,30)
	center("PRESSIONE ATAQUE PARA VOLTAR AO MENU",695,20,GOLD)

func draw_tournament() -> void:
	shade(.74)
	topbar("TORNEIO LOCAL / INSCRIÇÃO")
	tx(str(app.tournament_size)+" PARTICIPANTES. UM CAMPEÃO.",63,124,44)
	tx("ESCOLHA O PARTICIPANTE "+str(app.tournament_roster.size()+1)+" / "+str(app.tournament_size),65,164,22,GOLD)
	tx(app.binding_label(0,"heavy")+"  TIPO: "+("CPU" if app.entry_cpu else "HUMANO"),865,164,22,CYAN)
	for i in app.PLAYABLE:
		var rect=Rect2(65+(i%7)*165,205+int(i/7)*156,149,145)
		panel(rect,Color("123653"),GOLD if i==app.tournament_cursor else Color("3d6382"))
		app.arena.draw_portrait(self,i,Rect2(rect.position+Vector2(25,2),Vector2(99,111)),0,false)
		center(info(i).name,rect.position.y+132,16,GOLD if i==app.tournament_cursor else WHITE,rect.position.x,149)
	for i in app.tournament_size:
		var x=65+(i%4)*294
		var y=532+int(i/4)*53
		tx(str(i+1)+"  "+(info(app.tournament_roster[i]).name+(" · CPU" if app.tournament_cpu[i] else " · HUMANO") if i<app.tournament_roster.size() else "AGUARDANDO"),x,y,18,GOLD if i<app.tournament_roster.size() else MUTED)
	footer("MENU","INSCREVER")

func draw_bracket() -> void:
	topbar("TORNEIO / CHAVEAMENTO")
	var complete=app.bracket_current.size()==1
	center("CAMPEÃO DA UFN" if complete else "A DISPUTA CONTINUA",139,44,GOLD)
	if complete:
		var id=app.tournament_roster[app.bracket_current[0]]
		app.arena.draw_portrait(self,id,Rect2(454,180,372,351),3,false)
		center(info(id).name,591,42,GOLD)
	else:
		for i in app.bracket_current.size():
			var x=140+int(i/4)*550
			var y=229+(i%4)*88
			var slot=app.bracket_current[i]
			panel(Rect2(x,y,445,63),INK,CYAN if int(i/2)==app.bracket_match else MUTED)
			tx(info(app.tournament_roster[slot]).name+ (" · CPU" if app.tournament_cpu[slot] else " · HUMANO"),x+20,y+40,24)
		center("PRÓXIMA DISPUTA · "+str(app.bracket_match+1)+" / "+str(app.bracket_current.size()/2),606,23,GOLD)
	footer("MENU","CONTINUAR")

func draw_kart_stage() -> void:
	topbar("KART UFN / "+str(app.kart_players)+" JOGADORES")
	center("DO CAMPUS PARA A PISTA",131,44)
	center("3 VOLTAS · 8 PILOTOS · CAIXAS DE PODER",165,20,GOLD)
	for i in 4:
		var x=65+(i%2)*589
		var y=199+int(i/2)*216
		var r=Rect2(x,y,560,197)
		panel(r,INK,GOLD if app.stage_cursor==i else Color("47718f"))
		var bg=[0,7,2,4][i]
		if app.arena.backgrounds[bg]!=null:draw_texture_rect(app.arena.backgrounds[bg],Rect2(x+2,y+2,556,153),false)
		draw_rect(Rect2(x,y+149,560,48),Color(.012,.046,.1,.96))
		tx(app.KART_TRACKS[i],x+20,y+181,26,GOLD if app.stage_cursor==i else WHITE)
	footer("SELEÇÃO","CORRER")

func draw_setup() -> void:
	topbar("PREPARAR / "+app.setup_kind.to_upper())
	tx("MONTE SUA DISPUTA",70,148,49)
	var descriptions={"tower":"Dez andares. Oito rivais, André CSTH e Kelvin. Seu progresso fica salvo ao avançar.","versus":"Escolha um amigo no mesmo computador ou a CPU. Depois selecione os dois lutadores e a arena.","tournament":"Inscreva quatro ou oito participantes e escolha quem será controlado por humanos ou pela CPU.","kart":"Corrida rápida, campeonato de quatro etapas ou contrarrelógio solo. Oito pilotos disputam três voltas."}
	wrap_text(descriptions[app.setup_kind],74,212,430,27,MUTED,34)
	emblem(Vector2(282,478),100)
	choice_list(app.setup_options(),app.setup_index,554,223,652,57)
	footer("MENU","ESCOLHER")

func draw_tower() -> void:
	topbar("TORRE UFN / "+app.DIFFICULTIES[int(app.profile.data.settings.difficulty)])
	tx("CONQUISTE O CAMPUS",65,129,47)
	app.arena.draw_portrait(self,app.chosen[0],Rect2(55,203,346,370),1,false,app.skins[0])
	center(info(app.chosen[0]).name,614,33,CYAN,55,346)
	for i in app.arcade_order.size():
		var x=455+int(i/5)*385
		var y=191+(i%5)*85
		var id=app.arcade_order[i]
		panel(Rect2(x,y,354,68),Color("103859") if i==app.arcade_index else INK,GOLD if i==app.arcade_index else Color("355771"))
		app.arena.draw_portrait(self,id,Rect2(x+9,y+3,54,62),0,false)
		tx(str(i+1).pad_zeros(2)+"  "+info(id).name,x+78,y+29,23,GOLD if i==app.arcade_index else WHITE)
		tx("CONCLUÍDO" if i<app.arcade_index else ("PRÓXIMO COMBATE" if i==app.arcade_index else ("CHEFE" if id>=app.PLAYABLE else "DESAFIANTE")),x+78,y+51,14,MUTED)
	footer("SALVAR E VOLTAR","LUTAR")

func draw_gallery() -> void:
	topbar("GALERIA / ↑ ↓ CATEGORIA · ← → NAVEGAR")
	var categories=["LUTADORES E CHEFES","ARENAS DE SANTA MARIA","CONQUISTAS E RECORDES"]
	tx(categories[app.gallery_tab],65,128,43)
	if app.gallery_tab==0:
		var id=app.gallery_index
		var data=info(id)
		app.arena.draw_portrait(self,id,Rect2(72,174,390,441),1,false,app.skins[0] if id==3 else 0)
		tx(data.name,534,226,49,GOLD)
		tx("CHEFE DA TORRE · NÃO JOGÁVEL" if id>=app.PLAYABLE else data.title,537,271,22,MUTED)
		wrap_text(data.quote,537,333,620,30,WHITE,37)
		wrap_text(data.ending,537,425,620,23,MUTED,30)
		tx("ULTIMATE · "+data.super,537,583,24,GOLD)
		if id==3:tx(app.binding_label(0,"heavy")+" TROCA SKIN",537,625,19,WHITE)
	elif app.gallery_tab==1:
		var id=app.gallery_index
		draw_texture_rect(app.arena.backgrounds[id],Rect2(65,161,765,429),false)
		wrap_text(app.STAGES[id],869,230,324,37,WHITE,44)
		wrap_text(app.STAGE_SUB[id],869,360,315,24,MUTED,31)
		tx("Releitura artística · referências documentadas no projeto",65,627,20,MUTED)
	else:
		var achievements=app.profile.data.progress.achievements
		if achievements.is_empty():center("Jogue para registrar suas primeiras conquistas.",300,30,MUTED)
		else:
			emblem(Vector2(640,325),92)
			center(str(achievements[app.gallery_index]),503,38,GOLD)
		center("SOBREVIVÊNCIA · RECORDE "+str(app.profile.data.progress.records.get("survival",0)),584,25,WHITE)
	footer("MENU","")
