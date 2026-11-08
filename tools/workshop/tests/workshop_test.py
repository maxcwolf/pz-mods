"""Tests for the Workshop tools. Run: python3 -m unittest discover -s tools/workshop/tests -p '*_test.py'"""

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from PIL import Image  # noqa: E402

import cli  # noqa: E402
import manifest  # noqa: E402
import stage  # noqa: E402
import thumbnail  # noqa: E402


def make_mod(root, mod_id="DemoMod", description="Line one\n\nLine three\n", preview=True):
    """Builds a minimal repo-style mod folder under root and returns its path."""
    mod_dir = Path(root, "demo")
    version = mod_dir / "mod" / mod_id / "42"
    (version / "media" / "lua" / "client").mkdir(parents=True)
    (version / "mod.info").write_text(f"name=jabroni's Demo\nid={mod_id}\n")
    (version / "media" / "lua" / "client" / "demo.lua").write_text("return 1\n")
    (version / ".DS_Store").write_text("junk")
    w = mod_dir / "workshop"
    w.mkdir()
    (w / "workshop.txt").write_text("version=1\ntitle=jabroni's Demo [B42] [SP]\ntags=Build 42;QoL\nvisibility=unlisted\n")
    (w / "description.bbcode").write_text(description)
    if preview:
        Image.new("RGB", (512, 512)).save(w / "preview.png")
    return mod_dir


class ManifestTest(unittest.TestCase):
    """workshop.txt parsing, checking and rendering."""

    def test_parse_reads_tags_and_description_lines(self):
        """Tags split on semicolons and each description line is kept."""
        meta = manifest.parse("version=1\ntitle=T\ndescription=a\ndescription=\ndescription=b=c\ntags=Build 42;QoL;\nvisibility=unlisted\n")
        self.assertEqual(meta["tags"], ["Build 42", "QoL"])
        self.assertEqual(meta["description"], ["a", "", "b=c"])
        self.assertEqual(meta["visibility"], "unlisted")

    def test_render_round_trips(self):
        """Rendered text parses back to the same fields."""
        text = manifest.render({"title": "T", "tags": ["Build 42", "QoL"], "visibility": "unlisted", "id": "123"}, "one\n\ntwo\n")
        self.assertTrue(text.startswith("version=1\nid=123\ntitle=T\n"))
        meta = manifest.parse(text)
        self.assertEqual(meta["description"], ["one", "", "two"])
        self.assertEqual(meta["tags"], ["Build 42", "QoL"])

    def test_check_flags_unknown_tags_multiplayer_and_visibility(self):
        """Unknown tags, the Multiplayer tag and a bad visibility are reported."""
        problems = manifest.check({"title": "T", "tags": ["Build 42", "Cheats", "Multiplayer"], "visibility": "hidden"})
        self.assertEqual(len(problems), 3)
        self.assertEqual(manifest.check({"title": "T", "tags": ["Build 42"], "visibility": "public"}), [])

    def test_with_id_inserts_after_version_or_replaces(self):
        """An id is added after version=1, or an existing one is replaced."""
        self.assertEqual(manifest.with_id("version=1\ntitle=T\n", "9"), "version=1\nid=9\ntitle=T\n")
        self.assertEqual(manifest.with_id("version=1\nid=1\ntitle=T\n", "9"), "version=1\nid=9\ntitle=T\n")


class StageTest(unittest.TestCase):
    """Copying a mod into the uploader's layout."""

    def test_stage_builds_the_uploader_folder_and_unlinks_the_dev_copy(self):
        """Files land under Contents/mods, dotfiles stay behind and the symlink goes."""
        with tempfile.TemporaryDirectory() as tmp:
            mod_dir = make_mod(tmp)
            workshop_root, mods_root = Path(tmp, "Workshop"), Path(tmp, "mods")
            mods_root.mkdir()
            (mods_root / "DemoMod").symlink_to(mod_dir / "mod" / "DemoMod")
            item = stage.stage(mod_dir, workshop_root, mods_root)
            shipped = item / "Contents" / "mods" / "DemoMod" / "42"
            self.assertTrue((shipped / "mod.info").is_file())
            self.assertTrue((shipped / "media" / "lua" / "client" / "demo.lua").is_file())
            self.assertFalse((shipped / ".DS_Store").exists())
            self.assertTrue((item / "preview.png").is_file())
            meta = manifest.parse((item / "workshop.txt").read_text())
            self.assertEqual(meta["description"], ["Line one", "", "Line three"])
            self.assertFalse((mods_root / "DemoMod").exists())

    def test_stage_keeps_an_id_the_game_wrote(self):
        """Restaging before collect-id doesn't lose the id from the last upload."""
        with tempfile.TemporaryDirectory() as tmp:
            mod_dir = make_mod(tmp)
            item = stage.stage(mod_dir, Path(tmp, "W"), Path(tmp, "m"))
            (item / "workshop.txt").write_text(manifest.with_id((item / "workshop.txt").read_text(), "777"))
            stage.stage(mod_dir, Path(tmp, "W"), Path(tmp, "m"))
            self.assertEqual(manifest.parse((item / "workshop.txt").read_text())["id"], "777")

    def test_stage_refuses_missing_preview_and_blocked_files(self):
        """No preview, or a shell script in the mod, stops staging."""
        with tempfile.TemporaryDirectory() as tmp:
            mod_dir = make_mod(tmp, preview=False)
            (mod_dir / "mod" / "DemoMod" / "42" / "run.sh").write_text("echo")
            with self.assertRaises(ValueError) as caught:
                stage.stage(mod_dir, Path(tmp, "W"), Path(tmp, "m"))
            self.assertIn("preview.png", str(caught.exception))
            self.assertIn("run.sh", str(caught.exception))

    def test_collect_id_copies_the_id_into_the_repo(self):
        """The id written by the game ends up in the repo's workshop.txt."""
        with tempfile.TemporaryDirectory() as tmp:
            mod_dir = make_mod(tmp)
            item = stage.stage(mod_dir, Path(tmp, "W"), Path(tmp, "m"))
            with self.assertRaises(ValueError):
                stage.collect_id(mod_dir, Path(tmp, "W"))
            (item / "workshop.txt").write_text(manifest.with_id((item / "workshop.txt").read_text(), "3812345678"))
            self.assertEqual(stage.collect_id(mod_dir, Path(tmp, "W")), "3812345678")
            self.assertIn("id=3812345678", (mod_dir / "workshop" / "workshop.txt").read_text())

    def test_mod_id_needs_exactly_one_folder(self):
        """A mod folder must hold one mod id folder."""
        with tempfile.TemporaryDirectory() as tmp:
            mod_dir = make_mod(tmp)
            self.assertEqual(stage.mod_id(mod_dir), "DemoMod")
            (mod_dir / "mod" / "Other").mkdir()
            with self.assertRaises(ValueError):
                stage.mod_id(mod_dir)


class ThumbnailTest(unittest.TestCase):
    """The Option A thumbnail."""

    def test_wrap_two_splits_near_the_middle(self):
        """Long names split into two balanced lines."""
        self.assertEqual(thumbnail.wrap_two("Horse Shooting & Hitching"), ["Horse Shooting", "& Hitching"])
        self.assertEqual(thumbnail.wrap_two("A-Life Reputation Editor"), ["A-Life Reputation", "Editor"])
        self.assertEqual(thumbnail.wrap_two("Single"), ["Single"])

    def test_layout_prefers_one_big_line(self):
        """Short names stay on one line at the largest size that fits."""
        measure = lambda text, size: len(text) * size * 0.6  # noqa: E731
        plan = thumbnail.layout("Starting Gear", measure, 380)
        self.assertEqual((plan["lines"], plan["size"], plan["bar"]), (["Starting Gear"], 44, thumbnail.BAR_ONE_LINE))

    def test_layout_wraps_long_names_with_a_taller_bar(self):
        """Names too wide for one line wrap onto two."""
        measure = lambda text, size: len(text) * size * 0.6  # noqa: E731
        plan = thumbnail.layout("Horse Shooting & Hitching", measure, 380)
        self.assertEqual(len(plan["lines"]), 2)
        self.assertEqual(plan["bar"], thumbnail.BAR_TWO_LINES)

    def test_layout_refuses_names_that_cannot_fit(self):
        """A name too long even on two lines is an error."""
        measure = lambda text, size: len(text) * size  # noqa: E731
        with self.assertRaises(ValueError):
            thumbnail.layout("An Extremely Long Mod Name That Will Never Fit", measure, 200)

    def test_make_preview_writes_a_512_rgb_png(self):
        """The output meets the uploader's size and format limits."""
        with tempfile.TemporaryDirectory() as tmp:
            shot = Path(tmp, "shot.png")
            Image.new("RGB", (1920, 1080), (90, 110, 90)).save(shot)
            out = Path(tmp, "preview.png")
            for name in ("Alarm Shortcut", "Horse Shooting & Hitching", "A-Life Reputation Editor"):
                thumbnail.make_preview(shot, name, out)
                with Image.open(out) as img:
                    self.assertEqual((img.size, img.mode, img.format), ((512, 512), "RGB", "PNG"))
                self.assertLess(out.stat().st_size, 1024 * 1024)


class CliTest(unittest.TestCase):
    """Small helpers in the command line."""

    def test_set_poster_adds_or_replaces(self):
        """mod.info gets exactly one poster line."""
        self.assertEqual(cli.set_poster("name=X\n"), "name=X\nposter=poster.png\n")
        self.assertEqual(cli.set_poster("name=X\nposter=old.png\n"), "name=X\nposter=poster.png\n")

    def test_every_repo_mod_has_a_name_that_fits_the_bar(self):
        """All nine real names lay out on the thumbnail."""
        measure = thumbnail.measurer(thumbnail.BOLD)
        room = thumbnail.SIZE - 2 * thumbnail.PAD_X - thumbnail.font(thumbnail.BOLD, 18).getlength(thumbnail.TAG) - 16
        for mod_dir in cli.mod_dirs():
            with self.subTest(mod=mod_dir.name):
                thumbnail.layout(cli.short_name(mod_dir), measure, room)

    def test_every_repo_workshop_txt_passes_check(self):
        """Each mod's workshop.txt has a title, real tags and no Multiplayer."""
        for mod_dir in cli.mod_dirs():
            with self.subTest(mod=mod_dir.name):
                meta = manifest.parse((mod_dir / "workshop" / "workshop.txt").read_text())
                self.assertEqual(manifest.check(meta), [])
                self.assertIn("Build 42", meta["tags"])
                self.assertTrue(meta["title"].startswith("jabroni's ") and meta["title"].endswith("[B42] [SP]"))


if __name__ == "__main__":
    unittest.main()
