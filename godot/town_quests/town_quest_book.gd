class_name TownQuestBook
extends RefCounted
## The 30 quests in the town (QuestsInMap of the client) as data.
##
## The 1.4.07 client has the code of these quests, but it never starts them;
## see TownQuests. The port plays them with its own camp layouts. The texts,
## the items, the order of the quests, the races that play them and the units
## that the player gets come from the client; the layouts are new.
##
## A quest has one or more sites. A site is a grid of characters that the port
## puts in a land area at the border of the map, row by row from the top. A
## character is at the front tile of its item; a larger item covers the tiles
## above it and to the left of it, which must be ".". The characters:
##
## - "#" a wall and "T" a tower of the enemy race of the player (ENEMY_BUILDINGS).
##   They fight for the enemy.
## - "X" the treasure of the quest: it opens when the player has collected the
##   activators, killed the boss waves and killed the enemy units near it.
##   Collecting it ends the quest.
## - "A" an activator: it opens when no enemy unit is near it. Collecting it
##   removes it and the decorations of its site.
## - "e" an enemy unit of the player's level (VillageAttacks.enemy_ids()).
## - Other characters: the item of "legend". Units are enemies; buildings are
##   neutral decorations.
##
## Keys of a quest: "title", "text", "end_title", "end_text" (names of texts of
## the configuration), "races" (the races that play it, see
## TownQuests.playable_id()), "sites", "legend", "treasure" (item id by race),
## "activator" (item id), "guards" (true: more "e" units near the treasure, by
## level), "waves" (lists of enemy unit ids that come one after the other when
## the activators are collected), "helpers" (units of the player that come at
## the start), "prize" (units that the treasure gives, by race), "rewards"
## (items at the end: units on the map, buildings in the item store) and
## "resource" (food or stone that the end gives, as much as the gold).

## The number of quests in the chain (NUM_QUESTS).
const QUEST_COUNT := 30
## The pictures of the quest window (GameStatic.IMAGES_QUESTSINMAP and
## IMAGES_QUESTSINMAP_TROLL), by quest id; the trolls have pictures for the first 16.
const PICTURES := {
	"h": ["quest_princess.jpg", "quest_archers.jpg", "quest_kidnapped.jpg", "quest_treasure.jpg", "quest_villagers.jpg", "quest_troll.jpg",
		"quest_prince.jpg", "quest_mill.jpg", "quest_healers.jpg", "quest_stone_mine.jpg", "quest_allies.jpg", "quest_cages.jpg", "quest_siege.jpg",
		"quest_undead.jpg", "quest_chinos_fuegos.jpg", "quest_egypt_golem.jpg", "quest_vikingos_cerveza.jpg", "quest_yeti_negro.jpg",
		"quest_altar_azteca.jpg", "quest_vibora.jpg", "quest_arbolvida.jpg", "quest_egypt_sarcofago.jpg", "quest_rockdriller.jpg",
		"quest_chinos_dragones.jpg", "quest_cleopatra.jpg", "quest_ent.jpg", "quest_atlantes_tesoro.jpg", "quest_balrog.jpg", "quest_portales.jpg",
		"quest_magos.jpg"],
	"t": ["jaulaanimal_SCREEN.jpg", "cofre.png", "jaulaanimal_SCREEN.jpg", "jaulaanimal_SCREEN.jpg", "prisontroll.png", "jaulaanimal_SCREEN.jpg",
		"principecolgado.png", "molinollamaspopup.jpg", "jaulaanimal_SCREEN.jpg", "minapiedracandado_SCREEN.jpg", "jaulaanimal_SCREEN.jpg",
		"jaulaanimal_SCREEN.jpg", "jaulaanimal_SCREEN.jpg", "estatuaesqueletopopup.jpg", "fuegoschinos.jpg", "golemdorado.jpg"],
}
## The walls and towers of the enemy, by the race of the player.
const ENEMY_BUILDINGS := {"h": {"#": 305, "T": 291}, "t": {"#": 35, "T": 29}}

## A walled camp with four towers, a gate at the right and a large treasure
## (up to 3 x 3) in the middle.
const CAMP: Array[String] = [
	"#############",
	"#T.........T#",
	"#..e.....e..#",
	"#...........#",
	"#.e.........#",
	"#......X.....",
	"#..e.....e...",
	"#...........#",
	"#T...e.....T#",
	"#############",
]
## A smaller camp with two towers and the gate at the bottom.
const CAMP_SMALL: Array[String] = [
	"##########",
	"#T......T#",
	"#.e....e.#",
	"#........#",
	"#....X...#",
	"#.e....e.#",
	"###....###",
]
## An activator in the middle of a ring of its guards.
const POST: Array[String] = [
	".........",
	"..e...e..",
	".........",
	".....A...",
	".........",
	"..e...e..",
	".........",
]
## An activator behind a short wall with two towers.
const FORT: Array[String] = [
	"T.#####.T",
	"..e...e..",
	"#.......#",
	"#....A..#",
	"#.......#",
	"..e...e..",
	"T.......T",
]

## A skeleton statue between columns and its skeletons.
const STATUE: Array[String] = [
	"c.......c",
	"..s...s..",
	".........",
	".....A...",
	".........",
	"..k...k..",
	"c.......c",
]

const QUESTS := {
	0: {
		"title": "POPUP_MISION_CAMPAMENTO_TITULO_PRINCESA", "text": "POPUP_MISION_CAMPAMENTO_PIE_PRINCESA",
		"end_title": "POPUP_MISION_CAMPAMENTO_TITULO_PRINCESA_END", "end_text": "POPUP_MISION_CAMPAMENTO_PIE_PRINCESA_END",
		"races": "h", "sites": [CAMP], "treasure": {"h": 83}, "guards": true, "prize": {"h": [533]},
	},
	1: {
		"title": "POPUP_MISION_CAMPAMENTO_TITULO_ARQUEROS", "text": "POPUP_MISION_CAMPAMENTO_PIE_ARQUEROS",
		"end_title": "POPUP_MISION_CAMPAMENTO_TITULO_ARQUEROS_END", "end_text": "POPUP_MISION_CAMPAMENTO_PIE_ARQUEROS_END",
		"races": "ht", "sites": [CAMP], "treasure": {"h": 86, "t": 364}, "guards": true,
		"prize": {"h": [535, 535, 535], "t": [589, 589, 589]},
	},
	2: {
		"title": "POPUP_MISION_CAMPAMENTO_TITULO_SOLDADOS", "text": "POPUP_MISION_CAMPAMENTO_PIE_SOLDADOS",
		"end_title": "POPUP_MISION_CAMPAMENTO_TITULO_SOLDADOS_END", "end_text": "POPUP_MISION_CAMPAMENTO_PIE_SOLDADOS_END",
		"races": "ht", "sites": [CAMP], "treasure": {"h": 90, "t": 365}, "guards": true,
		"prize": {"h": [510, 517, 513], "t": [594, 593, 595]},
	},
	3: {
		"title": "POPUP_MISION_CAMPAMENTO_TITULO_TESORO", "text": "POPUP_MISION_CAMPAMENTO_PIE_TESORO",
		"end_title": "POPUP_MISION_CAMPAMENTO_TITULO_TESORO_END", "end_text": "POPUP_MISION_CAMPAMENTO_PIE_TESORO_END",
		"races": "h", "sites": [CAMP_SMALL], "treasure": {"h": 82}, "guards": true,
	},
	4: {
		"title": "POPUP_MISION_CAMPAMENTO_TITULO_ALDEANOS", "text": "POPUP_MISION_CAMPAMENTO_PIE_ALDEANOS",
		"end_title": "POPUP_MISION_CAMPAMENTO_TITULO_ALDEANOS_END", "end_text": "POPUP_MISION_CAMPAMENTO_PIE_ALDEANOS_END",
		"races": "h", "sites": [CAMP], "treasure": {"h": 84}, "guards": true,
		"prize": {"h": [500, 500, 500]},
	},
	5: {
		"title": "POPUP_MISION_CAMPAMENTO_TITULO_TROLL", "text": "POPUP_MISION_CAMPAMENTO_PIE_TROLL",
		"end_title": "POPUP_MISION_CAMPAMENTO_TITULO_TROLL_END", "end_text": "POPUP_MISION_CAMPAMENTO_PIE_TROLL_END",
		"races": "ht", "sites": [CAMP_SMALL], "treasure": {"h": 87, "t": 87}, "guards": true,
		"prize": {"h": [536], "t": [595]},
	},
	6: {
		"title": "POPUP_MISION_CAMPAMENTO_TITULO_PRINCIPE", "text": "POPUP_MISION_CAMPAMENTO_PIE_PRINCIPE",
		"end_title": "POPUP_MISION_CAMPAMENTO_TITULO_PRINCIPE_END", "end_text": "POPUP_MISION_CAMPAMENTO_PIE_PRINCIPE_END",
		"races": "h", "sites": [CAMP], "treasure": {"h": 85}, "guards": true, "prize": {"h": [534]},
	},
	7: {
		"title": "POPUP_MISION_CAMPAMENTO_TITULO_FUEGO", "text": "POPUP_MISION_CAMPAMENTO_PIE_FUEGO",
		"end_title": "POPUP_MISION_CAMPAMENTO_TITULO_FUEGO_END", "end_text": "POPUP_MISION_CAMPAMENTO_PIE_FUEGO_END",
		"races": "h", "activator": 210, "sites": [POST, POST, POST, [
			"..p....p..",
			"..........",
			"....X.....",
			"..p....p..",
		]], "legend": {"p": 104}, "treasure": {"h": 211}, "resource": "f",
	},
	8: {
		"title": "POPUP_MISION_CAMPAMENTO_TITULO_CURANDEROS", "text": "POPUP_MISION_CAMPAMENTO_PIE_CURANDEROS",
		"end_title": "POPUP_MISION_CAMPAMENTO_TITULO_CURANDEROS_END", "end_text": "POPUP_MISION_CAMPAMENTO_PIE_CURANDEROS_END",
		"races": "h", "sites": [CAMP], "treasure": {"h": 237}, "guards": true, "prize": {"h": [502, 502]},
	},
	10: {
		"title": "POPUP_MISION_CAMPAMENTO_TITULO_ALIADOS", "text": "POPUP_MISION_CAMPAMENTO_PIE_ALIADOS",
		"end_title": "POPUP_MISION_CAMPAMENTO_TITULO_ALIADOS_END", "end_text": "POPUP_MISION_CAMPAMENTO_PIE_ALIADOS_END",
		"races": "ht", "sites": [CAMP], "treasure": {"h": 238, "t": 367}, "guards": true,
		"prize": {"h": [576, 576, 576, 576], "t": [596, 600, 598, 597]},
	},
	12: {
		"title": "POPUP_MISION_CAMPAMENTO_TITULO_ASEDIO", "text": "POPUP_MISION_CAMPAMENTO_PIE_ASEDIO",
		"end_title": "POPUP_MISION_CAMPAMENTO_TITULO_ASEDIO_END", "end_text": "POPUP_MISION_CAMPAMENTO_PIE_ASEDIO_END",
		"races": "ht", "sites": [CAMP], "treasure": {"h": 257, "t": 368}, "guards": true,
		"prize": {"h": [521, 521, 521], "t": [586, 586, 586]},
	},
	13: {
		"title": "POPUP_MISION_CAMPAMENTO_TITULO_ESTATUA", "text": "POPUP_MISION_CAMPAMENTO_PIE_ESTATUA",
		"end_title": "POPUP_MISION_CAMPAMENTO_TITULO_ESTATUA_END", "end_text": "POPUP_MISION_CAMPAMENTO_PIE_ESTATUA_END",
		"races": "ht", "activator": 258, "sites": [STATUE, STATUE, STATUE, [
			"y.......y",
			".........",
			"....X....",
			".........",
			"y.......y",
		]], "legend": {"c": 913, "s": 558, "k": 559, "y": 907}, "treasure": {"h": 259, "t": 259},
		"waves": [[558, 558, 559, 559, 558]],
	},
	14: {
		"title": "POPUP_MISION_FIREWORKS_TITULO", "text": "POPUP_MISION_FIREWORKS_FOOTER",
		"end_title": "POPUP_MISION_FIREWORKS_TITULO_END", "end_text": "POPUP_MISION_FIREWORKS_FOOTER_END",
		"races": "ht", "activator": 488, "sites": [FORT, FORT, FORT, [
			"t........t",
			"..........",
			"..........",
			".....X....",
			"t........t",
		]], "legend": {"t": 103}, "treasure": {"h": 487, "t": 487}, "helpers": [577, 577], "rewards": [120],
	},
	15: {
		"title": "POPUP_MISION_CAMPAMENTO_TITULO_GOLEM", "text": "POPUP_MISION_CAMPAMENTO_PIE_GOLEM",
		"end_title": "POPUP_MISION_CAMPAMENTO_FIN_TITULO_GOLEM", "end_text": "POPUP_MISION_CAMPAMENTO_FIN_PIE_GOLEM",
		"races": "h", "sites": [[
			"wwwwwwwwwwww",
			"wf........fw",
			"w..g....g..w",
			"w..........w",
			"w.....X.....",
			"w..g....g...",
			"wf........fw",
			"wwwwwwwwwwww",
		]], "legend": {"w": 394, "f": 68, "g": 664}, "treasure": {"h": 489}, "waves": [[665]],
		"helpers": [613, 613], "rewards": [612],
	},
	16: {
		"title": "POPUP_MISION_VIKBEER_TITULO", "text": "POPUP_MISION_VIKBEER_FOOTER",
		"end_title": "POPUP_MISION_VIKBEER_TITULO_END", "end_text": "POPUP_MISION_VIKBEER_FOOTER_END",
		"races": "h", "activator": 491, "sites": [[
			"v.wwwww.v",
			"..e...e..",
			"w.......w",
			"w....A..w",
			"w.......w",
			"..e...e..",
			"v.......v",
		], [
			"v.wwwww.v",
			"..e...e..",
			"w.......w",
			"w....A..w",
			"w.......w",
			"..e...e..",
			"v.......v",
		], [
			"v.wwwww.v",
			"..e...e..",
			"w.......w",
			"w....A..w",
			"w.......w",
			"..e...e..",
			"v.......v",
		], [
			"s........s",
			"..........",
			"..........",
			".....X....",
			"s........s",
		]], "legend": {"w": 375, "v": 376, "s": 380}, "treasure": {"h": 490}, "helpers": [606], "rewards": [382],
	},
	17: {
		"title": "POPUP_MISION_CAMPAMENTO_TITULO_YETI_NEGRO", "text": "POPUP_MISION_CAMPAMENTO_PIE_YETI_NEGRO",
		"end_title": "POPUP_MISION_CAMPAMENTO_FIN_TITULO_YETI_NEGRO", "end_text": "POPUP_MISION_CAMPAMENTO_FIN_PIE_YETI_NEGRO",
		"races": "h", "sites": [[
			"............",
			".n...y....n.",
			"............",
			"...i....y...",
			"......X.....",
			"............",
			".y.....n....",
			"............",
			"...........l",
		]], "legend": {"n": 914, "i": 942, "l": 918, "y": 666}, "treasure": {"h": 492}, "waves": [[667]],
		"helpers": [606, 606], "rewards": [607, 607, 607],
	},
	18: {
		"title": "POPUP_MISION_AZTECALTAR_TITULO", "text": "POPUP_MISION_AZTECALTAR_FOOTER",
		"end_title": "POPUP_MISION_AZTECALTAR_TITULO_END", "end_text": "POPUP_MISION_AZTECALTAR_FOOTER_END",
		"races": "h", "activator": 494, "sites": [[
			"v.wwwww.v",
			"..a...a..",
			"w.......w",
			"w....A..w",
			"w.......w",
			"..a...a..",
			"v.......v",
		], [
			"v.wwwww.v",
			"..a...a..",
			"w.......w",
			"w....A..w",
			"w.......w",
			"..a...a..",
			"v.......v",
		], [
			"v.wwwww.v",
			"..a...a..",
			"w.......w",
			"w....A..w",
			"w.......w",
			"..a...a..",
			"v.......v",
		], [
			"b........b",
			"..........",
			".m........",
			".....X....",
			"b........b",
		]], "legend": {"w": 269, "v": 270, "a": 685, "m": 282, "b": 274}, "treasure": {"h": 493}, "rewards": [280],
	},
	19: {
		"title": "POPUP_MISION_CAMPAMENTO_TITULO_VIBORA_GIGANTE", "text": "POPUP_MISION_CAMPAMENTO_PIE_VIBORA_GIGANTE",
		"end_title": "POPUP_MISION_CAMPAMENTO_FIN_TITULO_VIBORA_GIGANTE", "end_text": "POPUP_MISION_CAMPAMENTO_FIN_PIE_VIBORA_GIGANTE",
		"races": "h", "sites": [[
			"k.....c....k",
			"............",
			"..c.....r...",
			"............",
			"......X.....",
			".d..........",
			"......k...c.",
			"k...........",
		]], "legend": {"k": 114, "c": 905, "d": 904, "r": 288}, "treasure": {"h": 495}, "waves": [[668]],
		"rewards": [418],
	},
	20: {
		"title": "POPUP_MISION_ELFOSARBOL_TITULO", "text": "POPUP_MISION_ELFOSARBOL_FOOTER",
		"end_title": "POPUP_MISION_ELFOSARBOL_TITULO_END", "end_text": "POPUP_MISION_ELFOSARBOL_FOOTER_END",
		"races": "h", "activator": 496, "sites": [[
			"v.wwwww.v",
			"..a...b..",
			"w.......w",
			"w....A..w",
			"w.......w",
			"..c...d..",
			"v.......v",
		], [
			"v.wwwww.v",
			"..b...c..",
			"w.......w",
			"w....A..w",
			"w.......w",
			"..d...a..",
			"v.......v",
		], [
			"v.wwwww.v",
			"..c...d..",
			"w.......w",
			"w....A..w",
			"w.......w",
			"..a...b..",
			"v.......v",
		], [
			"l........l",
			"..........",
			"..........",
			".....X....",
			"l........l",
		]], "legend": {"w": 473, "v": 474, "a": 673, "b": 674, "c": 676, "d": 677, "l": 446},
		"treasure": {"h": 497}, "helpers": [627, 627, 627, 627], "rewards": [627, 627, 627],
	},
	21: {
		"title": "POPUP_MISION_THEMUMMY_TITULO", "text": "POPUP_MISION_THEMUMMY_FOOTER",
		"end_title": "POPUP_MISION_THEMUMMY_TITULO_END", "end_text": "POPUP_MISION_THEMUMMY_FOOTER_END",
		"races": "h", "activator": 498, "sites": [[
			"s.......s",
			"..a...a..",
			".........",
			".....A...",
			".........",
			"..a...a..",
			"s.......s",
		], [
			"s.......s",
			"..a...a..",
			".........",
			".....A...",
			".........",
			"..a...a..",
			"s.......s",
		], [
			"s.......s",
			"..a...a..",
			".........",
			".....A...",
			".........",
			"..a...a..",
			"s.......s",
		], [
			"s........s",
			"..........",
			"..........",
			".....X....",
			"s........s",
		]], "legend": {"s": 400, "a": 670}, "treasure": {"h": 499}, "waves": [[669]], "helpers": [614],
	},
	22: {
		"title": "POPUP_MISION_PERFORARROCAS_TITULO", "text": "POPUP_MISION_PERFORARROCAS_FOOTER",
		"end_title": "POPUP_MISION_PERFORARROCAS_TITULO_END", "end_text": "POPUP_MISION_PERFORARROCAS_FOOTER_END",
		"races": "h", "activator": 1201, "sites": [[
			"p.......p",
			"..d...d..",
			".........",
			"....A....",
			".........",
			"..d...d..",
			"p.......p",
		], [
			"p.......p",
			"..d...d..",
			".........",
			"....A....",
			".........",
			"..d...d..",
			"p.......p",
		], [
			"p.......p",
			"..d...d..",
			".........",
			"....A....",
			".........",
			"..d...d..",
			"p.......p",
		], [
			"..........",
			".r......r.",
			"..........",
			"..........",
			"......X...",
			"..........",
		]], "legend": {"p": 907, "d": 697, "r": 288}, "treasure": {"h": 1200}, "waves": [[696]],
		"helpers": [578, 578, 578, 578], "rewards": [578, 578],
	},
	23: {
		"title": "POPUP_MISION_CHINOSDRAGON_TITULO", "text": "POPUP_MISION_CHINOSDRAGON_FOOTER",
		"end_title": "POPUP_MISION_CHINOSDRAGON_TITULO_END", "end_text": "POPUP_MISION_CHINOSDRAGON_FOOTER_END",
		"races": "h", "activator": 1203, "sites": [[
			"t.......t",
			"..e...d..",
			"........r",
			"....A....",
			".........",
			"..d...e..",
			"t.......t",
		], [
			"t.......t",
			"..e...d..",
			"........r",
			"....A....",
			".........",
			"..d...e..",
			"t.......t",
		], [
			"t.......t",
			"..e...d..",
			"........r",
			"....A....",
			".........",
			"..d...e..",
			"t.......t",
		], [
			"t........t",
			"..........",
			"..........",
			"..........",
			"......X...",
			"t........t",
		]], "legend": {"t": 103, "r": 946, "d": 672}, "treasure": {"h": 1202}, "waves": [[672, 672, 672]],
		"helpers": [577, 577, 577], "rewards": [577, 577],
	},
	24: {
		"title": "POPUP_MISION_NEPTUCLEOPATRA_TITULO", "text": "POPUP_MISION_NEPTUCLEOPATRA_FOOTER",
		"end_title": "POPUP_MISION_NEPTUCLEOPATRA_TITULO_END", "end_text": "POPUP_MISION_NEPTUCLEOPATRA_FOOTER_END",
		"races": "h", "sites": [[
			"wwwwwwwwwwww",
			"w..........w",
			"w..........w",
			"w..........w",
			"w..........w",
			"w.......X...",
			"w...........",
			"w..........w",
			"wwwwwwwwwwww",
		]], "legend": {"w": 425}, "treasure": {"h": 1204},
		"waves": [[679, 679, 679, 679], [680, 680, 680, 680], [678]], "helpers": [613, 613], "rewards": [613, 613],
	},
	25: {
		"title": "POPUP_MISION_ELFOSENT_TITULO", "text": "POPUP_MISION_ELFOSENT_FOOTER",
		"end_title": "POPUP_MISION_ELFOSENT_TITULO_END", "end_text": "POPUP_MISION_ELFOSENT_FOOTER_END",
		"races": "h", "sites": [[
			"wwwwwwwwwww",
			"w.........w",
			"w..a...b..w",
			"w..........",
			"w....c.....",
			"w..........",
			"w..b...a..w",
			"wwwwwwwwwww",
		]], "legend": {"w": 473, "a": 675, "b": 676, "c": 677}, "waves": [[675, 676, 677, 675, 676], [681]],
		"helpers": [628], "rewards": [628, 628],
	},
	26: {
		"title": "POPUP_MISION_TESOROATLANTE_TITULO", "text": "POPUP_MISION_TESOROATLANTE_FOOTER",
		"end_title": "POPUP_MISION_TESOROATLANTE_TITULO_END", "end_text": "POPUP_MISION_TESOROATLANTE_FOOTER_END",
		"races": "h", "activator": 1206, "sites": [[
			"w.wwwww.w",
			"..a...b..",
			"w.......w",
			"w....A..w",
			"w.......w",
			"..c...a..",
			"w.......w",
		], [
			"w.wwwww.w",
			"..b...c..",
			"w.......w",
			"w....A..w",
			"w.......w",
			"..a...b..",
			"w.......w",
		], [
			"w.wwwww.w",
			"..c...a..",
			"w.......w",
			"w....A..w",
			"w.......w",
			"..b...c..",
			"w.......w",
		], [
			"w.wwwww.w",
			"..a...b..",
			"w.......w",
			"w....A..w",
			"w.......w",
			"..c...a..",
			"w.......w",
		]], "legend": {"w": 425, "a": 688, "b": 689, "c": 680}, "rewards": [274],
	},
	27: {
		"title": "POPUP_MISION_BALROG_TITULO", "text": "POPUP_MISION_BALROG_FOOTER",
		"end_title": "POPUP_MISION_BALROG_TITULO_END", "end_text": "POPUP_MISION_BALROG_FOOTER_END",
		"races": "h", "sites": [[
			"..........",
			"..........",
			"..r....k..",
			"..........",
			"......s...",
			"..........",
			"....q.....",
			".k......m.",
		]], "legend": {"r": 947, "q": 948, "s": 946, "k": 114, "m": 288}, "waves": [[682]],
		"helpers": [644, 644, 646], "rewards": [644],
	},
	28: {
		"title": "POPUP_MISION_DEMONPORTAL_TITULO", "text": "POPUP_MISION_DEMONPORTAL_FOOTER",
		"end_title": "POPUP_MISION_DEMONPORTAL_TITULO_END", "end_text": "POPUP_MISION_DEMONPORTAL_FOOTER_END",
		"races": "h", "activator": 1209, "sites": [[
			"t........t",
			"..a....b..",
			"..........",
			"..........",
			"..........",
			"......A...",
			"..c....d..",
			"t........t",
		], [
			"t........t",
			"..b....c..",
			"..........",
			"..........",
			"..........",
			"......A...",
			"..d....a..",
			"t........t",
		], [
			"t........t",
			"..c....d..",
			"..........",
			"..........",
			"..........",
			"......A...",
			"..a....b..",
			"t........t",
		], [
			"t........t",
			"..d....a..",
			"..........",
			"..........",
			"..........",
			"......A...",
			"..b....c..",
			"t........t",
		]], "legend": {"t": 480, "a": 673, "b": 674, "c": 675, "d": 677}, "rewards": [701, 701],
	},
	29: {
		"title": "POPUP_MISION_MAGOSCORRUPTOS_TITULO", "text": "POPUP_MISION_MAGOSCORRUPTOS_FOOTER",
		"end_title": "POPUP_MISION_MAGOSCORRUPTOS_TITULO_END", "end_text": "POPUP_MISION_MAGOSCORRUPTOS_FOOTER_END",
		"races": "h", "activator": 1213, "sites": [[
			"h.......h",
			"..a...b..",
			".........",
			"....A....",
			".........",
			"..c...f..",
			"h.......h",
		], [
			"h.......h",
			"..b...c..",
			".........",
			"....A....",
			".........",
			"..d...f..",
			"h.......h",
		], [
			"h.......h",
			"..c...d..",
			".........",
			"....A....",
			".........",
			"..a...f..",
			"h.......h",
		], [
			"h.......h",
			"..d...a..",
			".........",
			"....A....",
			".........",
			"..b...f..",
			"h.......h",
		]], "legend": {"h": 107, "f": 68, "a": 690, "b": 691, "c": 692, "d": 693}, "rewards": [652],
	},
}


## The picture of the quest window for the race ("h" or "t"), or "" when the client has none.
static func picture(id: int, race: String) -> String:
	var pictures: Array = PICTURES.get(race, [])
	return pictures[id] if id >= 0 and id < pictures.size() else ""
