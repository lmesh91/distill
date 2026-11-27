# builds "Distill Mono": Departure Mono 1.500 (SIL OFL 1.1, Helena Zhang) plus pixel glyphs
# for the Lean symbols it's missing, drawn on the same 7 x 50-unit grid
#
# usage, from the repo root:
#   pip install fonttools skia-pathops brotli
#   python3 scripts/fonts/build-distill-mono.py
#
# to add a symbol, add a glyph(...) line below: one string per pixel row, top to bottom,
# 7 characters wide, '#' for a filled pixel. `top` is the row of the first string, where
# 0 is the baseline, 3 is the math axis (middle of = and +), 5 is x-height and 7 is cap height
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.t2CharStringPen import T2CharStringPen
import pathops

SRC = sys.argv[1] if len(sys.argv) > 1 else 'scripts/fonts/departure-mono/DepartureMono-Regular.otf'
OUT = sys.argv[2] if len(sys.argv) > 2 else 'src/lib/assets/fonts'
PX = 50

# every glyph is 7 pixels wide, matching the font's 350-unit advance
G = {}


def glyph(cp, top, *rows):
	assert all(len(r) == 7 for r in rows), (hex(cp), rows)
	G[cp] = (top, rows)


def flip_v(rows):
	return tuple(reversed(rows))


def flip_h(rows):
	return tuple(r[::-1] for r in rows)


A = ('...#...', '..#.#..', '.#...#.', '.#...#.', '.#####.', '.#...#.', '.#...#.', '.#...#.')
E = ('.#####.', '.#.....', '.#.....', '.####..', '.#.....', '.#.....', '.#.....', '.#####.')

# logic
glyph(0x2200, 7, *flip_v(A))  # ∀
glyph(0x2203, 7, *flip_h(E))  # ∃
AND = ('...#...', '...#...', '..#.#..', '..#.#..', '.#...#.', '.#...#.')
glyph(0x2227, 5, *AND)  # ∧
glyph(0x2228, 5, *flip_v(AND))  # ∨
glyph(0x22A2, 6, '.#.....', '.#.....', '.#.....', '.#####.', '.#.....', '.#.....', '.#.....')  # ⊢
TOP = ('.#####.', '...#...', '...#...', '...#...', '...#...', '...#...', '...#...')
glyph(0x22A4, 6, *TOP)  # ⊤
glyph(0x22A5, 6, *flip_v(TOP))  # ⊥

# sets
ELEM = ('..####.', '.#.....', '.#####.', '.#.....', '..####.')
glyph(0x2208, 5, *ELEM)  # ∈
glyph(0x220B, 5, *flip_h(ELEM))  # ∋
glyph(0x2209, 6, '....#..', '..###..', '.#.#...', '.####..', '.##....', '..###..', '.#.....')  # ∉
SUB = ('..####.', '.#.....', '.#.....', '.#.....', '..####.')
glyph(0x2282, 5, *SUB)  # ⊂
glyph(0x2283, 5, *flip_h(SUB))  # ⊃
SUBEQ = ('..####.', '.#.....', '.#.....', '.#.....', '..####.', '.......', '.#####.')
glyph(0x2286, 6, *SUBEQ)  # ⊆
glyph(0x2287, 6, *flip_h(SUBEQ))  # ⊇
CAP = ('..###..', '.#...#.', '.#...#.', '.#...#.', '.#...#.', '.#...#.')
glyph(0x2229, 5, *CAP)  # ∩
glyph(0x222A, 5, *flip_v(CAP))  # ∪
glyph(0x2205, 7, '..###.#', '.#...#.', '.#..##.', '.#.#.#.', '.##..#.', '.#...#.', '##...#.', '..###..')  # ∅ (as Ø)
glyph(0x2216, 7, '.#.....', '.#.....', '..#....', '...#...', '...#...', '....#..', '.....#.', '.....#.')  # ∖

# number sets: a doubled stem stands in for the double strike
glyph(0x2115, 7, '.##..#.', '.##..#.', '.###.#.', '.##.##.', '.##..#.', '.##..#.', '.##..#.', '.##..#.')  # ℕ
glyph(0x2124, 7, '.#####.', '....##.', '...##..', '..##...', '.##....', '.#.....', '.#.....', '.#####.')  # ℤ
glyph(0x211A, 7, '..###..', '.##..#.', '.##..#.', '.##..#.', '.##..#.', '.##..#.', '.##..#.', '..###..',
      '....##.')  # ℚ
glyph(0x211D, 7, '.####..', '.##..#.', '.##..#.', '.##..#.', '.####..', '.###...', '.##.#..', '.##..#.')  # ℝ

# arrows and operators (math axis is row 3)
glyph(0x2194, 5, '.#...#.', '#.....#', '#######', '#.....#', '.#...#.')  # ↔
glyph(0x21A6, 5, '....#..', '#....#.', '#######', '#....#.', '....#..')  # ↦
glyph(0x2218, 4, '..###..', '..#.#..', '..###..')  # ∘
glyph(0x25B8, 5, '..#....', '..##...', '..###..', '..##...', '..#....')  # ▸
glyph(0x2223, 8, '...#...', '...#...', '...#...', '...#...', '...#...', '...#...', '...#...', '...#...',
      '...#...', '...#...')  # ∣

# superscripts used in Lean (x⁻¹, Sᶜ)
glyph(0x207B, 6, '..###..')  # ⁻
glyph(0x1D9C, 7, '..###..', '.#.....', '.#.....', '..###..')  # ᶜ


def outline(top, rows):
	path = pathops.Path()
	for i, row in enumerate(rows):
		y = (top - i) * PX
		for x, c in enumerate(row):
			if c == '#':
				px = x * PX
				path.moveTo(px, y)
				path.lineTo(px + PX, y)
				path.lineTo(px + PX, y + PX)
				path.lineTo(px, y + PX)
				path.close()
	path.simplify(fix_winding=True)
	return path


font = TTFont(SRC)
cff = font['CFF '].cff
top_dict = cff.topDictIndex[0]
charstrings = top_dict.CharStrings
cmap_has = font.getBestCmap()
order = font.getGlyphOrder()
added = []
for cp, (top, rows) in sorted(G.items()):
	if cp in cmap_has:
		continue
	name = f'uni{cp:04X}' if cp <= 0xFFFF else f'u{cp:05X}'
	path = outline(top, rows)
	pen = T2CharStringPen(None, None)  # 350 is defaultWidthX, so no width operand
	path.draw(pen)
	cs = pen.getCharString(private=top_dict.Private, globalSubrs=cff.GlobalSubrs)
	if charstrings.charStringsAreIndexed:
		charstrings.charStringsIndex.append(cs)
		charstrings.charStrings[name] = len(charstrings.charStringsIndex) - 1
	else:
		charstrings.charStrings[name] = cs
	order.append(name)
	font['hmtx'][name] = (350, 0)
	for table in font['cmap'].tables:
		if table.format == 12 or (table.format == 4 and cp <= 0xFFFF):
			table.cmap[cp] = name
	added.append(chr(cp))

top_dict.charset = order
font.setGlyphOrder(order)
font['maxp'].numGlyphs = len(order)

# a modified OFL font shouldn't claim to be the original, so it gets its own name
FAMILY = 'Distill Mono'
names = font['name']
for rec in list(names.names):
	if rec.nameID in (1, 16):
		rec.string = FAMILY
	elif rec.nameID == 3:
		rec.string = '1.500-distill.1;DistillMono-Regular'
	elif rec.nameID == 4:
		rec.string = f'{FAMILY} Regular'
	elif rec.nameID == 6:
		rec.string = 'DistillMono-Regular'
	elif rec.nameID == 5:
		rec.string = 'Version 1.500; Distill modification 1'
	elif rec.nameID == 0:
		rec.string = 'Copyright 2022-2024 Helena Zhang (Departure Mono). Lean symbols added 2026 by the Distill team.'
top_dict.FullName = f'{FAMILY} Regular'
top_dict.FamilyName = FAMILY
cff.fontNames = ['DistillMono-Regular']

font.flavor = 'woff2'
font.save(f'{OUT}/distill-mono.woff2')
print('added', len(added), ''.join(added))
