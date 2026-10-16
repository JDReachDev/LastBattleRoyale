# Publishing Last Battle Royale on the Steam Workshop

This folder contains everything needed to build and upload the addon.
It is excluded from the `.gma` package (see `ignore` in `addon.json`).

| File | Purpose |
|---|---|
| `publish.bat` | Double-click to build and upload (wraps `publish.ps1`). |
| `publish.ps1` | Build + create/update script. |
| `icon.jpg` | Workshop thumbnail. **Must be a 512x512 JPEG.** |
| `workshop_description.txt` | Description in Steam BBCode, ready to paste on the Workshop page. |
| `workshop_id.txt` | ID of the existing Workshop item (`1549863126`). Its presence makes the script *update* instead of *create*. |
| `out/` | Build output (`lastbattleroyale.gma`), ignored by git. |

## Requirements

- Garry's Mod installed (the script finds it through your Steam libraries, or pass `-GModPath`).
- Steam running and logged in with the account that **owns** the Workshop item.
  Only the owner can update item `1549863126`. If you are a contributor, delete `workshop_id.txt`
  in your fork to publish your own item instead.

## Addon properties

Title, type and tags are read from [`../addon.json`](../addon.json) on every upload:

| Key | Allowed values |
|---|---|
| `title` | Workshop title. |
| `type` | **one** of: `gamemode`, `map`, `weapon`, `vehicle`, `npc`, `entity`, `tool`, `effects`, `model`, `servercontent` |
| `tags` | **up to two** of: `fun`, `roleplay`, `scenic`, `movie`, `realism`, `cartoon`, `water`, `comic`, `build` |
| `ignore` | Wildcard patterns of files that must not end up in the `.gma`. |

`gmad` only packs whitelisted file types (`.lua`, `.txt`, `.png`, `.jpg`, `.vmt`, `.vtf`, `.wav`, `.mp3`, models, maps...).
Anything else makes the build fail: add it to `ignore`.

## Build only (test locally)

```bat
publish\publish.bat -BuildOnly
```

## Update the Workshop item

```bat
publish\publish.bat -Changes "Fixed zone damage, added new map"
publish\publish.bat -Changes "New icon" -UpdateIcon
```

The changelog appears under *Change Notes* on the Workshop page.

## Things gmpublish cannot do

Open <https://steamcommunity.com/sharedfiles/filedetails/?id=1549863126> to:

1. edit the description (paste `workshop_description.txt`),
2. add screenshots / videos,
3. change visibility,
4. manage *required items* (the "Require Addons" collection).

## Manual commands

```bat
"<GMod>\bin\gmad.exe" create -folder "<repo>" -out "publish\out\lastbattleroyale.gma"
"<GMod>\bin\gmpublish.exe" update -addon "publish\out\lastbattleroyale.gma" -id 1549863126 -changes "message"
```

## Extract a published version

To compare with what is live on the Workshop:

```bat
"<GMod>\bin\gmad.exe" extract -file "<GMod>\garrysmod\cache\workshop\1549863126.gma" -out "extracted"
```
