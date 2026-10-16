# Configuration

Last Battle Royale is configured in two places:

1. **ConVars** (`lst_*`) — server settings you can change without touching code.
2. **Lua tables** in [`gamemode/config.lua`](../gamemodes/lastbattleroyale/gamemode/config.lua)
   and [`gamemode/classes.lua`](../gamemodes/lastbattleroyale/gamemode/classes.lua) — loot, vehicles,
   maps and classes.

All paths below are relative to `gamemodes/lastbattleroyale/`.

---

## 1. ConVars

They are created in [`gamemode/shared.lua`](../gamemodes/lastbattleroyale/gamemode/shared.lua) and
shown in the *Start New Game* menu by [`lastbattleroyale.txt`](../gamemodes/lastbattleroyale/lastbattleroyale.txt).

> **Two sets of defaults.** When you start a game from the main menu the values of
> `lastbattleroyale.txt` are used. On a dedicated server without a `server.cfg` the
> defaults written in `shared.lua` are used instead (they differ: see the table).
> Always set them explicitly in `server.cfg`.

| ConVar | Menu default | Code default | Description |
|---|---|---|---|
| `lst_minimumplayers` | `2` | `2` | Players needed to start a round |
| `lst_time_preparing` | `30` | `15` | Preparing phase (seconds) |
| `lst_time_actionpreparing` | `30` | `60` | Time before the round goes live (seconds) |
| `lst_time_postround` | `15` | `15` | Post round phase (seconds) |
| `lst_zonespeed` | `0.75` | `1` | Radius removed from the zone every tick |
| `lst_healhealth` | `1` | `1` | Regenerate health up to 20 HP while inside the zone |
| `lst_usecssarmor` | `1` | `1` | Use CS:S models for armor / ghillie (needs CS:S mounted) |
| `lst_event_enablenuke` | `0` | `1` | Random nuclear strike event during the round |
| `lst_enableimplosion` | `0` | `1` | Implosion bomb when the zone reaches radius 0 |
| `lst_expscale` | `1` | `1` | EXP multiplier for kills / wins |
| `lst_levelexp` | — | `25` | EXP for the next level = next level × this value |
| `lst_zonequality` | `3` | `3` | `3` high + texture, `2` medium, `1` low, `0` invisible |
| `lst_objoutline` | `1` | `1` | Outline (halo) on loot |

Optional: `lst_maxrounds` is **not** created by the gamemode. If it exists (for example created by the
map vote addon) the round system runs the `MapChange` hook after that many rounds.

### Example `server.cfg`

```cfg
hostname "Last Battle Royale"
gamemode lastbattleroyale

lst_minimumplayers 4
lst_time_preparing 30
lst_time_actionpreparing 30
lst_time_postround 15
lst_zonespeed 0.75
lst_healhealth 1
lst_usecssarmor 1
lst_event_enablenuke 0
lst_enableimplosion 0
lst_expscale 1
lst_levelexp 25
lst_zonequality 3
lst_objoutline 1

// CW 2.0: spawn weapons without attachments
cw_disable_all_attachments_on_spawn 1
```

### Zone damage

Players outside the zone lose **1 HP every 0.36 s** (`HurtPlayers` in `gamemode/sv_round.lua`).
To change it edit the timer interval or the `TakeDamage` amount:

```lua
v:TakeDamage( 1, v, v )                              -- damage per tick
timer.Create("HurtAllPlayers", 0.36, 0, HurtPlayers)   -- tick interval in seconds
```

---

## 2. Loot tables (`gamemode/config.lua`)

```lua
ITEMS = {
	BETTERWEAPONS     = { ... },  -- rare rifles, snipers, machine guns
	WEAPONS           = { ... },  -- SMGs, shotguns, revolvers
	ADDITIONALWEAPONS = { ... },  -- pistols, grenades, molotov
	ITEMS             = { ... },  -- medkit, adrenaline, armor, ghillie, attachment packs
	AMMO              = { ... }   -- CW 2.0 ammo kits
}
```

Each entry is an entity / weapon class name. A class listed more than once is more likely to be picked.
To add a weapon from another pack, add its class name (shown in the spawn menu → right click → *Copy to clipboard*)
and make sure the pack is installed on server and clients.

How many items of each category spawn is set **per map** with `weaponsc` (see below).

## 3. Vehicles

```lua
VEHICLES = { "sent_sakarias_car_junker1", ... }   -- SCars, spawned on vehiclepositions

FLYING_VEHICLES = {
	RARE     = { "wac_hc_littlebird_mh6" },                      -- 50%
	VERYRARE = { "wac_hc_littlebird_ah6", "wac_hc_ah1z_viper" }   -- 50%
}
```

Every point in `vehiclepositions` gets a random car; every point in `flying_vehiclespawns` gets a
helicopter (50% from each list).

## 4. Per-map configuration (`MAPCONFIG`)

```lua
MAPCONFIG = {
	gm_fork = {
		weaponsc = {18,14,13,15,16},  -- items to spawn: BETTERWEAPONS, WEAPONS, ADDITIONALWEAPONS, ITEMS, AMMO
		zone_radius = 40000,          -- starting zone radius
		playerspawns = { Vector(...), ... },          -- where players are placed when the round goes live
		initialspawns = { Vector(...), ... },         -- lobby / waiting area spawns
		vehiclepositions = { Vector(...), ... },      -- cars
		flying_vehiclespawns = { Vector(...), ... },  -- helicopters
		events = {
			nukepositions = { Vector(...), ... },     -- nuke event targets
			supplydrops = { Vector(...), ... }        -- airdrop positions (high in the sky)
		},
		endpositions = { Vector(...), ... },          -- possible zone centers (one is picked each round)
		playermodels = { "models/...mdl", ... },      -- random models while waiting
		weaponspawns = { Vector(...), ... }           -- loot positions
	},
	...
}
```

Rules:

- `weaponspawns` must contain **at least as many points as the sum of `weaponsc`**,
  because each item takes a free position.
- `playerspawns` should have at least as many points as the max player count.
- The map name key must match `game.GetMap()` exactly.

### Adding a new map

1. Load the map in singleplayer / listen server with `sv_cheats 1`.
2. Walk to each position and run `getpos` in the console (or `lua_run print(Entity(1):GetPos())`).
   Copy the coordinates as `Vector(x, y, z)`.
   For loot, aim at the floor and use `lua_run print(Entity(1):GetEyeTrace().HitPos + Vector(0,0,10))`.
3. Add a new block to `MAPCONFIG` with all the keys above (copy an existing map as template).
4. Pick `zone_radius` big enough to cover the playable area from every `endpositions` point.
5. Add the map to the Workshop collection of supported maps and to the README.

---

## 5. Classes

Classes are listed in [`gamemode/classes.lua`](../gamemodes/lastbattleroyale/gamemode/classes.lua)
and implemented in [`gamemode/player_class/`](../gamemodes/lastbattleroyale/gamemode/player_class/).

| Class | HP | Speed | Loadout | Unlock |
|---|---|---|---|---|
| Recruit | 100 | 1.0 | crowbar | — |
| Russian | 30 | 1.0 | fists, Makarov | — |
| Sprinter | 80 | 1.2 | knife, smoke grenade | Recruit 5 |
| Traceur | 50 | 1.3 walk / 1.6 run | Shorty | Recruit 10 |
| Mercenary | 120 | 0.8 | crowbar, M1911 | Sprinter 10 |
| Scout | 85 | 1.1 | knife, SLAM, 30 armor | Mercenary 15 |
| Soldier | 100 | 1.0 | crowbar, P99, frag grenade | Scout 25 |
| Medic | 115 | 1.1 | crowbar, adrenaline | Soldier 25 |
| Veteran | 115 | 1.15 | crowbar | Recruit, Sprinter, Mercenary, Scout, Soldier 15 |

Speed is a multiplier of the base speeds in `shared.lua` (`GetGMWalkSpeed` 190, `GetGMRunSpeed` 265).

### Adding a class

1. Copy `player_class/class_default.lua` to `player_class/class_<name>.lua`.
2. Change `OVPCLASSNAME`, `DisplayName`, the stats and `Loadout()`, and the name in
   `player_manager.RegisterClass( "class_<name>", ... )` at the bottom.
3. Register it in `classes.lua`:

```lua
class.Add({
	name = "Sniper",
	class = "class_sniper",
	classesneeded = {
		{ class = "class_scout", level = 10 }
	},
	premium = false
})
```

`customcheck` / `customcheckfailmsg` can restrict a class (for example to a user group) — see the
commented example at the top of `classes.lua`.

Levels and EXP are saved per class with `PData` (server `sv.db`), keys `<class>_level` / `<class>_exp`.

## 6. EXP rewards

In `gamemode/init.lua`:

- a kill gives `(25 + victim level × 2) × lst_expscale`
- winning the round gives `30 × 2.5 × lst_expscale`, or `30 × 4 × lst_expscale` with 5+ kills in the round

`PlayersReward()` and `ScoreReward()` in `classessystem.lua` are helpers for rewards based on
server population and kills (currently not called).
