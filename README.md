# Last Battle Royale (Garry's Mod)

[![Ko-fi](https://img.shields.io/badge/Ko--fi-support%20me-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/jdreach)

Battle royale gamemode for Garry's Mod, published on the Steam Workshop:
**<https://steamcommunity.com/sharedfiles/filedetails/?id=1549863126>**

It is based on **Last Stand** by Kanade, heavily modified: new weapons, new HUD, a
shrinking safe zone, outlines on loot, supply drops, vehicles, classes with levels and more.

This repository contains the full source of the Workshop addon so anyone can study it, fix it,
add maps/weapons and run it on their own server.

## Features

- Round flow: lobby → preparing → live → post round, with a configurable minimum player count
- Shrinking safe zone with damage outside it: a glowing wall, brightest at eye height and fading up and down, plus a storm effect (fog, grey colors) while you are outside
- Random loot (weapons, attachments, medkits, adrenaline, armor, ghillie suit, ammo) on every round
- Cars (SCars) and helicopters (WAC) spawned around the map
- Random supply airdrops, optional nuclear strike event and optional implosion bomb at the end
- 9 classes unlocked by levelling up (EXP saved per player with PData)
- Squads: invite other players to your team
- **In-game map editor (F8)**: configure any map by flying around and placing spawns, loot, vehicles and zone centers; configs are plain `.txt` files you can share
- **Loot editor** (F8 → Q → *Loot and vehicles*): choose which weapons, items and vehicles spawn and how often, pick them from the installed addons; saved in `data/lastbattleroyale/loot.txt`
- **Map vote** at the end of the match, only between the maps ready to play (configured with F8 or built in); admins change map with `F2`, where every installed map shows if it is ready or still to configure
- On-screen prompts when you look at something usable: `[E] PICK UP M4A1`, `[E] USE Personal Armor`, `[E] ENTER` a vehicle, `[E] OPEN` a supply drop
- Optimized for big maps: distance culling of loot and vehicles, lighter zone rendering and outlines
- Outline (halo) on loot to see it in the dark
- One look for everything: HUD, menus, map vote, map editor, dialogs, messages in the middle of the screen and in chat (`[LBR]` tag)

## Controls

| Key | Action |
|---|---|
| `TAB` (hold) | Scoreboard on the left (right click a player to mute; admins: *START NOW* in the lobby), on the right your **inventory** (5 equipment + 3 backpack slots: drag to move, right click to drop), your stats and the Classes / Squad / Map (admins: Change map) buttons. The view stays still |
| `M` | **Map** seen from above with a battleship grid (A–H / 1–8): you, your squad and the safe zone. Also from the *MAP* button in `TAB` |
| `F3` | Class menu: stats, loadout, level and what unlocks each class |
| `F4` | Squad menu: invite players, remove mates — `F6` decline / `F7` accept an invite |
| `Mouse wheel` / `1`–`5` | Switch between the 5 equipment slots (`6`: melee / fists). Weapons, medkits, adrenaline and grenades take a slot; with 8 items you must drop something to pick up more |
| `C` | CW 2.0 weapon customization: put on the attachments you found (press the category number `1`, `2`, `3`…; the ones you don't have are red) |
| `Q` | Drop the active weapon |
| `E` | Pick up a weapon, use an item, enter a vehicle, open a supply drop (a prompt shows what you are looking at) |
| `E` (hold) + left click | Throw grenades (with a CW 2.0 weapon) |
| `F2` | Admin: change map. Every installed map, split in *ready to play* and *to configure* (go there and press `F8`) |
| `F8` | Admin: map editor (configure spawns, loot, zone… of any map) |
| `!start` / `TAB` → *START NOW* | Admin: start the round now with the players already in (even below `lbr_min_players`, even alone to test the map) |

## Requirements

The gamemode uses weapons, entities and models from other Workshop addons.
Server **and** clients need them. The full list is in the Workshop collection
**[Last Battle Royale Require Addons](https://steamcommunity.com/workshop/filedetails/?id=1549569486)**:

| Addon | Used for |
|---|---|
| [Customizable Weaponry 2.0](https://steamcommunity.com/workshop/filedetails/?id=349050451) | Weapon base (`cw_*`) |
| [Extra Customizable Weaponry 2.0](https://steamcommunity.com/workshop/filedetails/?id=358608166) | Extra `cw_*` weapons |
| [Unofficial Extra Customizable Weaponry 2.0](https://steamcommunity.com/workshop/filedetails/?id=359830105) | `cw_g4p_*` weapons |
| [CW 2.0 - Melee](https://steamcommunity.com/workshop/filedetails/?id=707343339) | Knife (`cw_extrema_ratio_official`) |
| [[CW 2.0] Extra Rails](https://steamcommunity.com/workshop/filedetails/?id=462668882) | Attachments |
| [[CW2] Hitmarker plugin V2](https://steamcommunity.com/workshop/filedetails/?id=512986704) | Hitmarkers |
| Khris CW 2.0 packs: [Shared Content](https://steamcommunity.com/workshop/filedetails/?id=886451400), [Pistols](https://steamcommunity.com/workshop/filedetails/?id=886125449), [Revolvers](https://steamcommunity.com/workshop/filedetails/?id=886156547), [SMGs](https://steamcommunity.com/workshop/filedetails/?id=886132509), [Shotguns](https://steamcommunity.com/workshop/filedetails/?id=886148959), [Assault Rifles](https://steamcommunity.com/workshop/filedetails/?id=886137508), [Long-range rifles](https://steamcommunity.com/workshop/filedetails/?id=886146194), [Heavy Weapons](https://steamcommunity.com/workshop/filedetails/?id=886153712) | `khr_*` weapons |
| [Medkit and Adrenaline](https://steamcommunity.com/workshop/filedetails/?id=180842642) | Base for `sg_medkit_fix` / `sg_adrenaline_fix` |
| [Arctic's Slightly Nicer Armor and Medkits](https://steamcommunity.com/workshop/filedetails/?id=494180444) | Armor / ghillie models |
| [Molotov Cocktail](https://steamcommunity.com/workshop/filedetails/?id=137173046) | `weapon_molotov_c` |
| [SCars Slim](https://steamcommunity.com/workshop/filedetails/?id=104483020) + [SCars Extra](https://steamcommunity.com/workshop/filedetails/?id=104492363) | Cars |
| [WAC Aircraft](https://steamcommunity.com/workshop/filedetails/?id=104990330) | Helicopters |
| [HBOMBS Base Pack](https://steamcommunity.com/workshop/filedetails/?id=668552230) + [Materials](https://steamcommunity.com/workshop/filedetails/?id=668558959) | Nuke and implosion bomb |
| [Legacy Rust Sweps](https://steamcommunity.com/workshop/filedetails/?id=702289635) + [Rust (Legacy) Entities Pack](https://steamcommunity.com/workshop/filedetails/?id=705904773) | Supply signal / supply drop |
| [Viper's Operators Playermodels](https://steamcommunity.com/workshop/filedetails/?id=636790055) | Class player models |
| [Last Stand Map Voting](https://steamcommunity.com/workshop/filedetails/?id=798682244) | Map vote at the end of the match |
| [Pripyat (Resources)](https://steamcommunity.com/workshop/filedetails/?id=1486462327) | Content for `rp_pripyat_cop` |

Counter-Strike: Source content is recommended (armor). Without it set `lbr_css_armor 0`.

## Supported maps

Collection: **[Last Battle Royale Supported Maps](https://steamcommunity.com/workshop/filedetails/?id=1127085806)**

| Map | Notes |
|---|---|
| `rp_pripyat_cop` | Best one, good for many players |
| `rp_city17_build210` | |
| `gm_marsh` | |
| `rp_wasteland` | |
| `gm_fork` | Big map |
| `gm_valley` | Big map |
| `rp_ineu_pass_v1e` | |

Any other map can be configured in game: join as admin, press `F8`, place the points and save —
see [docs/CONFIGURATION.md](docs/CONFIGURATION.md#map-editor-f8).

## Installation

**From the Workshop:** subscribe to the addon and to the two collections above.

**From this repository (development):**

1. Clone the repo into your addons folder:
   ```bash
   git clone https://github.com/JDReachDev/LastBattleRoyale.git "garrysmod/addons/lastbattleroyale"
   ```
2. Subscribe to (or install) the required addons.
3. Start one of the supported maps with the gamemode:
   ```
   gamemode lastbattleroyale
   map rp_pripyat_cop
   ```
   or pick **Last Battle Royale** from the gamemode list in the main menu.

Lua changes are picked up on map change (many client/server files also auto-refresh while the game runs).

### Dedicated server

```bat
srcds.exe -game garrysmod +gamemode lastbattleroyale +map rp_pripyat_cop +host_workshop_collection <YOUR_COLLECTION_ID> +maxplayers 32
```

Make a Workshop collection containing this addon, the required addons and the maps you use,
and pass its ID with `+host_workshop_collection` so clients download everything automatically.

## Configuration

All server settings are ConVars (`lbr_*`). They used to be called `lst_*`: the old names still work
(`lst_zonespeed 1` in an old `server.cfg` sets `lbr_zone_speed`). Quick reference:

| ConVar | Default | Description |
|---|---|---|
| `lbr_min_players` | `2` | Players needed to start a round |
| `lbr_time_preparing` | `30` | Preparing time (seconds) |
| `lbr_time_weapons_hot` | `30` | Time before the round goes live (seconds) |
| `lbr_time_postround` | `15` | Time after the round ends (seconds) |
| `lbr_zone_speed` | `0.75` | How fast the zone shrinks (units per tick) |
| `lbr_zone_heal` | `1` | `1` = health regenerates up to 20 while inside the zone |
| `lbr_css_armor` | `1` | `1` = use CS:S armor models (needs CS:S mounted) |
| `lbr_event_nuke` | `0` | `1` = enable the random nuclear strike event |
| `lbr_event_implosion` | `0` | `1` = implosion bomb when the zone fully closes |
| `lbr_exp_scale` | `1` | EXP multiplier |
| `lbr_level_exp` | `25` | EXP needed for the next level = next level × this value |
| `lbr_zone_quality` | `3` | Client: zone wall quality: `3` high, `2` medium (textured wall), `1` low (plain wall), `0` invisible |
| `lbr_outline` | `1` | `1` = outline on loot |
| `lbr_outline_distance` | `1500` | Client: max loot outline distance (lower = more FPS) |
| `lbr_zone_view_distance` | `9000` | Client: how far the zone wall is drawn (lower = more FPS) |
| `lbr_cull_loot_distance` | `4000` | Loot farther than this is not sent to the player (big maps FPS), `0` = off |
| `lbr_cull_vehicle_distance` | `8000` | Client: parked vehicles farther than this are not drawn, `0` = off |
| `lbr_editor_superadminonly` | `0` | `1` = only superadmins can use the map editor |
| `lbr_mapvote` | `1` | `1` = map vote at the end of the match (only configured maps) |
| `lbr_mapvote_rounds` | `1` | Matches on the same map before the vote |
| `lbr_mapvote_maps` | `8` | Max maps in the vote |
| `lbr_mapvote_time` | `20` | Seconds to vote |
| `lbr_cw_spawn_attachments` | `0` | `1` = every CW 2.0 attachment on spawn, `0` = attachments only from the loot |
| `lst_maxrounds` | *(not created)* | Optional, created by the map vote addon: after this many rounds the `MapChange` hook runs |

Defaults above are the ones shown in the *Start New Game* menu ([`lastbattleroyale.txt`](gamemodes/lastbattleroyale/lastbattleroyale.txt)).

Map configs live in `garrysmod/data/lastbattleroyale/maps/<map>.txt` and are made in game with `F8`.
Loot and vehicles are chosen in game too (`F8` → `Q` → *Loot and vehicles*, saved in `data/lastbattleroyale/loot.txt`).
Classes and the default loot tables are plain Lua: see
**[docs/CONFIGURATION.md](docs/CONFIGURATION.md)**.

Attachments are loot: players start with none and find them in the attachment packs (`lbr_cw_spawn_attachments 1` gives every attachment on spawn, as plain CW 2.0 does).

## Repository layout

```
addon.json                       Workshop metadata used by gmad
gamemodes/lastbattleroyale/
    lastbattleroyale.txt         gamemode definition + Start New Game settings
    icon24.png, logo.png
    backgrounds/                 main menu backgrounds
    entities/entities/           zone, loot, armor, supply drop, implosion bomb,
                                 base_gmodentity (Sandbox base needed by addon entities)
    entities/weapons/            medkit, adrenaline, supply signal
    gamemode/
        init.lua                 server entry point, net messages, squads, death handling
        cl_init.lua              client entry point, key binds
        cl_hud.lua               HUD
        sh_notify.lua            messages: [LBR] chat lines and notifications in the middle of the screen
        cl_zone.lua              zone wall, storm effect, loot outlines
        cl_editor.lua            in-game map editor (client)
        cl_perf.lua / sv_perf.lua  distance culling of vehicles / loot on big maps
        sh_mapconfig.lua         map config format, validation, JSON
        sh_zone.lua              zone math shared by server and client
        sv_mapconfig.lua         map config files + map editor (server)
        cl_ui.lua                shared look of the menus (fonts, colors, buttons)
        cl_scoreboard.lua        TAB: scoreboard, inventory, stats
        cl_menus.lua / sv_menus.lua  F3 class menu, F4 squad menu, squad invite popup
        cl_prompt.lua            "[E] PICK UP ..." interaction prompt
        cl_weaponselect.lua      weapon selection bar (mouse wheel / 1-5 equipment, 6 hands)
        sh_inventory.lua / sv_inventory.lua  inventory: 5 equipment + 3 backpack slots, pickup limit, swap and drop
        sv_attachments.lua       CW 2.0: no attachments on spawn (they are loot)
        sv_mapvote.lua / cl_mapvote.lua  end of match map vote, F2 admin map menu
        sh_loot.lua / sv_loot.lua / cl_loot.lua  loot.txt format, loading, Loot panel of the editor
        sh_spawn.lua             safe spawn positions (players, loot, vehicles)
        shared.lua               ConVars (and their old lst_ names), teams, round states
        sv_round.lua             round system, zone, loot/vehicle spawning, events
        sv_player.lua            player helpers, class switching
        config.lua               loot tables, vehicles, built-in map configs
        classes.lua              class list, unlock requirements, menu descriptions
        player_class/            one file per class (stats + loadout)
materials/                       HUD icons and map images
docs/                            documentation
publish/                         scripts to build and upload to the Workshop
```

## Publishing to the Workshop

See [publish/README.md](publish/README.md). In short:

```bat
publish\publish.bat -Changes "What changed"
```

## Known issues

- `class_officer` exists in `player_class/` but is not registered in `classes.lua`.
- With many addons installed, problems are often caused by old files downloaded from public servers:
  clear `garrysmod/download/` and `garrysmod/downloads/server/`.

## Support

If you enjoy Last Battle Royale, you can support it on Ko-fi:
[![Ko-fi](https://img.shields.io/badge/Ko--fi-support%20me-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/jdreach)

## Contributing

Pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## License and credits

The code in this repository is released under the [MIT License](LICENSE), with the exception of the
parts derived from third-party addons listed in [CREDITS.md](CREDITS.md), which remain the
property of their original authors.
