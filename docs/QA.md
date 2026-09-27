# Validação — UFN Combate 0.2.0

## Ambiente

Windows x64, **Godot 4.7.2 stable**, renderer Compatibility/OpenGL 3.3. A captura nativa identificou CPU **Intel Core i5-1235U (12ª geração)** e GPU **Intel Iris Xe Graphics**, driver **32.0.101.7085**. Resolução base: 1280 × 720.

Os resultados abaixo descrevem as execuções registradas nesta entrega. Não são uma certificação de compatibilidade com todo computador ou de balanceamento competitivo.

## Testes automatizados

A suíte completa `tools/test.ps1` foi executada em **27/09/2026**, incluindo importação dos recursos e as nove suítes abaixo. O processo terminou com código 0, sem erros de importação, parser ou execução registrados no log `work/release-suite.log`:

| Suíte | Verificações | Falhas |
|---|---:|---:|
| `ufn_combat_test.gd` | 194 | 0 |
| `modules_test.gd` | 60 | 0 |
| `audio_test.gd` | 47 | 0 |
| `defense_test.gd` | 11 | 0 |
| `data_test.gd` | 12 | 0 |
| `flow_test.gd` | 32 | 0 |
| `test_kart.gd` | 26 | 0 |
| `v2_test.gd` | 64 | 0 |
| `release_test.gd` | 43 | 0 |
| **Total** | **489** | **0** |

Cobertura principal:

- Comandos, defesa alta/baixa, dano, especiais, energia e limites de combate.
- Quatro botões de ação; prioridade das combinações com defesa; ausência de golpe normal quando Ultimate/troca estão indisponíveis.
- Troca manual, intervalo e entrada forçada após KO; vida de chefes por dificuldade e timeout proporcional.
- Ataques de Fernando a partir do urso, postura sem perda de vida do dono e interrupção ao atingir Fernando.
- Embalo de Leonardo sem cura; consumo no ataque.
- Novos Ultimates: custo integral, captura quando aplicável e devolução do controle; gás de André sem captura.
- Remapeamento de teclado/gamepad, conflitos, perfil sem numérico, mapas separados de luta/kart, persistência e recuperação de perfil.
- Torre com oito lutadores e dois chefes, retomada no andar salvo e torneio de oito resolvendo sete confrontos.
- Kart com dois humanos e seis CPUs, 14 poderes utilizáveis, contrarrelógio sem CPU/caixas, campeonato com pontos preservados.
- Aceleração, freio, direção, drift, checkpoints, volta inválida por ré/atalho, escudo, impacto, pausa e reposicionamento.
- CPU completando três voltas válidas nas quatro pistas: 54,9 s, 50,7 s, 71,9 s e 64,0 s de simulação na execução registrada.
- Tutorial completo com comandos reais, passagem para o kart e conquista persistida; KO simultâneo de duplas e round extra; tentativa e conclusão da torre.
- Campeonato de quatro etapas com retomada, identidade dos pilotos preservada, evento de chegada idempotente e campeão definido pela pontuação acumulada.
- Recursos e encerramento do áudio.

Os testes de entrada física usam a API de entrada e cenários controlados. Eles **não comprovam** a ausência de ghosting em um teclado específico nem o comportamento de dois controles USB reais.

## Sessões nativas e desempenho

**60 FPS sustentados não foram comprovados.** A amostra curta de captura atingiu 60 FPS, mas as sessões funcionais mais extensas abaixo apresentaram cadência inferior. Os resultados têm condições diferentes e não devem ser resumidos apenas pelo melhor valor.

Todas as medições usaram Godot nativo, renderer Compatibility e janela 1280 × 720, no hardware descrito acima. Os valores são o inverso de `root.get_process_delta_time()` por frame de processamento, ordenados para calcular mediana e percentil 5. Não são leituras de `Engine.get_frames_per_second()`, tempos diretos da GPU, latência de entrada ou frequência da simulação física, que permanece configurada em 60 passos por segundo.

### Amostra curta de captura

O script `capture_v2.gd` registrou os resultados abaixo após o agrupamento da geometria estática do kart por material, com qualidade leve. Houve 120 frames de aquecimento e aproximadamente 300 frames medidos por modo (cerca de cinco segundos). O foco/posição da janela e a carga dos demais processos não foram registrados nesse log.

| Cenário | Mediana | Percentil 5 |
|---|---:|---:|
| Luta | 60 FPS | 60 FPS |
| Kart com tela dividida | 60 FPS | 60 FPS |

### Sessões funcionais de aproximadamente 96 segundos

`session_test.gd` usa uma janela com `WINDOW_FLAG_NO_FOCUS`, deslocada para `(-30000, -30000)`, com bots no lugar das entradas humanas e pausa automática por perda de foco desativada para a validação. A primeira execução, em 25/09/2026, forçou **qualidade padrão (0)**. Em 27/09/2026, uma cópia em `work/session-light.gd` repetiu a sequência alterando apenas essa opção para **leve (1)**. Não havia outra instância Godot ao iniciar a segunda execução; a carga total do sistema não foi controlada nem registrada.

Cada segmento descarta seus primeiros 500 ms. As durações abaixo são do segmento completo, incluindo esse descarte:

| Cenário | Qualidade | Duração | Frames medidos | Mediana | Percentil 5 |
|---|---|---:|---:|---:|---:|
| Luta Fernando × Kelvin | Padrão | 15 s | 434 | 30,00 FPS | 28,80 FPS |
| Kart dividido vertical | Padrão | 22 s | 436 | 20,57 FPS | 15,66 FPS |
| Kart dividido horizontal | Padrão | 15 s | 304 | 20,57 FPS | 18,34 FPS |
| Luta Fernando × Kelvin | Leve | 15 s | 444 | 30,69 FPS | 30,00 FPS |
| Kart dividido vertical | Leve | 22 s | 352 | 17,50 FPS | 11,11 FPS |
| Kart dividido horizontal | Leve | 15 s | 261 | 19,29 FPS | 13,18 FPS |

Nos trechos de retomada e revanche da sessão leve, a luta registrou medianas de 27,27 e 28,80 FPS e percentis 5 de 23,33 e 20,00 FPS. A diferença entre as execuções não isola o efeito da qualidade: foco/visibilidade, personagens, carga de cena e carga externa também diferem da captura curta. Não há evidência suficiente para atribuir os números a uma causa específica ou estimar o desempenho de uma partida em primeiro plano.

As duas sessões verificam 11 comportamentos: avanço da luta, pausa, retomada, revanche sem vitórias herdadas, nova seleção, oito pilotos/duas câmeras, pausa e retomada do kart, reinício horizontal, liberação do mundo 3D e retorno à luta. A primeira durou **96,27 s** e a repetição leve, **96,44 s**, cada uma com **11 verificações, zero falhas, saída 0 e sem erros no stderr**. Ambas terminaram com 27 nós (mesma contagem da referência) e zero nós órfãos. A memória estática subiu de 48.546.846 para 73.436.295 bytes na primeira e de 48.544.393 para 73.311.334 bytes na segunda; essas observações isoladas não demonstram ausência de vazamentos.

Essas sessões ampliam a cobertura funcional, mas ainda não são testes térmicos, sessões longas com jogadores ou benchmarks controlados. Os números não devem ser extrapolados para 1080p, outros drivers ou computadores. A captura de interface em 1080p não constitui benchmark nessa resolução.

## Inspeção visual

Capturas reais do projeto, geradas em Godot:

- [Menu](screens/menu.png), [seleção](screens/select.png), [arenas](screens/stage.png).
- [Luta com Fernando e urso](screens/fight.png), [torre](screens/tower.png).
- [Configurações](screens/settings.png), [controles](screens/controls.png), [créditos](screens/credits.png).
- [Kart vertical](screens/kart.png), [kart horizontal](screens/kart_horizontal.png), [pódio](screens/podium.png).
- Novos Ultimates: [Lorenzo](screens/ultimate_10.png), [Leonardo](screens/ultimate_11.png), [Cristian](screens/ultimate_12.png), [Fernando](screens/ultimate_13.png), [André](screens/ultimate_14.png) e [Kelvin](screens/ultimate_15.png).

Foram conferidos carregamento dos sprites, transparência, associação dos personagens, alinhamento dos pés, contraste das telas, HUD e apresentação das habilidades. Capturas congeladas não substituem avaliação de animação e resposta em uma partida humana.

## Formato de distribuição Windows

O Controle de Aplicativo do Windows bloqueou a exportação convencional modificada e sem assinatura. A distribuição foi ajustada sem alterar essa proteção: `tools/build.ps1 -SignedRuntime` preserva byte a byte o executável oficial **Godot 4.7.2**, cuja assinatura Authenticode foi verificada como **Valid**, renomeando-o para **UFNCombate.exe** e exportando os recursos do jogo para **UFNCombate.pck** separado. Ambos devem permanecer na mesma pasta. A assinatura pertence à engine oficial e não certifica o conteúdo ou a autoria do jogo. Essa verificação de assinatura não substitui a validação funcional do pacote exportado.

### Verificação do pacote em 27/09/2026

O próprio `outputs/Windows/UFNCombate.exe`, com o PCK ao lado, foi aberto em quatro execuções: menu, créditos, luta Fernando/Kelvin e kart com duas câmeras. Todas produziram captura, encerraram com código 0 e sem erros da engine. As capturas de créditos e luta acima vêm desse pacote. Os logs ficaram em `work/export-smoke.log` e `work/export-*.log`/`.err`. O SHA-256 do executável foi comparado ao binário oficial original e é idêntico; Authenticode permaneceu válido. O teste confirma abertura e carregamento dos modos, sem substituir uma partida humana completa.

## Limites e próximas validações

- As poses fornecidas são reaproveitadas entre estados e interpolações. A inspeção encontrou fragmentos de poses vizinhas em recortes das novas pranchas; a correção limita a região desenhada por quadro e reutiliza uma pose íntegra onde faltava parte do corpo. Caminhadas e transições de alguns personagens usam poses repetidas/alternativas. Animação completa, mais desenhos específicos e coreografia corporal permanecem pendentes.
- Cenários de luta usam imagem principal e efeitos; a separação completa em planos de paralaxe está incompleta.
- O kart tem geometria e pilotos estilizados simples. A aparência não equivale a uma produção 3D de grande orçamento.
- Quatro arenas são interpretações temáticas, sem confirmação fotográfica da instalação específica.
- Faltam sessões longas com jogadores, balanceamento por confrontos, testes de latência/ghosting e validação presencial de dois controles simultâneos.
- Não há modo online, rollback de rede ou matchmaking.
- O pacote Windows usa a engine oficial assinada e os dados locais do jogo em PCK separado; a assinatura da engine não se estende a esses dados.

A suíte automatizada e a sessão nativa são reproduzíveis pelos comandos em [TECHNICAL.md](TECHNICAL.md). Os logs de desenvolvimento utilizados foram `work/release-suite.log`, `work/v2-capture-final.log`, `work/session-native.log` e `work/session-light.log`; a pasta de trabalho não faz parte do código distribuído.
