# 0007: The Crew tab edits A-Life's own skills, fighting stats and gear

Date: 2026-11-17

## Context

Players want to change the skills and loadout of the NPCs in their crew. A-Life
keeps three separate things that look like "skills and loadout":

- **Companion skills**: nine levels from 0 to 10 (melee, aiming, first aid,
  cooking, carpentry, mechanics, music, stealth, foraging) in
  `memory.companion.state.skills`. A-Life's Companions sheet shows them and picks
  a role from the highest one. Only first aid changes behavior today (1 lets
  them bandage themselves, 2 lets them bandage you); the rest are shown, and
  normally only rise by one a day when you teach them.
- **Fighting stats**: `strength` (melee hit power, 0 to 10) and `aiming` (gun
  accuracy, 0 to 10). These come from the NPC's profile and are rebuilt every
  time the body loads (`ProfileHydrator.plan`), then stamped on the body's mod
  data, where combat reads them.
- **Gear**: the body's inventory. When the body unloads, A-Life saves up to 8
  weapons, the gun ammo reserve and up to 24 items marked as scavenged
  (`ShellState.capture`). Everything else, including clothing, is rebuilt
  from the profile on the next load, and clothing also changes with the seasons.

## Decision

- A **Crew** tab lists your crew. Picking someone shows their nine companion
  skills and two fighting stats, each with - and +, plus **Max everything**.
- Skills are written into A-Life's companion state through `Companions.write`,
  so A-Life's sheet and its first-aid checks see them, and they move with the
  companion's kept state if they leave and rejoin.
- Fighting stats are saved in our own world data
  (`ALifeRepEditor.v1.crew[uid]`), stamped on the loaded body at once, and
  re-applied by wrapping `ProfileHydrator.plan`, so they survive the body
  unloading. We don't write into A-Life's profile catalog.
- **Give** spawns any item in the game into their inventory. Weapons get A-Life's
  weapon slot (melee, or primary for two-handed guns, secondary for one-handed)
  and can be equipped. A gun given and equipped comes with 60 rounds of ammo,
  because A-Life's NPCs fire from an ammo reserve, not from inventory boxes.
  Other items are marked as scavenged so A-Life keeps them when the body unloads.
- **Wear** replaces whatever they wear on that body location. The whole outfit
  is saved in our world data, put on at once with A-Life's
  `ProfileHydrator.redress`, and re-applied through the same `plan` wrapper.
  We also wrap `ProfileHydrator.wardrobePinned`, so A-Life's seasonal wardrobe
  doesn't swap the outfit back.
- Giving someone a gun also marks them as allowed to use firearms (A-Life bars
  guns for NPCs whose profile has none), saved and re-applied the same way.
- Edits stay with the NPC after they leave your crew; only crew members can be
  edited.

## How to reverse

- To drop the fighting stats and outfits surviving a reload: remove the
  `ProfileHydrator.plan` and `wardrobePinned` wrappers in `hooks.lua`. Edits
  then last until the body next unloads.
- To clear everyone's saved stats and outfits: delete `crew` from the
  `ALifeRepEditor.v1` world data (`Crew.forget` does it for one NPC).
- To remove the feature: delete the `crew*` commands in `hooks.lua`, the Crew
  tab in `RepEditorWindow.lua` and `CrewView.lua`.
