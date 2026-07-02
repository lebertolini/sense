extends Node
## Autoload. Internacionalizacao (i18n) no padrao do Godot: registra as
## traducoes em runtime e seleciona o idioma a partir do locale do sistema.
## Use sempre via chaves, ex.: tr("FIND_THE_EXIT") / tr("RESTART").
##
## Para adicionar um idioma novo, basta acrescentar uma entrada em MESSAGES
## com o locale (ex.: "fr") e os textos das mesmas chaves.

# chave -> { locale: texto }
const MESSAGES := {
	"FIND_THE_EXIT": {
		"en": "FIND THE EXIT",
		"pt_BR": "ENCONTRE A SAÍDA",
		"es": "ENCUENTRA LA SALIDA",
	},
	"RESTART": {
		"en": "RESTART",
		"pt_BR": "REINICIAR",
		"es": "REINICIAR",
	},
	"CAUGHT": {
		"en": "ABBATH CAUGHT YOU",
		"pt_BR": "ABBATH TE PEGOU",
		"es": "ABBATH TE ATRAPÓ",
	},
}

# Idioma usado quando o locale do sistema nao casa com nenhum suportado.
const FALLBACK_LOCALE := "en"

func _ready() -> void:
	_register()
	TranslationServer.set_locale(_pick_locale())

func _register() -> void:
	# Monta um Translation por locale e registra no TranslationServer.
	var by_locale := {}
	for key in MESSAGES:
		for locale in MESSAGES[key]:
			if not by_locale.has(locale):
				var t := Translation.new()
				t.locale = locale
				by_locale[locale] = t
			by_locale[locale].add_message(key, MESSAGES[key][locale])
	for locale in by_locale:
		TranslationServer.add_translation(by_locale[locale])

func _pick_locale() -> String:
	# Tenta o locale completo do SO (ex.: pt_BR), depois so o idioma (ex.: pt),
	# senao cai no fallback.
	var os_locale := OS.get_locale()
	if _has_locale(os_locale):
		return os_locale
	var lang := os_locale.split("_")[0]
	for locale in _supported_locales():
		if locale.split("_")[0] == lang:
			return locale
	return FALLBACK_LOCALE

func _supported_locales() -> Array:
	var set := {}
	for key in MESSAGES:
		for locale in MESSAGES[key]:
			set[locale] = true
	return set.keys()

func _has_locale(locale: String) -> bool:
	return _supported_locales().has(locale)
