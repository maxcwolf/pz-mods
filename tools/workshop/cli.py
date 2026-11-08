"""Command line for getting mods onto the Steam Workshop.

  python3 tools/workshop/cli.py preview <mod>     screenshot.png -> preview.png and poster.png
  python3 tools/workshop/cli.py stage <mod>       copy into ~/Zomboid/Workshop for the uploader
  python3 tools/workshop/cli.py collect-id <mod>  save the id the game wrote after an upload
  python3 tools/workshop/cli.py check             check every mod's Workshop files
"""

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import manifest  # noqa: E402
import stage  # noqa: E402
import thumbnail  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
ZOMBOID = Path(os.environ.get("ZOMBOID_HOME", Path.home() / "Zomboid"))


def mod_dirs():
    """Lists every mod folder in the repo."""
    return sorted(p for p in REPO.iterdir() if (p / "mod").is_dir())


def short_name(mod_dir):
    """Returns the mod's name from mod.info without the jabroni's prefix."""
    info = (mod_dir / "mod" / stage.mod_id(mod_dir) / "42" / "mod.info").read_text()
    name = re.search(r"^name=(.*)$", info, re.M).group(1).strip()
    return name.removeprefix("jabroni's ").strip()


def set_poster(info_text):
    """Returns mod.info text with a poster=poster.png line."""
    if re.search(r"^poster=", info_text, re.M):
        return re.sub(r"^poster=.*$", "poster=poster.png", info_text, flags=re.M)
    return info_text.rstrip("\n") + "\nposter=poster.png\n"


def cmd_preview(mod_dir):
    """Makes preview.png and the in-game poster.png from workshop/screenshot.png."""
    shot = mod_dir / "workshop" / "screenshot.png"
    if not shot.is_file():
        raise SystemExit(f"Take an in-game screenshot and save it as {shot}")
    out = mod_dir / "workshop" / "preview.png"
    plan = thumbnail.make_preview(shot, short_name(mod_dir), out)
    version_dir = mod_dir / "mod" / stage.mod_id(mod_dir) / "42"
    (version_dir / "poster.png").write_bytes(out.read_bytes())
    info = version_dir / "mod.info"
    info.write_text(set_poster(info.read_text()))
    print(f"Wrote {out} and {version_dir / 'poster.png'} ({len(plan['lines'])} line name, {plan['size']} px)")


def cmd_stage(mod_dir):
    """Stages one mod for the in-game uploader."""
    item = stage.stage(mod_dir, ZOMBOID / "Workshop", ZOMBOID / "mods")
    print(f"Staged {item}")
    print("Removed the ~/Zomboid/mods link so the two copies don't clash.")
    print(f"After uploading: python3 tools/workshop/cli.py collect-id {mod_dir.name}")
    print(f"Back to the dev copy: {mod_dir.name}/scripts/install.sh")


def cmd_collect_id(mod_dir):
    """Saves the Workshop id into the repo after the first upload."""
    print(f"Workshop id {stage.collect_id(mod_dir, ZOMBOID / 'Workshop')} saved to {mod_dir.name}/workshop/workshop.txt")


def cmd_check():
    """Reports what each mod still needs before it can be staged."""
    bad = 0
    for mod_dir in mod_dirs():
        w = mod_dir / "workshop"
        problems = []
        if (w / "workshop.txt").is_file():
            problems += manifest.check(manifest.parse((w / "workshop.txt").read_text()))
        else:
            problems.append("workshop.txt missing")
        if not (w / "description.bbcode").is_file():
            problems.append("description.bbcode missing")
        if not (w / "screenshot.png").is_file():
            problems.append("screenshot.png missing (take one in game)")
        if not (w / "preview.png").is_file():
            problems.append("preview.png missing (run preview)")
        bad += bool(problems)
        print(f"{mod_dir.name}: {'ready' if not problems else '; '.join(problems)}")
    return 1 if bad else 0


def main(argv):
    """Runs one subcommand."""
    if len(argv) == 1 and argv[0] == "check":
        return cmd_check()
    if len(argv) != 2 or argv[0] not in ("preview", "stage", "collect-id"):
        print(__doc__)
        return 2
    mod_dir = REPO / argv[1]
    if not (mod_dir / "mod").is_dir():
        raise SystemExit(f"No mod folder named {argv[1]}")
    {"preview": cmd_preview, "stage": cmd_stage, "collect-id": cmd_collect_id}[argv[0]](mod_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
