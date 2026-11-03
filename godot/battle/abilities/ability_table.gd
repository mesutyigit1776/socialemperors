class_name AbilityTable
extends RefCounted
## The abilities of the port by item id, like the table of delegates of the
## client (DelegatesManager).

const SCRIPTS := {
	502: preload("res://battle/abilities/healer_ability.gd"),  # Healer
	590: preload("res://battle/abilities/healer_ability.gd"),  # Troll healer
	537: preload("res://battle/abilities/golem_ability.gd"),  # Stone Golem
	538: preload("res://battle/abilities/giant_boss_ability.gd"),  # Stone Golem boss
	545: preload("res://battle/abilities/giant_boss_ability.gd"),  # Giant Yeti
	630: preload("res://battle/abilities/giant_boss_ability.gd"),  # Golem of the spell Golem's Wrath
	631: preload("res://battle/abilities/giant_boss_ability.gd"),  # Yeti of the spell Yeti's Trail
	739: preload("res://battle/abilities/golden_dragon_boss_ability.gd"),
	1532: preload("res://battle/abilities/deadly_dragon_ability.gd"),
	699: preload("res://battle/abilities/area_blast_ability.gd"),  # Celestial Priest
	704: preload("res://battle/abilities/area_blast_ability.gd"),  # Celestial Reaper
	2098: preload("res://battle/abilities/timed_shot_ability.gd"),  # Antimatter Golem
	774: preload("res://battle/abilities/aquiles_ability.gd"),  # Achilles
	797: preload("res://battle/abilities/axe_skeleton_ability.gd"),  # Axe Skeleton
	850: preload("res://battle/abilities/shot_ability.gd"),  # Bahamut Draggy
	818: preload("res://battle/abilities/shot_ability.gd"),  # Skeleton Archer
	790: preload("res://battle/abilities/shot_ability.gd"),  # Crystal Draggy
	890: preload("res://battle/abilities/shot_ability.gd"),  # Pharaoh Draggy
	891: preload("res://battle/abilities/beam_ability.gd"),  # Black Bahamut Dragon
	793: preload("res://battle/abilities/beam_ability.gd"),  # Angelical Dragon
	777: preload("res://battle/abilities/beam_ability.gd"),  # Crystal Dragon
	888: preload("res://battle/abilities/beam_ability.gd"),  # Pharaoh Bahamut Dragon
	651: preload("res://battle/abilities/blue_draggy_ability.gd"),  # Lightning Draggy
	814: preload("res://battle/abilities/timed_shot_ability.gd"),  # Celestial Draggy
	756: preload("res://battle/abilities/timed_shot_ability.gd"),  # Centaur
	754: preload("res://battle/abilities/cerberus_ability.gd"),  # Cerberus
	748: preload("res://battle/abilities/cyclops_ability.gd"),  # Cyclops
	569: preload("res://battle/abilities/monk_ability.gd"),  # Monk
	2073: preload("res://battle/abilities/death_warrior_ability.gd"),  # Death Warrior
	2043: preload("res://battle/abilities/dual_dragon_ability.gd"),  # 2-Head Holydeath Dragon
	2006: preload("res://battle/abilities/timed_shot_ability.gd"),  # Imperial Elf Archer
	2010: preload("res://battle/abilities/elf_axe_ability.gd"),  # Imperial Elf Axe
	2012: preload("res://battle/abilities/elf_catapult_ability.gd"),  # Imperial Elf Catapult
	2021: preload("res://battle/abilities/elf_crossbow_ability.gd"),  # Elven Crossbow
	2022: preload("res://battle/abilities/elf_eagle_rider_ability.gd"),  # Elven Eagle Rider
	2011: preload("res://battle/abilities/elf_gryphon_ability.gd"),  # Imperial Elf Gryphon
	2009: preload("res://battle/abilities/elf_knight_ability.gd"),  # Imperial Elf Knight
	2007: preload("res://battle/abilities/elf_priest_ability.gd"),  # Elf Priest
	2008: preload("res://battle/abilities/elf_raptor_ability.gd"),  # Reptile Knight
	2019: preload("res://battle/abilities/elf_bull_rider_ability.gd"),  # Red Bull Rider
	753: preload("res://battle/abilities/scorpion_ability.gd"),  # Scorpion
	2005: preload("res://battle/abilities/elf_sword_ability.gd"),  # Imperial Elf Sword
	2020: preload("res://battle/abilities/elf_sword_ability.gd"),  # Silver Paladin
	198: preload("res://battle/abilities/shot_ability.gd"),  # Castle III
	722: preload("res://battle/abilities/trex_ability.gd"),  # Fire T-Rex
	649: preload("res://battle/abilities/furious_red_dragon_ability.gd"),  # Furious Dragon
	2023: preload("res://battle/abilities/dual_dragon_ability.gd"),  # 2-Head Frostfire Dragon
	785: preload("res://battle/abilities/shot_ability.gd"),  # Furious Bull Dragon
	778: preload("res://battle/abilities/shot_ability.gd"),  # God Zeus
	828: preload("res://battle/abilities/shot_ability.gd"),  # Furious Zeus
	773: preload("res://battle/abilities/poseidon_ability.gd"),  # Poseidon
	575: preload("res://battle/abilities/kamikaze_ability.gd"),  # Kamikaze
	686: preload("res://battle/abilities/kamikaze_ability.gd"),  # Infernal Kamikaze
	745: preload("res://battle/abilities/godzilla_ability.gd"),  # Godzilla
	2083: preload("res://battle/abilities/minion_whirlwind_ability.gd"),  # Evil crow whirlwind
	2154: preload("res://battle/abilities/minion_whirlwind_ability.gd"),  # Whirlwind of the earth god
	780: preload("res://battle/abilities/grabber_ability.gd"),  # Harpy
	789: preload("res://battle/abilities/grabber_ability.gd"),  # Hercules
	751: preload("res://battle/abilities/hermes_ability.gd"),  # Hermes
	710: preload("res://battle/abilities/shot_ability.gd"),  # Golden Draggie
	765: preload("res://battle/abilities/shot_ability.gd"),  # Hades
	784: preload("res://battle/abilities/shot_ability.gd"),  # Horned Draggy
	2036: preload("res://battle/abilities/timed_shot_ability.gd"),  # Golden Paladin
	846: preload("res://battle/abilities/beam_ability.gd"),  # Green Bahamut Dragon
	867: preload("res://battle/abilities/horus_ability.gd"),  # Horus Herald
	869: preload("res://battle/abilities/horus_ability.gd"),  # Horus Gryphon
	625: preload("res://battle/abilities/hurricane_ability.gd"),  # Hurricane
	758: preload("res://battle/abilities/infernal_dragon_ability.gd"),  # Infernal Dragon
	866: preload("res://battle/abilities/isis_healer_ability.gd"),  # Isis Healer
	717: preload("res://battle/abilities/kong_ability.gd"),  # King Kong
	705: preload("res://battle/abilities/shot_ability.gd"),  # Celestial Lancer
	684: preload("res://battle/abilities/lightning_dragon_ability.gd"),  # Stormy Dragon
	831: preload("res://battle/abilities/mad_balrog_ability.gd"),  # Mad Balrog
	702: preload("res://battle/abilities/angel_mech_ability.gd"),  # Celestial Mech
	2099: preload("res://battle/abilities/golden_slayer_ability.gd"),  # Medieval Golden Slayer
	2101: preload("res://battle/abilities/shot_ability.gd"),  # Medieval Ether Messiah
	2102: preload("res://battle/abilities/shot_ability.gd"),  # Medieval Samurai
	749: preload("res://battle/abilities/medusa_ability.gd"),  # Medusa
	2053: preload("res://battle/abilities/metal_trex_ability.gd"),  # Metal T-Rex
	752: preload("res://battle/abilities/minotaur_ability.gd"),  # Minotaur
	807: preload("res://battle/abilities/necro_abomination_ability.gd"),  # Necro Abomination
	806: preload("res://battle/abilities/necro_king_ability.gd"),  # Necro King
	820: preload("res://battle/abilities/necro_draggy_ability.gd"),  # Death Draggy
	826: preload("res://battle/abilities/beam_ability.gd"),  # Death Dragon
	845: preload("res://battle/abilities/beam_ability.gd"),  # Death Dragon Rider
	803: preload("res://battle/abilities/necro_units_ability.gd"),  # Necro Multi-arms
	805: preload("res://battle/abilities/necro_units_ability.gd"),  # Necro Shark Monster
	795: preload("res://battle/abilities/necro_units_ability.gd"),  # Necro Warrior
	816: preload("res://battle/abilities/necro_units_ability.gd"),  # Necro Worm
	811: preload("res://battle/abilities/necro_winged_ability.gd"),  # Necro Winged Warrior
	369: preload("res://battle/abilities/oil_tower_ability.gd"),  # Oil Tower
	2060: preload("res://battle/abilities/orc_slasher_ability.gd"),  # Brutal Slasher
	2112: preload("res://battle/abilities/orc_slasher_ability.gd"),  # Evil Demon
	744: preload("res://battle/abilities/phoenix_ability.gd"),  # The Phoenix
	775: preload("res://battle/abilities/phoenix_ability.gd"),  # Blue Phoenix
	856: preload("res://battle/abilities/phoenix_ability.gd"),  # Green Phoenix
	1254: preload("res://battle/abilities/phoenix_egg_ability.gd"),  # Phoenix Egg
	1282: preload("res://battle/abilities/phoenix_egg_ability.gd"),  # Phoenix Blue Egg
	2055: preload("res://battle/abilities/soul_eater_ability.gd"),  # Soul Eater
	2081: preload("res://battle/abilities/soul_eater_ability.gd"),  # Fire Soul Eater
	742: preload("res://battle/abilities/spider_ability.gd"),  # Tiger Spider
	766: preload("res://battle/abilities/punk_ability.gd"),  # Heavy Dragon
	840: preload("res://battle/abilities/punk_ability.gd"),  # Heavy Dragon rider
	764: preload("res://battle/abilities/shot_ability.gd"),  # Rodas Colossus
	813: preload("res://battle/abilities/shot_ability.gd"),  # Rubies Draggy
	798: preload("res://battle/abilities/beam_ability.gd"),  # Rubies Dragon
	782: preload("res://battle/abilities/shot_ability.gd"),  # Spiky Spider
	713: preload("res://battle/abilities/trex_ability.gd"),  # T-Rex
	772: preload("res://battle/abilities/titan_hydros_ability.gd"),  # Titan Hydros
	728: preload("res://battle/abilities/hurricane_ability.gd"),  # Hurricane of Titan Hydros
	757: preload("res://battle/abilities/titan_lythos_ability.gd"),  # Titan Lythos
	755: preload("res://battle/abilities/titan_pyros_ability.gd"),  # Titan Pyros
	762: preload("res://battle/abilities/titan_stratos_ability.gd"),  # Titan Stratos
	716: preload("res://battle/abilities/topo_ability.gd"),  # Mole
	617: preload("res://battle/abilities/tornado_ability.gd"),  # Tornado
	884: preload("res://battle/abilities/tutankamon_ability.gd"),  # Tutankamon
	779: preload("res://battle/abilities/shot_ability.gd"),  # Ulysses
	849: preload("res://battle/abilities/shot_ability.gd"),  # Volcano Draggy
	847: preload("res://battle/abilities/beam_ability.gd"),  # Volcano Dragon
	2042: preload("res://battle/abilities/vulcano_golem_ability.gd"),  # Volcano Golem
	791: preload("res://battle/abilities/werewolf_albino_ability.gd"),  # Albino Werewolf
	# The special attacks that the client writes in IsoUnit, see HeroAbility.
	603: preload("res://battle/abilities/hero_ability.gd"),
	643: preload("res://battle/abilities/hero_ability.gd"),
	644: preload("res://battle/abilities/hero_ability.gd"),
	673: preload("res://battle/abilities/hero_ability.gd"),
	648: preload("res://battle/abilities/hero_ability.gd"),
	677: preload("res://battle/abilities/hero_ability.gd"),
	645: preload("res://battle/abilities/hero_ability.gd"),
	674: preload("res://battle/abilities/hero_ability.gd"),
	533: preload("res://battle/abilities/hero_ability.gd"),
	629: preload("res://battle/abilities/hero_ability.gd"),
	632: preload("res://battle/abilities/hero_ability.gd"),
	646: preload("res://battle/abilities/hero_ability.gd"),
	675: preload("res://battle/abilities/hero_ability.gd"),
	647: preload("res://battle/abilities/hero_ability.gd"),
	676: preload("res://battle/abilities/hero_ability.gd"),
	650: preload("res://battle/abilities/hero_ability.gd"),
	534: preload("res://battle/abilities/hero_ability.gd"),
	618: preload("res://battle/abilities/hero_ability.gd"),
	628: preload("res://battle/abilities/hero_ability.gd"),
	554: preload("res://battle/abilities/hero_ability.gd"),
	555: preload("res://battle/abilities/hero_ability.gd"),
	556: preload("res://battle/abilities/hero_ability.gd"),
	557: preload("res://battle/abilities/hero_ability.gd"),
	612: preload("res://battle/abilities/hero_ability.gd"),
	670: preload("res://battle/abilities/hero_ability.gd"),
	608: preload("res://battle/abilities/hero_ability.gd"),
	610: preload("res://battle/abilities/hero_ability.gd"),
	609: preload("res://battle/abilities/hero_ability.gd"),
	652: preload("res://battle/abilities/hero_ability.gd"),
	691: preload("res://battle/abilities/hero_ability.gd"),
	# Delegates that only set the shot, the beam or the melee hit (step 3.2).
	730: preload("res://battle/abilities/shot_ability.gd"),
	763: preload("res://battle/abilities/shot_ability.gd"),
	768: preload("res://battle/abilities/shot_ability.gd"),
	781: preload("res://battle/abilities/shot_ability.gd"),
	788: preload("res://battle/abilities/shot_ability.gd"),
	854: preload("res://battle/abilities/shot_ability.gd"),
	868: preload("res://battle/abilities/shot_ability.gd"),
	876: preload("res://battle/abilities/shot_ability.gd"),
	2014: preload("res://battle/abilities/shot_ability.gd"),
	2017: preload("res://battle/abilities/shot_ability.gd"),
	2070: preload("res://battle/abilities/shot_ability.gd"),
	2075: preload("res://battle/abilities/shot_ability.gd"),
	2076: preload("res://battle/abilities/shot_ability.gd"),
	2078: preload("res://battle/abilities/shot_ability.gd"),
	2084: preload("res://battle/abilities/shot_ability.gd"),
	2085: preload("res://battle/abilities/shot_ability.gd"),
	2086: preload("res://battle/abilities/shot_ability.gd"),
	2089: preload("res://battle/abilities/shot_ability.gd"),
	2090: preload("res://battle/abilities/shot_ability.gd"),
	2094: preload("res://battle/abilities/shot_ability.gd"),
	2096: preload("res://battle/abilities/shot_ability.gd"),
	2103: preload("res://battle/abilities/shot_ability.gd"),
	2122: preload("res://battle/abilities/shot_ability.gd"),
	2130: preload("res://battle/abilities/shot_ability.gd"),
	2141: preload("res://battle/abilities/shot_ability.gd"),
	2148: preload("res://battle/abilities/shot_ability.gd"),
	2149: preload("res://battle/abilities/shot_ability.gd"),
	2157: preload("res://battle/abilities/shot_ability.gd"),
	2160: preload("res://battle/abilities/shot_ability.gd"),
	2167: preload("res://battle/abilities/shot_ability.gd"),
	2194: preload("res://battle/abilities/shot_ability.gd"),
	2197: preload("res://battle/abilities/shot_ability.gd"),
	2200: preload("res://battle/abilities/shot_ability.gd"),
	2203: preload("res://battle/abilities/shot_ability.gd"),
	2206: preload("res://battle/abilities/shot_ability.gd"),
	2209: preload("res://battle/abilities/shot_ability.gd"),
	2215: preload("res://battle/abilities/shot_ability.gd"),
	2221: preload("res://battle/abilities/shot_ability.gd"),
	2224: preload("res://battle/abilities/shot_ability.gd"),
	2227: preload("res://battle/abilities/shot_ability.gd"),
	2230: preload("res://battle/abilities/shot_ability.gd"),
	2233: preload("res://battle/abilities/shot_ability.gd"),
	2239: preload("res://battle/abilities/shot_ability.gd"),
	2242: preload("res://battle/abilities/shot_ability.gd"),
	2245: preload("res://battle/abilities/shot_ability.gd"),
	2248: preload("res://battle/abilities/shot_ability.gd"),
	2251: preload("res://battle/abilities/shot_ability.gd"),
	2254: preload("res://battle/abilities/shot_ability.gd"),
	2257: preload("res://battle/abilities/shot_ability.gd"),
	2260: preload("res://battle/abilities/shot_ability.gd"),
	2276: preload("res://battle/abilities/shot_ability.gd"),
	2279: preload("res://battle/abilities/shot_ability.gd"),
	2282: preload("res://battle/abilities/shot_ability.gd"),
	2285: preload("res://battle/abilities/shot_ability.gd"),
	2288: preload("res://battle/abilities/shot_ability.gd"),
	2290: preload("res://battle/abilities/shot_ability.gd"),
	2293: preload("res://battle/abilities/shot_ability.gd"),
	2296: preload("res://battle/abilities/shot_ability.gd"),
	2300: preload("res://battle/abilities/shot_ability.gd"),
	2303: preload("res://battle/abilities/shot_ability.gd"),
	2306: preload("res://battle/abilities/shot_ability.gd"),
	2315: preload("res://battle/abilities/shot_ability.gd"),
	2316: preload("res://battle/abilities/shot_ability.gd"),
	2317: preload("res://battle/abilities/shot_ability.gd"),
	2319: preload("res://battle/abilities/shot_ability.gd"),
	2322: preload("res://battle/abilities/shot_ability.gd"),
	2325: preload("res://battle/abilities/shot_ability.gd"),
	2328: preload("res://battle/abilities/shot_ability.gd"),
	2331: preload("res://battle/abilities/shot_ability.gd"),
	2334: preload("res://battle/abilities/shot_ability.gd"),
	2337: preload("res://battle/abilities/shot_ability.gd"),
	2340: preload("res://battle/abilities/shot_ability.gd"),
	2342: preload("res://battle/abilities/shot_ability.gd"),
	2343: preload("res://battle/abilities/shot_ability.gd"),
	2345: preload("res://battle/abilities/shot_ability.gd"),
	2348: preload("res://battle/abilities/shot_ability.gd"),
	2352: preload("res://battle/abilities/shot_ability.gd"),
	2355: preload("res://battle/abilities/shot_ability.gd"),
	2358: preload("res://battle/abilities/shot_ability.gd"),
	2361: preload("res://battle/abilities/shot_ability.gd"),
	2364: preload("res://battle/abilities/shot_ability.gd"),
	2367: preload("res://battle/abilities/shot_ability.gd"),
	786: preload("res://battle/abilities/shot_ability.gd"),
	841: preload("res://battle/abilities/beam_ability.gd"),
	844: preload("res://battle/abilities/beam_ability.gd"),
	851: preload("res://battle/abilities/beam_ability.gd"),
	852: preload("res://battle/abilities/beam_ability.gd"),
	889: preload("res://battle/abilities/beam_ability.gd"),
	893: preload("res://battle/abilities/beam_ability.gd"),
	2000: preload("res://battle/abilities/beam_ability.gd"),
	2002: preload("res://battle/abilities/beam_ability.gd"),
	2003: preload("res://battle/abilities/beam_ability.gd"),
	2013: preload("res://battle/abilities/beam_ability.gd"),
	2015: preload("res://battle/abilities/beam_ability.gd"),
	2039: preload("res://battle/abilities/beam_ability.gd"),
	2041: preload("res://battle/abilities/beam_ability.gd"),
	2048: preload("res://battle/abilities/beam_ability.gd"),
	2050: preload("res://battle/abilities/beam_ability.gd"),
	2063: preload("res://battle/abilities/beam_ability.gd"),
	2065: preload("res://battle/abilities/beam_ability.gd"),
	2069: preload("res://battle/abilities/beam_ability.gd"),
	2071: preload("res://battle/abilities/beam_ability.gd"),
	2121: preload("res://battle/abilities/beam_ability.gd"),
	2123: preload("res://battle/abilities/beam_ability.gd"),
	2129: preload("res://battle/abilities/beam_ability.gd"),
	2131: preload("res://battle/abilities/beam_ability.gd"),
	2174: preload("res://battle/abilities/beam_ability.gd"),
	2176: preload("res://battle/abilities/beam_ability.gd"),
	2183: preload("res://battle/abilities/beam_ability.gd"),
	2185: preload("res://battle/abilities/beam_ability.gd"),
	2186: preload("res://battle/abilities/beam_ability.gd"),
	2188: preload("res://battle/abilities/beam_ability.gd"),
	2190: preload("res://battle/abilities/beam_ability.gd"),
	2192: preload("res://battle/abilities/beam_ability.gd"),
	2199: preload("res://battle/abilities/beam_ability.gd"),
	2201: preload("res://battle/abilities/beam_ability.gd"),
	2211: preload("res://battle/abilities/beam_ability.gd"),
	2213: preload("res://battle/abilities/beam_ability.gd"),
	2214: preload("res://battle/abilities/beam_ability.gd"),
	2216: preload("res://battle/abilities/beam_ability.gd"),
	2217: preload("res://battle/abilities/beam_ability.gd"),
	2219: preload("res://battle/abilities/beam_ability.gd"),
	2220: preload("res://battle/abilities/beam_ability.gd"),
	2222: preload("res://battle/abilities/beam_ability.gd"),
	2226: preload("res://battle/abilities/beam_ability.gd"),
	2228: preload("res://battle/abilities/beam_ability.gd"),
	2229: preload("res://battle/abilities/beam_ability.gd"),
	2231: preload("res://battle/abilities/beam_ability.gd"),
	2232: preload("res://battle/abilities/beam_ability.gd"),
	2234: preload("res://battle/abilities/beam_ability.gd"),
	2237: preload("res://battle/abilities/beam_ability.gd"),
	2238: preload("res://battle/abilities/beam_ability.gd"),
	2240: preload("res://battle/abilities/beam_ability.gd"),
	2241: preload("res://battle/abilities/beam_ability.gd"),
	2243: preload("res://battle/abilities/beam_ability.gd"),
	2244: preload("res://battle/abilities/beam_ability.gd"),
	2246: preload("res://battle/abilities/beam_ability.gd"),
	2247: preload("res://battle/abilities/beam_ability.gd"),
	2249: preload("res://battle/abilities/beam_ability.gd"),
	2250: preload("res://battle/abilities/beam_ability.gd"),
	2252: preload("res://battle/abilities/beam_ability.gd"),
	2253: preload("res://battle/abilities/beam_ability.gd"),
	2255: preload("res://battle/abilities/beam_ability.gd"),
	2256: preload("res://battle/abilities/beam_ability.gd"),
	2258: preload("res://battle/abilities/beam_ability.gd"),
	2259: preload("res://battle/abilities/beam_ability.gd"),
	2261: preload("res://battle/abilities/beam_ability.gd"),
	2267: preload("res://battle/abilities/beam_ability.gd"),
	2268: preload("res://battle/abilities/beam_ability.gd"),
	2269: preload("res://battle/abilities/beam_ability.gd"),
	2271: preload("res://battle/abilities/beam_ability.gd"),
	2272: preload("res://battle/abilities/beam_ability.gd"),
	2274: preload("res://battle/abilities/beam_ability.gd"),
	2275: preload("res://battle/abilities/beam_ability.gd"),
	2277: preload("res://battle/abilities/beam_ability.gd"),
	2278: preload("res://battle/abilities/beam_ability.gd"),
	2280: preload("res://battle/abilities/beam_ability.gd"),
	2281: preload("res://battle/abilities/beam_ability.gd"),
	2283: preload("res://battle/abilities/beam_ability.gd"),
	2284: preload("res://battle/abilities/beam_ability.gd"),
	2286: preload("res://battle/abilities/beam_ability.gd"),
	2287: preload("res://battle/abilities/beam_ability.gd"),
	2289: preload("res://battle/abilities/beam_ability.gd"),
	2291: preload("res://battle/abilities/beam_ability.gd"),
	2295: preload("res://battle/abilities/beam_ability.gd"),
	2297: preload("res://battle/abilities/beam_ability.gd"),
	2299: preload("res://battle/abilities/beam_ability.gd"),
	2301: preload("res://battle/abilities/beam_ability.gd"),
	2302: preload("res://battle/abilities/beam_ability.gd"),
	2304: preload("res://battle/abilities/beam_ability.gd"),
	2305: preload("res://battle/abilities/beam_ability.gd"),
	2307: preload("res://battle/abilities/beam_ability.gd"),
	2308: preload("res://battle/abilities/beam_ability.gd"),
	2310: preload("res://battle/abilities/beam_ability.gd"),
	2312: preload("res://battle/abilities/beam_ability.gd"),
	2313: preload("res://battle/abilities/beam_ability.gd"),
	2318: preload("res://battle/abilities/beam_ability.gd"),
	2320: preload("res://battle/abilities/beam_ability.gd"),
	2321: preload("res://battle/abilities/beam_ability.gd"),
	2323: preload("res://battle/abilities/beam_ability.gd"),
	2324: preload("res://battle/abilities/beam_ability.gd"),
	2326: preload("res://battle/abilities/beam_ability.gd"),
	2327: preload("res://battle/abilities/beam_ability.gd"),
	2329: preload("res://battle/abilities/beam_ability.gd"),
	2330: preload("res://battle/abilities/beam_ability.gd"),
	2332: preload("res://battle/abilities/beam_ability.gd"),
	2333: preload("res://battle/abilities/beam_ability.gd"),
	2335: preload("res://battle/abilities/beam_ability.gd"),
	2339: preload("res://battle/abilities/beam_ability.gd"),
	2341: preload("res://battle/abilities/beam_ability.gd"),
	2344: preload("res://battle/abilities/beam_ability.gd"),
	2346: preload("res://battle/abilities/beam_ability.gd"),
	2347: preload("res://battle/abilities/beam_ability.gd"),
	2349: preload("res://battle/abilities/beam_ability.gd"),
	2350: preload("res://battle/abilities/beam_ability.gd"),
	2351: preload("res://battle/abilities/beam_ability.gd"),
	2353: preload("res://battle/abilities/beam_ability.gd"),
	2354: preload("res://battle/abilities/beam_ability.gd"),
	2356: preload("res://battle/abilities/beam_ability.gd"),
	2357: preload("res://battle/abilities/beam_ability.gd"),
	2359: preload("res://battle/abilities/beam_ability.gd"),
	2360: preload("res://battle/abilities/beam_ability.gd"),
	2362: preload("res://battle/abilities/beam_ability.gd"),
	2363: preload("res://battle/abilities/beam_ability.gd"),
	2365: preload("res://battle/abilities/beam_ability.gd"),
	2366: preload("res://battle/abilities/beam_ability.gd"),
	2368: preload("res://battle/abilities/beam_ability.gd"),
	2369: preload("res://battle/abilities/beam_ability.gd"),
	2370: preload("res://battle/abilities/beam_ability.gd"),
	2375: preload("res://battle/abilities/beam_ability.gd"),
	# Orcs (step 3.2).
	2027: preload("res://battle/abilities/orc_units_ability.gd"),  # Orc Crusher
	2046: preload("res://battle/abilities/orc_units_ability.gd"),  # Orc Kamikaze
	2068: preload("res://battle/abilities/orc_units_ability.gd"),  # Orc Boomerang
	2030: preload("res://battle/abilities/orc_units_ability.gd"),  # Orc Spear Warrior
	2056: preload("res://battle/abilities/orc_units_ability.gd"),  # Monster Orc Rider
	2029: preload("res://battle/abilities/orc_units_ability.gd"),  # Orc Boar Rider
	2074: preload("res://battle/abilities/orc_units_ability.gd"),  # Orc Battering Ram
	2061: preload("res://battle/abilities/orc_units_ability.gd"),  # Orc Dual Axe
	2054: preload("res://battle/abilities/orc_units_ability.gd"),  # Orc Priest
	2031: preload("res://battle/abilities/orc_units_ability.gd"),  # Orc Spider Rider
	2066: preload("res://battle/abilities/orc_units_ability.gd"),  # Two-Headed Orc
	2047: preload("res://battle/abilities/orc_slasher_ability.gd"),  # OrcSlasherDelegate
	2072: preload("res://battle/abilities/orc_slasher_ability.gd"),  # OrcSlasherDelegate
}


## The ability of the item, or null when it has none.
static func create(item_id: int) -> BattleAbility:
	var script: Variant = SCRIPTS.get(item_id)
	if script == null:
		# A special unit without a delegate gets a plain ability for its buttons.
		return BattleAbility.new() if SpecialUnitTable.has(item_id) else null
	var ability: BattleAbility = script.new()
	ability.configure(item_id)
	return ability
