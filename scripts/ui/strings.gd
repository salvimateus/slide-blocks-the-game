extends RefCounted
## All UI text, one table for each locale. Placeholders use the `{name}` form of String.format.
## Each table has the same keys; `tools/load_all.gd` checks the keys and the placeholders.

const DEFAULT_LOCALE := &"pt"

const PT := {
	"app_title": "Trilha Jujuba",
	"loading": "Carregando",
	"back": "Voltar",
	"tap_to_skip": "Toque para pular",
	"tap_to_continue": "Toque para continuar",

	# Home.
	"home_play": "Jogar",
	"home_levels": "Fases",
	"home_random": "Fase aleatória",

	# Level select.
	"levels_title": "Fases",
	"level_number": "Fase {n}",
	"level_locked": "Bloqueada",
	"level_locked_hint": "Complete a fase anterior para abrir esta",
	"level_new": "Nova",
	"level_best": "Recorde: {moves} movimentos",
	"level_unlocked": "Nova fase liberada!",
	"level_subtitle": "Fase {n} · {name}",
	"levels_stars_total": "{n}/{max}",
	"level_subtitle_solo": "Fase {n} · Uma jujuba",
	"level_solo_none": "Só normal",

	# One jelly mode.
	"solo_short": "1 jujuba",

	# Random level.
	"random_seed": "Semente {seed}",
	"random_subtitle": "Fase aleatória · Semente {seed}",
	"random_new": "Nova aleatória",
	"random_home": "Início",
	"random_loading": "Criando fase aleatória",
	"random_cancel": "Cancelar",

	# Replay.
	"replay_button": "Ver replay",
	"replay_title": "Replay",
	"replay_count": "{n}/{total}",
	"replay_tap": "Toque para voltar",

	# Level names.
	"level_1_name": "Primeiro Docinho",
	"level_2_name": "Caminho de Açúcar",
	"level_3_name": "Curva de Caramelo",
	"level_4_name": "Dupla de Goma",
	"level_5_name": "Jardim de Balas",
	"level_6_name": "Trio de Confeitos",
	"level_7_name": "Praça do Algodão-Doce",
	"level_8_name": "Festa da Jujuba",
	"level_9_name": "Parada do Pirulito",
	"level_10_name": "Garagem de Bombom",
	"level_11_name": "Arco de Alcaçuz",
	"level_12_name": "Trenzinho de Chiclete",
	"level_13_name": "Taça de Chocolate",
	"level_14_name": "Grampo de Marshmallow",
	"level_15_name": "Estante de Biscoitos",
	"level_16_name": "Escada de Waffle",
	"level_17_name": "Pedras de Torrone",
	"level_18_name": "Espelho de Açúcar",
	"level_19_name": "Câmaras de Brigadeiro",
	"level_20_name": "Bala Embrulhada",
	"level_21_name": "Cata-vento de Menta",
	"level_22_name": "Rosquinha Glaçada",
	"level_23_name": "Ladeira de Paçoca",
	"level_24_name": "Grande Confeitaria",

	# HUD.
	"hud_level": "Fase {n}",
	"hud_pause": "Pausar",
	"hud_restart": "Recomeçar",
	"hud_moves_left": "Restam {n}",
	"hud_moves_left_one": "Resta {n}",
	"hud_moves_used": "{n} movimentos",
	"hud_moves_used_one": "{n} movimento",
	"hud_painted": "{p}% pintado",
	"hud_level_solo": "Fase {n} · Uma jujuba",
	"hud_random": "Fase aleatória",
	"hud_random_solo": "Fase aleatória · Uma jujuba",

	# Hints.
	"hint_swipe": "Deslize para mover a jujuba e pintar a trilha",
	"hint_rails": "Os trilhos curvos viram a jujuba sozinhos",
	"hint_stopper": "Uma jujuba parada vira parede para as outras",
	"hint_race": "Se duas jujubas disputam uma casa, uma delas espera",

	# Pause dialog.
	"pause_title": "Pausa",
	"pause_continue": "Continuar",
	"pause_levels": "Fases",
	"pause_music": "Música",
	"pause_sfx": "Efeitos sonoros",
	"pause_haptics": "Vibração",
	"pause_reduced_motion": "Movimento reduzido",
	"pause_solo": "Uma jujuba",
	"pause_solo_restart": "Ao continuar, a fase recomeça.",
	"pause_solo_none": "Esta fase não tem a opção de uma jujuba.",
	"pause_language": "Idioma",
	"language_pt": "Português",
	"language_en": "English",
	"pause_dark_mode": "Modo escuro",
	"setting_on": "Ligado",
	"setting_off": "Desligado",
	"font_credit": "Fonte Nunito, SIL Open Font License 1.1",

	# Result card.
	"result_title": "Fase completa!",
	"result_time": "Tempo",
	"result_time_value": "{m}:{s}",
	"result_moves": "Movimentos",
	"result_stars": "Estrelas",
	"result_new_best": "Novo recorde!",
	"result_range": "Faixa de {stars} estrelas: {lo} a {hi} movimentos.\nVocê fez {moves}.",
	"result_range_one": "Faixa de 1 estrela: {lo} a {hi} movimentos.\nVocê fez {moves}.",
	"result_range_three": "3 estrelas",
	"result_range_two": "2 estrelas",
	"result_range_one_short": "1 estrela",
	"range_span": "{lo}-{hi}",
	"result_retry": "Repetir",
	"result_next": "Próxima fase",
	"result_levels": "Fases",
	"result_all_done": "Você completou todas as fases",

	# Defeat card.
	"defeat_title": "Acabaram os movimentos",
	"defeat_painted": "Você pintou {p}% da trilha",
	"defeat_retry": "Tentar de novo",
	"defeat_levels": "Fases",

	# Performance panel.
	"perf_title": "Desempenho",
	"perf_fps": "FPS",
	"perf_frame": "Quadro",
	"perf_script": "Script",
	"perf_draw": "Desenho",
	"perf_render": "Render",
	"perf_draw_calls": "Chamadas de desenho",
	"perf_primitives": "Primitivas",
	"perf_device": "Aparelho",
	"perf_gpu": "GPU",
	"perf_particles": "Partículas",
	"perf_glow": "Brilho",
	"perf_background": "Fundo",
	"perf_close": "Fechar",
}

const EN := {
	"app_title": "Trilha Jujuba",
	"loading": "Loading",
	"back": "Back",
	"tap_to_skip": "Tap to skip",
	"tap_to_continue": "Tap to continue",

	# Home.
	"home_play": "Play",
	"home_levels": "Levels",
	"home_random": "Random level",

	# Level select.
	"levels_title": "Levels",
	"level_number": "Level {n}",
	"level_locked": "Locked",
	"level_locked_hint": "Finish the level before this one to open it",
	"level_new": "New",
	"level_best": "Best: {moves} moves",
	"level_unlocked": "New level unlocked!",
	"level_subtitle": "Level {n} · {name}",
	"levels_stars_total": "{n}/{max}",
	"level_subtitle_solo": "Level {n} · One jelly",
	"level_solo_none": "Normal only",

	# One jelly mode.
	"solo_short": "1 jelly",

	# Random level.
	"random_seed": "Seed {seed}",
	"random_subtitle": "Random level · Seed {seed}",
	"random_new": "New random",
	"random_home": "Home",
	"random_loading": "Making a random level",
	"random_cancel": "Cancel",

	# Replay.
	"replay_button": "Watch replay",
	"replay_title": "Replay",
	"replay_count": "{n}/{total}",
	"replay_tap": "Tap to go back",

	# Level names.
	"level_1_name": "First Sweet",
	"level_2_name": "Sugar Path",
	"level_3_name": "Caramel Curve",
	"level_4_name": "Gummy Duo",
	"level_5_name": "Candy Garden",
	"level_6_name": "Sprinkle Trio",
	"level_7_name": "Cotton Candy Square",
	"level_8_name": "Jelly Party",
	"level_9_name": "Lollipop Stop",
	"level_10_name": "Bonbon Garage",
	"level_11_name": "Licorice Arch",
	"level_12_name": "Bubblegum Train",
	"level_13_name": "Chocolate Chalice",
	"level_14_name": "Marshmallow Hairpin",
	"level_15_name": "Cookie Shelves",
	"level_16_name": "Waffle Staircase",
	"level_17_name": "Nougat Stones",
	"level_18_name": "Sugar Mirror",
	"level_19_name": "Fudge Chambers",
	"level_20_name": "Wrapped Candy",
	"level_21_name": "Peppermint Pinwheel",
	"level_22_name": "Glazed Donut",
	"level_23_name": "Peanut Brittle Slope",
	"level_24_name": "Grand Candy Shop",

	# HUD.
	"hud_level": "Level {n}",
	"hud_pause": "Pause",
	"hud_restart": "Restart",
	"hud_moves_left": "{n} moves left",
	"hud_moves_left_one": "{n} move left",
	"hud_moves_used": "{n} moves",
	"hud_moves_used_one": "{n} move",
	"hud_painted": "{p}% painted",
	"hud_level_solo": "Level {n} · One jelly",
	"hud_random": "Random level",
	"hud_random_solo": "Random level · One jelly",

	# Hints.
	"hint_swipe": "Swipe to slide the jelly and paint the trail",
	"hint_rails": "Curved rails turn the jelly on their own",
	"hint_stopper": "A parked jelly is a wall for the others",
	"hint_race": "When two jellies race for one tile, one of them waits",

	# Pause dialog.
	"pause_title": "Paused",
	"pause_continue": "Resume",
	"pause_levels": "Levels",
	"pause_music": "Music",
	"pause_sfx": "Sound effects",
	"pause_haptics": "Vibration",
	"pause_reduced_motion": "Reduced motion",
	"pause_solo": "One jelly",
	"pause_solo_restart": "The level starts again when you resume.",
	"pause_solo_none": "This level has no one-jelly option.",
	"pause_language": "Language",
	"language_pt": "Português",
	"language_en": "English",
	"pause_dark_mode": "Dark mode",
	"setting_on": "On",
	"setting_off": "Off",
	"font_credit": "Nunito font, SIL Open Font License 1.1",

	# Result card.
	"result_title": "Level complete!",
	"result_time": "Time",
	"result_time_value": "{m}:{s}",
	"result_moves": "Moves",
	"result_stars": "Stars",
	"result_new_best": "New best!",
	"result_range": "{stars}-star range: {lo} to {hi} moves.\nYou used {moves}.",
	"result_range_one": "1-star range: {lo} to {hi} moves.\nYou used {moves}.",
	"result_range_three": "3 stars",
	"result_range_two": "2 stars",
	"result_range_one_short": "1 star",
	"range_span": "{lo}-{hi}",
	"result_retry": "Retry",
	"result_next": "Next level",
	"result_levels": "Levels",
	"result_all_done": "You finished every level",

	# Defeat card.
	"defeat_title": "Out of moves",
	"defeat_painted": "You painted {p}% of the trail",
	"defeat_retry": "Try again",
	"defeat_levels": "Levels",

	# Performance panel.
	"perf_title": "Performance",
	"perf_fps": "FPS",
	"perf_frame": "Frame",
	"perf_script": "Script",
	"perf_draw": "Draw",
	"perf_render": "Render",
	"perf_draw_calls": "Draw calls",
	"perf_primitives": "Primitives",
	"perf_device": "Device",
	"perf_gpu": "GPU",
	"perf_particles": "Particles",
	"perf_glow": "Glow",
	"perf_background": "Background",
	"perf_close": "Close",
}

const TABLES := {&"pt": PT, &"en": EN}

static var _locale: StringName = DEFAULT_LOCALE
## Entries `[WeakRef, key, vars]` of the nodes whose text follows the locale.
static var _bound: Array = []


## The text of `key` in the current locale, with each `{name}` of `vars` filled in. A missing key returns the key itself.
static func t(key: String, vars: Dictionary = {}) -> String:
	var table: Dictionary = TABLES[_locale]
	if not table.has(key):
		if not PT.has(key):
			push_warning("Strings: missing key '%s'" % key)
			return key
		table = PT
	var text: String = table[key]
	if vars.is_empty():
		return text
	return text.format(vars)


static func locale() -> StringName:
	return _locale


## The locale for a device language code: a code that starts with "pt" gives pt, each other code gives en.
static func locale_for(language_code: String) -> StringName:
	return &"pt" if language_code.to_lower().begins_with("pt") else &"en"


## Changes the locale and sets the text of each bound node again. An unknown code does nothing.
static func set_locale(code: StringName) -> void:
	if not TABLES.has(code):
		push_warning("Strings: unknown locale '%s'" % code)
		return
	_locale = code
	var alive: Array = []
	for entry: Array in _bound:
		var node: Object = (entry[0] as WeakRef).get_ref()
		if node == null:
			continue
		node.set("text", t(entry[1], entry[2]))
		alive.append(entry)
	_bound = alive


## Sets `node.text` now and after each locale change. For text that is set one time.
static func bind(node: Object, key: String, vars: Dictionary = {}) -> void:
	node.set("text", t(key, vars))
	_bound.append([weakref(node), key, vars])


## Each different character of all tables, for the glyph warm-up.
static func all_text() -> String:
	var seen := {}
	for table: Dictionary in TABLES.values():
		for text: String in table.values():
			for character in text:
				seen[character] = true
	return "".join(PackedStringArray(seen.keys()))
