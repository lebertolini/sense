extends Node
## Autoload. Rastreia os tablets do desafio e quantos ja foram ativados.
## Tambem resolve a ativacao quando o jogador aperta de frente para um tablet.

const TOTAL := 5
const INTERACT_RANGE := 4.5         # alcance maximo para ativar (unidades)
const FACING_MIN := 0.5             # cos do angulo: precisa estar olhando para ele

signal count_changed(activated: int, total: int)

var tablets: Array = []
var activated_count := 0

func register(t) -> void:
	if not tablets.has(t):
		tablets.append(t)
		count_changed.emit(activated_count, TOTAL)

func notify_activated(_t) -> void:
	activated_count += 1
	count_changed.emit(activated_count, TOTAL)

## Tenta ativar o tablet para o qual o jogador esta olhando (mais bem alinhado
## dentro do alcance). Retorna true se ativou algum.
func try_activate(origin: Vector3, look_dir: Vector3) -> bool:
	look_dir = look_dir.normalized()
	var best = null
	var best_score := FACING_MIN
	for t in tablets:
		if t.is_activated:
			continue
		var to: Vector3 = t.global_position - origin
		var dist := to.length()
		if dist > INTERACT_RANGE or dist < 0.001:
			continue
		var facing := look_dir.dot(to / dist)
		if facing > best_score:
			best_score = facing
			best = t
	if best != null:
		return best.activate()
	return false
