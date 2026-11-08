"""Makes the Option A Workshop thumbnail: a real screenshot over a plain black name bar.

512x512, 8-bit RGB PNG (the game's uploader limit). The bar reads "jabroni's"
small, the mod name big in Arial Bold, and "B42 · SP" in the corner.
"""

from PIL import Image, ImageDraw, ImageFont

SIZE = 512
PAD_X = 24
BAR_ONE_LINE = 120
BAR_TWO_LINES = 156
TAG = "B42 · SP"
BAR_COLOR = (17, 17, 17)
SOFT_TEXT = (207, 207, 207)
NAME_TEXT = (255, 255, 255)
FONT_DIR = "/System/Library/Fonts/Supplemental/"
REGULAR = FONT_DIR + "Arial.ttf"
BOLD = FONT_DIR + "Arial Bold.ttf"


def font(path, size):
    """Loads a TrueType font at a pixel size."""
    return ImageFont.truetype(path, size)


def measurer(path):
    """Returns a function giving the pixel width of text in a font at a size."""
    cache = {}

    def measure(text, size):
        if size not in cache:
            cache[size] = font(path, size)
        return cache[size].getlength(text)

    return measure


def wrap_two(name):
    """Splits a name into two lines at the space nearest its middle, longer line first on a tie."""
    words = name.split()
    if len(words) < 2:
        return [name]
    best = min(range(1, len(words)), key=lambda i: (abs(len(" ".join(words[:i])) - len(" ".join(words[i:]))), -i))
    return [" ".join(words[:best]), " ".join(words[best:])]


def layout(name, measure, room):
    """Picks the name's lines and font size so it fits the room beside the tag."""
    for size in range(44, 33, -2):
        if measure(name, size) <= room:
            return {"lines": [name], "size": size, "bar": BAR_ONE_LINE}
    lines = wrap_two(name)
    for size in range(36, 25, -2):
        if all(measure(line, size) <= room for line in lines):
            return {"lines": lines, "size": size, "bar": BAR_TWO_LINES}
    raise ValueError(f"{name!r} is too long for the name bar; shorten it")


def cover(image, width, height):
    """Scales and center-crops an image to fill exactly width x height."""
    scale = max(width / image.width, height / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)
    left = (resized.width - width) // 2
    top = (resized.height - height) // 2
    return resized.crop((left, top, left + width, top + height))


def make_preview(screenshot_path, name, out_path):
    """Writes the thumbnail for a mod name over a screenshot and returns its layout."""
    tag_font = font(BOLD, 18)
    room = SIZE - 2 * PAD_X - tag_font.getlength(TAG) - 16
    plan = layout(name, measurer(BOLD), room)
    bar = plan["bar"]

    canvas = Image.new("RGB", (SIZE, SIZE), BAR_COLOR)
    shot = Image.open(screenshot_path).convert("RGB")
    canvas.paste(cover(shot, SIZE, SIZE - bar), (0, 0))

    draw = ImageDraw.Draw(canvas)
    name_font = font(BOLD, plan["size"])
    line_height = round(plan["size"] * 1.05)
    bottom = SIZE - 18
    name_top = bottom - line_height * len(plan["lines"])
    draw.text((PAD_X, name_top - 6), "jabroni's", font=font(REGULAR, 24), fill=SOFT_TEXT, anchor="ls")
    for i, line in enumerate(plan["lines"]):
        draw.text((PAD_X, name_top + line_height * (i + 1) - round(plan["size"] * 0.2)), line,
                  font=name_font, fill=NAME_TEXT, anchor="ls")
    draw.text((SIZE - PAD_X, bottom - 4), TAG, font=tag_font, fill=SOFT_TEXT, anchor="rs")

    canvas.save(out_path, "PNG", optimize=True)
    return plan
