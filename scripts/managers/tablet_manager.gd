extends Node
## Autoload. Rastreia os tablets do desafio e quantos ja foram ativados.
## Tambem resolve a ativacao quando o jogador aperta de frente para um tablet.

const TOTAL := 5
const INTERACT_RANGE := 4.5         # alcance maximo para ativar (unidades)
const FACING_MIN := 0.5             # cos do angulo: precisa estar olhando para ele

signal count_changed(activated: int, total: int)
## Emitido quando o jogador ativa todos os tablets (abre o desafio da saida).
signal challenge_complete
signal tablet_minigame_requested(tablet, player)
signal tablet_minigame_cancelled

var tablets: Array = []
var activated_count := 0
var active_tablet = null
var active_player = null
var _progress := {}

func register(t) -> void:
	if not tablets.has(t):
		tablets.append(t)
		count_changed.emit(activated_count, TOTAL)

func notify_activated(_t) -> void:
	activated_count += 1
	count_changed.emit(activated_count, TOTAL)
	if activated_count >= TOTAL:
		challenge_complete.emit()

## Limpa o estado (usado ao reiniciar o jogo; os tablets antigos sao liberados
## junto com a cena).
func reset() -> void:
	cancel_minigame()
	tablets.clear()
	activated_count = 0
	_progress.clear()
	count_changed.emit(activated_count, TOTAL)

## Tenta ativar o tablet para o qual o jogador esta olhando (mais bem alinhado
## dentro do alcance). Retorna true se ativou algum.
func try_activate(origin: Vector3, look_dir: Vector3, player = null) -> bool:
	if active_tablet != null:
		cancel_minigame()
		return true

	look_dir = look_dir.normalized()
	var best = find_target(origin, look_dir)
	if best != null:
		active_tablet = best
		active_player = player
		tablet_minigame_requested.emit(best, player)
		return true
	return false

func find_target(origin: Vector3, look_dir: Vector3):
	look_dir = look_dir.normalized()
	var best = null
	var best_score := FACING_MIN
	for t in tablets:
		if t == null or not is_instance_valid(t) or t.is_activated:
			continue
		var to: Vector3 = t.global_position - origin
		var dist := to.length()
		if dist > INTERACT_RANGE or dist < 0.001:
			continue
		var facing := look_dir.dot(to / dist)
		if facing > best_score:
			best_score = facing
			best = t
	return best

func is_minigame_active() -> bool:
	return active_tablet != null

func get_stage(t) -> int:
	return int(_progress.get(t, 0))

func save_stage(t, stage: int) -> void:
	_progress[t] = clampi(stage, 0, 2)

func cancel_minigame() -> void:
	if active_player != null and is_instance_valid(active_player) and active_player.has_method("set_tablet_minigame_active"):
		active_player.set_tablet_minigame_active(false)
	active_tablet = null
	active_player = null
	tablet_minigame_cancelled.emit()

func complete_minigame(t) -> bool:
	if t == null or not is_instance_valid(t) or t.is_activated:
		cancel_minigame()
		return false
	_progress.erase(t)
	active_tablet = null
	if active_player != null and is_instance_valid(active_player) and active_player.has_method("set_tablet_minigame_active"):
		active_player.set_tablet_minigame_active(false)
	active_player = null
	tablet_minigame_cancelled.emit()
	return t.activate()
