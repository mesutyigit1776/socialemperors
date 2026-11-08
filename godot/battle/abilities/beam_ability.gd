class_name BeamAbility
extends BattleAbility
## The dragons that shoot beams (AbstractBeamDelegate of the client). An attack
## starts a beam: after the shot delay, a beam goes to the target and hurts it
## with the attack of the dragon when it ends. The dragon does not attack again
## while its beam lasts; when it walks, the beam stops.
##
## The limit attacks of these dragons (smash, healing beams) start only from
## the buttons of the player, see roadmap step 3.2.

## Item id -> [beam graphic in <data>/fx, shot delay in frames]. The graphic
## can also be a list of [beam, blast] that the beams take in turn, or at
## random when a third element "random" follows.
const UNITS := {
	891: ["p.blackBeam", 13],  # Black Bahamut Dragon
	793: ["p.energyBeam", 13],  # Angelical Dragon
	777: ["p.crystalBeam", 12],  # Crystal Dragon
	888: ["p.egyptianBeam", 13],  # Pharaoh Bahamut Dragon
	846: ["p.necroBeam", 13],  # Green Bahamut Dragon
	826: ["p.necroBeam", 13],  # Death Dragon (NecroDragonDelegate)
	845: ["p.necroBeam", 13],  # Death Dragon Rider (NecroDragonDelegate)
	798: ["p.beamBlackDragonFire", 12],  # Rubies Dragon
	847: ["p.lavaBeam", 13],  # Volcano Dragon
	841: ["p.crystalBeam", 12],  # Crystal Dragon Rider (CrystalDragonDelegate)
	844: ["p.beamBlackDragonFire", 12],  # Rubies Dragon Rider (RubiesDragonDelegate)
	851: ["p.lavaBeam", 13],  # Vulcano Dragon Rider (VulcanoDragonDelegate)
	852: ["p.necroBeam", 13],  # Green Bahamut Rider (GreenBahamutDragonDelegate)
	889: ["p.egyptianBeam", 13],  # Pharaoh Bahamut Dragon Rider (EgyptianDragonDelegate)
	893: ["p.blackBeam", 13],  # Black Bahamut Rider (BlackBahamutDragonDelegate)
	2000: ["p.egyptianBeam", 13],  # Paladin Bahamut Dragon (BahamutPaladinDelegate)
	2002: ["p.egyptianBeam", 13],  # Paladin Bahamut Rider (BahamutPaladinDelegate)
	2003: ["p.multicoloredBeam", 13],  # Supreme Bahamut Dragon (BahamutSupremeDelegate)
	2013: ["p.egyptianBeam", 13],  # Dynasty Dragon (SnakeDragonDelegate)
	2015: ["p.egyptianBeam", 13],  # Dynasty Dragon Rider (SnakeDragonDelegate)
	2039: ["p.egyptianBeam", 13],  # Solar Dragon (SunDragonDelegate)
	2041: ["p.egyptianBeam", 13],  # Solar Dragon Rider (SunDragonDelegate)
	2048: ["p.galaxyDragon", 13],  # Galaxy Dragon (GalaxyDragonDelegate)
	2050: ["p.galaxyDragon", 13],  # Galaxy Dragon Rider (GalaxyDragonDelegate)
	2063: ["p.starBeam", 12],  # Star Dragon (StarDragonDelegate)
	2065: ["p.starBeam", 12],  # Star Dragon Rider (StarDragonDelegate)
	2069: ["p.lightBeam", 12],  # Golden Dynasty Dragon (GoldenDynastyDragonDelegate)
	2071: ["p.lightBeam", 12],  # Golden Dynasty Dragon Rider (GoldenDynastyDragonDelegate)
	2121: ["p.lightBeam", 12],  # Sky Bahamut Dragon (SkyBahamutDragonDelegate)
	2123: ["p.lightBeam", 12],  # Sky Bahamut Dragon Rider (SkyBahamutDragonDelegate)
	2129: ["p.hellBeam", 18],  # Hell Abyss Dragon (HellDragonDelegate)
	2131: ["p.hellBeam", 18],  # Hell Abyss Dragon Rider (HellDragonDelegate)
	2174: ["p.lightBeam", 13],  # Golden Extreme Dragon (ExtremeGoldenDragonDelgate)
	2176: ["p.lightBeam", 13],  # Golden Extreme Dragon Rider (ExtremeGoldenDragonDelgate)
	2183: ["p.crystalBeam", 13],  # Frost Extreme Dragon (ExtremeFrostDragonDelegate)
	2185: ["p.crystalBeam", 13],  # Frost Extreme Dragon Rider (ExtremeFrostDragonDelegate)
	2186: ["p.greenBeam", 16],  # Forest Extreme Dragon (ExtremeForestDragonDelegate)
	2188: ["p.greenBeam", 16],  # Forest Extreme Dragon Rider (ExtremeForestDragonDelegate)
	2190: ["p.blueBeam", 16],  # Wind Extreme Dragon (ExtremeWindDragonDelegate)
	2192: ["p.blueBeam", 16],  # Wind Extreme Dragon Rider (ExtremeWindDragonDelegate)
	2199: ["p.violetRay", 13],  # Black Epic Dragon (BlackEpicDragonDelegate)
	2201: ["p.violetRay", 13],  # Black Epic Dragon Rider (BlackEpicDragonDelegate)
	2211: ["p.blueBeam", 10],  # Neon Epic Dragon (NeonEpicDragonDelegate)
	2213: ["p.blueBeam", 10],  # Neon Epic Dragon Rider (NeonEpicDragonDelegate)
	2214: ["p.blueBeam", 13],  # Skull Epic Dragon (SkullEpicDragonDelegate)
	2216: ["p.blueBeam", 13],  # Skull Epic Dragon Rider (SkullEpicDragonDelegate)
	2217: ["p.goldenRay", 13],  # Shogun Epic Dragon (ShogunEpicDragonDelegate)
	2219: ["p.goldenRay", 13],  # Shogun Epic Dragon Rider (ShogunEpicDragonDelegate)
	2220: ["p.bicoloredBeam", 9],  # Taiji Epic Dragon (TaijiEpicDragonDelegate)
	2222: ["p.bicoloredBeam", 9],  # Taiji Epic Dragon Rider (TaijiEpicDragonDelegate)
	2226: ["p.yellowRedBeam", 13],  # Red Djinn Dragon (RedDjinnDragonDelegate)
	2228: ["p.yellowRedBeam", 13],  # Red Djinn Dragon Rider (RedDjinnDragonDelegate)
	2229: ["p.multicoloredBeam", 13],  # Nebula Epic Dragon (NebulaEpicDragonDelegate)
	2231: ["p.multicoloredBeam", 13],  # Nebula Epic Dragon Rider (NebulaEpicDragonDelegate)
	2232: ["p.blueMagicBeam", 13],  # Blue Fire Djinn Dragon (BlueFireDjinnDragonDelegate)
	2234: ["p.blueMagicBeam", 13],  # Blue Fire Djinn Dragon Rider (BlueFireDjinnDragonDelegate)
	2237: ["p.ironBeam", 13],  # Genesis Iron Colossus (GenesisIronColossusDelegate)
	2238: ["p.electricityBeam", 13],  # Thunder Epic Dragon (ThunderEpicDragonDelegate)
	2240: ["p.electricityBeam", 13],  # Thunder Epic Dragon Rider (ThunderEpicDragonDelegate)
	2241: ["p.firebeamBahamut", 13],  # Savage Dragon (SavageDragonDelegate)
	2243: ["p.firebeamBahamut", 13],  # Savage Dragon Rider (SavageDragonDelegate)
	2244: ["p.firebeamBahamut", 13],  # Scorch Savage Dragon (ScorchSavageDragonDelegate)
	2246: ["p.firebeamBahamut", 13],  # Scorch Savage Dragon Rider (ScorchSavageDragonDelegate)
	2247: ["p.electricityBeam", 13],  # Shock Savage Dragon (ShockSavageDragonDelegate)
	2249: ["p.electricityBeam", 13],  # Shock Savage Dragon Rider (ShockSavageDragonDelegate)
	2250: ["p.greenRay", 13],  # Rock Savage Dragon (RockSavageDragonDelegate)
	2252: ["p.greenRay", 13],  # Rock Savage Dragon Rider (RockSavageDragonDelegate)
	2253: ["p.redEnergyLaser", 11],  # Laser Epic Dragon (LaserEpicDragonDelegate)
	2255: ["p.redEnergyLaser", 11],  # Laser Epic Dragon Rider (LaserEpicDragonDelegate)
	2256: ["p.diamondsBeam", 13],  # Diamonds Savage Dragon (DiamondsSavageDragonDelegate)
	2258: ["p.diamondsBeam", 13],  # Diamonds Savage Dragon Rider (DiamondsSavageDragonDelegate)
	2259: ["p.electricityBeam", 13],  # Space Savage Dragon (SpaceSavageDragonDelegate)
	2261: ["p.electricityBeam", 13],  # Space Savage Dragon Rider (SpaceSavageDragonDelegate)
	2267: ["p.easterBeam", 13],  # Easter Dragon (EasterDragonDelegate)
	2268: ["p.easterBeam", 13],  # Easter Dragon Rider (EasterDragonDelegate)
	2269: ["p.fire_01", 13],  # Forge Dragon (ForgeDragonDelegate)
	2271: ["p.fire_01", 13],  # Forge Dragon Rider (ForgeDragonDelegate)
	2272: ["p.fire_01", 13],  # Demon Dragon (DemonDragonDelegate)
	2274: ["p.fire_01", 13],  # Demon Dragon Rider (DemonDragonDelegate)
	2275: ["p.psiquicEnergy", 13],  # Spawn Savage Dragon (SpawnDragonDelegate)
	2277: ["p.psiquicEnergy", 13],  # Spawn Savage Dragon Rider (SpawnDragonDelegate)
	2278: ["p.goldenRay", 13],  # Dark Shogun Epic Dragon (DarkShogunEpicDragonDelegate)
	2280: ["p.goldenRay", 13],  # Dark Shogun Epic Dragon Rider (DarkShogunEpicDragonDelegate)
	2281: ["p.firebeamBahamut", 13],  # Ancient Dragon (AncientDragonDelegate)
	2283: ["p.firebeamBahamut", 13],  # Ancient Dragon Rider (AncientDragonDelegate)
	2284: ["p.lightBeam", 13],  # Shaman Ancient Dragon (ShamanAncientDragonDelegate)
	2286: ["p.lightBeam", 13],  # Shaman Ancient Dragon Rider (ShamanAncientDragonDelegate)
	2287: ["p.thunderLightningBolt", 13],  # Saint George Dragon (SaintGeorgeDragonDelegate)
	2289: ["p.yellowEnergyRay", 13],  # Rune Ancient Dragon (RuneAncientDragonDelegate)
	2291: ["p.yellowEnergyRay", 13],  # Rune Ancient Dragon Rider (RuneAncientDragonDelegate)
	2295: ["p.violetSoul", 13],  # Corpse Ancient Dragon (CorpseAncientDragonDelegate)
	2297: ["p.violetSoul", 13],  # Corpse Ancient Dragon Rider (CorpseAncientDragonDelegate)
	2299: ["p.firebeamBahamut", 13],  # Core Ancient Dragon (CoreAncientDragonDelegate)
	2301: ["p.firebeamBahamut", 13],  # Core Ancient Dragon Rider (CoreAncientDragonDelegate)
	2302: ["", 13],  # Hellborn Ancient Dragon (HellbornAncientDragonDelegate)
	2304: ["", 13],  # Hellborn Ancient Dragon Rider (HellbornAncientDragonDelegate)
	2305: ["", 20],  # Ent Ancient Dragon (EntAncientDragonDelegate)
	2307: ["", 20],  # Ent Ancient Dragon Rider (EntAncientDragonDelegate)
	2308: ["", 13],  # Horror Ancient Dragon (HorrorAncientDragonDelegate)
	2310: ["", 20],  # Atrocity (HorrorAncientDragonMinionDelegate2)
	2312: ["", 44],  # Impaler (HorrorAncientDragonMinionDelegate4)
	2313: ["", 13],  # Horror Ancient Dragon Rider (HorrorAncientDragonDelegate)
	2318: ["p.wraithBeam", 13],  # Wraith Extreme Dragon (WraithExtremeDragonDelegate)
	2320: ["p.wraithBeam", 13],  # Wraith Extreme Dragon Rider (WraithExtremeDragonDelegate)
	2321: ["p.waterBeam", 13],  # Waterborn Bahamut Dragon (WaterbornEpicDragonDelegate)
	2323: ["p.waterBeam", 13],  # Waterborn Bahamut Dragon Rider (WaterbornEpicDragonDelegate)
	2324: ["p.whiteFire", 13],  # Ivory Dinasty Dragon (IvoryDinastyDragonDelegate)
	2326: ["p.whiteFire", 13],  # Ivory Dinasty Dragon Rider (IvoryDinastyDragonDelegate)
	2327: ["p.wraithBeam", 13],  # Ghost Epic Dragon (GhostEpicDragonDelegate)
	2329: ["p.wraithBeam", 13],  # Ghost Epic Dragon Rider (GhostEpicDragonDelegate)
	2330: ["p.moonLight", 13],  # Night Enel Dragon (NightEnelDragonDelegate)
	2332: ["p.moonLight", 13],  # Night Enel Dragon Rider (NightEnelDragonDelegate)
	2333: ["p.whiteBeam", 13],  # Rock Extreme Dragon (RockExtremeDragonDelegate)
	2335: ["p.whiteBeam", 13],  # Rock Extreme Dragon Rider (RockExtremeDragonDelegate)
	2339: ["p.thunderForgeLighting", 13],  # Thunder Forge Dragon (ThunderForgeDragonDelegate)
	2341: ["p.thunderForgeLighting", 13],  # Thunder Forge Dragon Rider (ThunderForgeDragonDelegate)
	2344: ["p.whiteBeam", 13],  # Wolf Ancient Dragon (WolfAncientDragonDelegate)
	2346: ["p.whiteBeam", 13],  # Wolf Ancient Dragon Rider (WolfAncientDragonDelegate)
	2347: ["p.redArmorBeam", 13],  # Red Armor Dragon (RedArmorDragonDelegate)
	2349: ["p.redArmorBeam", 13],  # Red Armor Dragon Rider (RedArmorDragonDelegate)
	2350: ["p.electricityBeam", 13],  # Elemental Light Goddess (ElementalLightGoddessDelegate)
	2351: ["p.redArmorBeam", 13],  # Golden Armor Dragon (GoldenArmorDragonDelegate)
	2353: ["p.redArmorBeam", 13],  # Golden Armor Dragon Rider (GoldenArmorDragonDelegate)
	2354: ["p.blueWaterRay", 13],  # Abyss Ancient Dragon (AbyssAncientDragonDelegate)
	2356: ["p.blueWaterRay", 13],  # Abyss Ancient Dragon Rider (AbyssAncientDragonDelegate)
	2357: ["p.goldenRay", 13],  # Platinum Armor Dragon (PlatinumArmorDragonDelegate)
	2359: ["p.goldenRay", 13],  # Platinum Armor Dragon Rider (PlatinumArmorDragonDelegate)
	2360: ["p.redArmorBeam", 13],  # Bull Armor Dragon (BullArmorDragonDelegate)
	2362: ["p.redArmorBeam", 13],  # Bull Armor Dragon Rider (BullArmorDragonDelegate)
	2363: ["", 13],  # Night Forge Dragon (NightForgeDragonDelegate)
	2365: ["", 13],  # Night Forge Dragon Rider (NightForgeDragonDelegate)
	2366: ["p.violetSoul", 13],  # Devil Ancient Dragon (DevilAncientDragonDelegate)
	2368: ["p.violetSoul", 13],  # Devil Ancient Dragon Rider (DevilAncientDragonDelegate)
	2369: ["p.fireBeam", 13],  # Elemental Fire Goddess (ElementalFireGoddessDelegate)
	2370: ["", 13],  # Dark Horror Ancient Dragon (DarkHorrorAncientDragonDelegate)
	2375: ["", 13],  # Dark Horror Ancient Dragon Rider (DarkHorrorAncientDragonDelegate)
	# Dragons whose delegates add only button or limit logic to the beam (step 3.2).
	2292: ["p.steamBeam", 9],  # BlackDemonEpicDragonDelegate
	2294: ["p.steamBeam", 9],
	2202: ["p.electricityBeam", 12],  # ElectricEpicDragonDelegate
	2204: ["p.electricityBeam", 12],
	2223: ["p.blueBeam", 13],  # EnelEpicDragonDelegate
	2225: ["p.blueBeam", 13],
	2171: ["p.electricityBeam", 13],  # ExtremeElectricDragonDelegate
	2173: ["p.electricityBeam", 13],
	2177: ["p.firebeamBahamut", 13],  # ExtremeFireDragonDelegate
	2179: ["p.firebeamBahamut", 13],
	2193: ["p.steamBeam", 13],  # ExtremeSoulDragonDelegate
	2195: ["p.steamBeam", 13],
	2196: ["p.goldenRay", 13],  # GoldenEpicDragonDelegate
	2198: ["p.goldenRay", 13],
	2205: ["p.rainbowBeam", 9],  # JewelEpicDragonDelegate
	2207: ["p.rainbowBeam", 9],
	2208: ["p.fireBeam", 9],  # RedHotEpicDragonDelegate
	2210: ["p.fireBeam", 9],
	853: ["p.firebeamBahamut", 13],  # RedBahamutDragonDelegate; the flames of its flight are in special_units/
	855: ["p.firebeamBahamut", 13],
	2140: ["p.greenBeam", 16],  # FourWingDragonDelegate; the flames of its flight are in special_units/
	2142: ["p.greenBeam", 16],
	2016: ["p.energyBeam", 13],  # SnakeDragonElecDelegate
	2018: ["p.energyBeam", 13],
	2180: ["p.galaxyDragon", 13],  # ExtremeBullDragonDelegate
	2182: ["p.galaxyDragon", 13],
	843: ["p.energyBeam", 13],  # CelestialDragonDelegate
	2132: [[["p.hellBeam", ""], ["p.beamWater", ""], ["p.brownBeam", ""]], 20],  # ThreeHeadedElementalDragonDelegate: the heads in turn
	2134: [[["p.hellBeam", ""], ["p.beamWater", ""], ["p.brownBeam", ""]], 20],
	2336: [[["p.cerberusPoisonBeam", "b.cerberusPoisonBlast"], ["p.cerberusFireBeam", "b.cerberusFireBlast"], ["p.cerberusSkullBeam", "b.cerberusSkullBlast"]], 13, "random"],  # CerberusAncientDragonDelegate
	2338: [[["p.cerberusPoisonBeam", "b.cerberusPoisonBlast"], ["p.cerberusFireBeam", "b.cerberusFireBlast"], ["p.cerberusSkullBeam", "b.cerberusSkullBlast"]], 13, "random"],
	# Three-Headed Dragon (ThreeHeadedDragonDelegate): the client shows the
	# heads in turn (special attacks 1 to 3); the port shows the attack.
	2057: ["p.lightBeam", 22],
	2058: ["p.lightBeam", 22],
}
const BEAM_FRAMES := 15  ## The client lets a beam of a dragon last 0.5 seconds.
## Item id -> frames of a beam, for the dragons whose beams last longer.
const LONG_BEAMS := {2057: 90, 2058: 90}
## The client plays MAGIC_FIRE when a beam leaves, except for the
## Three-Headed Dragon, which roars when it starts to walk and has its own
## sound when it dies; the three-headed dragons play THREE_HEADED_BEAM 18
## frames after the start of each attack.
const SILENT_BEAMS: Array[int] = [2057, 2058]
const THREE_HEADED: Array[int] = [2057, 2058, 2132, 2134]
const THREE_HEADED_BEAM_MS := 18 * 1000 / 30

var _beaming := false
var _beam := 0  # Counts the beams, so that an old beam does nothing.
var _choices: Array = []  # [beam, blast] pairs, see UNITS.
var _random := false
var _turn := 0
var _item_id := 0


func configure(item_id: int) -> void:
	_item_id = item_id
	var data: Array = UNITS.get(item_id, ["p.energyBeam", 12])
	if data[0] is Array:
		_choices = data[0]
		_random = data.size() > 2 and data[2] == "random"
		shot_graphic = _choices[0][0]
	else:
		shot_graphic = data[0]
	shot_delay = data[1]
	beam = true
	beam_frames = LONG_BEAMS.get(item_id, BEAM_FRAMES)


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _beaming:
		return false
	_beaming = true
	_beam += 1
	if _item_id in THREE_HEADED:
		sim.sound_played.emit(SoundEffect.THREE_HEADED_BEAM, THREE_HEADED_BEAM_MS)
	var beam_id := _beam
	var target := fighter.target
	var blast := ""
	if not _choices.is_empty():
		var choice: Array = _choices[sim.rng.randi_range(0, _choices.size() - 1)] if _random else _choices[_turn % _choices.size()]
		_turn += 1
		shot_graphic = choice[0]
		blast = choice[1]
	sim.after(shot_delay, func() -> void:
		if beam_id != _beam or fighter.dead or fighter.moving or target == null or target.dead or fighter.target != target:
			_beaming = false
			return
		var tile := target.tile
		if not _item_id in SILENT_BEAMS:
			sim.sound_played.emit(SoundEffect.MAGIC_FIRE, -1)
		sim.shoot(fighter, target, shot_graphic, fighter.attack, func(_shot: BattleProjectile) -> void:
			if blast != "":
				sim.effect(blast, tile)
			if beam_id == _beam:
				_beaming = false))
	return false


func on_update(_sim: BattleSim, fighter: BattleFighter) -> void:
	if _beaming and fighter.moving:
		_beaming = false
		_beam += 1


func on_start_move(sim: BattleSim, _fighter: BattleFighter) -> void:
	if _item_id in SILENT_BEAMS:
		sim.sound_played.emit(SoundEffect.THREE_HEADED_ROAR_SMALL, 0)


func on_died(sim: BattleSim, _fighter: BattleFighter) -> void:
	if _item_id in SILENT_BEAMS:
		sim.sound_played.emit(SoundEffect.THREE_HEADED_DEATH, -1)
