extends SceneTree
## Release regression: complete progression, tutorials and persistent local controls.
const App = preload("res://scripts/main.gd")
const Profile = preload("res://scripts/save_manager.gd")
const Combat = preload("res://scripts/combat.gd")
var checks = 0
var failures = 0
var app

func _initialize(): call_deferred("run")
func check(value: bool, label: String):
	checks += 1
	if not value:
		failures += 1
		printerr("FALHOU: " + label)
func press(): return [{"attack_pressed":true},{}]
func settle(count: int):
	for frame in count: app.tick_fight([{},{}],false)
func reset_positions():
	app.reset_training()
	app.combat.fighters[0].x=450
	app.combat.fighters[1].x=525
func key(code: int, held: bool):
	var event=InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=held
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run():
	app=App.new()
	app.profile=Profile.new("user://release_test_"+str(OS.get_process_id())+".json")
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.arena.set_process(false)
	app.ui.set_process(false)
	# Tutorial always provides its own defaults, regardless of the last free-training session.
	app.train_options={"dummy":4,"health":false,"meter":false,"guard":true,"boxes":true}
	app.start_tutorial()
	check(app.combat.training and app.combat.team_mode and app.train_options.health and app.train_options.meter and not app.train_options.guard,"Tutorial prepara vida, energia e reserva sem herdar treino anterior")
	check(app.tutorial_step==0 and app.combat.fighters[0].meter==100,"Tutorial começa na etapa de movimento")
	app.combat.fighters[0].x+=140
	app.tick_tutorial()
	check(app.tutorial_step==1,"Movimento conclui apenas a primeira etapa")
	for hit in 3:
		reset_positions()
		app.tick_fight(press(),true)
		settle(38)
	check(app.tutorial_step==2 and app.tutorial_hits>=3,"Três acertos reais abrem a lição de defesa")
	reset_positions()
	for frame in 250:
		app.tick_fight([{"block":true},{}],true)
		if app.tutorial_step==3: break
	check(app.tutorial_step==3,"Defesa em pé contra o dummy avança")
	for frame in 250:
		app.tick_fight([{"block":true,"down":true},{}],true)
		if app.tutorial_step==4: break
	check(app.tutorial_step==4,"Defesa agachada contra o dummy avança")
	reset_positions()
	app.tick_fight([{"block":true,"attack_pressed":true},{}],true)
	settle(45)
	check(app.tutorial_step==5,"D+A1 confirma agarrão real na lição")
	reset_positions()
	app.tick_fight([{"down":true},{}],true)
	app.tick_fight([{"right":true},{}],true)
	app.tick_fight(press(),true)
	check(app.tutorial_step==6,"Baixo, frente e A1 executam o especial da lição")
	# A newly opened combo lesson cannot complete from two stale hits in the preceding lesson.
	app.tutorial_step=5
	app.combat.fighters[0].combo=2
	app.tick_tutorial()
	check(app.tutorial_step==6 and app.combat.fighters[0].combo==0,"Uma avaliação não pula duas etapas nem reutiliza combo anterior")
	reset_positions()
	app.combat.fighters[0].combo=2
	app.tick_tutorial()
	check(app.tutorial_step==7,"Combo abre a lição de ultimate")
	reset_positions()
	app.tick_fight([{"block":true,"heavy_pressed":true},{}],true)
	check(app.tutorial_step==8,"D+A2 dispara o ultimate com energia fornecida pelo tutorial")
	reset_positions()
	app.tick_fight([{"block":true,"kick_pressed":true},{}],true)
	check(app.tutorial_step==9 and app.combat.fighters[0].id==3,"D+A3 faz troca e chega à décima etapa")
	app.tick_fight(press(),true)
	app.kart.set_process(false)
	app.kart.set_physics_process(false)
	check(app.screen=="kart" and app.kart.tutorial_mode and app.kart.player_count==1,"Confirmação transfere tutorial para kart de um jogador")
	check(app.kart.boxes.is_empty(),"Tutorial do drift não pode ser concluído usando turbo de caixa")
	app.kart.phase="race"
	var racer=app.kart.racers[0]
	racer.speed=23.0
	app.kart._physics_process(1.0/60.0)
	check(app.kart.tutorial_step==1,"Aceleração suficiente abre a lição de drift")
	racer.drift=1.0
	racer.drifting=true
	app.kart.step_racer(racer,{"throttle":1.0,"drift":false},1.0/60.0)
	app.kart._physics_process(1.0/60.0)
	check(app.kart.tutorial_step==2 and racer.item==7,"Soltar drift carregado libera miniturbo e fornece item")
	key(KEY_U,true)
	app.kart._physics_process(1.0/60.0)
	key(KEY_U,false)
	app.kart._physics_process(1.0/60.0)
	app.kart._physics_process(1.0/60.0)
	check(app.kart.tutorial_step==3 and app.profile.data.progress.achievements.has("PRIMEIROS PASSOS"),"Usar item com D encerra as três lições de kart")
	app._exit_kart()
	app.profile.load_profile()
	check(app.profile.data.progress.achievements.has("PRIMEIROS PASSOS"),"Conclusão do tutorial persiste ao voltar ao menu")
	# Input history exposes only four actions and the held block modifier.
	app.input_history=[[],[]]
	app.record_input(0,{"block":true,"heavy_pressed":true,"power_pressed":true,"tag_pressed":true})
	check(app.input_history[0]==["D + A2"],"Histórico usa ações atuais e mostra defesa mantida")
	# Same-frame KOs must neither award a phantom win nor lose the team reserve.
	var combat=Combat.new()
	combat.setup([0,3],false,[2,4])
	combat.fighters[0].hp=0
	combat.fighters[1].hp=0
	combat.tag_cooldowns=[200,200]
	combat.tick([{},{}])
	check(combat.winner==-1 and combat.fighters[0].id==2 and combat.fighters[1].id==4,"KO simultâneo de líderes chama as duas reservas mesmo com cooldown")
	combat.fighters[0].hp=0
	combat.fighters[1].hp=0
	combat.tick([{},{}])
	check(combat.winner==2,"KO simultâneo das últimas reservas termina empatado")
	app.mode="teams"
	app.chosen=[0,3]
	app.reserves=[2,4]
	app.start_match()
	app.wins=[1,1]
	app.combat.winner=2
	app.resolve_round()
	check(app.wins==[1,1] and app.combat.winner==-1 and app.screen=="fight" and app.combat.time_frames==9000,"Empate em 1×1 exige novo round de 150 segundos")
	check(app.combat.teams[0][0].hp==1000 and app.combat.teams[0][1].hp==1000,"Round extra restaura os dois membros de cada equipe")
	app.combat.winner=1
	app.resolve_round()
	check(app.screen=="result" and app.match_winner==1,"Vitória após empate encerra melhor de três")
	# Boss retries and the final tower result survive saving and loading.
	app.begin_mode("tower")
	app.cursors[0]=10
	app.tick_select(press())
	app.arcade_index=8
	app.chosen[1]=14
	app.start_match()
	app.combat.winner=1
	app.resolve_round()
	app.combat.winner=1
	app.resolve_round()
	app.screen_time=1
	app.tick_result(press())
	check(app.screen=="fight" and app.chosen==[10,14] and app.arcade_index==8,"Tentar novamente conserva personagem e penúltimo chefe")
	app.arcade_index=9
	app.chosen[1]=15
	app.start_match()
	app.combat.winner=0
	app.resolve_round()
	app.combat.winner=0
	app.resolve_round()
	app.screen_time=1
	app.tick_result(press())
	app.profile.load_profile()
	check(app.screen=="ending" and app.profile.data.progress.tower.is_empty(),"Kelvin derrotado conclui torre e limpa retomada")
	check(app.profile.data.progress.records.get("torre_1",false),"Dificuldade concluída da torre fica registrada")
	# Keyboard bindings remain independent at the actual polling boundary.
	app.input.defaults()
	app.input.set_binding(0,"attack",KEY_T,true)
	app.input.set_binding(1,"attack",KEY_Y,true)
	key(KEY_T,true)
	key(KEY_Y,true)
	app.input.update()
	check(not app.input.sample(0).get("attack",false) and not app.input.sample(1).get("attack",false),"Aceleradores remapeados não disparam soco no mapa de luta")
	check(app.input.sample_kart(0).attack and app.input.sample_kart(1).attack,"Dois aceleradores remapeados são lidos simultaneamente")
	key(KEY_T,false)
	key(KEY_Y,false)
	app.persist()
	app.profile.load_profile()
	app.input.defaults()
	app.input.load_bindings(app.profile.data.bindings)
	check(app.input.get_binding(0,"attack",true)==KEY_T and app.input.get_binding(0,"attack")==KEY_J,"Mapa de kart persistido não altera mapa de luta")
	# Four races, a resume, and a rerun must not duplicate cup points.
	app.chosen=[7,8]
	app.skins=[0,0]
	app.kart_players=2
	app.kart.tutorial_mode=false
	app.kart.race_mode="championship"
	app.kart.championship_points={}
	app.kart.start(app.chosen,app.skins,0,2)
	var ids=app.kart.racers.map(func(r):return r.character)
	var unique={}
	for id in ids:unique[id]=true
	check(unique.size()==8,"Grade de dois humanos tem seis CPUs com personagens distintos")
	for stage in 4:
		for r in app.kart.racers:
			r.finish_time=50.0+r.id if stage<3 else 50.0+posmod(r.id+1,8)
			r.progress=1000
		app.kart.finish_race()
		var points=app.kart.championship_points.duplicate()
		app.kart.finish_race()
		check(app.kart.championship_points==points,"Repetir evento de chegada não duplica pontos da etapa "+str(stage+1))
		app.profile.load_profile()
		if stage<3:
			check(app.profile.data.progress.championship.track==stage+1,"Campeonato salva próxima pista "+str(stage+2))
			if stage==0:
				app.kart.stop()
				app.kart.tutorial_mode=true
				app.open_setup("kart")
				app.setup_index=5
				app.tick_setup(press())
				check(app.kart.track_id==1 and app.kart.championship_points["0"]==15 and not app.kart.tutorial_mode,"Retomada recupera pontos e desativa tutorial anterior")
				check(app.kart.racers.map(func(r):return r.character)==ids,"Retomada conserva identidade dos oito pilotos")
			else:app.kart.next_race()
	check(app.profile.data.progress.championship.is_empty(),"Quarta corrida limpa retomada do campeonato")
	check(app.profile.data.progress.records.campeonato.character==7 and app.profile.data.progress.records.campeonato.points==57,"Campeão persistido vem da soma das quatro corridas, não da última chegada")
	check(app.profile.data.progress.records.campeonato.standings.size()==8,"Classificação final de oito pilotos fica registrada")
	app.kart.stop()
	await app.sound.shutdown()
	app.queue_free()
	await process_frame
	print("RELEASE: %d verificações, %d falhas"%[checks,failures])
	quit(0 if failures==0 else 1)
