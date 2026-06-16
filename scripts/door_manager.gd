extends Node
## Autoload. Rastreia a porta de saida e resolve a abertura quando o jogador
## aperta E de frente e perto dela. Avisa a interface de reiniciar.

const INTERACT_RANGE := 4.5    # alcance maximo para abrir (unidades)
const FACING_MIN := 0.5        # cos do angulo: precisa estar olhando para ela

## Emitido quando o jogador abre a porta (mostra a interface de reiniciar).
signal door_opened

var door = null

func register(d) -> void:
	door = d

## Tenta abrir a porta se o jogador estiver perto e olhando para ela.
## Retorna true se abriu.
func try_open(origin: Vector3, look_dir: Vector3) -> bool:
	if door == null or door.is_open:
		return false
	var to: Vector3 = door.global_position - origin
	var dist := to.length()
	if dist > INTERACT_RANGE or dist < 0.001:
		return false
	if look_dir.normalized().dot(to / dist) < FACING_MIN:
		return false
	if door.open():
		door_opened.emit()
		return true
	return false

## Limpa o estado (usado ao reiniciar; a porta antiga sai com a cena).
func reset() -> void:
	door = null
