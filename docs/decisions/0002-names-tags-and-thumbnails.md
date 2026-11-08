# 0002: Names, tags and thumbnails for the Workshop

Date: 2026-11-07

## Context

Before publishing, Max wanted the nine mods to read as one author's set. He
also didn't want them to look AI-made, because Project Zomboid players react
badly to AI-generated thumbnails. Three thumbnail styles were drawn on a
design canvas (https://claude.ai/artifact/HLKAR8yfvCrzJakbxaN9HB): a
screenshot with a name bar, the name written on the screenshot, and text
only. Max picked the screenshot with a name bar, and the proposed names.

## Decision

- **Names.** Every `mod.info` name is "jabroni's <Name>", so the in-game mod
  list sorts all nine together. Several names got shorter:

  | Before | After |
  | --- | --- |
  | Choose Starting Gear | jabroni's Starting Gear |
  | Choose Starting Vehicle | jabroni's Starting Vehicle |
  | Furnish by Room | jabroni's Room Furnisher |
  | Vehicle Storage Capacity | jabroni's Vehicle Storage |
  | Face Covering Protection | jabroni's Face Mask Protection |
  | Clock Alarm Shortcut | jabroni's Alarm Shortcut |
  | Horse Mod: Mounted Shooting and Hitching | jabroni's Horse Shooting & Hitching |

  Base Blueprints and A-Life Reputation Editor just gained the prefix. Labels
  inside the game use the short name without the prefix, for example the
  "Room Furnisher" window and the "Vehicle Storage" sandbox page.
- **IDs and folders stay.** Mod IDs and repo folder names are unchanged.
  Max didn't take up the suggestion to prefix the IDs.
- **Titles and tags.** Each Workshop title is the name plus " [B42] [SP]".
  The Workshop has no single-player tag; its tag list is in the game's
  `WorkshopTags.txt`. So single player is stated in the title, at the start
  of every description, and at the end of every `mod.info` description.
  Every mod gets the "Build 42" tag and never "Multiplayer".
- **Thumbnail.** A real in-game screenshot, with a plain black bar under it.
  The bar says "jabroni's" in Arial, the name in Arial Bold, and "B42 · SP"
  in the corner. Long names wrap onto two lines with a taller bar.
  `tools/workshop/thumbnail.py` builds it. The same image is the in-game
  `poster.png`.

## How to reverse

- Names: edit `name=` in each `mod/<Id>/42/mod.info` and `title=` in
  `workshop/workshop.txt`. Revert the label changes in the Translate files:
  `Sandbox.json` in vehicle-storage-capacity, face-covering-protection and
  choose-starting-vehicle, and `UI.json` in furnish-by-room.
- Thumbnail style: change `tools/workshop/thumbnail.py` and run `preview`
  again for each mod. Option C on the canvas (text only) needs no
  screenshot.
- After a mod is public, renaming only changes what players see. Changing a
  mod ID would break their saves, so don't.
