# Design system

Distill's colors, type, spacing and component styles (#20). Open `/design` in the running app to
see everything below rendered live.

| File                             | What's in it                                                   |
| -------------------------------- | -------------------------------------------------------------- |
| `src/lib/styles/tokens.css`      | CSS variables for every color, font, size, space and shadow    |
| `src/lib/styles/base.css`        | Page defaults: background, body text, links, code, focus ring  |
| `src/lib/styles/components.css`  | Shared classes: `.button`, `.card`, `.badge`, `.display`, etc. |
| `src/lib/styles/clerk.ts`        | The same theme for Clerk's sign-in and sign-up components      |
| `src/lib/styles/global.css`      | Imports the three CSS files; loaded once in `+layout.svelte`   |
| `src/routes/design/+page.svelte` | The live style guide at `/design`                              |

## Rules

1. **Use a variable, not a raw value.** Write `color: var(--color-text-muted)`, not `#5b5b66`, and
   `gap: var(--space-3)`, not `12px`. If nothing fits, add a token to `tokens.css` instead of
   hard-coding it in a component.
2. **Use the shared classes** for buttons, cards and badges, and add component-specific styles on
   top in the component's `<style>`.
3. **Keep it accessible.** Every text color in `tokens.css` is at least 4.5:1 against white and
   the page background. Don't put muted text on tinted backgrounds, and don't use color as the only
   signal (pair it with an icon or text, like the save status does).
4. **Respect reduced motion.** `--duration-*` drop to 0 when the user turns animations off. Use
   them for transitions, and add a `prefers-reduced-motion` fallback for anything that loops.

## Look and feel

Distill is a game, so the style borrows from pixel art and our slide deck: an off-white "notebook
paper" page, ink-black 2px borders, solid offset "pixel" shadows, the blue from our logo, and
yellow, pink and mint accents. Text stays plain and readable; the game feel comes from headings,
borders, shadows and the pixel code font.

## Dark mode

Dark mode follows the system setting, and the sun/moon button in the nav overrides it (saved in
`localStorage` as `distill-theme`). It works by redefining the color tokens in `tokens.css`, so
components get it for free as long as they use tokens:

- Use `--color-ink` / `--color-text` for text and borders; they turn light in dark mode.
- Use `--color-shadow` for shadows (it stays black in dark mode).
- Text on the yellow highlight uses `--color-on-highlight`, and text or icons on solid status
  colors use `--color-on-status`; never hard-code `#fff` or `#000`.
- Check new screens in both themes. `/design` shows every token in whichever theme is active.

Clerk's sign-in card stays light in dark mode for now (`src/lib/styles/clerk.ts` uses fixed hex
values).

## Colors

| Token                    | Value     | Use                                                |
| ------------------------ | --------- | -------------------------------------------------- |
| `--color-brand`          | `#1a6db8` | Links, primary buttons, focus ring (logo blue)     |
| `--color-brand-strong`   | `#145a99` | Brand hover and pressed states                     |
| `--color-brand-soft`     | `#e3eef9` | Tinted backgrounds, editor selection               |
| `--color-highlight`      | `#fff269` | Marker highlight, current nav item, text selection |
| `--color-pink`           | `#f6b5d3` | Decorative accent                                  |
| `--color-mint`           | `#b8f5d9` | Decorative accent                                  |
| `--color-ink`            | `#1b1b1f` | Text, borders, pixel shadows                       |
| `--color-text-muted`     | `#5b5b66` | Secondary text                                     |
| `--color-text-subtle`    | `#6e6e78` | Timestamps, placeholders                           |
| `--color-page`           | `#faf8f3` | Page background                                    |
| `--color-surface`        | `#ffffff` | Panels, cards, the editor                          |
| `--color-surface-sunken` | `#f1eee6` | Title bars, gutters, inline code                   |
| `--color-border-subtle`  | `#d8d4c8` | Dividers inside panels                             |
| `--color-success`        | `#1a7f37` | Accepted proofs, saved                             |
| `--color-warning`        | `#9a6700` | Lean warnings                                      |
| `--color-error`          | `#b42318` | Errors                                             |
| `--color-neutral`        | `#6e6e78` | Info, idle states                                  |

Status colors also have a `-soft` background (`--color-error-soft`, etc.) for banners.

## Typography

- **Display: Jersey 10**, a pixel font, for page and section headings. Use the `.display` class,
  and only at `--text-xl` (24px) or larger; it isn't readable smaller.
- **Body: Space Grotesk** (variable) for UI: buttons, labels, navigation, status text.
- **Reading: Source Serif 4** (`--font-reading`) for level goals, descriptions and English
  translations. It sits well next to KaTeX's math, which a geometric sans like Space Grotesk
  doesn't. Level panels use it by default; their small headings stay in the body font.
- **Code: Distill Mono** (`--font-mono`) for Lean. It's Departure Mono with pixel glyphs added
  for the Lean symbols it lacked (∀ ∃ ∧ ∨ ∈ ⊆ ∩ ∪ ℕ ℝ ↔ ⊢ and more); see
  `src/lib/assets/fonts/README.md`. Use `--text-code` (16.5px) or `--text-code-sm` (11px) so its
  pixels stay sharp.

Jersey 10, Space Grotesk and Source Serif 4 are self-hosted from npm (`@fontsource`), and Distill
Mono from `src/lib/assets/fonts`, all under the SIL Open Font License, so no requests go to
Google Fonts.

Sizes: `--text-xs` 12px, `--text-sm` 14px, `--text-md` 16px, `--text-lg` 18px, `--text-xl` 24px,
`--text-2xl` 36px, `--text-3xl` 40–56px (scales with the window). Code: `--text-code` 16.5px,
`--text-code-sm` 11px.

Small panel headings (like "Your goal" and "Lean output") use `--text-xs`, bold, uppercase, with
`letter-spacing: 0.06em`, in `--color-text-muted`.

## Spacing and shape

- Spacing is in 4px steps: `--space-1` (4px) through `--space-8` (64px).
- Borders are `--border-width` (2px) in `--color-border`. Use `--color-border-subtle` at 1px for
  dividers inside a panel.
- Radii: `--radius-sm` 4px (badges, inline code), `--radius` 6px (panels, buttons), `--radius-lg`
  10px (cards, popovers).
- Shadows: `--shadow-pixel-sm` (buttons) and `--shadow-pixel` (cards, popovers) are solid offsets,
  not blurs. `--shadow-popover` is the one soft shadow, for floating menus.
- Pages are at most `--page-width` (75rem) wide with `--page-gutter` padding on the sides.

## Components

| Class                                       | Use                                                                |
| ------------------------------------------- | ------------------------------------------------------------------ |
| `.button`                                   | Default button or button-styled link                               |
| `.button.primary`                           | The one main action on a screen (e.g. Check proof, Start learning) |
| `.button.ghost`                             | Low-emphasis actions (e.g. the back link on a level)               |
| `.button.small`                             | Toolbars and title bars (e.g. Hints, Sign out)                     |
| `.card`                                     | Standalone content tiles                                           |
| `.badge` (`.success`, `.warning`, `.error`) | Small status labels                                                |
| `.display`                                  | Pixel-font headings                                                |
| `.highlight`                                | Yellow marker highlight behind a phrase                            |
| `.muted`                                    | Secondary text                                                     |
| `.sr-only`                                  | Text only screen readers see                                       |

Buttons press into their shadow on click. Disabled buttons lose the shadow and fade.

## Not done yet

- Lean syntax highlighting colors (#69) should be added here as `--syntax-*` tokens, with values
  for both themes.
- Clerk's components in dark mode.
