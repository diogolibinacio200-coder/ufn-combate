# Guia técnico — UFN Combate 0.2.0

## Ambiente e execução

- **Godot 4.7.2 Standard**, GDScript, Windows x64.
- Renderer **Compatibility**, OpenGL 3.3 na máquina validada.
- Interface lógica 1280 × 720, escala com preservação de proporção.
- Física de 60 passos por segundo; limite de apresentação de 60 FPS. Esse limite não garante 60 FPS sustentados; consulte as medições em [QA.md](QA.md).
- Cena inicial: `scenes/main.tscn`.
- Nenhum serviço remoto é necessário para jogar.

Importe `project.godot` no editor e execute com F5. Não versione a pasta de cache `.godot/`.

## Organização

| Arquivo | Responsabilidade |
|---|---|
| `scripts/main.gd` | Telas, seleção, rounds, modos, progressão e integração |
| `scripts/input_manager.gd` | Entradas físicas, remapeamento, gamepads e conflitos |
| `scripts/combat.gd` | Passos fixos, comandos, contatos, projéteis, defesa e duplas |
| `scripts/fighter.gd` | Estado individual, hurtbox, pushbox e atributos de referência |
| `scripts/move_db.gd` | Elenco ativo, atributos específicos, normais, especiais e Ultimates |
| `scripts/ai.gd` | Decisões dos oponentes de luta |
| `scripts/arena_view.gd` | Sprites, arenas, câmera e efeitos; lê o estado do combate |
| `scripts/interface.gd` | Menus, HUD, galeria, créditos e guias |
| `scripts/kart.gd` | Mundo 3D, pistas, condução, CPUs, itens e campeonato |
| `scripts/kart_hud.gd` | HUD de corrida, pausa, classificação e pódio |
| `scripts/audio_manager.gd` | Cache, volumes, vozes, efeitos e transições musicais |
| `scripts/save_manager.gd` | Perfil versionado, validação, gravação e recuperação |
| `data/balance.json` | Ajustes numéricos dos golpes |
| `data/roster.json` | Catálogo exportado; a definição ativa fica no MoveDB |

A simulação de luta usa dicionários de estado e eventos. O renderer e o áudio consomem esses eventos. Alterar uma pose desenhada não altera automaticamente o alcance do golpe.

## Combate

`Combat.tick()` recebe uma entrada por lado. Tempos de startup, atividade, recuperação, stun e efeitos usam frames de 60 Hz. A vida de referência é 1000, guarda 100 e energia 100; velocidade e modificadores variam por personagem.

Há nove normais contextuais, três especiais por personagem, agarrão comum e Ultimate. A janela de movimento direcional é de 18 frames, com buffer de ação de oito frames. As sequências usam o lado atual do personagem.

Com defesa segurada, o novo pressionamento de A2 tenta Ultimate; A3 tenta troca; A1 tenta agarrão, nessa prioridade. Combinações indisponíveis são consumidas e não se convertem em um golpe normal acidental.

Defesa alta/baixa é testada contra o nível do golpe. A defesa perfeita usa janela de cinco frames e o aparo frontal de três frames. Há perda de guarda, quebra de guarda, redução de dano em combos e limites de cancelamento/juggle.

Ultimates de captura confirmados usam 210 frames, cerca de 3,5 s, com impactos e retorno ao controle. Bloqueio ou erro não iniciam captura. Mirkos usa transformação; André aplica zonas de gás evitáveis, sem prender os dois lutadores numa sequência. Os novos personagens possuem efeitos próprios, mas parte dos tempos e movimentos corporais das sequências é compartilhada.

### Duplas e rounds

- `teams` guarda dois estados por lado; `team_active` indica o lutador presente.
- Vida e energia são independentes por integrante.
- Troca manual exige lutador livre, no chão, reserva vivo e intervalo encerrado.
- Intervalo de troca: 300 frames. KO pode forçar a entrada da reserva sem esperar esse intervalo.
- Objetos do personagem que sai são retirados para evitar atribuição indevida de dano/energia.
- Duração: 99 s no individual e 150 s nas duplas.
- Melhor de três; Sobrevivência exige uma vitória por adversário.
- Timeout compara a proporção de vida da equipe. Empate exige outro round.

André e Kelvin recebem vida máxima própria por dificuldade. Na ordem fácil a extremo, André usa 1100/1150/1250/1300; Kelvin usa 1150/1250/1300/1400. O HUD e o timeout usam essa vida máxima.

### Sistemas específicos

- **Lorenzo:** aceleração do pacote após 18 frames, reposicionamento e firewall consumível.
- **Leonardo:** concluir o trago concede até três níveis de Embalo por oito segundos. Um ataque com dano consome os níveis e recebe +12% por nível. Não há cura.
- **Cristian:** tijolo em arco, parede que intercepta dois projéteis ou é destruída por golpe corporal e pilar anunciado.
- **Fernando:** ataques físicos partem da posição do urso; o dono gesticula. Postura do urso é separada da vida de Fernando. Acertar o dono interrompe a ação; postura esgotada desorganiza o urso.
- **André:** ataques anunciados de gás e Ultimate com três regiões temporizadas.
- **Kelvin:** golpes com skate, ascendente, giro e investida.

## Entrada e remapeamento

Há oito entradas por jogador: quatro direções e quatro ações. O Input Manager consulta teclas físicas e botões/eixos a cada passo, gerando bordas de pressionamento e soltura.

O mapa padrão de teclado é WASD + J/K/L/U para J1 e setas + Num1/2/3/4 para J2. Gamepad: X/Y/A/LB; direcional e analógico esquerdo; Start pausa. O perfil sem numérico usa F/G/H/R para as ações de J1 e J/K/L/U para J2.

`bindings` e `kart_bindings` são separados; o mesmo vale para botões de gamepad. Dispositivo, zona morta e eixos ficam na configuração do jogador. Remapear para uma tecla ocupada troca as atribuições, evitando que a mesma tecla controle dois jogadores no mesmo mapa. Esc, Enter, Tab, F2, F3 e F11 são reservados.

O sistema permite automático, somente teclado ou somente controle. A perda de controle pausa a partida e libera retorno ao teclado. Atribuição e persistência são testadas por software; ghosting de teclado e dois controles reais simultâneos precisam ser avaliados no equipamento final.

## Sprites e arenas

Cada personagem usa:

```text
assets/sprites/<id>/atlas.png
assets/sprites/<id>/portrait.png
assets/sprites/<id>/frames.json
```

O JSON contém `frames` (retângulos), `animations` (nomes de poses em sequência), `anchor` e `source`. As células atuais medem 384 × 320, com ancoragem dos pés em **192,304**. O espelhamento acompanha a direção do lutador.

Os dez personagens anteriores e a skin têm 35 poses catalogadas por atlas. Lorenzo, Cristian e Fernando têm 30; Leonardo, 32; André e Kelvin, 26. Sequências de 24 posições repetem essas poses; **24 posições não significam 24 desenhos distintos**. Alguns estados reutilizam poses aproximadas. O urso usa um atlas independente de oito poses. A revisão dos novos recortes usa limites por quadro nos metadados para ocultar fragmentos de poses vizinhas, preservando a ancoragem. Onde o recorte de origem omite parte do corpo, uma pose íntegra alternativa é reutilizada; não são reconstruídos membros com pixels inventados. Caminhada e transições de alguns personagens, portanto, repetem poses. Consulte as notas dos respectivos `frames.json`.

Para trocar um sprite, mantenha as coordenadas de ancoragem coerentes e confira idle, caminhada, ataque, queda e espelhamento em ambas as extremidades da arena. Verifique também recortes de retrato e sombra. A lista de nomes deve continuar alinhada entre MoveDB, renderer e kart.

As oito arenas são imagens em `assets/arenas/`. A seleção usa a mesma ordem de `main.gd` e `arena_view.gd`. Há efeitos sobrepostos, mas a composição atual não é um cenário integralmente dividido em planos de paralaxe.

## Kart

O mundo 3D é compartilhado por um ou dois SubViewports, cada um com sua câmera. Circuitos fechados usam uma curva suavizada e distância acumulada para posição, orientação, classificação e condução da CPU.

Cada volta exige **20 checkpoints ordenados** e a passagem correta na chegada. Cruzar de ré, fora do portão ou pulando o próximo checkpoint não avança a volta. São três voltas por corrida. Reposicionamento conserva o progresso legítimo.

Há aceleração, frenagem/ré, direção, atrito fora da pista, drift e miniturbo, colisões, saltos em rampas, recuperação e aviso de contramão. A corrida termina após os humanos concluírem; CPUs ainda em pista são classificadas pelo progresso.

As caixas sorteiam seis categorias: pulso, turbo, escudo, choque, óleo e poder exclusivo. A capivara é o poder de Maria. Escudo absorve impacto; a recuperação concede proteção temporária para reduzir encadeamento de ataques.

O campeonato soma 15/12/10/8/6/4/2/1 pontos por posição nas quatro pistas. Reiniciar uma corrida restaura a pontuação anterior à etapa. O contrarrelógio desativa CPUs e caixas, salvando o melhor tempo local.

Geometria estática com o mesmo material é agrupada por `_batch_static_geometry()` para reduzir chamadas de desenho; karts e itens continuam independentes. A qualidade leve desativa sombras mais caras. Os modelos são estilizados e simples, não personagens 3D detalhados.

## Áudio e perfil

Há buses `UFNMusic`, `UFNSFX` e `UFNVoice`, sob o volume geral. Efeitos usam pool de 18 canais; música usa dois players para transição; narrador usa fila própria. Arquivos são pré-carregados no início.

- Música/efeitos: `tools/generate_audio.py`.
- Narrador pt-BR: `tools/generate_announcer_pt.ps1`, com Microsoft Maria Desktop instalada.

O perfil versão 2 fica em `user://profile.json`, equivalente no Windows a `%APPDATA%/Godot/app_userdata/UFN COMBATE/profile.json`. Inclui settings, stats, bindings e progress. A escrita passa por arquivo temporário e mantém `.bak`; tipos e faixas são validados na leitura. Torre salva personagem, skin, dificuldade, ordem e andar; campeonato salva pilotos, skins, humanos, próxima pista e pontos.

## Alterar conteúdo

1. **Balanceamento:** ajuste valores existentes em `data/balance.json`. `name`, `kind` e `family` permanecem definidos no código. Reinicie a simulação e rode os testes.
2. **Novo lutador:** atualize elenco/IDs/velocidades/visuais/especiais/Ultimate no MoveDB; arte e índices no renderer/interface; piloto e assinatura no kart; limites de seleção e persistência; testes.
3. **Novo comportamento:** implemente o tipo na simulação, depois o evento e a apresentação. Um nome novo no JSON não cria uma mecânica.
4. **Nova arena/pista:** atualize a lista ativa, miniatura, construção e música; confirme a seleção e o sorteio.
5. **Skin:** mantenha os mesmos dados de combate e associe somente o atlas/retrato alternativo.

## Testes e exportação

```powershell
./tools/test.ps1 -Godot 'C:/caminho/Godot_v4.7.2-stable_win64_console.exe'
./tools/build.ps1 -Godot 'C:/caminho/Godot_v4.7.2-stable_win64_console.exe' -SignedRuntime 'C:/caminho/Godot_v4.7.2-stable_win64.exe'
```

O comando recomendado importa os recursos, verifica a assinatura Authenticode do executável fornecido em `-SignedRuntime` e exporta os dados com o preset **Windows Desktop** para `../Windows/UFNCombate.pck`. Em seguida, copia o executável oficial, sem alterar seus bytes, para `../Windows/UFNCombate.exe`. O binário utilizado nesta entrega é **Godot_v4.7.2-stable_win64.exe**, com assinatura válida. O nome muda, mas a assinatura da engine é preservada; os dados do jogo não são cobertos por essa assinatura.

**Distribua o EXE e o PCK juntos, com o mesmo nome-base.** `-Output` muda o caminho do EXE; o PCK será criado ao lado dele, trocando apenas a extensão. O preset inclui explicitamente os JSONs de balanceamento e frames. Testes, ferramentas e documentação ficam fora dos dados executáveis do jogo. Mantenha os avisos de terceiros junto ao pacote Windows.

Sem `-SignedRuntime`, o script mantém a exportação Windows convencional com PCK embutido. Nesse caso, é possível indicar `-WindowsReleaseTemplate 'C:/caminho/windows_release_x86_64.exe'`; o ajuste temporário do preset é restaurado ao terminar. Essa exportação convencional não é o formato distribuído nesta entrega.

A sessão funcional nativa opcional é executada sem `--headless`, separadamente da suíte:

```powershell
& 'C:/caminho/Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/session_test.gd
```

Ela dura cerca de 96 segundos, alterna luta, menus e kart, e verifica pausa, retomada, revanche, tela dividida e liberação do mundo 3D. O script força 720p/qualidade padrão, janela sem foco e fora da tela, com bots no lugar dos jogadores. Os valores de FPS vêm do inverso do delta de processamento; não constituem benchmark em primeiro plano ou teste térmico. A simulação continua configurada em 60 passos por segundo independentemente dessa cadência de apresentação.

[Resultados e limitações da validação](QA.md) · [Lista de golpes](../GOLPES.md) · [Procedência](../LICENSES.md)
