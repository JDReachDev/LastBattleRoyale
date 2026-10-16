# Last Battle Royale (Garry's Mod)

Battle royale gamemode for Garry's Mod, published on the Steam Workshop:
**<https://steamcommunity.com/sharedfiles/filedetails/?id=1549863126>**

It is based on **Last Stand** by Kanade, heavily modified: new weapons, new HUD, a shrinking
"Fortnite-style" safe zone, outlines on loot, supply drops, vehicles, classes with levels and more.

This repository contains the full source of the Workshop addon so anyone can study it, fix it,
add maps/weapons and run it on their own server.

## Features

- Round flow: lobby → preparing → live → post round, with a configurable minimum player count
- Shrinking safe zone with damage outside it, visible zone with 4 quality levels
- Random loot (weapons, attachments, medkits, adrenaline, armor, ghillie suit, ammo) on every round
- Cars (SCars) and helicopters (WAC) spawned around the map
- Random supply airdrops, optional nuclear strike event and optional implosion bomb at the end
- 9 classes unlocked by levelling up (EXP saved per player with PData)
- Squads: invite other players to your team
- Outline (halo) on loot to see it in the dark, custom scoreboard and HUD

## Controls

| Key | Action |
|---|---|
| `TAB` | Show alive players (scoreboard) |
| `F3` | Class menu |
| `F4` | Team (squad) menu — `F6` decline / `F7` accept an invite |
| `Q` | Drop the active weapon |
| `E` | Pick up a weapon from the ground |
| `E` (hold) + left click | Throw grenades (with a CW 2.0 weapon) |

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

Counter-Strike: Source content is recommended (armor). Without it set `lst_usecssarmor 0`.

## Supported maps

Collection: **[Last Battle Royale Supported Maps](https://steamcommunity.com/workshop/filedetails/?id=1127085806)**

| Map | Notes |
|---|---|
| `rp_pripyat_cop` | Best one, good for many players |
| `rp_city17_build210` | |
| `gm_marsh` | |
| `rp_wasteland` | |
| `gm_fork` | Heavy map, lower FPS |
| `gm_valley` | Heavy map, lower FPS |
| `rp_ineu_pass_v1e` | |

Any other map needs an entry in [`config.lua`](gamemodes/lastbattleroyale/gamemode/config.lua) —
see [docs/CONFIGURATION.md](docs/CONFIGURATION.md#adding-a-new-map).

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

All server settings are ConVars (`lst_*`). Quick reference:

| ConVar | Default | Description |
|---|---|---|
| `lst_minimumplayers` | `2` | Players needed to start a round |
| `lst_time_preparing` | `30` | Preparing time (seconds) |
| `lst_time_actionpreparing` | `30` | Time before the round goes live (seconds) |
| `lst_time_postround` | `15` | Time after the round ends (seconds) |
| `lst_zonespeed` | `0.75` | How fast the zone shrinks (units per tick) |
| `lst_healhealth` | `1` | `1` = health regenerates up to 20 while inside the zone |
| `lst_usecssarmor` | `1` | `1` = use CS:S armor models (needs CS:S mounted) |
| `lst_event_enablenuke` | `0` | `1` = enable the random nuclear strike event |
| `lst_enableimplosion` | `0` | `1` = implosion bomb when the zone fully closes |
| `lst_expscale` | `1` | EXP multiplier |
| `lst_levelexp` | `25` | EXP needed for the next level = next level × this value |
| `lst_zonequality` | `3` | Zone render quality: `3` high + texture, `2` medium, `1` low, `0` invisible |
| `lst_objoutline` | `1` | `1` = outline on loot |
| `lst_maxrounds` | *(not created)* | Optional, created by the map vote addon: after this many rounds the `MapChange` hook runs |

Defaults above are the ones shown in the *Start New Game* menu ([`lastbattleroyale.txt`](gamemodes/lastbattleroyale/lastbattleroyale.txt)).

Everything else (loot tables, vehicles, maps, classes) is plain Lua: see
**[docs/CONFIGURATION.md](docs/CONFIGURATION.md)**.

Tip: if every weapon spawns with all attachments, run `cw_disable_all_attachments_on_spawn 1` on the server.

## Repository layout

```
addon.json                       Workshop metadata used by gmad
gamemodes/lastbattleroyale/
    lastbattleroyale.txt         gamemode definition + Start New Game settings
    icon24.png, logo.png
    backgrounds/                 main menu backgrounds
    entities/entities/           zone, loot, armor, supply drop, implosion bomb
    entities/weapons/            medkit, adrenaline, supply signal
    gamemode/
        init.lua                 server entry point, net messages, squads, death handling
        cl_init.lua              HUD, zone rendering, class/team menus
        cl_scoreboard.lua        scoreboard
        shared.lua               ConVars, teams, round states
        sv_round.lua             round system, zone, loot/vehicle spawning, events
        sv_player.lua            player helpers, class switching
        config.lua               loot tables, vehicles and per-map configuration
        classes.lua              class list and unlock requirements
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

- The zone is sometimes visible through the background (rendering order).
- `lastbattleroyale.txt` lists `lst_enableimplosion` twice in the settings menu.
- `class_officer` exists in `player_class/` but is not registered in `classes.lua`.
- With many addons installed, problems are often caused by old files downloaded from public servers:
  clear `garrysmod/download/` and `garrysmod/downloads/server/`.

## Contributing

Pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## License and credits

The code in this repository is released under the [MIT License](LICENSE), with the exception of the
parts derived from third-party addons listed in [CREDITS.md](CREDITS.md), which remain the
property of their original authors.
