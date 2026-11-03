class_name ShotAbility
extends BattleAbility
## The abilities of the client that only change the shots or other fixed
## properties of a unit: the graphic of its shots, the delay of a shot after
## the attack, beams, a ranged unit that hits like a melee unit, the size of
## its graphic, and the effects that do not act on it.

## Item id -> properties: "shot" (graphic in <data>/fx), "delay" (frames),
## "beam" (frames until a beam hurts), "melee" (true: ranged_melee), "scale",
## "immune" (true: push, freeze, poison, swallow, conversion and stun do not act),
## "cycle" ([intervals, durations] of a cycle of special animations; the unit
## does not attack while one plays, as in the client).
const UNITS := {
	818: {"shot": "p.arrow", "delay": 5},  # Skeleton Archer (ArcherSkeletonDelegate)
	850: {"shot": "p.lightBall", "delay": 12},  # Bahamut Draggy
	790: {"shot": "p.crystalBall", "delay": 10},  # Crystal Draggy
	890: {"shot": "p.crystalBall", "delay": 12},  # Pharaoh Draggy (EgyptianDraggyDelegate)
	# Castle III (FireCastleDelegate): fire arrows. The client also draws a
	# stream of fire arrows without damage while the castle keeps its target;
	# the port does not draw it.
	198: {"shot": "p.fireArrow"},
	785: {"shot": "p.bullDragonBeam", "delay": 13, "beam": 30},  # Furious Bull Dragon
	778: {"shot": "p.zeusLightning", "delay": 6, "scale": 0.8},  # God Zeus
	828: {"shot": "p.zeusLightning", "delay": 6, "scale": 0.8},  # Furious Zeus
	710: {"shot": "p.lightMiniBeam"},  # Golden Draggie (GoldenDragonDelegate)
	765: {"melee": true},  # Hades
	784: {"shot": "p.energyBallBullDragon", "delay": 12},  # Horned Draggy
	705: {"shot": "p.lance", "cycle": [[105], [35]]},  # Celestial Lancer (LancerDelegate)
	2101: {"melee": true},  # Medieval Ether Messiah
	2102: {"melee": true},  # Medieval Samurai
	# Rodas Colossus: it hits like a melee unit, so its light beam never leaves.
	764: {"melee": true},
	813: {"shot": "p.fireBall_02", "delay": 10},  # Rubies Draggy
	782: {"shot": "p.spike", "melee": true},  # Spiky Spider
	779: {"shot": "p.ulisesArrow", "delay": 10},  # Ulysses
	849: {"shot": "p.lavaBall_01", "delay": 10},  # Volcano Draggy
	730: {"shot": "p.pumpkin", "delay": 11},  # Scarecrow (ScareCrowDelegate)
	763: {"melee": true},  # Lythos Minion (TitanLythosMinionDelegate)
	768: {"shot": "p.punkEnergyBall", "delay": 10},  # Heavy Draggy (HeavyDraggyDelegate)
	781: {"melee": true},  # Vulcano (HefestoDelegate)
	788: {"melee": true},  # Ares (AresDelegate)
	854: {"shot": "p.fireBall", "delay": 10},  # Red Bahamut Draggy (RedBahamutDraggyDelegate)
	868: {"shot": "p.crystalBall", "delay": 12},  # Electric Bahamut Draggy (ElectricBahamutDraggyDelegate)
	876: {"shot": "p.lightBall", "delay": 10},  # Golden  Bahamut Draggy (GoldenBahamutDraggyDelegate)
	2014: {"shot": "p.lightBall", "delay": 12},  # Dynasty Draggy (SnakeDraggyDelegate)
	2017: {"shot": "p.crystalBall", "delay": 12},  # Electric Dynasty Draggy (SnakeDraggyElecDelegate)
	2070: {"shot": "p.lightBall", "delay": 12},  # Golden Dynasty Draggy (GoldenDynastyDraggyDelegate)
	2075: {"melee": true},  # Elemental Fire God (GodElementalRedDelegate)
	2076: {"shot": "p.napalm", "delay": 16},  # Vulcano Minion (VulcanoMinionDelegate)
	2078: {"melee": true},  # Elemental Forest Minion (ForestGodMinionDelegate)
	2084: {"shot": "p.waterGodMinion", "delay": 15},  # Elemental Water Minion (ElementalWaterGodMinionDelegate)
	2085: {"melee": true},  # Elemental Water God (GodElementalWaterDelegate)
	2086: {"melee": true},  # Elemental Water Colossus (ElementalWaterColossusDelegate)
	2089: {"melee": true},  # Elemental Soul God (GodElementalSoulDelegate)
	2090: {"shot": "p.purpleBall", "delay": 2},  # Elemental Soul Colossus (InfraworldCollosusDelegate)
	2094: {"melee": true},  # Elemental Light Colossus (ColossusHeavenDelegate)
	2096: {"shot": "p.waterGodMinion", "delay": 15},  # Elemental Water Minion (ElementalWaterGodMinionDelegate)
	2103: {"shot": "p.fireBall", "delay": 14},  # Slayer Minion (MedievalGoldenSlayerMinionDelegate)
	2122: {"shot": "p.lightBall", "delay": 12},  # Sky Bahamut Draggy (SkyBahamutDraggyDelegate)
	2130: {"shot": "p.lavaBall_01", "delay": 11},  # Hell Abyss Draggy (HellDraggyDelegate)
	2141: {"shot": "p.lightBall", "delay": 12},  # Green Extreme Draggy (FourWingDraggyDelegate)
	2148: {"melee": true},  # Genesis Earth God (GodElementalEarthDelegate)
	2149: {"shot": "p.napalm", "delay": 16},  # Genesis Earth God Minion (VulcanoMinionDelegate)
	2157: {"melee": true},  # Caesar Gladiator (CaesarGladiatorDelegate)
	2160: {"melee": true},  # Genesis Shadow God (GodGenesisShadowDelegate)
	2167: {"melee": true},  # Genesis Ice God (GodGenesisIceDelegate)
	2194: {"shot": "p.antimatter", "delay": 10},  # Soul Extreme Draggy (ExtremeSoulDraggyDelegate)
	2197: {"shot": "p.lightBall", "delay": 10},  # Golden Epic Draggy (GoldenEpicDraggyDelegate)
	2200: {"shot": "p.punkEnergyBall", "delay": 10},  # Black Epic Draggy (BlackEpicDraggyDelegate)
	2203: {"shot": "p.crystalBall", "delay": 10},  # Electric Epic Draggy (ElectricEpicDraggyDelegate)
	2206: {"shot": "p.fireBall_02", "delay": 10},  # Jewel Epic Draggy (JewelEpicDraggyDelegate)
	2209: {"shot": "p.lightBall", "delay": 10},  # Red-Hot Epic Draggy (RedHotEpicDraggyDelegate)
	2215: {"shot": "p.crystalBall", "delay": 10},  # Skull Epic Draggy (SkullEpicDraggyDelegate)
	2221: {"shot": "p.crystalBall", "delay": 10},  # Taiji Epic Draggy (TaijiEpicDraggyDelegate)
	2224: {"shot": "p.lightMiniBeam", "delay": 10},  # Enel Epic Draggy (EnelEpicDraggyDelegate)
	2227: {"shot": "p.crystalBall", "delay": 10},  # Red Djinn Draggy (RedDjinnDraggyDelegate)
	2230: {"shot": "p.crystalBall", "delay": 10},  # Nebula Epic Draggy (NebulaEpicDraggyDelegate)
	2233: {"shot": "p.crystalBall", "delay": 10},  # Blue Fire Djinn Draggy (BlueFireDjinnDraggyDelegate)
	2239: {"shot": "p.crystalBall", "delay": 10},  # Thunder Epic Draggy (ThunderEpicDragonMinionDelegate)
	2242: {"shot": "p.energyBall", "delay": 10},  # Savage Draggy (SavageDragonMinionDelegate)
	2245: {"shot": "p.fireBall", "delay": 10},  # Scorch Savage Draggy (ScorchSavageDragonMinionDelegate)
	2248: {"shot": "p.crystalBall", "delay": 10},  # Shock Savage Draggy (ShockSavageDragonMinionDelegate)
	2251: {"shot": "p.boulder", "delay": 10},  # Rock Savage Draggy (RockSavageDragonMinionDelegate)
	2254: {"shot": "p.crystalBall", "delay": 10},  # Laser Epic Draggy (LaserEpicDragonMinionDelegate)
	2257: {"shot": "p.crystalBall", "delay": 10},  # Diamonds Savage Draggy (DiamondsSavageDragonMinionDelegate)
	2260: {"shot": "p.crystalBall", "delay": 10},  # Space Savage Draggy (SpaceSavageDragonMinionDelegate)
	2276: {"shot": "p.necroFireball", "delay": 10},  # Spawn Savage Draggy (SpawnDragonMinionDelegate)
	2279: {"shot": "p.lightBall", "delay": 10},  # Dark Shogun Epic Draggy (DarkShogunEpicDragonMinionDelegate)
	2282: {"shot": "p.fireBall", "delay": 10},  # Ancient Draggy (AncientDragonMinionDelegate)
	2285: {"shot": "p.fireBall", "delay": 10},  # Shaman Ancient Draggy (ShamanAncientDragonMinionDelegate)
	2288: {"shot": "p.fireBall", "delay": 10},  # Saint George Draggy (SaintGeorgeDragonMinionDelegate)
	2290: {"shot": "p.crystalBall", "delay": 10},  # Rune Ancient Draggy (RuneAncientDragonMinionDelegate)
	2293: {"shot": "p.punkEnergyBall", "delay": 10},  # Black Demon Epic Draggy (BlackDemonEpicDragonMinionDelegate)
	2296: {"shot": "p.punkEnergyBall", "delay": 10},  # Corpse Ancient Draggy (CorpseAncientDragonMinionDelegate)
	2300: {"shot": "p.crystalBall", "delay": 10},  # ? (CoreAncientDragonMinionDelegate)
	2303: {"shot": "p.necroFireball", "delay": 10},  # Hellborn Ancient Draggy (HellbornAncientDragonMinionDelegate)
	2306: {"shot": "p.hojarada", "delay": 10},  # Ent Ancient Draggy (EntAncientDragonMinionDelegate)
	2315: {"shot": "p.fireball_01", "delay": 13},  # Fireborn Bahamut Dragon (FirebornBahamutDragonDelegate)
	2316: {"shot": "p.fireBall", "delay": 10},  # Fireborn Bahamut Draggy (FirebornBahamutDragonMinionDelegate)
	2317: {"shot": "p.fireball_01", "delay": 13},  # Fireborn Bahamut Dragon Rider (FirebornBahamutDragonDelegate)
	2319: {"shot": "p.necroFireball", "delay": 10},  # Wraith Extreme Draggy (WraithExtremeDragonMinionDelegate)
	2322: {"shot": "p.energyBall", "delay": 10},  # Waterborn Bahamut Draggy (WaterbornEpicDragonMinionDelegate)
	2325: {"shot": "p.fireBall", "delay": 10},  # Ivory Dinasty Draggy (IvoryDinastyDragonMinionDelegate)
	2328: {"shot": "p.ghostSpit", "delay": 10},  # Ghost Epic Draggy (GhostEpicDragonMinionDelegate)
	2331: {"shot": "p.energyBall", "delay": 10},  # Night Enel Draggy (NightEnelDragonMinionDelegate)
	2334: {"shot": "p.fireBall", "delay": 10},  # Rock Extreme Draggy (RockExtremeDragonMinionDelegate)
	2337: {"shot": "p.energyBall", "delay": 10},  # Fire Cerberus Draggy (CerberusAncientDragonMinionDelegate)
	2340: {"shot": "p.energyBall", "delay": 10},  # Thunder Forge Draggy (ThunderForgeDragonMinionDelegate)
	2342: {"shot": "p.energyBall", "delay": 10},  # Venom Cerberus Draggy (CerberusAncientDragonMinionDelegate)
	2343: {"shot": "p.energyBall", "delay": 10},  # Bones Cerberus Draggy (CerberusAncientDragonMinionDelegate)
	2345: {"shot": "p.energyBall", "delay": 10},  # Wolf Ancient Draggy (WolfAncientDragonMinionDelegate)
	2348: {"shot": "p.fireBall", "delay": 10},  # Red Armor Draggy (RedArmorDragonMinionDelegate)
	2352: {"shot": "p.energyBall", "delay": 10},  # Golden Armor Draggy (GoldenArmorDragonMinionDelegate)
	2355: {"shot": "p.energyBall", "delay": 10},  # Abyss Ancient Draggy (AbyssAncientDragonMinionDelegate)
	2358: {"shot": "p.lightBall", "delay": 10},  # Platinum Armor Draggy (PlatinumArmorDragonMinionDelegate)
	2361: {"shot": "p.fireBall_02", "delay": 10},  # Bull Armor Draggy (BullArmorDragonMinionDelegate)
	2364: {"shot": "p.energyBall", "delay": 10},  # Night Forge Draggy (NightForgeDragonMinionDelegate)
	2367: {"shot": "p.energyBall", "delay": 10},  # Devil Ancient Draggy (DevilAncientDragonMinionDelegate)
	786: {"melee": true},  # Manticora (ManticoraDelegate)
	2109: {"shot": "p.axeMonster", "delay": 8},  # Monster Gladiator (MonsterGladiatorDelegate)
}

func configure(item_id: int) -> void:
	var data: Dictionary = UNITS.get(item_id, {})
	shot_graphic = data.get("shot", "")
	shot_delay = data.get("delay", 0)
	if data.has("beam"):
		beam = true
		beam_frames = data["beam"]
	ranged_melee = data.get("melee", false)
	if data.has("cycle"):
		special_intervals.assign(data["cycle"][0])
		special_durations.assign(data["cycle"][1])
	scale = data.get("scale", 1.0)
	if data.get("immune", false):
		immune_to_push = true
		immune_to_freeze = true
		immune_to_poison = true
		immune_to_swallow = true
		immune_to_conversion = true
		immune_to_stun = true

