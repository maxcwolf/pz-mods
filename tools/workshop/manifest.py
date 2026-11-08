"""Reads and writes Project Zomboid workshop.txt files.

The format comes from the game's own SteamWorkshopItem class (42.21):
`key=value` lines, one `description=` line per line of text, tags joined
with ";" and visibility stored as a word.
"""

VISIBILITIES = ("public", "friendsOnly", "private", "unlisted")

ALLOWED_TAGS = (
    "Build 40", "Build 41", "Build 42", "Animals", "Audio", "Balance",
    "Building", "Clothing/Armor", "Farming", "Food", "Framework", "Hardmode",
    "Interface", "Items", "Language/Translation", "Literature", "Map",
    "Military", "Misc", "Models", "Multiplayer", "Pop Culture", "Realistic",
    "Silly/Fun", "Skills", "Textures", "Traits", "Vehicles", "QoL", "WIP",
    "Weapons",
)


def parse(text):
    """Parses workshop.txt text into a dict with description as a list of lines."""
    meta = {"description": []}
    for raw in text.splitlines():
        if "=" not in raw:
            continue
        key, value = raw.split("=", 1)
        key = key.strip()
        if key == "description":
            meta["description"].append(value)
        elif key == "tags":
            meta["tags"] = [t.strip() for t in value.split(";") if t.strip()]
        else:
            meta[key] = value.strip()
    return meta


def check(meta):
    """Returns a list of problems that would stop or spoil an upload."""
    problems = []
    if not meta.get("title"):
        problems.append("title is missing")
    for tag in meta.get("tags", []):
        if tag not in ALLOWED_TAGS:
            problems.append(f"tag {tag!r} is not one the Workshop offers")
    if "Multiplayer" in meta.get("tags", []):
        problems.append("these mods are single player; drop the Multiplayer tag")
    if meta.get("visibility", "public") not in VISIBILITIES:
        problems.append(f"visibility must be one of {', '.join(VISIBILITIES)}")
    if meta.get("id") and not meta["id"].isdigit():
        problems.append("id must be the numeric Workshop id")
    return problems


def render(meta, description_text):
    """Renders workshop.txt text from metadata plus a multi-line description."""
    lines = ["version=1"]
    if meta.get("id"):
        lines.append(f"id={meta['id']}")
    lines.append(f"title={meta['title']}")
    for line in description_text.rstrip("\n").split("\n"):
        lines.append(f"description={line.rstrip()}")
    lines.append("tags=" + ";".join(meta.get("tags", [])))
    lines.append(f"visibility={meta.get('visibility', 'public')}")
    return "\n".join(lines) + "\n"


def with_id(text, workshop_id):
    """Returns workshop.txt text with its id line set, added after version if absent."""
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.startswith("id="):
            lines[i] = f"id={workshop_id}"
            return "\n".join(lines) + "\n"
    at = 1 if lines and lines[0].startswith("version=") else 0
    lines.insert(at, f"id={workshop_id}")
    return "\n".join(lines) + "\n"
