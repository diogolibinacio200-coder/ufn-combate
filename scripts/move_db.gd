extends RefCounted
## Frame data is centralized here. Adding a roster entry needs no combat changes.

const BASE = preload("res://scripts/fighter.gd").BASE
var balance_overrides: Dictionary = {}

func _init(path: String = "res://data/balance.json") -> void:
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.get("moves",{}) is Dictionary:
			balance_overrides = parsed.get("moves", {})

const ROSTER = [
	["ARTHUR","FORÇA • ACADEMIA","f7b75f","RECORDE PESSOAL","Mais uma repetição.","Arthur conquista o campeonato e transforma o pátio em um treino aberto. A força da UFN está em quem levanta junto."],
	["VITOR DO BEM","RAIVA • PRESSÃO","ff854d","AGORA CHEGA!","Hoje eu perdi a paciência.","Depois de uma final explosiva, Vitor respira fundo. A vitória rende histórias e uma tarde tranquila nos bancos do campus."],
	["MARIA","PRECISÃO • CAPIVARAS","a8c9ff","OPERAÇÃO CAPIVARA","Seis chances. Uma estratégia.","Maria comemora cercada por suas capivaras. No campus, precisão e companheirismo vencem o improviso."],
	["DIOGO","NATUREZA • CONTROLE","7bf3a9","DOMÍNIO DA NATUREZA","Deixa a natureza responder.","Diogo faz florescer uma nova árvore no pátio. A comunidade da UFN se reúne à sombra dela para a próxima competição."],
	["MIRKOS","TECNOLOGIA • INTELIGÊNCIA ARTIFICIAL","69e0fb","PROTOCOLO SINGULARIDADE","O próximo passo já foi calculado.","Mirkos apresenta seu exoesqueleto no laboratório. A tecnologia que decidiu a final agora inspira novos projetos da UFN."],
	["FELIPE","FUTEBOL • MOBILIDADE","8ae6cf","GOL DE PLACA","Esse vai para o replay.","Felipe fecha o torneio com uma bicicleta e leva a festa para a quadra. O próximo desafio já tem bola e torcida."],
	["MURILO","HANDEBOL • TRAJETÓRIAS","f4a3d2","SETE METROS DECISIVO","Olha a finta.","Murilo recebe a medalha depois do arremesso perfeito. A quadra ganha uma nova história para contar."],
	["GABRIEL","VELOCIDADE • VEÍCULOS","ffc868","GIRO MÁXIMO","Segura essa arrancada.","Gabriel estaciona a Biz após a volta da vitória. O campeonato acaba, mas o próximo encontro no campus já está marcado."],
	["FABIANO","MATEMÁTICA • PROGRAMAÇÃO","c4a6ff","EQUAÇÃO FINAL","A solução está no próximo passo.","Fabiano demonstra que timing também é matemática. Sua equação campeã vira assunto da próxima aula."],
	["VITOR DO MAL","CARISMA • ALIADAS","fca0cd","ENTRADA DO HARÉM","Essa entrada merece plateia.","Vitor divide o pódio com suas aliadas. A formação campeã encerra o torneio com uma apresentação no pátio."],
	["LORENZO","REDES • CONEXÃO","70dcff","CONEXÃO MÁXIMA","Sua rota termina aqui.","Lorenzo conecta o campus inteiro para transmitir a final. Nenhum pacote se perde na festa da UFN."],
	["LEONARDO","EMBALO • FINTAS","f2bf6d","ÚLTIMA RODADA","Um brinde ao próximo round.","Leonardo brinda com a turma depois da conquista. O troféu rende mais histórias do que qualquer rodada."],
	["CRISTIAN","ARQUITETURA • CONSTRUÇÃO","f6ad75","CASA PRONTA","Tudo começa com uma boa fundação.","Cristian ergue um pavilhão para celebrar o campeonato. A UFN ganha espaço para os próximos projetos."],
	["FERNANDO","MARIONETE • URSO","cf9a6d","GRANDE ESPETÁCULO","Atenção ao meu comando.","Fernando e seu urso dividem os aplausos. A apresentação final vira tradição do campus."],
	["ANDRÉ CSTH","CHEFE • GASES CARTUNESCOS","bee17c","APOCALIPSE GASOSO","É melhor abrir as janelas.",""],
	["KELVIN","CHEFE • SKATE","d5a1ff","LINHA PERFEITA","Essa pista é minha.",""]

]
const PLAYABLE = 14
const IDS = ["arthur","vitorbem","maria","diogo","mirkos","felipe","murilo","gabriel","fabiano","vitormal","lorenzo","leonardo","cristian","fernando","andre","kelvin"]
const SPEEDS = [3.5,4.0,4.1,4.0,3.7,4.6,4.7,5.0,3.9,4.3,4.6,3.8,3.6,3.7,3.3,5.2]
const VISUALS = ["dumbbell","rage","capybara","roots","exosuit","football","handball","car","equation","allies","network","foam","brick","bear","gas","skate"]

func move(n: String, kind: String = "strike", damage: float = 60.0, start: int = 10, active: int = 4, recovery: int = 22, reach: float = 135.0, cost: float = 20.0, extras: Dictionary = {}) -> Dictionary:
	var m := {"name":n,"kind":kind,"damage":damage,"startup":start,"active":active,"recovery":recovery,"range":reach,"height":80.0,"offset_y":-116.0,"guard_damage":18.0,"cost":cost,"level":"mid","hitstun":23,"blockstun":13,"push":5.0,"launch":0.0,"speed":0.0,"duration":90,"cancel":false,"family":"special","chip":0.06,"invuln":0,"freeze":0,"pull":0.0,"chargeable":false,"visual":"impact","body_pose":"punch","gravity":0.0,"vy":0.0,"bounces":0,"pulse_count":1,"pulse_interval":24,"root":0,"setup_time":0}
	m.merge(extras,true)
	# JSON supplies tuning values only; move identities and mechanics remain typed.
	var config_name = n+" [DEFENSE]" if m.family == "defense" else n
	var entry = balance_overrides.get(config_name,{})
	var overrides: Dictionary = entry if entry is Dictionary else {}
	for key in overrides:
		if m.has(key) and key not in ["name","kind","family"]:
			var value = overrides[key]
			if typeof(m[key]) in [TYPE_INT,TYPE_FLOAT] and typeof(value) in [TYPE_INT,TYPE_FLOAT]:
				m[key] = int(value) if typeof(m[key]) == TYPE_INT else float(value)
			elif typeof(m[key]) == typeof(value):
				m[key] = value
	return m

func normals() -> Array:
	return [
		move("SOCO RÁPIDO","strike",42,6,3,11,106,0,{"family":"normal","cancel":true,"guard_damage":8.0,"hitstun":21,"body_pose":"punch"}),
		move("GOLPE EM AVANÇO","strike",58,9,4,15,140,0,{"family":"normal","cancel":true,"guard_damage":12.0,"speed":1.8}),
		move("SOCO DE RECUO","strike",46,8,4,16,125,0,{"family":"normal","cancel":true,"guard_damage":10.0,"speed":-1.8}),
		move("RASTEIRA","strike",46,8,4,20,128,0,{"family":"normal","cancel":true,"guard_damage":10.0,"level":"low","offset_y":-39.0,"height":47.0,"body_pose":"sweep"}),
		move("GOLPE AÉREO","strike",50,6,9,12,113,0,{"family":"normal","cancel":true,"guard_damage":10.0,"level":"high","offset_y":-79.0,"height":112.0,"body_pose":"airkick"}),
		move("CHUTE EM MERGULHO","strike",60,8,8,18,150,0,{"family":"normal","cancel":true,"guard_damage":12.0,"level":"high","offset_y":-52.0,"height":102.0,"speed":3.0,"body_pose":"airkick"}),
		move("SOCO FORTE","strike",86,16,5,28,156,0,{"family":"normal","cancel":true,"guard_damage":27.0,"push":9.0,"launch":-5.0,"body_pose":"heavy"}),
		move("ASCENDENTE","uppercut",69,10,7,29,111,0,{"family":"normal","cancel":true,"guard_damage":15.0,"offset_y":-170.0,"height":190.0,"launch":-10.0,"body_pose":"uppercut"}),
		move("CHUTE ALTO","strike",65,11,5,23,173,0,{"family":"normal","cancel":true,"guard_damage":16.0,"level":"high","offset_y":-140.0,"height":120.0,"body_pose":"kick"})
	]

func character(id: int) -> Dictionary:
	var index := clampi(id,0,ROSTER.size()-1)
	var r: Array = ROSTER[index]
	var base = BASE.duplicate()
	base.walk_speed = SPEEDS[index]
	return {"id":index,"name":r[0],"title":r[1],"color":r[2],"super":r[3],"quote":r[4],"ending":r[5],"playable":index<PLAYABLE,"difficulty":[2,1,2,2,3,2,2,2,3,2,3,2,3,4,4,4][index],"specials":specials(index),"defense":defense(index),"base":base,"signature":["SOCO RÁPIDO","SOCO FORTE",specials(index)[0].name]}

func specials(id: int) -> Array:
	match id:
		0: return [move("ROSCA EXPLOSIVA","uppercut",96,12,8,28,136,18,{"speed":4.0,"height":195.0,"launch":-12.0,"visual":"dumbbell","body_pose":"uppercut"}),move("PESO MORTO","wave",98,23,7,34,235,20,{"level":"low","height":63.0,"offset_y":-32.0,"guard_damage":30.0,"visual":"barbell","body_pose":"heavy"}),move("PEGADA DE FERRO","throw",145,10,4,35,99,20,{"family":"throw","visual":"dumbbell","body_pose":"grab"})]
		1: return [move("RECLAMAÇÃO EXPLOSIVA","burst",68,13,5,23,151,15,{"push":13.0,"visual":"rage","body_pose":"projectile"}),move("PERDEU A PACIÊNCIA","dash",84,11,7,29,144,18,{"speed":7.0,"visual":"rage","body_pose":"punch"}),move("RESPIRA NADA","buff",0,19,1,29,0,10,{"duration":300,"visual":"rage","body_pose":"charge"})]
		2: return [move("DISPARO CERTEIRO","projectile",66,20,1,25,34,0,{"speed":18.0,"duration":65,"visual":"bullet","body_pose":"projectile"}),move("CAPIVARA VAI!","projectile",78,19,1,28,78,20,{"speed":7.7,"vy":-7.0,"gravity":0.28,"visual":"capybara","body_pose":"throw"}),move("RECARGA ESPERTA","reload",0,12,1,48,0,0,{"speed":-2.5,"visual":"reload","body_pose":"crouch"})]
		3: return [move("CHICOTE DE CIPÓ","pull",73,16,5,24,253,16,{"pull":5.0,"visual":"vine","body_pose":"projectile"}),move("NÉVOA VERDE","cloud",0,20,1,28,150,18,{"duration":210,"visual":"smoke","body_pose":"projectile"}),move("RAÍZES ASCENDENTES","trap",66,23,1,31,230,22,{"duration":140,"root":28,"visual":"roots","body_pose":"heavy","setup_time":22})]
		4: return [move("DRONE DE PULSO","drone",65,20,1,28,70,18,{"speed":9.0,"duration":90,"setup_time":22,"visual":"drone","body_pose":"projectile"}),move("SENTINELA","sentry",29,29,1,37,50,24,{"duration":240,"speed":7.4,"visual":"robot","body_pose":"crouch"}),move("ESCUDO ADAPTATIVO","counter",92,4,18,30,146,18,{"reflect":true,"visual":"shield","body_pose":"block"})]
		5: return [move("CHUTE COLOCADO","projectile",76,17,1,27,57,16,{"speed":9.0,"vy":-0.8,"gravity":0.025,"visual":"football","body_pose":"kick"}),move("CARRINHO LIMPO","slide",80,12,8,36,150,18,{"speed":7.5,"level":"low","offset_y":-43.0,"height":58.0,"visual":"football","body_pose":"sweep"}),move("EMBAIXADINHA PREPARADA","prepare",0,18,1,14,0,10,{"duration":210,"visual":"football","body_pose":"kick"})]
		6: return [move("ARREMESSO EM SUSPENSÃO","jump_toss",79,19,1,29,55,18,{"speed":8.7,"vy":5.0,"visual":"handball","body_pose":"airkick"}),move("PASSE PICADO","projectile",70,16,1,25,56,16,{"speed":8.0,"vy":5.8,"gravity":0.1,"bounces":2,"level":"low","visual":"handball","body_pose":"throw"}),move("FINTA DE QUADRA","feint",0,7,1,17,150,12,{"duration":160,"visual":"handball","body_pose":"run"})]
		7: return [move("ARRANCADA","dash",86,10,8,33,150,18,{"speed":9.0,"visual":"speed","body_pose":"run"}),move("CAVALO DE PAU","burst",78,14,7,29,161,18,{"push":10.0,"visual":"tire","body_pose":"spin"}),move("PASSAGEM DE BIZ","dash",109,26,12,40,167,24,{"speed":10.0,"guard_damage":28.0,"visual":"biz","body_pose":"sweep"})]
		8: return [move("VETOR DIRECIONAL","projectile",72,16,1,24,54,16,{"speed":10.0,"visual":"vector","body_pose":"projectile"}),move("FUNÇÃO PARABÓLICA","projectile",85,22,1,27,63,19,{"speed":7.8,"vy":-8.0,"gravity":0.32,"visual":"parabola","body_pose":"throw"}),move("LOOP CALCULADO","loop",33,24,1,31,235,24,{"duration":125,"pulse_count":3,"pulse_interval":26,"visual":"loop","body_pose":"projectile","setup_time":24})]
		9: return [move("DUPLA INVESTIDA","allies",42,20,1,29,67,20,{"speed":7.0,"duration":85,"visual":"ally","body_pose":"projectile"}),move("DISTRAÇÃO CHARMOSA","feint",0,9,1,26,-145,16,{"duration":120,"visual":"hearts","body_pose":"run"}),move("GUARDA DO SÉQUITO","counter",94,4,17,31,150,20,{"visual":"ally","body_pose":"block"})]

		10:return [move("PACOTE EXPRESSO","projectile",70,19,1,27,45,16,{"speed":7.0,"visual":"packet","body_pose":"projectile"}),move("ROTA ALTERNATIVA","teleport",0,18,1,27,160,19,{"visual":"network","body_pose":"run"}),move("FIREWALL","barrier",0,19,1,31,48,22,{"duration":135,"visual":"firewall","body_pose":"block"})]
		11:return [move("BRINDE DE IMPACTO","strike",79,13,6,27,150,16,{"visual":"mug","body_pose":"punch"}),move("PASSO CAMBALEANTE","evade",0,13,1,27,-125,12,{"visual":"foam","body_pose":"spin"}),move("MAIS UM TRAGO","drink",0,22,1,38,0,0,{"duration":480,"visual":"mug","body_pose":"guard"})]
		12:return [move("TIJOLADA CALCULADA","projectile",83,22,1,30,58,18,{"speed":7.5,"vy":-4.8,"gravity":0.22,"visual":"brick","body_pose":"throw"}),move("PAREDE DE EMERGÊNCIA","barrier",0,25,1,36,45,23,{"duration":180,"visual":"wall","body_pose":"heavy"}),move("FUNDAÇÃO ASCENDENTE","trap",84,23,1,33,245,24,{"duration":110,"setup_time":28,"visual":"pillar","body_pose":"heavy","launch":-8.0})]
		13:return [move("PATADA COMANDADA","strike",89,16,6,30,126,18,{"visual":"bear","body_pose":"projectile"}),move("ABRAÇO DE URSO","throw",142,18,4,36,109,21,{"family":"throw","visual":"bear","body_pose":"grab"}),move("VOLTA PARA MIM","strike",66,15,7,29,111,14,{"visual":"bear_return","body_pose":"projectile","level":"low","offset_y":-49.0,"height":67.0})]
		14:return [move("ARROTO SÔNICO","strike",81,25,7,34,210,17,{"visual":"burp","body_pose":"projectile","push":12.0}),move("NUVEM DE RESPEITO","loop",27,28,1,37,245,23,{"duration":155,"setup_time":32,"pulse_count":3,"pulse_interval":35,"visual":"gas","body_pose":"crouch"}),move("PROPULSÃO GASOSA","dash",90,24,10,40,145,20,{"speed":6.2,"visual":"gas","body_pose":"run"})]
		15:return [move("OLLIE ASCENDENTE","uppercut",89,21,8,37,145,18,{"visual":"skate","body_pose":"uppercut","launch":-11.0}),move("KICKFLIP DE IMPACTO","strike",88,21,8,37,188,20,{"visual":"skate","body_pose":"spin"}),move("GRIND RADICAL","dash",98,30,12,45,160,24,{"speed":7.0,"visual":"rail","body_pose":"run"})]
	return []

func defense(id: int) -> Dictionary:
	return move("REVERSÃO", "counter",72,3,12,30,150,35,{"family":"defense","visual":VISUALS[clampi(id,0,ROSTER.size()-1)],"body_pose":"block"})

func super_move(id: int) -> Dictionary:
	var i = clampi(id,0,ROSTER.size()-1)
	var kind = ["throw","counter","projectile","trap","transform","uppercut","projectile","dash","trap","allies","projectile","strike","trap","throw","loop","dash"][i]
	var extras = {"family":"super","guard_damage":45.0,"chip":0.04,"hitstun":42,"launch":-10.0,"push":14.0,"height":185.0,"offset_y":-125.0,"visual":VISUALS[i],"body_pose":"projectile","speed":0.0,"duration":150}
	if i == 0: extras.merge({"body_pose":"grab"},true)
	if i == 1: extras.merge({"body_pose":"charge"},true)
	if i == 2: extras.merge({"speed":11.0,"body_pose":"projectile"},true)
	if i == 3: extras.merge({"root":30,"setup_time":30,"body_pose":"heavy"},true)
	if i == 4: extras.merge({"duration":480,"body_pose":"charge"},true)
	if i == 5: extras.merge({"body_pose":"uppercut"},true)
	if i == 6: extras.merge({"speed":13.0,"body_pose":"throw"},true)
	if i == 7: extras.merge({"speed":9.5,"body_pose":"run"},true)
	if i == 8: extras.merge({"setup_time":28,"body_pose":"projectile"},true)
	if i == 9: extras.merge({"speed":9.0,"body_pose":"projectile"},true)
	if i==10:extras.merge({"speed":9.0,"visual":"network"},true)
	if i==11:extras.merge({"body_pose":"spin","visual":"foam"},true)
	if i==12:extras.merge({"setup_time":30,"visual":"house"},true)
	if i==13:extras.merge({"body_pose":"projectile","visual":"bear"},true)
	if i==14:extras.merge({"setup_time":38,"duration":185,"pulse_count":3,"pulse_interval":44,"visual":"gas","damage":93,"launch":0.0,"push":5.0,"hitstun":16},true)
	if i==15:extras.merge({"speed":7.5,"body_pose":"run","visual":"skate"},true)
	return move(ROSTER[i][3],kind,280,12 if i == 1 else 27,42 if i == 1 else 9,44,104 if i == 0 else (82 if i in [2,6,9,10] else (106 if i==13 else 285)),100,extras)
