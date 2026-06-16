# Sense

Jogo 3D em primeira pessoa de "sonar": o personagem não enxerga nada no escuro.
Ao apertar **espaço**, uma onda sai do personagem e se propaga pela sala. Onde a
onda toca uma superfície surgem **partículas neon** que vão sumindo com o tempo —
as partículas atingidas primeiro (mais próximas) somem mais rápido.

## Controles
- **WASD** — mover
- **Mouse** — olhar
- **Espaço** — emitir onda (pode emitir várias seguidas, até 6 simultâneas)
- **Esc** — liberar o mouse

## Estrutura
- `scenes/main.tscn` — cena principal (monta ambiente, sala e player via `scripts/main.gd`)
- `scripts/wave_manager.gd` — autoload; gerencia as ondas e os parâmetros globais do shader
- `scripts/player.gd` — controlador FPS e emissão de onda
- `scripts/level.gd` — gera a sala (chão, teto, paredes, pilares, caixas) com colisão
- `assets/sonar.gdshader` — material de sonar (pontos neon + frente de onda + fade)
- `scripts/test_capture.gd` — harness de teste automático

Os parâmetros das ondas (velocidade, vida, alcance) ficam em
`WaveManager` e no bloco `[shader_globals]` do `project.godot`.

## Testar visualmente (sem jogar manualmente)
Roda o jogo, emite uma onda automaticamente e salva screenshots em vários
instantes em `test_output/`, depois fecha sozinho:

```powershell
& "C:\Users\Luiz\Documents\Godot_v4.6.2-stable_win64.exe" --path "C:\Users\Luiz\Documents\sense" -- --autotest
```

## Rodar normalmente
```powershell
& "C:\Users\Luiz\Documents\Godot_v4.6.2-stable_win64.exe" --path "C:\Users\Luiz\Documents\sense"
```
