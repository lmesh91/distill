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
borders and shadows.

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
- **Body: Space Grotesk** (variable) for all other text and UI.
- **Code: the system monospace font** (`--font-mono`) for Lean.

Both fonts are self-hosted from npm (`@fontsource/jersey-10`, `@fontsource-variable/space-grotesk`)
under the SIL Open Font License, so no requests go to Google Fonts.

Sizes: `--text-xs` 12px, `--text-sm` 14px, `--text-md` 16px, `--text-lg` 18px, `--text-xl` 24px,
`--text-2xl` 36px, `--text-3xl` 40–56px (scales with the window).

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

- Dark mode. The tokens make it a matter of redefining the variables under
  `@media (prefers-color-scheme: dark)`, but every screen needs checking first.
- Lean syntax highlighting colors (#69) should be added here as `--syntax-*` tokens.
