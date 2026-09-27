extends SceneTree
const Combat = preload("res://scripts/combat.gd")
const AI = preload("res://scripts/ai.gd")
const Inputs = preload("res://scripts/input_manager.gd")
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures.append(label)
  printerr("FALHOU: "+label)
func fresh(a: int = 0,b: int = 3):
 var c = Combat.new()
 c.setup([a,b])
 c.fighters[0].x = 550.0
 c.fighters[1].x = 645.0
 return c
func frames(c,n: int,a: Dictionary = {},b: Dictionary = {}) -> Array:
 var events: Array = []
 for i in n:
  c.tick([a,b])
  events.append_array(c.events.duplicate(true))
 return events
func special(c,slot: int,player: int=0) -> void:
 var a: Dictionary = {"down":true}
 var b: Dictionary = {}
 var facing: int = c.fighters[player].face
 var second = "down" if slot == 2 else (("right" if facing == 1 else "left") if slot == 0 else ("left" if facing == 1 else "right"))
 var values = [{},{}]
 values[player] = a
 c.tick(values)
 c.tick([{},{}])
 b[second] = true
 b["heavy" if slot == 2 else "attack"] = true
 b["heavy_pressed" if slot == 2 else "attack_pressed"] = true
 values[player] = b
 c.tick(values)
func event_has(events: Array,type: String) -> bool:
 return events.any(func(e): return e.type == type)
func run() -> void:
 var c = fresh()
 var input = Inputs.new()
 check(input.get_binding(0,"attack") == KEY_J and input.get_binding(1,"attack") == KEY_KP_1,"Teclado 2 jogadores tem mapeamento correto")
 check(input.set_binding(1,"attack",KEY_F),"Remapeamento para teclado sem numérico")
 check(input.get_binding(1,"attack") == KEY_F,"Remapeamento usado no input")
 check(c.move_db.ROSTER.size() == 16 and c.move_db.PLAYABLE==14,"Elenco tem 14 jogáveis e dois chefes")
 for id in 16:
  for slot in 3:
   c = fresh(id,(id+1)%16)
   c.fighters[0].meter = 100.0
   special(c,slot)
   check(not c.fighters[0].move.is_empty() and c.fighters[0].move.name == c.move_db.specials(id)[slot].name,"Comando especial %d/%d reconhecido" % [id,slot])
   frames(c,110)
   check(c.fighters[0].state != "attack" or c.winner >= 0,"Especial %d/%d termina sem travar" % [id,slot])
 c = fresh(3,0)
 c.fighters[0].meter=100
 c.fighters[0].x=700
 c.fighters[1].x=500
 c.tick([{},{}])
 special(c,0)
 check(c.fighters[0].move.name == "CHICOTE DE CIPÓ","Comando inverte com a direção do rival")
 c = fresh()
 c.fighters[0].meter=100
 c.tick([{"down":true},{}])
 frames(c,22)
 c.tick([{"right":true,"attack":true,"attack_pressed":true},{}])
 check(c.fighters[0].move.family == "normal","Comando expirado não produz especial acidental")
 c = fresh()
 c.tick([{"attack":true,"attack_pressed":true},{}])
 frames(c,12)
 check(c.fighters[1].hp < 1000 and c.fighters[0].meter > 0,"Acerto tira vida e gera energia")
 c = fresh()
 frames(c,10,{}, {"block":true})
 c.tick([{"attack":true,"attack_pressed":true},{"block":true}])
 frames(c,15,{}, {"block":true})
 check(c.fighters[1].hp>990 and c.fighters[1].guard<100,"Defesa segura normal e consome guarda")
 c = fresh()
 c.tick([{"down":true,"kick":true,"kick_pressed":true},{"block":true}])
 frames(c,18,{}, {"block":true})
 check(c.fighters[1].hp<980,"Rasteira vence defesa alta")
 c = fresh()
 c.fighters[1].x=625
 c.tick([{"block":true,"attack":true,"attack_pressed":true},{"block":true}])
 frames(c,35,{}, {"block":true})
 check(c.fighters[1].hp==895,"Agarrão vence guarda e resolve dano")
 c = fresh()
 c.fighters[1].x=625
 c.tick([{"block":true,"attack":true,"attack_pressed":true},{}])
 frames(c,7)
 c.tick([{}, {"block":true,"attack":true,"attack_pressed":true}])
 check(c.fighters[1].hp==1000 and event_has(c.events,"throw_break"),"Agarrão tem janela para escapar")
 c = fresh(2,0)
 c.fighters[1].x=1150
 for i in 6:
  special(c,0)
  frames(c,65)
 check(c.fighters[0].ammo==0,"Maria consome seis munições")
 special(c,0)
 check(c.fighters[0].ammo==0 and c.fighters[0].move.is_empty(),"Maria sem munição não dispara")
 frames(c,10)
 special(c,2)
 frames(c,70)
 check(c.fighters[0].ammo==6,"Recarga completa devolve seis munições")
 c = fresh(2,0)
 c.fighters[0].ammo=1
 special(c,2)
 frames(c,18)
 c.fighters[1].x=c.fighters[0].x+90
 c.tick([{}, {"heavy":true,"heavy_pressed":true}])
 frames(c,60)
 check(c.fighters[0].ammo==1,"Recarga interrompida não concede munição")
 c = fresh(4,0)
 c.fighters[0].meter=100
 c.tick([{"block":true,"heavy":true,"heavy_pressed":true},{}])
 frames(c,43)
 check(c.fighters[0].transform>400 and not c.cinematic.active,"Mirkos transforma em exoesqueleto por oito segundos")
 frames(c,480)
 check(c.fighters[0].transform==0,"Transformação termina sem alterar stats permanentemente")
 c = fresh(1,0)
 c.fighters[0].meter=100
 c.tick([{"block":true,"heavy":true,"heavy_pressed":true},{}])
 frames(c,115)
 check(c.fighters[1].hp==1000 and c.fighters[0].meter<5,"Ultimate de Vitor exige contra-ataque e perde energia ao errar")
 c = fresh(1,0)
 c.fighters[0].meter=100
 c.tick([{"block":true,"heavy":true,"heavy_pressed":true},{}])
 frames(c,22)
 c.tick([{}, {"attack":true,"attack_pressed":true}])
 frames(c,18)
 check(c.cinematic.active,"Ultimate de Vitor reage a golpe dentro da janela")
 frames(c,220)
 check(c.fighters[1].hp==720,"Contra-ataque ultimate aplica dano exato")
 for id in [0,2,3,5,6,7,8,9]:
  c=fresh(id,0 if id !=0 else 3)
  c.fighters[0].meter=100
  c.fighters[1].x=c.fighters[0].x+(90 if id==0 else (265 if id in [3,8] else 140))
  c.tick([{"block":true,"heavy":true,"heavy_pressed":true},{}])
  var log=frames(c,380)
  check(event_has(log,"cinematic_start"),"Ultimate %d conecta e inicia coreografia" % id)
  check(c.fighters[1].hp==720,"Ultimate %d encerra com dano único de280" % id)
  check(not c.cinematic.active,"Ultimate %d devolve controle" % id)
 c=fresh()
 c.setup([0,3],false,[2,4])
 check(c.time_frames==150*60 and c.team_mode,"Duplas têm150 segundos")
 c.fighters[0].hp=610
 c.fighters[0].meter=65
 check(c.tag(0),"Troca manual funciona")
 check(c.fighters[0].id==2 and c.reserve(0).hp==610 and c.reserve(0).meter==65,"Reserva preserva vida/energia independente")
 check(not c.tag(0),"Cooldown impede troca consecutiva")
 frames(c,301)
 check(c.tag(0),"Troca libera após5segundos")
 c.fighters[0].stun=20
 c.fighters[0].state="hitstun"
 c.tag_cooldowns[0]=0
 check(not c.tag(0),"Não troca durante golpe recebido")
 c.fighters[0].hp=0
 c.tick([{},{}])
 check(c.fighters[0].id==2 and c.winner==-1,"Parceiro entra automaticamente após KO")
 c.fighters[0].hp=0
 c.tick([{},{}])
 check(c.winner==1,"Dupla perde só quando ambos caem")
 c.setup([0,3],false,[2,4])
 c.fighters[0].hp=200
 c.reserve(0).hp=900
 c.fighters[1].hp=800
 c.reserve(1).hp=200
 c.time_frames=1
 c.tick([{},{}])
 check(c.winner==0,"Timeout compara soma de vida da dupla")
 c.reset_round()
 check(c.team_health(0)==2000 and c.fighters[0].meter==0 and c.time_frames==9000,"Novo round restaura integrantes,energia e relógio")
 c.setup([0,3])
 c.time_frames=1
 c.tick([{},{}])
 check(c.winner==2,"Empate exato é sinalizado para round extra")
 c=fresh(3,0)
 c.fighters[0].meter=100
 c.fighters[1].x=780
 special(c,0)
 frames(c,35)
 check(c.fighters[1].hp<1000 and c.fighters[1].x<780,"Cipó atinge média distância e puxa")
 c=fresh(3,0)
 c.fighters[0].meter=100
 c.fighters[1].x=730
 special(c,1)
 frames(c,45)
 check(c.fighters[1].status=="slow" and c.fighters[1].hp==1000,"Névoa reduz movimento sem dano invisível")
 c=fresh(8,0)
 c.fighters[0].meter=100
 c.fighters[1].x=790
 special(c,2)
 var pulses=frames(c,155)
 check(pulses.filter(func(e): return e.type=="special" and str(e.text).begins_with("LOOP")).size()==3,"Loop emite exatamente três pulsos anunciados")
 c=fresh(4,0)
 c.fighters[0].meter=100
 c.fighters[1].x=950
 special(c,0)
 frames(c,20)
 check(c.projectiles.size()==1 and c.projectiles[0].kind=="drone","Drone se posiciona antes do disparo")
 frames(c,60)
 check(c.fighters[1].hp<1000,"Drone dispara após preparação")
 c=fresh(4,0)
 c.fighters[0].meter=100
 c.fighters[1].x=1050
 special(c,1)
 frames(c,75)
 special(c,1)
 frames(c,60)
 check(c.projectiles.filter(func(q): return q.kind=="sentry").size()==1,"Só uma sentinela por lutador")
 c=fresh(5,0)
 c.fighters[0].meter=100
 c.fighters[1].x=930
 special(c,2)
 frames(c,40)
 c.tick([{ "kick":true,"kick_pressed":true},{}])
 check(c.fighters[0].move.name=="VOLEIO PREPARADO","Embaixadinha habilita finalização com chute")
 c=fresh(6,0)
 c.fighters[0].meter=100
 c.fighters[1].x=1080
 special(c,2)
 frames(c,30)
 c.tick([{ "attack":true,"attack_pressed":true},{}])
 check(c.fighters[0].move.name=="FINALIZAÇÃO DE QUADRA","Finta permite segundo comando de arremesso")
 c=fresh(1,0)
 c.tick([{}, {"heavy":true,"heavy_pressed":true}])
 frames(c,30)
 check(c.fighters[0].rage>0,"Vitor acumula irritação ao sofrer dano")
 c=fresh(3,0)
 c.tick([{ "right":true},{}])
 c.tick([{},{}])
 c.tick([{ "right":true},{}])
 check(c.fighters[0].dash_time>0 and c.fighters[0].vel.x>8,"Duplo toque produz avanço rápido")
 c=fresh(3,0)
 c.fighters[1].x=1150
 c.fighters[0].meter=100
 c.tick([{ "heavy":true,"heavy_pressed":true},{}])
 frames(c,40)
 special(c,0)
 frames(c,7)
 check(not c.fighters[0].move.is_empty() and c.fighters[0].move.name=="CHICOTE DE CIPÓ","Buffer mantém especial no final da recuperação")
 for id in 16:
  c=fresh(id,(id+5)%16)
  var ai0=AI.new(100+id)
  var ai1=AI.new(200+id)
  for tick in 18000:
   if c.winner>=0: break
   c.tick([ai0.think(c,0,2),ai1.think(c,1,2)])
  check(c.winner>=0,"Partida completa entre bots encerra para personagem%d" % id)
  check(c.fighters[0].damage_dealt+c.fighters[1].damage_dealt>300,"IA combate de fato com personagem%d" % id)
 print("UFN COMBATE: %d verificações, %d falhas" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
