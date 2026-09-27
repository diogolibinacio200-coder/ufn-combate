extends SceneTree
const App=preload("res://scripts/main.gd")
const Profile=preload("res://scripts/save_manager.gd")
var checks:=0
var failed:=0
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if not ok:
  failed+=1
  printerr("FALHOU: "+label)
func confirm_both(): return [{"attack_pressed":true},{"attack_pressed":true}]
func run():
 var app=App.new()
 app.profile=Profile.new("user://ufn_flow_test_%d.json" % OS.get_process_id())
 root.add_child(app)
 app.set_process(false)
 app.set_physics_process(false)
 app.arena.set_process(false)
 app.ui.set_process(false)
 app.profile.data.settings.rounds=3
 app.set_screen("menu")
 check(app.MENU.size()==15,"Menu oferece quinze entradas")
 app.begin_mode("teams")
 app.cursors=[0,3]
 app.tick_select(confirm_both())
 check(app.selection_phase==1 and app.screen=="select","Duplas pedem reserva após líderes")
 app.cursors=[2,4]
 app.tick_select(confirm_both())
 check(app.reserves==[2,4] and app.screen=="stage","Seleção de reservas conclui duplas")
 app.tick_stage(confirm_both())
 check(app.screen=="vs","Arena segue para confronto")
 app.start_match()
 check(app.combat.team_mode and app.combat.time_frames==9000,"Confronto inicia partida de duplas")
 app.combat.winner=0
 app.resolve_round()
 check(app.wins==[1,0] and app.round_number==2,"Primeira vitória vai ao segundo round")
 app.combat.winner=0
 app.resolve_round()
 check(app.screen=="result" and app.match_winner==0,"Duas vitórias encerram melhor de três")
 app.screen_time=1
 app.result_index=0
 app.tick_result(confirm_both())
 check(app.screen=="fight" and app.combat.team_mode and app.wins==[0,0],"Revanche restaura a mesma dupla")
 app.begin_mode("versus")
 app.cursors=[3,3]
 app.tick_select([{"heavy_pressed":true},{}])
 check(app.skins[0]==1 and app.skins[1]==0,"Skin de Diogo é independente por jogador")
 app.tick_select(confirm_both())
 app.start_match()
 app._process(0)
 check(app.combat.fighters[0].skin==1 and app.combat.fighters[1].skin==0,"Skins chegam aos lutadores da partida")
 app.begin_mode("arcade")
 app.cursors[0]=9
 app.tick_select([{ "attack_pressed":true},{}])
 check(app.arcade_order.size()==10 and app.arcade_order[-2]==14 and app.arcade_order[-1]==15,"Arcade tem dez lutas e os dois chefes finais")
 check(app.arcade_order.slice(0,8).all(func(id):return id<14 and id!=9),"Arcade nunca cria personagem extra")
 for index in 10:
  app.arcade_index=index
  app.chosen[1]=app.arcade_order[index]
  app.start_match()
  app.match_winner=0
  app.set_screen("result")
  app.screen_time=1
  app.result_index=0
  app.tick_result(confirm_both())
  check(app.screen==("ending" if index==9 else "vs"),"Progressão arcade %d" % index)
 app.mode="tournament"
 app.tournament_roster=[]
 app.tournament_winners=[]
 app.tournament_round=0
 for id in [0,3,8,9]:
  app.tournament_cursor=id
  app.tick_tournament(confirm_both())
 check(app.tournament_roster==[0,3,8,9] and app.chosen==[0,3],"Torneio registra quatro participantes")
 for round_index in 3:
  app.tournament_round=round_index
  app.prepare_tournament_match()
  app.match_winner=0
  app.set_screen("result")
  app.screen_time=1
  app.result_index=0
  app.tick_result(confirm_both())
 check(app.tournament_round==3 and app.tournament_winners.size()==3,"Torneio resolve semifinais e final")
 app.begin_mode("training")
 app.cursors[0]=5
 app.tick_select([{ "attack_pressed":true},{}])
 app.start_match()
 check(app.combat.training and app.intro_frames==0,"Treino começa sem contagem e com dummy")
 app.combat.fighters[0].hp=1
 app.combat.fighters[0].meter=0
 app.reset_training()
 check(app.combat.fighters[0].hp==1000 and app.combat.fighters[0].meter==100,"Reset de treino restaura vida e energia")
 app.previous_screen="settings"
 app.set_screen("controls")
 app.controls_index=7
 app.tick_controls([{ "attack_pressed":true},{}])
 check(app.capturing_binding,"Defesa é remapeável na oitava ação")
 app.finish_binding_capture()
 app.binding_capture_wait_release=false
 app.controls_index=14
 app.tick_controls([{ "attack_pressed":true},{}])
 check(app.screen=="settings","Voltar dos controles retorna à origem")
 app.begin_mode("kart")
 app.cursors=[7,3]
 app.tick_select(confirm_both())
 check(app.screen=="kart_stage","Kart usa seleção de pista própria")
 app.stage_cursor=1
 app.tick_kart_stage(confirm_both())
 check(app.screen=="kart" and app.kart.active,"Kart começa com dois jogadores")
 app._exit_kart()
 check(app.screen=="menu" and not app.kart.active,"Saída do kart retorna ao menu")
 app.combat.setup([0,3])
 app.mode="versus"
 app.wins=[0,0]
 app.combat.winner=2
 app.resolve_round()
 check(app.wins==[0,0],"Empate não concede vitória fictícia")
 await app.sound.shutdown()
 app.queue_free()
 await process_frame
 print("FLUXO UFN: %d verificações, %d falhas" % [checks,failed])
 quit(0 if failed==0 else 1)
