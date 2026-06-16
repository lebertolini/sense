# Sense

Jogo 3D em primeira pessoa de "sonar": o personagem não enxerga nada no escuro.
Ao apertar **espaço**, uma onda sai do personagem e se propaga pela sala. Onde a
onda toca uma superfície surgem **partículas neon** que vão sumindo com o tempo —
as partículas atingidas primeiro (mais próximas) somem mais rápido.

## Controles
- **WASD** — mover
- **Mouse** — olhar
- **Espaço** — emitir onda (pode emitir várias seguidas, até 6 simultâneas)
- **E** — ativar um tablet (de frente e perto dele)
- **Esc** — liberar o mouse

## Desafio dos tablets
Há **5 tablets** (retângulos achatados) espalhados pelo mapa — grudados em
caixas, pilares ou no chão. No escuro ficam invisíveis; quando a onda passa por
um deles, ele brilha em **amarelo neon**. Ficando de frente e apertando **E**,
o tablet muda para o **verde** das partículas e fica **aceso permanentemente**.
Um contador `0 / 5` no topo da tela sobe a cada tablet ativado.

## Abbath, a criatura
Pelo mapa ronda **Abbath**: um vulto humanoide alto e magro. No escuro é
invisível como tudo, mas ao contrário dos demais objetos, quando a onda passa
por ele **só a lateral (a silhueta/contorno) é marcada — nunca o centro**,
deixando apenas um vulto delineado. Seus **olhos** têm um brilho fraco
constante (mais forte quando ele está caçando), o único aviso da presença dele.

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
As traduções ficam em `scripts/i18n.gd` (pt_BR, en, es) e o idioma é escolhido
pelo locale do sistema. Para adicionar um idioma, basta acrescentar os textos das
mesmas chaves para o novo locale em `i18n.gd`.

## Estrutura
- `scenes/main.tscn` — cena principal (monta ambiente, sala e player via `scripts/main.gd`)
- `scripts/wave_manager.gd` — autoload; gerencia as ondas e os parâmetros globais do shader
- `scripts/player.gd` — controlador FPS e emissão de onda
- `scripts/level.gd` — gera a sala (chão, teto, paredes, pilares, caixas) com colisão
- `assets/sonar.gdshader` — material de sonar (pontos neon + frente de onda + fade)
- `scripts/test_capture.gd` — harness de teste automático das ondas
- `scripts/tablet.gd` — um tablet do desafio (revela amarelo / ativa verde)
- `scripts/tablet_manager.gd` — autoload; conta os tablets e resolve a ativação
- `scripts/tablet_counter_hud.gd` — contador `0 / 5` na tela
- `assets/tablet.gdshader` — material dos tablets (amarelo na onda, verde ao ativar)
- `scripts/test_tablets.gd` — harness de teste do desafio dos tablets
- `scripts/door.gd` — porta de saída (moldura na onda / miolo verde ao abrir)
- `scripts/door_manager.gd` — autoload; resolve a abertura da porta com **E**
- `assets/door.gdshader` — material da porta (moldura persistente + miolo verde)
- `scripts/restart_ui.gd` — interface **REINICIAR** (recarrega o jogo)
- `scripts/i18n.gd` — autoload; traduções da interface (padrão i18n do Godot)
- `scripts/test_doors.gd` — harness de teste da porta de saída
- `scripts/abbath.gd` — a criatura Abbath (silhueta na onda, teleporte, visão em cone, jumpscare)
- `scripts/abbath_manager.gd` — autoload; rastreia a criatura e centraliza o jumpscare
- `assets/abbath.gdshader` — material da criatura (marca só a lateral/silhueta)
- `scripts/test_abbath.gd` — harness de teste da criatura Abbath

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

## Rodar normalmente
```powershell
& "C:\Users\Luiz\Documents\Godot_v4.6.2-stable_win64.exe" --path "C:\Users\Luiz\Documents\sense"
```
