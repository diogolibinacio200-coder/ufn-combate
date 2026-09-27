extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const App=preload("res://scripts/main.gd")
const Profile=preload("res://scripts/save_manager.gd")
const Inputs=preload("res://scripts/input_manager.gd")
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(value:bool,label:String):
	checks+=1
	if not value:failures+=1;printerr("FALHOU: "+label)
func frames(c,n:int):
	for i in n:c.tick([{},{}])
func fresh(a=0,b=3):
	var c=Combat.new();c.setup([a,b]);c.fighters[0].x=420;c.fighters[1].x=700;return c
func run():
	var c=fresh()
	check(Inputs.ACTIONS.size()==8 and not Inputs.ACTIONS.has("power") and not Inputs.ACTIONS.has("tag"),"4 direções e exatamente quatro ações")
	c.tick([{"block":true,"heavy":true,"heavy_pressed":true},{}])
	check(c.fighters[0].move.is_empty() and c.fighters[0].state=="block","Ultimate sem energia consome combinação, sem normal acidental")
	c.fighters[0].meter=100
	c.tick([{"block":true,"heavy_pressed":true,"kick_pressed":true,"attack_pressed":true},{}])
	check(c.fighters[0].move.family=="super","A2 tem prioridade sobre A3 e A1 com defesa")
	c=fresh();c.tick([{"block":true,"kick_pressed":true},{}])
	check(c.fighters[0].move.is_empty(),"Troca fora de dupla não vira chute")
	c=fresh();c.fighters[0].meter=100;c.tick([{"power":true,"power_pressed":true},{}])
	check(c.fighters[0].meter==100 and c.fighters[0].move.is_empty(),"Botão antigo de ultimate não existe")
	c.setup([0,3],false,[2,4]);c.tick([{"block":true,"kick_pressed":true},{}])
	check(c.fighters[0].id==2 and c.tag_cooldowns[0]==300,"D+A3 troca corretamente")
	c.fighters[0].hp=0;c.tick([{},{}])
	check(c.fighters[0].id==0,"KO ignora cooldown de troca")
	for difficulty in 4:
		c.difficulty=difficulty;c.setup([0,14]);check(is_equal_approx(c.fighters[1].max_hp,[1100.0,1150.0,1250.0,1300.0][difficulty]),"Vida André por dificuldade")
		c.setup([0,15]);check(is_equal_approx(c.fighters[1].max_hp,[1150.0,1250.0,1300.0,1400.0][difficulty]),"Vida Kelvin por dificuldade")
	c.fighters[0].hp=500;c.fighters[1].hp=c.fighters[1].max_hp*.5;c.time_frames=1;c.tick([{},{}])
	check(c.winner==2,"Timeout compara porcentagens contra chefe")
	c=fresh(13,0);c.fighters[0].bear_x=580;c.fighters[1].x=680
	c.tick([{"attack_pressed":true},{}]);frames(c,12)
	check(c.fighters[1].hp<1000,"Golpe de Fernando parte do urso além do alcance do dono")
	check(c.fighters[0].move.body_pose=="projectile" or c.fighters[0].move.is_empty(),"Fernando gesticula em vez de socar")
	var owner_hp=c.fighters[0].hp;c._bear_damage(c.fighters[0],220)
	check(c.fighters[0].hp==owner_hp and c.fighters[0].bear_stun>0,"Dano de postura não retira vida do dono")
	c=fresh(13,0);c.fighters[0].bear_x=520;c.fighters[0].meter=100;c._start_move(c.fighters[0],c.move_db.specials(13)[0])
	c._apply_hit(c.fighters[1],c.fighters[0],c.move_db.normals()[0],c.EMPTY,false)
	check(c.fighters[0].move.is_empty() and c.fighters[0].bear_stun>0,"Dono atingido interrompe urso")
	c=fresh(11,0);c._start_move(c.fighters[0],c.move_db.specials(11)[2]);frames(c,70)
	check(c.fighters[0].embalo==1 and c.fighters[0].hp==1000,"Trago vulnerável dá embalo e não cura")
	c._start_move(c.fighters[0],c.move_db.normals()[0]);check(c.fighters[0].embalo==0 and c.fighters[0].move.damage>42,"Ataque consome embalo")
	var input=Inputs.new();input.use_laptop_profile()
	check(input.get_binding(0,"block")==KEY_R and input.get_binding(1,"attack")==KEY_J,"Perfil sem numérico independente")
	input.set_binding(0,"attack",KEY_J)
	check(input.get_binding(1,"attack")==KEY_F,"Conflito de teclado troca atribuição sem controlar dois jogadores")
	input.set_binding(0,"attack",KEY_T,true)
	input.set_gamepad_binding(0,"attack",JOY_BUTTON_B,-1,true)
	var saved=input.export_bindings();input.defaults();input.load_bindings(saved)
	check(input.get_binding(0,"attack",true)==KEY_T and input.get_binding(0,"attack")==KEY_J,"Kart tem teclado separado e persistente")
	check(input.get_gamepad_binding(0,"attack",true)==JOY_BUTTON_B and input.get_gamepad_binding(0,"attack")==JOY_BUTTON_X,"Kart tem gamepad separado e persistente")
	for id in range(10,16):
		c=fresh(id,0);var a=c.fighters[0];var d=c.fighters[1];var ult=c.move_db.super_move(id)
		a.meter=100;c._start_move(a,ult);check(a.meter==0,"Ultimate consome energia integral: "+str(id))
		c._apply_hit(a,d,ult,c.EMPTY,false)
		if id!=14:
			check(c.cinematic.active,"Novo ultimate confirmado inicia sequência: "+str(id))
			frames(c,210)
			check(not c.cinematic.active and d.hp<1000 and a.state=="idle","Cinemática termina e devolve controle: "+str(id))
		else:check(not c.cinematic.active,"Gás do André permite movimento e fuga")
	var app=App.new();app.profile=Profile.new("user://v2_test_"+str(OS.get_process_id())+".json");root.add_child(app);app.set_physics_process(false);app.set_process(false)
	app.begin_mode("tower");app.cursors[0]=13;app.tick_select([{"attack_pressed":true},{}])
	check(app.screen=="tower" and app.arcade_order.size()==10 and app.arcade_order[-2]==14 and app.arcade_order[-1]==15,"Torre contém oito jogáveis e chefes finais")
	app.arcade_index=8;app.save_tower();app.profile.load_profile();app.open_setup("tower");app.tick_setup([{"attack_pressed":true},{}])
	check(app.arcade_index==8 and app.chosen==[13,14],"Torre retoma personagem e andar salvos")
	app.mode="tournament";app.tournament_size=8;app.tournament_roster=[];app.tournament_cpu=[]
	for id in 8:app.tournament_cursor=id;app.entry_cpu=id%2==1;app.tick_tournament([{"attack_pressed":true},{}])
	for bout in 7:
		app.match_winner=0;app.screen_time=1;app.result_index=0;app.tick_result([{"attack_pressed":true},{}])
		if bout<6:app.prepare_tournament_match()
	check(app.bracket_current.size()==1 and app.tournament_winners.size()==7,"Torneio de oito resolve sete confrontos")
	app.kart.race_mode="quick";app.kart.start([13,10],[0,0],0,2)
	check(app.kart.racers.size()==8 and app.kart.racers.filter(func(r):return r.human).size()==2,"Kart possui dois humanos e seis CPUs")
	for id in 14:
		var r=app.kart.racers[0];r.character=id;r.item=7;app.kart.use_item(r)
		check(r.item==0,"Poder de kart é utilizável: "+str(id))
	app.kart._update_items(.1)
	app.kart.stop();app.kart.race_mode="time_trial";app.kart.start([3],[],2,1)
	check(app.kart.racers.size()==1 and app.kart.boxes.is_empty(),"Contrarrelógio não possui CPU nem itens ofensivos")
	app.kart.stop();app.kart.race_mode="championship";app.kart.championship_points={};app.kart.start([3,10],[0,0],0,2)
	for r in app.kart.racers:r.finish_time=50+r.id;r.progress=1000
	app.kart.finish_race()
	check(app.kart.championship_points.size()==8 and app.kart.championship_points["0"]==15,"Campeonato pontua oito posições")
	app.kart.next_race();check(app.kart.track_id==1 and app.kart.championship_points["0"]==15,"Próxima etapa preserva pontos")
	app.kart.stop();await app.sound.shutdown();app.queue_free();await process_frame
	print("V2: %d verificações, %d falhas"%[checks,failures]);quit(0 if failures==0 else 1)
