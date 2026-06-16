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

## Rodar normalmente
```powershell
& "C:\Users\Luiz\Documents\Godot_v4.6.2-stable_win64.exe" --path "C:\Users\Luiz\Documents\sense"
```
