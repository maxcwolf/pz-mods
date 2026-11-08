# Steam Workshop plan

How the mods in this repo get onto the Steam Workshop as **jabroni**.
Written 2026-11-07 against Build 42.21 stable (42.22 is out for modders).

## How the game's uploader works

These facts come from PZwiki
([Mod structure](https://pzwiki.net/wiki/Mod_structure),
[Uploading mods](https://pzwiki.net/wiki/Uploading_mods),
[workshop.txt](https://pzwiki.net/wiki/Workshop.txt)).

- The in-game uploader is at **Main menu → Workshop → Create and update
  items**. It only sees items under `~/Zomboid/Workshop/<Item>/`, not
  `~/Zomboid/mods/`.
- An item has this layout. Only `Contents/` is uploaded:

  ```
  ~/Zomboid/Workshop/<Item>/
    Contents/mods/<ModId>/42/{mod.info, poster.png, media/}
    workshop.txt
    preview.png        Workshop thumbnail, at most 512x512, 8-bit color
  ```

  The game needs at least one version folder (`42/`) or a `common/`
  folder. Our mods already have `42/`.
- `workshop.txt` holds `version=1`, `id=`, `title=`, one `description=`
  line per line of text, `tags=` and `visibility=` (0 public, 1 friends,
  2 private, 3 unlisted). With no `id`, the uploader makes a new item.
  After the first upload, that item's id is what ties later uploads to
  the same Workshop page.
- **Every upload replaces the whole Steam description** with the one in
  the uploader. It also adds `Workshop ID:` and `Mod ID:` lines at the end.
  So the description has to live in this repo. Never edit it on Steam.
- Files you delete from a mod stay on players' machines after an update.
  To retire a file, ship it empty instead of deleting it.
- Two copies of the same mod id clash: a `~/Zomboid/mods` symlink, a
  Workshop staging folder and a subscribed copy. Only one can be present
  when you play.

## What's missing today

| Need | Status |
| --- | --- |
| `author=jabroni` in mod.info | Done in all nine |
| In-game test pass | Only Choose Starting Gear has run in game (and its preview still fails). The other eight are untested. |
| `poster.png` (shown in the in-game mod list) and `poster=` line in mod.info | None of the nine |
| `preview.png` (Workshop thumbnail) | None |
| Workshop title, description (Steam BBCode), tags | None |
| Staging script from repo layout to Workshop layout | None |
| Steam account set up to publish | Not checked |

## Plan

### 1. Steam account (once, by you)

- Accept the Steam Workshop legal agreement. Until you do, uploaded items
  stay hidden from everyone but you. Steam links to it from the new item's
  page.
- Check the account isn't a "limited" Steam account (one that has never
  spent $5). Limited accounts are blocked from some community features.
- Confirm the Steam profile name shows as jabroni. Steam lists the
  uploading account as the item's author, whatever mod.info says.

### 2. Repo changes (Claude can do these)

1. **Per-mod `workshop/` folder**, not loaded by the game:
   - `workshop/workshop.txt`: title, tags, visibility, and the `id` once
     it exists.
   - `workshop/description.bbcode`: the Steam description, written in
     Steam BBCode with headings, a feature list, a compatibility section,
     a link to this repo and a credit for any mod it depends on. The
     staging script turns it into `description=` lines.
   - `workshop/preview.png`: 512x512.
   - `workshop/changelog.md`: the note pasted into the uploader for each
     update.
2. **`poster.png` in each `mod/<Id>/42/`**, plus a `poster=poster.png`
   line in mod.info.
3. **`scripts/stage-workshop.sh <mod>`** at the repo root. It:
   - copies `mod/<Id>/` into `~/Zomboid/Workshop/<Id>/Contents/mods/<Id>/`.
     It makes real copies rather than symlinks, because there's no
     guarantee the uploader follows symlinks. It leaves out tests, docs
     and dotfiles.
   - writes `workshop.txt` from `workshop/workshop.txt` plus the
     description file, and copies `preview.png`.
   - removes the mod's `~/Zomboid/mods/<Id>` symlink so the two copies
     don't clash, and prints how to restore it (`<mod>/scripts/install.sh`).
4. **`scripts/collect-workshop-id.sh <mod>`**: after the first upload,
   copies the `id=` the game wrote into the staged `workshop.txt` back
   into the repo, then commits it.
5. **Shared art style for posters and previews**, so the nine read as one
   author's set. A plain look works: a dark tile, the mod name, one icon,
   and a small "jabroni" mark. It's worth reviewing a few options as
   mockups before making all nine.
6. **A release checklist in each mod's README**: bump `modversion`, run
   the tests, stage, upload, collect the id, tag the commit
   `<mod>-v<version>`.

### 3. Test every mod in game first

Work through each mod's `todo.md` "first in-game run" list, then fix what
breaks. Nothing should go up public before it has run in game at least
once, in a fresh save and in an existing save. Suggested order, simplest
first, so the pipeline gets proven on low-risk mods:

1. Clock Alarm Shortcut
2. Face Covering Protection
3. Vehicle Storage Capacity
4. Choose Starting Gear (fix the preview first)
5. Furnish by Room
6. Choose Starting Vehicle
7. Base Blueprints
8. Horse Mod: Mounted Shooting and Hitching (needs the Horse mod,
   Workshop 3661336777)
9. A-Life Reputation Editor (needs Project A-Life, Workshop 3803984183)

### 4. First upload of each mod (unlisted)

1. `scripts/stage-workshop.sh <mod>`, then launch the game.
2. In **Workshop → Create and update items**, pick the item, check the
   title, tags (pick the Build 42 tag the uploader offers) and preview,
   set visibility to **Unlisted**, and upload.
3. `scripts/collect-workshop-id.sh <mod>` and commit.
4. Smoke-test the real Workshop copy. Delete the staged folder and the
   `~/Zomboid/mods` symlink, subscribe on Steam, launch, and check that
   the mod loads from Steam and works.
5. For the Horse and A-Life add-ons, open the Steam page, choose **Add/Remove
   Required Items**, and add the parent mod. Players then get prompted to
   subscribe to it too. Steam doesn't do this from `require=`.
6. Unsubscribe, then run `install.sh` again to go back to the dev copy.

### 5. Go public

- Switch visibility to Public, through `workshop.txt` (`visibility=0`)
  plus a re-upload, or on the Steam page.
- Make a Steam **collection**, "jabroni's Build 42 mods", with all nine.
- Add the Workshop link to each mod's README and to the root README table.

### 6. Updates

- Batch changes into fewer, bigger updates. Every update makes servers
  that run the mod restart.
- For each update: bump `modversion`, write the change note, stage,
  upload, then tag `<mod>-v<x.y.z>` and push.
- Keep the description in the repo. The uploader overwrites Steam's copy
  every time.
- When a new game build breaks something, add a newer version folder
  (for example `42.22/`) next to `42/` rather than editing `42/` in place,
  so players on older builds keep working.

## Open questions

- **License.** The repo is public with no license, so by default all
  rights are reserved. Steam's terms already let players download the
  mods. Pick a license if you want others to fork or reuse the code
  (MIT is common for PZ Lua mods).
- **Multiplayer.** Most of these mods are single-player only or untested
  in multiplayer. Each description should say so.
- **Parent-mod permissions.** The Horse and A-Life add-ons wrap those
  mods' functions without copying their files. Check each parent mod's
  page for add-on rules before going public.
- **Tag list.** The uploader's tag names weren't checked. Confirm a
  Build 42 tag exists on the first upload.
