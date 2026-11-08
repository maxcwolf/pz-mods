"""Copies a mod from this repo into the layout the game's Workshop uploader reads.

Repo layout:      <mod>/mod/<Id>/42/...   <mod>/workshop/{workshop.txt, description.bbcode, preview.png}
Uploader layout:  ~/Zomboid/Workshop/<Id>/Contents/mods/<Id>/42/...  plus workshop.txt and preview.png
"""

import os
import shutil
from pathlib import Path

import manifest

# The game refuses to upload these (SteamWorkshopItem.validateFileTypes).
BLOCKED_SUFFIXES = (".exe", ".dll", ".bat", ".app", ".dylib", ".sh", ".so", ".zip")


def mod_id(mod_dir):
    """Returns the mod id, the one folder under <mod>/mod/."""
    ids = [p.name for p in Path(mod_dir, "mod").iterdir() if p.is_dir() and not p.name.startswith(".")]
    if len(ids) != 1:
        raise ValueError(f"{mod_dir}/mod should hold exactly one mod folder, found {ids}")
    return ids[0]


def shipped_files(source):
    """Lists the files under a mod folder that belong in the upload, as relative paths."""
    files = []
    for root, dirs, names in os.walk(source):
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        for name in sorted(names):
            if not name.startswith("."):
                files.append(Path(root, name).relative_to(source))
    return files


def blocked(files):
    """Returns the files the uploader would reject by type."""
    return [f for f in files if f.name.lower().endswith(BLOCKED_SUFFIXES)]


def item_dir(workshop_root, the_id):
    """Returns the uploader folder for a mod id."""
    return Path(workshop_root, the_id)


def stage(mod_dir, workshop_root, mods_root):
    """Builds the uploader folder for one mod and unlinks its dev symlink; returns the item folder."""
    mod_dir = Path(mod_dir)
    the_id = mod_id(mod_dir)
    meta_text = Path(mod_dir, "workshop", "workshop.txt").read_text()
    description = Path(mod_dir, "workshop", "description.bbcode").read_text()
    preview = Path(mod_dir, "workshop", "preview.png")
    meta = manifest.parse(meta_text)
    problems = manifest.check(meta)
    if not description.strip():
        problems.append("description.bbcode is empty")
    if not preview.is_file():
        problems.append("workshop/preview.png is missing; make it with the preview command")
    source = mod_dir / "mod" / the_id
    files = shipped_files(source)
    problems += [f"{f} has a file type the Workshop refuses" for f in blocked(files)]
    if problems:
        raise ValueError("; ".join(problems))

    item = item_dir(workshop_root, the_id)
    target = item / "Contents" / "mods" / the_id
    if target.exists():
        shutil.rmtree(target)
    for rel in files:
        dest = target / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / rel, dest)

    staged_txt = item / "workshop.txt"
    if staged_txt.exists() and not meta.get("id"):
        # Keep an id the game wrote after an upload we haven't collected yet.
        meta.setdefault("id", manifest.parse(staged_txt.read_text()).get("id"))
    staged_txt.write_text(manifest.render(meta, description))
    shutil.copy2(preview, item / "preview.png")

    link = Path(mods_root, the_id)
    if link.is_symlink():
        link.unlink()
    return item


def collect_id(mod_dir, workshop_root):
    """Copies the Workshop id the game wrote after an upload back into the repo; returns it."""
    mod_dir = Path(mod_dir)
    staged = manifest.parse((item_dir(workshop_root, mod_id(mod_dir)) / "workshop.txt").read_text())
    workshop_id = staged.get("id")
    if not workshop_id:
        raise ValueError("the staged workshop.txt has no id yet; upload the item first")
    repo_txt = mod_dir / "workshop" / "workshop.txt"
    repo_txt.write_text(manifest.with_id(repo_txt.read_text(), workshop_id))
    return workshop_id
