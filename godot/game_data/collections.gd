class_name Collections
extends RefCounted
## The item collections. The client contains this table, not the game
## configuration: the language text names of each collection and its 5 items,
## and where each item can drop. The configuration has the rewards
## (GameConfig.collection_rewards), and the save counts the items in
## privateState.collections.

## Where an item drops. The port has only the Treasure Mine and harvests, see
## Village.find_collectible(); the other sources are battles.
enum Source { MOBS, BOSS, ASSAULT, HARVEST, CHEST, HARDCORE }
enum Rarity { EPIC, RARE, UNCOMMON }

const ITEMS_PER_COLLECTION := 5
## A drop roll below DROP_LIMITS[rarity] gives an item of that rarity; the
## lowest rarity that the roll is below wins. A harvest rolls up to
## HARVEST_ROLL, so it drops an item 4 times in 100. The Treasure Mine rolls up
## to TREASURE_ROLL from a random source, so it drops an item unless the source
## has no item of the rarity or a more common one.
const DROP_LIMITS: Array[float] = [0.5, 2.5, 4.0]
const HARVEST_ROLL := 100.0
const TREASURE_ROLL := 4.0
## An item of the HARDCORE source drops only with this chance.
const HARDCORE_DROP_CHANCE := 0.5
## Cash that completes collection n without all its items, less 1 cash for each
## kind of item that the player has, but at least 1 cash. Collections in
## FIXED_PRICE_COLLECTIONS cost the full price, and the player cannot buy
## collections in NO_CASH_COLLECTIONS.
const CASH_PRICES: Array[int] = [0, 5, 5, 5, 5, 5, 5, 5, 5, 5, 15, 5, 5, 5, 5, 5, 5, 5, 5, 5, 20, 400, 400, 999]
const FIXED_PRICE_COLLECTIONS: Array[int] = [10, 20]
const NO_CASH_COLLECTIONS: Array[int] = [23]
## The player cannot complete these collections while the reward is in the item store.
const UNIQUE_COLLECTIONS: Array[int] = [21, 22]

## TABLE[n - 1] is collection n: [text name, [[item text name, source, rarity] x 5]].
const TABLE := [
	["COLECCION_MISTERIOS_ARENA", [["COLECCION_JEROGLIFO_EGIPCIO", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_MASCARA_FARAON", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_VIEJA_CERAMICA", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_PAPIRO_ESCRITO", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_ESTATUILLA_HORUS", Source.HARVEST, Rarity.UNCOMMON]]],
	["COLECCION_VIEJO_BAUL", [["COLECCION_SUPERFICIE_MADERA", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_TABLA_CURVA", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_CERRADURA_ORO", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_MAPA_TESORO", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_CLAVOS_LARGOS", Source.HARVEST, Rarity.UNCOMMON]]],
	["COLECCION_PODER_FLOR", [["COLECCION_ROSA_ROJA", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_GIRASOL", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_LIRIO_BLANCO", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_GERANIO_AZUL", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_FERTILIZANTE", Source.HARVEST, Rarity.UNCOMMON]]],
	["COLECCION_TOQUE_RENACIMIENTO", [["COLECCION_REMACHE_ORO", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_ESTATUA_ORO", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_COLUMNA_SOLIDA", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_LADRILLO_DECORADO", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_AGUA_PURA", Source.HARVEST, Rarity.UNCOMMON]]],
	["COLECCION_DESCUBRIMIENTO_ANTIGUO", [["COLECCION_PIEL_MARRON", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_COLMILLO_MARFIL", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_BLOQUE_HIELO", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_ANTIGUO_CACAHUETE", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_HUELLA_FOSSIL", Source.HARVEST, Rarity.UNCOMMON]]],
	["COLECCION_AMENAZA_CAZADORA", [["COLECCION_PULSERA_CUERO", Source.MOBS, Rarity.RARE], ["COLECCION_COLMILLO_GRANDE", Source.MOBS, Rarity.RARE], ["COLECCION_ARNES_CUERO", Source.MOBS, Rarity.RARE], ["COLECCION_CASCO_CORNUDO", Source.MOBS, Rarity.RARE], ["COLECCION_HACHA_AFILADA", Source.BOSS, Rarity.RARE]]],
	["COLECCION_DESCUBRIMIENTO_ARTICO", [["COLECCION_AGUA_FRIA", Source.ASSAULT, Rarity.RARE], ["COLECCION_PESCADO_MALOLIENTE", Source.ASSAULT, Rarity.RARE], ["COLECCION_IGLU_SOLIDO", Source.ASSAULT, Rarity.RARE], ["COLECCION_BOLA_NIEVE", Source.ASSAULT, Rarity.RARE], ["COLECCION_HUEVO_ENTERO", Source.BOSS, Rarity.RARE]]],
	["COLECCION_VIAJE_NEVADO", [["COLECCION_PIEL_AZUL", Source.ASSAULT, Rarity.RARE], ["COLECCION_COLMILLO_AFILADO", Source.ASSAULT, Rarity.RARE], ["COLECCION_PIEL_BLANCA", Source.ASSAULT, Rarity.RARE], ["COLECCION_CUERNO_PARTIDO", Source.ASSAULT, Rarity.RARE], ["COLECCION_GARRA_GIGANTE", Source.BOSS, Rarity.RARE]]],
	["COLECCION_APARICION_DIABOLICA", [["COLECCION_BOTAS_ORO", Source.MOBS, Rarity.EPIC], ["COLECCION_CINTURON_CALAVERA", Source.MOBS, Rarity.EPIC], ["COLECCION_PENDIENTE_ORO", Source.MOBS, Rarity.EPIC], ["COLECCION_COLETA_NEGRA", Source.MOBS, Rarity.EPIC], ["COLECCION_CIMITARRA", Source.BOSS, Rarity.EPIC]]],
	["COLECCION_FRAGANCIA_MAGICA", [["COLECCION_GORRO_TELA", Source.ASSAULT, Rarity.EPIC], ["COLECCION_TUNICA_TELA", Source.ASSAULT, Rarity.EPIC], ["COLECCION_BASTON_MADERA", Source.MOBS, Rarity.EPIC], ["COLECCION_BARBA_BLANCA", Source.MOBS, Rarity.EPIC], ["COLECCION_LIBRO_HECHIZOS", Source.BOSS, Rarity.EPIC]]],
	["COLECCION_TRAMPA_MORTAL", [["COLECCION_BARRO_SUCIO", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_ROCA_SUCIA", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_SAPO_MARRON", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_PIRANYA_CANIBAL", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_COCODRILO_FEROZ", Source.HARVEST, Rarity.UNCOMMON]]],
	["COLECCION_CIRCULO_VIDA", [["COLECCION_ESTATUA_DELICADA", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_RAICES_FUERTES", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_RAMA_PEQUENYA", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_HOJAS_ROSAS", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_SEMILLAS_VIDA", Source.HARVEST, Rarity.UNCOMMON]]],
	["COLECCION_SENTENCIA_MUERTE", [["COLECCION_GRILLETES_MADERA", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_PLANCHAS_FUERTES", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_CESTO_MIMBRE", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_CUERDA_FUERTE", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_HOJA_GUILLOTINA", Source.HARVEST, Rarity.UNCOMMON]]],
	["COLECCION_ATRAPADO_OSCURIDAD", [["COLECCION_CERRADURA_HIERRO", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_BARRA_HIERRO", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_CADENAS_HIERRO", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_GRILLETES_HIERRO", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_TRAJE_PRESO", Source.HARVEST, Rarity.UNCOMMON]]],
	["COLECCION_TRIBUTO_HEROE", [["COLECCION_PEDESTAL_PIEDRA", Source.HARVEST, Rarity.UNCOMMON], ["COLECCION_PIERNAS_PIEDRA", Source.MOBS, Rarity.UNCOMMON], ["COLECCION_PECHO_PIEDRA", Source.ASSAULT, Rarity.UNCOMMON], ["COLECCION_CABEZA_PIEDRA", Source.CHEST, Rarity.RARE], ["COLECCION_ESPADA_PIEDRA", Source.BOSS, Rarity.RARE]]],
	["COLECCION_AMIGO_TROLL", [["COLECCION_COLGANTE_ROJO", Source.HARVEST, Rarity.RARE], ["COLECCION_HUESO_RICO", Source.MOBS, Rarity.RARE], ["COLECCION_PELO_MARRON", Source.ASSAULT, Rarity.RARE], ["COLECCION_GLOBO_ROJO", Source.CHEST, Rarity.RARE], ["COLECCION_GORRO_PILOTO", Source.BOSS, Rarity.RARE]]],
	["COLECCION_BOLA_PELO", [["COLECCION_COLGANTE_MONO", Source.HARVEST, Rarity.RARE], ["COLECCION_LATA_ATUN", Source.MOBS, Rarity.RARE], ["COLECCION_PELO_AZUL", Source.ASSAULT, Rarity.RARE], ["COLECCION_CASCABEL_PEQUENYO", Source.CHEST, Rarity.RARE], ["COLECCION_BOLA_LANA", Source.BOSS, Rarity.RARE]]],
	["COLECCION_HUESOS", [["COLECCION_HUESO_CARNE", Source.HARVEST, Rarity.RARE], ["COLECCION_ESPADA_OXIDADA", Source.MOBS, Rarity.RARE], ["COLECCION_YELMO_PODRIDO", Source.ASSAULT, Rarity.RARE], ["COLECCION_ESCUDO_DANYADO", Source.CHEST, Rarity.RARE], ["COLECCION_CALAVERA_MALVADA", Source.BOSS, Rarity.RARE]]],
	["COLECCION_ALIADO_MONSTRUOSO", [["COLECCION_HOMBRERA_CUERO", Source.HARVEST, Rarity.EPIC], ["COLECCION_YELMO_ESPELUZNANTE", Source.MOBS, Rarity.EPIC], ["COLECCION_BRAZALETES_REFORZADOS", Source.ASSAULT, Rarity.EPIC], ["COLECCION_MANDIBULAS_HUESO", Source.CHEST, Rarity.EPIC], ["COLECCION_MARTILLO_PUNTA", Source.BOSS, Rarity.EPIC]]],
	["COLECCION_SONIDO_BOSQUE", [["COLECCION_ARCO_LARGO", Source.HARVEST, Rarity.EPIC], ["COLECCION_DIADEMA_ORO", Source.MOBS, Rarity.EPIC], ["COLECCION_FLECHA_AFILADA", Source.ASSAULT, Rarity.EPIC], ["COLECCION_CARCAJ_CUERO", Source.CHEST, Rarity.EPIC], ["COLECCION_OCARINA_MADERA", Source.BOSS, Rarity.EPIC]]],
	["COLECCION_BAHAMUT_GOLDEN", [["COLECCION_BAHAMUT_GOLDEN_ITEM1", Source.HARDCORE, Rarity.RARE], ["COLECCION_BAHAMUT_GOLDEN_ITEM2", Source.HARDCORE, Rarity.RARE], ["COLECCION_BAHAMUT_GOLDEN_ITEM3", Source.HARDCORE, Rarity.RARE], ["COLECCION_BAHAMUT_GOLDEN_ITEM4", Source.HARDCORE, Rarity.RARE], ["COLECCION_BAHAMUT_GOLDEN_ITEM5", Source.HARDCORE, Rarity.RARE]]],
	["COLECCION_BAHAMUT_RED", [["COLECCION_BAHAMUT_RED_ITEM1", Source.HARDCORE, Rarity.RARE], ["COLECCION_BAHAMUT_RED_ITEM2", Source.HARDCORE, Rarity.RARE], ["COLECCION_BAHAMUT_RED_ITEM3", Source.HARDCORE, Rarity.RARE], ["COLECCION_BAHAMUT_RED_ITEM4", Source.HARDCORE, Rarity.RARE], ["COLECCION_BAHAMUT_RED_ITEM5", Source.HARDCORE, Rarity.RARE]]],
	["COLECCION_BAHAMUT_HEART", [["COLECCION_BAHAMUT_HEART_ITEM1", Source.HARDCORE, Rarity.EPIC], ["COLECCION_BAHAMUT_HEART_ITEM2", Source.HARDCORE, Rarity.EPIC], ["COLECCION_BAHAMUT_HEART_ITEM3", Source.HARDCORE, Rarity.EPIC], ["COLECCION_BAHAMUT_HEART_ITEM4", Source.HARDCORE, Rarity.EPIC], ["COLECCION_BAHAMUT_HEART_ITEM5", Source.HARDCORE, Rarity.EPIC]]],
]


static func count() -> int:
	return TABLE.size()


## The text name of the collection, or of its item when index is 1 to ITEMS_PER_COLLECTION.
static func text_name(collection: int, index: int = 0) -> String:
	return TABLE[collection - 1][0] if index == 0 else TABLE[collection - 1][1][index - 1][0]


## A random item that drops from the source with the roll: Vector2i(collection,
## item index from 1), or Vector2i.ZERO when nothing drops. When no item of the
## rarity drops from the source, the client takes the next more common rarity.
static func loot(source: Source, roll: float, rng: RandomNumberGenerator) -> Vector2i:
	if source == Source.HARDCORE and rng.randf() >= HARDCORE_DROP_CHANCE:
		return Vector2i.ZERO
	for rarity in DROP_LIMITS.size():
		if roll >= DROP_LIMITS[rarity]:
			continue
		for common in range(rarity, DROP_LIMITS.size()):
			var candidates: Array[Vector2i] = []
			for collection in range(1, count() + 1):
				for index in range(1, ITEMS_PER_COLLECTION + 1):
					var item: Array = TABLE[collection - 1][1][index - 1]
					if item[1] == source and item[2] == common:
						candidates.append(Vector2i(collection, index))
			if not candidates.is_empty():
				return candidates[rng.randi_range(0, candidates.size() - 1)]
		break
	return Vector2i.ZERO
