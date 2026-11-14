# Configuration

Last Battle Royale is configured in two places:

1. **ConVars** (`lbr_*`) — server settings you can change without touching code.
2. **Lua tables** in [`gamemode/config.lua`](../gamemodes/lastbattleroyale/gamemode/config.lua)
   and [`gamemode/classes.lua`](../gamemodes/lastbattleroyale/gamemode/classes.lua) — loot, vehicles,
   maps and classes.

All paths below are relative to `gamemodes/lastbattleroyale/`.

---

## 1. ConVars

They are created in [`gamemode/shared.lua`](../gamemodes/lastbattleroyale/gamemode/shared.lua) and
shown in the *Start New Game* menu by [`lastbattleroyale.txt`](../gamemodes/lastbattleroyale/lastbattleroyale.txt).

> **Old names.** Until this version they were called `lst_*` (from Last Stand). The old names
> still work: `lst_zonespeed 1` in an old `server.cfg` sets `lbr_zone_speed`. The defaults of the
> *Start New Game* menu and of a dedicated server are now the same.

| ConVar | Old name | Default | Description |
|---|---|---|---|
| `lbr_min_players` | `lst_minimumplayers` | `2` | Players needed to start a round |
| `lbr_time_preparing` | `lst_time_preparing` | `30` | Preparing phase (seconds) |
| `lbr_time_weapons_hot` | `lst_time_actionpreparing` | `30` | Time before players can attack (seconds) |
| `lbr_time_postround` | `lst_time_postround` | `15` | Post round phase (seconds) |
| `lbr_zone_speed` | `lst_zonespeed` | `0.75` | Radius removed from the zone every tick |
| `lbr_zone_delay` | `lst_zonedelay` | `60` | Seconds after the start before the zone starts shrinking (a map can set its own `zone_delay`) |
| `lbr_zone_heal` | `lst_healhealth` | `1` | Regenerate health up to 20 HP while inside the zone |
| `lbr_css_armor` | `lst_usecssarmor` | `1` | Use CS:S models for armor / ghillie (needs CS:S mounted) |
| `lbr_event_nuke` | `lst_event_enablenuke` | `0` | Random nuclear strike event during the round |
| `lbr_event_implosion` | `lst_enableimplosion` | `0` | Implosion when the zone reaches radius 0 |
| `lbr_exp_scale` | `lst_expscale` | `1` | EXP multiplier for kills / wins |
| `lbr_level_exp` | `lst_levelexp` | `25` | EXP for the next level = next level × this value |
| `lbr_zone_quality` | `lst_zonequality` | `3` | Client: zone wall quality: `3` high, `2` medium (textured wall), `1` low (plain wall), `0` invisible |
| `lbr_outline` | `lst_objoutline` | `1` | Client: outline (halo) on loot |

New ConVars / commands:

| Name | Side | Default | Description |
|---|---|---|---|
| `lbr_editor_superadminonly` | server | `0` | `1` = only superadmins can open the map editor (admins otherwise) |
| `lbr_outline_distance` | client | `1500` | Max distance of loot outlines; lower = more FPS on big maps |
| `lbr_zone_view_distance` | client | `9000` | How far the zone wall is drawn; lower = more FPS |
| `lbr_changeclass <class>` | command | — | Choose the class for the next round (same as the F3 menu) |
| `lbr_cw_spawn_attachments` | server | `0` | `0` = players start with no CW 2.0 attachments (they come from the attachment packs), `1` = every attachment on spawn (plain CW 2.0) |
| `lbr_cull_loot_distance` | server | `4000` | Loot farther than this from a player is not sent to (nor drawn by) that player; `0` = off |
| `lbr_cull_vehicle_distance` | client | `8000` | Parked vehicles farther than this are not drawn; `0` = off |
| `lbr_cull_stats` | command | — | Admin: print how much loot is being culled |
| `lbr_start` | command | — | Admin: start the round now with the players already in, even below `lbr_min_players` or alone to test the map (also `!start` in chat or *START NOW* in the `TAB` scoreboard) |
| `lbr_mapvote` | server | `1` | Map vote at the end of the match. Only installed maps with a valid config (made with `F8` or built in) are in the vote; the current map is always one of them |
| `lbr_mapvote_rounds` | server | `1` | Matches played on the same map before the vote |
| `lbr_mapvote_time` | server | `20` | Seconds to vote |
| `lbr_mapvote_maps` | server | `12` | Max maps in the vote (random pick when more are ready) |
| `lbr_mapvote_start` | command | — | Admin: start a map vote now (in the lobby or after a match) |
| `lbr_changemap <map>` | command | — | Admin: change map (also `F2`: list of every installed map, ready ones and ones still to configure) |
| `lbr_editor` | command | — | Open / close the map editor (same as `F8`) |
| `lbr_map_reload` | command | — | Superadmin: reload `data/lastbattleroyale/maps/<map>.txt` and respawn loot points |
| `lbr_loot_reload` | command | — | Superadmin: reload `data/lastbattleroyale/loot.txt` (see *Loot editor* below) |

Optional: `lst_maxrounds` is **not** created by the gamemode. If it exists (for example created by the
map vote addon) the round system runs the `MapChange` hook after that many rounds.

### Example `server.cfg`

```cfg
hostname "Last Battle Royale"
gamemode lastbattleroyale

lbr_min_players 4
lbr_time_preparing 30
lbr_time_weapons_hot 30
lbr_time_postround 15
lbr_zone_speed 0.75
lbr_zone_delay 60
lbr_zone_heal 1
lbr_css_armor 1
lbr_event_nuke 0
lbr_event_implosion 0
lbr_exp_scale 1
lbr_level_exp 25

// CW 2.0 attachments only from the attachment packs (the default)
lbr_cw_spawn_attachments 0

// map vote after every match, 20 seconds
lbr_mapvote 1
lbr_mapvote_rounds 1
lbr_mapvote_time 20
```

### Zone damage

Players outside the zone lose **1 HP every 0.36 s** (`HurtPlayers` in `gamemode/sv_round.lua`).
To change it edit the timer interval or the `TakeDamage` amount:

```lua
v:TakeDamage( 1, v, v )                              -- damage per tick
timer.Create("HurtAllPlayers", 0.36, 0, HurtPlayers)   -- tick interval in seconds
```

---

## 2. Loot and vehicles

### In game: Loot editor (recommended)

Open the map editor (`F8`), press `Q` and click **Loot and vehicles**:

- the groups are on the left: **green**, **blue** and **purple** weapons (the tiers), throwables, items,
  ammo kits, attachment kits, cars, helicopters. A weapon is in one tier only: adding it to a tier takes
  it out of the others. Any CW 2.0 or ArcCW weapon can go in a tier;
- **damage %** (tiers and throwables): damage of that weapon, `100` = as the weapon pack made it
  (the tooltip shows the base damage);
- **Tiers and supply drop** (first button): the price of a magazine of each color in an ammo kit
  (green 100%, blue 50%, purple 25% by default: a magazine costs 1 / 2 / 4 green ones, a medium kit =
  10 green or 5 blue or 2.5 purple, mixed as the player likes), and the supply drop: opening time,
  purple and blue weapons, chance that a blue one is purple, purple magazines, items that always come out;
- **extra ammo** (weapons only): reserve ammo given when the weapon is picked up, on top of the
  loaded magazine (`0` = only the magazine, as before; the tooltip shows the ammo type);
- untick an entry to disable it, change its **weight** to make it more or less likely (the *chance*
  column shows the result), `X` removes it;
- **+ ADD** lists every weapon / entity installed (search by class, name or category); you can also
  type a class name by hand. Classes not installed on your client are shown in red as *NOT INSTALLED*;
- **SAVE** writes `garrysmod/data/lastbattleroyale/loot.txt` on the server; it is used from the next round;
- **RESET TO DEFAULT** deletes the file and goes back to the lists in `config.lua`.

Without `loot.txt` the gamemode uses the `config.lua` tables below. A version 1 file (old groups
BETTERWEAPONS / WEAPONS / ADDITIONALWEAPONS, CW 2.0 kits) is converted when read.
The file is the same on every map (how *many* items spawn is per map, see `weaponsc`).
`lbr_loot_reload` (superadmin / server console) reloads the file after editing it by hand.

```json
{
  "format": "lastbattleroyale-loot",
  "version": 2,
  "groups": {
    "GREEN": [ { "class": "cw_m1911", "weight": 1, "on": true, "ammo": 0, "damage": 100 }, ... ],
    "BLUE": [...], "PURPLE": [...], "THROWABLES": [...], "ITEMS": [...], "AMMO": [...],
    "ATTACHMENTS": [...], "CARS": [...], "HELI_RARE": [...], "HELI_VERYRARE": [...]
  },
  "tiers": { "green": 100, "blue": 50, "purple": 25 },
  "supply": { "time": 5, "purple": 1, "blue": 1, "purple_chance": 50,
              "items": [ "kevlar_armor", "sg_medkit_fix", "sg_adrenaline_fix", "lbr_ammo_medium" ] }
}
```

`ammo` (optional, 0–9999): extra reserve ammo on pickup. `damage` (optional, 1–1000): damage percent.
`tiers`: percent of an ammo kit's magazines for each tier.
`weight` 1–100: an entry with weight 2 is twice as likely as one with weight 1 (in the old lists that
meant writing the class twice). `on: false` keeps the entry but never spawns it.

### Default tables (`gamemode/config.lua`)

```lua
ITEMS = {
	GREEN       = { ... },  -- pistols, simple SMGs
	BLUE        = { ... },  -- assault rifles, good SMGs, shotguns
	PURPLE      = { ... },  -- snipers, machine guns, special weapons
	THROWABLES  = { ... },  -- grenades, molotov, mines
	ITEMS       = { ... },  -- medkit, adrenaline, armor, ghillie
	ATTACHMENTS = { ... },  -- lbr_attpack_small / medium / big (1 / 2 / 4 attachments)
	AMMO        = { ... },  -- lbr_ammo_small / medium / big (6 / 10 / 24 green magazines)
}
TIERS = { green = 100, blue = 50, purple = 25 }   -- price of a magazine per color: 100 / percent green ones
WEAPON_DAMAGE = { cw_l115 = 80 }                  -- damage percent per weapon class
SUPPLY_DROP = { time = 5, purple = 1, blue = 1, purple_chance = 50, purple_clips = 2, items = { ... } }
```

Ammo is three stores of magazines, one per color (green, blue, purple; weapons not in any tier use the
green one). The reserve of a weapon is its store x its magazine size, reloading takes the part of a
magazine you loaded (15 rounds of a 30 round M4 = 0.5). Every weapon with a magazine gets its own
engine ammo type (`lbr_w_<class>`) for this.
Each color has a limit, set in the server settings when you start a game: `lbr_clips_max_green`,
`lbr_clips_max_blue`, `lbr_clips_max_purple` (10 / 8 / 6, `0` = no limit). Boxes and kits give only up to
it, the rest stays in them.
Weapons always spawn with no attachments.

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

## 4. Per-map configuration

Every map has its own text file (JSON inside):

```
garrysmod/data/lastbattleroyale/maps/<map>.txt
```

- On server start every map built into `config.lua` (`MAPCONFIG`) is **exported** to that folder,
  only if its file does not exist yet. Existing configs are never lost or overwritten.
- The game always plays the `.txt` file. Edit it with the in-game editor, by hand, or drop in a file
  shared by someone else (the file name must be the map name, e.g. `gm_fork.txt`).
- Delete a file (or press *Reset* in the editor) to get the built-in config back.
- A map without a valid config does not start rounds; admins get a chat message telling them to press `F8`.
- Addons can ship configs in `data_static/lastbattleroyale/maps/<map>.txt`.

### Map editor (F8)

Join the map as admin (or in singleplayer / listen server) between rounds and press **F8**
(or run `lbr_editor`). You fly in noclip with god mode and see every existing point.

| Key | Action |
|---|---|
| `Left click` | Place a point of the selected category where you aim |
| `Right click` | Remove the hovered point |
| `Mouse wheel` / `1`–`8` | Change category |
| `R` | Place mode: on the aimed surface / at your own position (supply drops always use your position) |
| `E` | Teleport to the next point of the category |
| `Z` | Undo |
| `M` | Map from above with the points: mouse wheel / `0`–`8` (or a click on the list) show all the categories or only one, left click flies there, right click removes the point under the cursor |
| `W` `A` `S` `D` | Fly (noclip); `SHIFT` faster, `CTRL` slower |
| `Q` | Menu: save, zone radius and shrink delay, loot amounts, **Loot and vehicles** panel, player models, copy/import JSON, reload, reset |
| `F8` | Close (asks to save if there are unsaved changes) |

The panel on the left shows the point counts and what is still missing for the map to be playable.
*Save* writes the `.txt` file and applies it immediately.

Categories: player spawns, lobby spawns, loot spawns, cars, helicopters, zone centers
(`endpositions`), nuke targets, supply drops.

### File format

```json
{
  "format": "lastbattleroyale-map",
  "version": 1,
  "map": "gm_fork",
  "zone_radius": 40000,
  "zone_delay": 120,
  "weaponsc": [18, 14, 13, 15, 16, 15],
  "playermodels": ["models/player/group03/male_01.mdl"],
  "playerspawns": [[x, y, z], ...],
  "initialspawns": [...], "weaponspawns": [...], "vehiclepositions": [...],
  "flying_vehiclespawns": [...], "endpositions": [...],
  "events": { "nukepositions": [...], "supplydrops": [...] }
}
```

`weaponsc` = items to spawn for GREEN, BLUE, PURPLE, ITEMS, AMMO, ATTACHMENTS (attachment kits),
THROWABLES. Without the 6th number a map gets one kit every 3 weapons. Configs without `"lootv": 2`
(made before the tiers) are converted when loaded: 10% of the weapons become throwables, the rest
50% green, 35% blue, 15% purple.

Rules:

- Required: `playerspawns`, `weaponspawns`, `endpositions` and `zone_radius`.
- `weaponspawns` should contain at least as many points as the sum of the first 5 numbers of `weaponsc`
  (attachment kits use the free points, then spawn next to other loot).
- `playerspawns` should have at least as many points as the max player count (extra players reuse points with a small offset).
- `zone_radius` must cover the playable area from every `endpositions` point (the editor draws it).
- `zone_delay` (optional) = seconds before the zone starts shrinking on this map; without it the
  server option `lbr_zone_delay` is used. In the editor: "Shrink delay", -1 = server option.

The old `MAPCONFIG` table in `config.lua` still works: it is only used as the source of the
built-in files.

---

## 5. Classes

### In game: Classes editor (recommended)

Open the map editor (`F8`), press `Q` and click **Classes**: for every class you can change the name,
the description shown in the F3 menu, health, armor at spawn, walk and run speed (percent of the server
speed), the loadout (+ ADD WEAPON lists the installed weapons) and the levels needed in other classes
to unlock it. **SAVE** writes `garrysmod/data/lastbattleroyale/classes.txt` (one file for every map);
the changes are used from the next spawn. **RESET TO DEFAULT** deletes the file and goes back to the
Lua files below. `lbr_classes_reload` (superadmin / server console) reloads the file after editing it by hand.

```json
{
  "format": "lastbattleroyale-classes", "version": 1,
  "classes": {
    "class_soldier": { "name": "Soldier", "desc": "...", "health": 100, "armor": 0, "walk": 100, "run": 100,
                       "loadout": [ "weapon_crowbar", "cw_p99", "cw_frag_grenade" ],
                       "needs": [ { "class": "class_scout", "level": 25 } ] }
  }
}
```

### In Lua (defaults)

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

- a kill gives `(25 + victim level × 2) × lbr_exp_scale`
- winning the round gives `30 × 2.5 × lbr_exp_scale`, or `30 × 4 × lbr_exp_scale` with 5+ kills in the round

`PlayersReward()` and `ScoreReward()` in `classessystem.lua` are helpers for rewards based on
server population and kills (currently not called).
