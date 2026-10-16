# Contributing

Thanks for helping! Bug fixes, new map configs, balance changes and new features are welcome.

## Setup

1. Fork and clone the repo into `garrysmod/addons/lastbattleroyale`.
2. Install the required addons (see the [README](README.md#requirements)).
3. Start a supported map with `gamemode lastbattleroyale`.
   Use `developer 1` and `bot` to add bots for quick tests (`lst_minimumplayers 1` helps too).

## Guidelines

- Keep the existing file layout: `sv_*` / `init.lua` server, `cl_*` client, `shared.lua` both.
- Add every new client file with `AddCSLuaFile` in `init.lua`.
- New settings → a `lst_*` ConVar in `shared.lua`, an entry in `lastbattleroyale.txt`,
  and a line in [docs/CONFIGURATION.md](docs/CONFIGURATION.md).
- New map → a `MAPCONFIG` block in `config.lua` and a row in the README maps table.
- Use tabs for indentation, like the rest of the code.
- Test on a listen server with at least two players (or bots) before opening the pull request.

## Pull requests

- One topic per pull request, with a short description of what changed and how you tested it.
- Do not commit `.gma` files or content from other addons.

## Bugs

Open an issue with: map, steps to reproduce, and the Lua error from the console (if any).
