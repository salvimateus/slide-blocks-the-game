extends RefCounted
## All UI text, in pt-BR. Placeholders use the `{name}` form of String.format.

const TABLE := {
	"app_title": "Trilha Jujuba",
	"loading": "Carregando",
	"back": "Voltar",
	"tap_to_skip": "Toque para pular",
	"tap_to_continue": "Toque para continuar",

	# Home.
	"home_play": "Jogar",
	"home_levels": "Fases",

	# Level select.
	"levels_title": "Fases",
	"level_number": "Fase {n}",
	"level_locked": "Bloqueada",
	"level_locked_hint": "Complete a fase anterior para abrir esta",
	"level_new": "Nova",
	"level_best": "Recorde: {moves} movimentos",
	"level_unlocked": "Nova fase liberada!",

	# Level names.
	"level_1_name": "Primeiro Docinho",
	"level_2_name": "Caminho de Açúcar",
	"level_3_name": "Curva de Caramelo",
	"level_4_name": "Dupla de Goma",
	"level_5_name": "Jardim de Balas",
	"level_6_name": "Trio de Confeitos",
	"level_7_name": "Praça do Algodão-Doce",
	"level_8_name": "Festa da Jujuba",

	# HUD.
	"hud_level": "Fase {n}",
	"hud_pause": "Pausar",
	"hud_restart": "Recomeçar",
	"hud_moves_left": "Restam {n}",
	"hud_moves_left_one": "Resta {n}",
	"hud_moves_used": "{n} movimentos",
	"hud_moves_used_one": "{n} movimento",
	"hud_painted": "{p}% pintado",

	# Hints.
	"hint_swipe": "Deslize para mover a jujuba e pintar a trilha",
	"hint_rails": "Os trilhos curvos viram a jujuba sozinhos",

	# Pause dialog.
	"pause_title": "Pausa",
	"pause_continue": "Continuar",
	"pause_levels": "Fases",
	"pause_music": "Música",
	"pause_sfx": "Efeitos sonoros",
	"pause_haptics": "Vibração",
	"pause_reduced_motion": "Movimento reduzido",
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
	"result_range": "Faixa de {stars} estrelas: {lo} a {hi} movimentos. Você fez {moves}.",
	"result_range_one": "Faixa de 1 estrela: {lo} a {hi} movimentos. Você fez {moves}.",
	"result_range_three": "3 estrelas",
	"result_range_two": "2 estrelas",
	"result_range_one_short": "1 estrela",
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


## The text of `key` with each `{name}` of `vars` filled in. A missing key returns the key itself.
static func t(key: String, vars: Dictionary = {}) -> String:
	if not TABLE.has(key):
		push_warning("Strings: missing key '%s'" % key)
		return key
	var text: String = TABLE[key]
	if vars.is_empty():
		return text
	return text.format(vars)
