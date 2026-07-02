# Sense

Jogo 3D em primeira pessoa de "sonar": o personagem não enxerga nada no escuro.
Ao apertar **espaço**, uma onda sai do personagem e se propaga pela sala. Onde a
onda toca uma superfície surgem **partículas neon** que vão sumindo com o tempo —
as partículas atingidas primeiro (mais próximas) somem mais rápido.

## Controles
- **WASD** — mover
- **Mouse** — olhar
- **Espaço** — usar a habilidade selecionada: emitir onda (pode emitir várias
  seguidas, até 6 simultâneas) ou, com a super-audição selecionada, **segurar**
  para ouvir o Abbath
- **Tab** — alternar entre as habilidades **onda** e **super-audição**
- **Scroll** — no minigame dos tablets, ajustar a intensidade da malha
- **E** — abrir o minigame de um tablet (de frente e perto dele) / cancelar o
  minigame aberto
- **Ctrl+D** — mostrar/ocultar o painel de diagnóstico do Abbath
- **Esc** — liberar o mouse

## Habilidades: onda e super-audição
As duas habilidades **compartilham uma única carga** que recarrega sozinha em
cerca de **3 segundos**. O **HUD no canto inferior esquerdo** (arte desenhada à
mão) mostra a carga preenchendo as barras e os olhos brilhando; **Tab** troca a
pose do HUD junto com a habilidade ativa.

- **Onda** (padrão) — o pulso de sonar. Emiti-lo **zera a carga**; enquanto ela
  recarrega, você não pode emitir de novo.
- **Super-audição** — com ela selecionada, **segure espaço** para **drenar a
  carga** e ouvir o Abbath de qualquer lugar do mapa, mesmo através de paredes.
  Enquanto ativa, os passos e a onda ficam **abafados** para destacar o som dele.

Sem a super-audição você **só ouve o Abbath quando ele está à sua frente e sem
obstáculo na linha de visão**; atrás de você ou coberto por parede o som some.

## Desafio dos tablets
Há **5 tablets** (retângulos achatados) espalhados pelo mapa — grudados em
caixas, pilares ou no chão. No escuro ficam invisíveis; quando a onda passa por
um deles, ele brilha em **amarelo neon**. Ficando de frente e apertando **E**,
abre-se o **minigame de sincronização**: uma malha ondulada (verde neon) que
você molda com o **scroll** para encaixar no formato do **anel-alvo branco**,
que pulsa e muda de forma o tempo todo. Encaixado dentro da tolerância, um arco
de progresso enche; é preciso **manter o encaixe** pelo tempo exigido. São
**3 estágios (anéis)**, cada um com um tempo de espera maior. Completando os
três, o tablet muda para o **verde** das partículas e fica **aceso
permanentemente**. Afastar-se ou desviar o olhar (ou apertar **E**) cancela o
minigame. Um contador `0 / 5` no topo da tela sobe a cada tablet ativado.

## Abbath, a criatura
Pelo mapa ronda **Abbath**: um vulto humanoide alto e magro. No escuro é
invisível como tudo, mas ao contrário dos demais objetos, quando a onda passa
por ele **só a lateral (a silhueta/contorno) é marcada — nunca o centro**,
deixando apenas um vulto delineado. Seus **olhos** têm um brilho fraco
constante (mais forte quando ele está caçando), o único aviso **visual** da
presença dele.

O Abbath também **emite um som contínuo** (áudio 3D preso a ele). Sem a
super-audição, você só o escuta quando ele está **à sua frente e sem parede na
linha de visão**, e o volume cresce conforme ele se aproxima (audível até ~30
unidades, no volume cheio a partir de ~5). Com a **super-audição** ativa, você o
ouve de qualquer direção e através de paredes — a forma de rastreá-lo no escuro.

Comportamento:
- **Teleporta** para um ponto aleatório do mapa a cada **5 segundos**.
- Se você entra no **campo de visão dele (cone frontal)**, dentro do alcance e
  à vista, ele passa a **caçar**: a cada teleporte salta **mais perto** de você
  e o **intervalo entre teleportes diminui proporcionalmente à proximidade**
  (quanto mais perto, mais rápido). Isso só acontece enquanto você está no cone.
- Se ele chega **perto demais**, você toma um **jumpscare** e aparece a
  interface **REINICIAR**.
- Para **se livrar dele**, esconda-se atrás de algo que cubra **pelo menos 60%
  do seu corpo** do campo de visão dele: ele perde o alvo e **volta para um
  spawn aleatório**.

## A saída
Ao ativar os **5 tablets**, o contador vira **"ENCONTRE A SAÍDA"** e surge uma
**porta** (um pouco maior que o personagem) em alguma parede. No escuro ela é
invisível; quando a onda a atinge, a superfície inteira brilha e dali em diante
**só a moldura** fica acesa (a "amostra" da porta). Chegando perto e apertando
**E** de frente, o **miolo acende em verde neon** e aparece a interface
**REINICIAR**, que ao ser clicada recomeça o jogo do zero.

### Idiomas (i18n)
Os textos da interface (`ENCONTRE A SAÍDA`, `REINICIAR`) usam o padrão de
internacionalização do Godot via chaves (`tr("FIND_THE_EXIT")`, `tr("RESTART")`).
As traduções ficam em `scripts/managers/i18n.gd` (pt_BR, en, es) e o idioma é
escolhido pelo locale do sistema. Para adicionar um idioma, basta acrescentar os
textos das mesmas chaves para o novo locale em `i18n.gd`.

## Estrutura
Os scripts são organizados por domínio dentro de `scripts/`:

- `scenes/main.tscn` — cena principal; aponta para `scripts/main.gd`
- `scenes/hud.tscn` — camada de interface (`CanvasLayer`) com os HUDs; instanciada pelo `main.gd`
- `scripts/main.gd` — ponto de composição: monta ambiente, sala, player, instancia o HUD e (em teste) os harnesses

**`scripts/managers/`** (autoloads — estado global e coordenação)
- `wave_manager.gd` — ondas, carga compartilhada das habilidades, super-audição e parâmetros globais do shader
- `tablet_manager.gd` — conta os tablets, abre/resolve o minigame
- `door_manager.gd` — resolve a abertura da porta com **E**
- `abbath_manager.gd` — rastreia a criatura e centraliza o jumpscare
- `i18n.gd` — traduções da interface (padrão i18n do Godot)

**`scripts/gameplay/`** (entidades do mundo 3D)
- `player.gd` — controlador FPS, emissão de onda e ativação da super-audição
- `level.gd` — gera a sala (chão, teto, paredes, pilares, caixas) com colisão
- `abbath.gd` — a criatura Abbath (silhueta na onda, teleporte, visão em cone, áudio 3D, jumpscare)
- `tablet.gd` — um tablet do desafio (revela amarelo / ativa verde)
- `door.gd` — porta de saída (moldura na onda / miolo verde ao abrir)

**`scripts/ui/`** (interface em `CanvasLayer`)
- `wave_cooldown_hud.gd` — HUD da onda (arte PNG, barras que enchem com a carga, brilho dos olhos, pose por habilidade)
- `tablet_minigame_ui.gd` — minigame de sincronização (malha por scroll x anel-alvo)
- `tablet_counter_hud.gd` — contador `0 / 5` na tela
- `restart_ui.gd` — interface **REINICIAR** (recarrega o jogo)
- `debug_hud.gd` — painel de diagnóstico do Abbath (Ctrl+D)

**`scripts/test/`** (harnesses acionados por flag de linha de comando)
- `test_capture.gd` — ondas · `test_tablets.gd` — desafio dos tablets · `test_doors.gd` — porta de saída
- `test_abbath.gd` — criatura · `test_abbath_sound.gd` — áudio 3D (cone, oclusão, super-audição)
- `test_hud_pose.gd` — poses do HUD · `test_debug_hud.gd` — painel de diagnóstico

**`assets/`**
- `shaders/sonar.gdshader` — material de sonar (pontos neon + frente de onda + fade)
- `shaders/tablet.gdshader` — material dos tablets (amarelo na onda, verde ao ativar)
- `shaders/door.gdshader` — material da porta (moldura persistente + miolo verde)
- `shaders/abbath.gdshader` — material da criatura (marca só a lateral/silhueta)
- `abbath.glb` — modelo 3D usado para montar o vulto
- `wave_power.png`, `super_hearing.png`, `power_bar.png` — arte do HUD (corpo, pose alternativa, barras)

## Som
- `sounds/wave.ogg` — estouro da onda ao emitir, com atenuação por alcance.
- `sounds/walking.ogg` — passos do player (com reverb da sala), no bus `Footsteps`.
- `sounds/abbath.ogg` — som contínuo 3D do Abbath, no bus `EnemyFocus`.

Com a super-audição ativa, o `WaveManager` **abafa** os buses de passos e da
onda para o som do Abbath se destacar.

Os parâmetros das ondas (velocidade, vida, alcance) ficam em
`WaveManager` e no bloco `[shader_globals]` do `project.godot`.

## Testar visualmente (sem jogar manualmente)
Roda o jogo, emite uma onda automaticamente e salva screenshots em vários
instantes em `test_output/`, depois fecha sozinho:

```powershell
& "C:\Users\Luiz\Documents\Godot_v4.6.2-stable_win64.exe" --path "C:\Users\Luiz\Documents\sense" -- --autotest
```

### Testar o desafio dos tablets
Posiciona o player na frente de alguns tablets, emite a onda (brilho amarelo),
ativa cada um pelo caminho real (vira verde, contador sobe) e salva screenshots
em `test_output/` — incluindo um tablet aceso sozinho no escuro:

```powershell
& "C:\Users\Luiz\Documents\Godot_v4.6.2-stable_win64.exe" --path "C:\Users\Luiz\Documents\sense" -- --tablettest
```

### Testar a saída
Ativa os 5 tablets (o contador vira "ENCONTRE A SAÍDA" e a porta surge numa
parede), revela a porta com uma onda (sobra só a moldura), abre com **E** (miolo
verde) e confirma a interface **REINICIAR**. Salva screenshots em `test_output/`:

```powershell
& "C:\Users\Luiz\Documents\Godot_v4.6.2-stable_win64.exe" --path "C:\Users\Luiz\Documents\sense" -- --doortest
```

### Testar a criatura Abbath
Valida, de forma determinística, todas as mecânicas da criatura: marca só a
silhueta quando a onda passa, visão em cone, esconder ≥60% do corpo para perdê-la,
intervalo de teleporte proporcional à proximidade e o jumpscare ao chegar perto.
Imprime `PASS`/`FAIL` de cada checagem e salva screenshots em `test_output/`:

```powershell
& "C:\Users\Luiz\Documents\Godot_v4.6.2-stable_win64.exe" --path "C:\Users\Luiz\Documents\sense" -- --abbathtest
```

Para testar so a modelagem/silhueta do Abbath sem montar o mapa nem rodar as
mecanicas do jogo, use o preview isolado. Ele salva frente, lateral e 3/4 em
`test_output/`:

```powershell
& "C:\Users\Luiz\Documents\Godot_v4.6.2-stable_win64.exe" --path "C:\Users\Luiz\Documents\sense" -- --abbathmodeltest
```

Para abrir a modelagem isolada em uma janela e olhar o Abbath fora do gameplay
(sem mapa, HUD, onda ou jumpscare), use:

```powershell
& "C:\Users\Luiz\Documents\Godot_v4.6.2-stable_win64.exe" --path "C:\Users\Luiz\Documents\sense" -- --abbathmodelview
```

### Testar o áudio 3D do Abbath
Valida, de forma determinística, o som contínuo da criatura: existe e toca em
loop, cresce com a proximidade, só é audível no cone frontal com linha de visão
livre, some quando ocluído por parede e volta a ser audível de qualquer direção
(inclusive através de paredes) com a super-audição ativa. Imprime `PASS`/`FAIL`:

```powershell
& "C:\Users\Luiz\Documents\Godot_v4.6.2-stable_win64.exe" --path "C:\Users\Luiz\Documents\sense" -- --abbathsoundtest
```

### Testar o HUD da onda
Exercita as poses do HUD (onda x super-audição), o preenchimento das barras
conforme a carga e o brilho dos olhos, salvando screenshots em `test_output/`:

```powershell
& "C:\Users\Luiz\Documents\Godot_v4.6.2-stable_win64.exe" --path "C:\Users\Luiz\Documents\sense" -- --hudposetest
```

### Testar o painel de diagnóstico
Abre o painel de diagnóstico do Abbath (Ctrl+D) e valida os campos exibidos,
salvando screenshots em `test_output/`:

```powershell
& "C:\Users\Luiz\Documents\Godot_v4.6.2-stable_win64.exe" --path "C:\Users\Luiz\Documents\sense" -- --debughudtest
```

## Rodar normalmente
```powershell
& "C:\Users\Luiz\Documents\Godot_v4.6.2-stable_win64.exe" --path "C:\Users\Luiz\Documents\sense"
```
