# Distill Mono

`distill-mono.woff2` is the monospace font for Lean code in the editor, the Lean output and
code samples (`--font-mono` in `src/lib/styles/tokens.css`).

It's [Departure Mono](https://departuremono.com) 1.500 by Helena Zhang, with pixel glyphs added
for the Lean symbols it doesn't include:

```
∀ ∃ ∧ ∨ ⊢ ⊤ ⊥ ∈ ∉ ∋ ⊂ ⊃ ⊆ ⊇ ∩ ∪ ∅ ∖ ℕ ℤ ℚ ℝ ↔ ↦ ∘ ▸ ∣ ⁻ ᶜ
```

The added glyphs are drawn on the original's 7 x 11 pixel grid so they match the rest of the font.
Everything else is unchanged.

## License

Departure Mono is licensed under the [SIL Open Font License 1.1](OFL.txt), which allows
modifying and redistributing it, including in a web app. It declares no Reserved Font Name, but
the modified version is still renamed to "Distill Mono" so it isn't mistaken for the original.
The license file must stay next to the font.

## Sizes

The font is pixel art drawn at 11px, so it's sharpest at multiples of 11px. `--text-code` is
16.5px (3 screen pixels per font pixel on Retina displays) and `--text-code-sm` is 11px.

## Adding a symbol

The glyphs are defined in `scripts/fonts/build-distill-mono.py`, one string per pixel row.
Add a line there and rebuild from the repo root:

```sh
pip install fonttools skia-pathops brotli
python3 scripts/fonts/build-distill-mono.py
```

The original font it builds from is in `scripts/fonts/departure-mono/`.
