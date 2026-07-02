extends Node
## Autoload. Rastreia a criatura Abbath e centraliza o jumpscare: quando ela
## alcanca o jogador dispara `jumpscare`, que a interface de reiniciar escuta
## para mostrar a tela de fim (reaproveitando o fluxo de REINICIAR ja existente).

## Emitido quando Abbath pega o jogador (mostra o jumpscare + interface de reiniciar).
signal jumpscare

var abbath = null
var caught := false

func register(a) -> void:
	abbath = a

## Dispara o jumpscare uma unica vez (ignora chamadas repetidas ate o reset).
func trigger_jumpscare() -> void:
	if caught:
		return
	caught = true
	jumpscare.emit()

## Limpa o estado (usado ao reiniciar; a criatura antiga sai com a cena).
func reset() -> void:
	abbath = null
	caught = false
